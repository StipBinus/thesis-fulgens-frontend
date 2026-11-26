import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/parent_ui.dart';
import 'children_account_card.dart';
import 'children_calendar.dart';
import 'home_page_provider.dart';
import 'spending_chart_card.dart';

// Parent home
//
// Layout follows Fuse's wallet screen: a small greeting with the date, a hero
// balance with a sparkline, a 2x2 tile grid, then the detail cards. Fulgens'
// warm palette replaces Fuse's monochrome one.
class ParentHomePage extends StatelessWidget {
  const ParentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentPalette.canvas,
      body: const ParentHomePageBody(),
      bottomNavigationBar: ParentBottomNav(
        index: 0,
        onSelect: (index) {
          if (index == 1) context.go('/parent/tasks');
          if (index == 2) context.go('/parent/answers');
        },
        onFabPressed: () => context.go('/child-register'),
        fabTooltip: 'Add child',
      ),
    );
  }
}

class ParentHomePageBody extends StatelessWidget {
  const ParentHomePageBody({super.key});

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: ParentHomePageTopMessage(),
            ),
          ),

          // Child picker sits directly under the header: every card below it
          // follows the selected child, so the choice comes first.
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 0),
              child: ParentHomePageChildAccount(),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 0),
              child: _ParentHomeHero(),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: _ParentHomeTiles(),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 0),
              child: ParentHomePageCalendar(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 24 + bottomInset),
              child: const ParentHomeSpendingChart(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Greeting + today's date, the small header Fuse puts above the balance.
class ParentHomePageTopMessage extends StatelessWidget {
  const ParentHomePageTopMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: parentText(size: 20, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _todayLabel(DateTime.now()),
                style: parentText(
                  size: 12.5,
                  weight: FontWeight.w500,
                  color: ParentPalette.label,
                ),
              ),
            ],
          ),
        ),
        Image.asset(
          'assets/app/fulgens_logo_parent.png',
          height: 26,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

/// Balance hero for the selected child, with the sparkline under it.
class _ParentHomeHero extends ConsumerWidget {
  const _ParentHomeHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childAccountsProvider);
    final child = ref.watch(selectedChildProvider);
    final count = children.asData?.value.length ?? 0;

    if (children.hasError) {
      return ParentCard(
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 20,
              color: ParentPalette.faint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${children.error}',
                style: parentText(
                  size: 12.5,
                  weight: FontWeight.w500,
                  color: ParentPalette.label,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(childAccountsProvider),
              child: Text(
                'Retry',
                style: parentText(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: ParentPalette.accent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParentHeroBalance(
          amount: child?.userBalance ?? 0,
          label: 'Total balance',
          badge: count > 0 ? '$count ${count == 1 ? 'child' : 'children'}' : null,
          caption:
              child == null
                  ? 'Link a child to start tracking'
                  : '${child.name} · everyday balance',
        ),
        const SizedBox(height: 14),
        ParentSparkline(
          values: _placeholderTrend(child?.childId ?? 'empty', 26),
        ),
      ],
    );
  }
}

/// The 2x2 tile grid that replaced Fuse's Cash / Investments / Earn / Card.
class _ParentHomeTiles extends ConsumerWidget {
  const _ParentHomeTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    final childCount = ref.watch(childAccountsProvider).asData?.value.length ?? 0;
    final now = DateTime.now();

    // Both keys match the ones the cards below use, so the provider cache is
    // shared and no extra request goes out.
    final spending =
        child == null
            ? null
            : ref.watch(
              spendingChartProvider((
                childId: child.childId,
                startDate: DateTime(now.year, now.month, 1),
                endDate: DateTime(now.year, now.month, now.day),
              )),
            );
    final logs =
        child == null
            ? null
            : ref.watch(
              childLogMonthProvider((
                childId: child.childId,
                year: now.year,
                month: now.month,
              )),
            );

    final spent = spending?.asData?.value.total;
    final loggedDays = logs?.asData?.value.length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ParentTile(
                icon: Icons.people_alt_rounded,
                label: 'Children',
                caption:
                    childCount == 0
                        ? 'Add the first one'
                        : '$childCount ${childCount == 1 ? 'child' : 'children'} linked',
                tint: ParentPalette.accent,
                onTap: () => context.go('/child-register'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ParentTile(
                icon: Icons.stars_rounded,
                label: 'Game coins',
                caption: child == null ? '—' : parentGrouped(child.userCurrency),
                tint: const Color(0xFFB07A12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ParentTile(
                icon: Icons.pie_chart_rounded,
                label: 'Spending',
                caption:
                    spent == null ? 'This month' : parentRupiah(spent),
                tint: const Color(0xFF2A6EA8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ParentTile(
                icon: Icons.menu_book_rounded,
                label: 'Logbook',
                caption:
                    loggedDays == null
                        ? 'This month'
                        : loggedDays == 0
                        ? 'Nothing logged yet'
                        : '$loggedDays ${loggedDays == 1 ? 'day' : 'days'} logged',
                tint: const Color(0xFF7B4FBF),
                dashed: loggedDays == 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ helpers

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// `Sun, 15 Nov 2026`.
String _todayLabel(DateTime date) {
  return '${_weekdays[date.weekday - 1]}, ${date.day} '
      '${_months[date.month - 1]} ${date.year}';
}

/// Placeholder trend for the sparkline.
///
/// There is no time-series endpoint yet (the chart endpoint returns category
/// totals only), so the bars are derived from the child id. Swap this for real
/// daily totals once the backend exposes them.
List<double> _placeholderTrend(String seed, int points) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }

  return [
    for (var i = 0; i < points; i++)
      () {
        hash = (hash * 1103515245 + 12345) & 0x7fffffff;
        return 0.35 + (hash % 65) / 100;
      }(),
  ];
}
