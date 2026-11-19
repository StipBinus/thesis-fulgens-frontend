import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../model/ChildAccount.dart';
import '../ui/parent_ui.dart';
import 'home_page_provider.dart';
import 'selected_child_provider.dart';

/// Card listing every child linked to the parent, with a tab per child.
///
/// The selected tab is stored in [selectedChildIdProvider] so the calendar and
/// the spending chart below follow it without extra wiring.
///
/// The tabs use the same underline treatment as Fuse's range selector, and the
/// card itself is a flat [ParentCard] instead of a bordered box.
class ParentHomePageChildAccount extends ConsumerWidget {
  const ParentHomePageChildAccount({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childAccountsProvider);

    return ParentCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your Children',
                  style: parentText(size: 15, weight: FontWeight.w700),
                ),
              ),
              _addChildButton(context),
            ],
          ),
          const SizedBox(height: 6),
          _body(ref, children),
        ],
      ),
    );
  }

  Widget _addChildButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/child-register'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 16,
                color: ParentPalette.accent,
              ),
              const SizedBox(width: 4),
              Text(
                'Add',
                style: parentText(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: ParentPalette.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(WidgetRef ref, AsyncValue<List<ChildAccount>> children) {
    if (children.isLoading && !children.hasValue) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: ParentPalette.accent,
            ),
          ),
        ),
      );
    }

    if (children.hasError) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${children.error}',
              style: parentText(
                size: 12.5,
                weight: FontWeight.w500,
                color: ParentPalette.red,
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(childAccountsProvider),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Try again',
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

    final list = children.asData?.value ?? const <ChildAccount>[];
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'No children linked yet.',
          style: parentText(
            size: 12.5,
            weight: FontWeight.w500,
            color: ParentPalette.label,
          ),
        ),
      );
    }

    final selected = ref.watch(selectedChildProvider) ?? list.first;
    final selectedIndex = list.indexWhere(
      (child) => child.childId == selected.childId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ParentUnderlineTabs(
          labels: [for (final child in list) child.name],
          index: selectedIndex < 0 ? 0 : selectedIndex,
          onChanged:
              (index) => ref
                  .read(selectedChildIdProvider.notifier)
                  .select(list[index].childId),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(selected.childId),
            child: _childCard(selected),
          ),
        ),
      ],
    );
  }

  Widget _childCard(ChildAccount child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      decoration: BoxDecoration(
        color: ParentPalette.raised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(child.name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: parentText(size: 17, weight: FontWeight.w700),
                    ),
                    // TODO: age and grade are not part of the endpoint's
                    // response yet. Add the line here once the backend
                    // returns them.
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: ParentPalette.faint,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();

    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ParentPalette.accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: parentText(
          size: 20,
          weight: FontWeight.w700,
          color: ParentPalette.accentDeep,
        ),
      ),
    );
  }
}
