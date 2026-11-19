import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/ChildAccount.dart';
import '../ui/parent_ui.dart';
import 'home_models.dart';
import 'home_page_provider.dart';

/// Donut chart of the selected child's spending per category.
///
/// The card follows [selectedChildProvider] and asks
/// [spendingChartProvider] for the chosen [SpendingPeriod]. The period picker
/// is an underline tab row, matching the range selector on Fuse's wallet.
class ParentHomeSpendingChart extends ConsumerStatefulWidget {
  const ParentHomeSpendingChart({super.key});

  @override
  ConsumerState<ParentHomeSpendingChart> createState() =>
      _ParentHomeSpendingChartState();
}

class _ParentHomeSpendingChartState
    extends ConsumerState<ParentHomeSpendingChart> {
  SpendingPeriod _period = SpendingPeriod.thisMonth;

  static const List<String> _periodLabels = [
    'This month',
    'Last month',
    'Last 3 months',
  ];

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider);
    final range = _period.range(DateTime.now());
    final key =
        child == null
            ? null
            : (
              childId: child.childId,
              startDate: range.start,
              endDate: range.end,
            );

    final chart = key == null ? null : ref.watch(spendingChartProvider(key));

    return ParentCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(child),
          const SizedBox(height: 14),
          ParentUnderlineTabs(
            labels: _periodLabels,
            index: _period.index,
            onChanged:
                (index) =>
                    setState(() => _period = SpendingPeriod.values[index]),
          ),
          const SizedBox(height: 18),
          _body(ref, child, key, chart),
        ],
      ),
    );
  }

  Widget _header(ChildAccount? child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Spending',
          style: parentText(size: 15, weight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          child?.name ?? 'No child selected',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: parentText(
            size: 12,
            weight: FontWeight.w500,
            color: ParentPalette.label,
          ),
        ),
      ],
    );
  }

  Widget _body(
    WidgetRef ref,
    ChildAccount? child,
    SpendingChartKey? key,
    AsyncValue<SpendingChartData>? chart,
  ) {
    if (child == null) {
      return _placeholder('Link a child to see their spending.');
    }

    if (chart == null || key == null) {
      return _placeholder('No spending data yet.');
    }

    if (chart.hasError) {
      return _error(
        '${chart.error}',
        onRetry: () => ref.invalidate(spendingChartProvider(key)),
      );
    }

    final data = chart.asData?.value;
    if (data == null) {
      return const SizedBox(
        height: 152,
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

    if (data.isEmpty) {
      return _placeholder('No spending recorded for this period.');
    }

    return _chartRow(data);
  }

  Widget _chartRow(SpendingChartData data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 138,
          height: 138,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 2,
                  centerSpaceRadius: 43,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (var i = 0; i < data.slices.length; i++)
                      PieChartSectionData(
                        value: data.slices[i].amount.toDouble(),
                        color: _sliceColors[i % _sliceColors.length],
                        radius: 26,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total',
                      style: parentText(
                        size: 10,
                        weight: FontWeight.w500,
                        color: ParentPalette.faint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 78,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          parentRupiah(data.total),
                          style: parentText(
                            size: 14,
                            weight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < data.slices.length; i++)
                _legendRow(
                  slice: data.slices[i],
                  color: _sliceColors[i % _sliceColors.length],
                  total: data.total,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow({
    required SpendingSlice slice,
    required Color color,
    required int total,
  }) {
    final percentage =
        slice.percentage > 0
            ? slice.percentage
            : (total <= 0 ? 0.0 : slice.amount / total * 100);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              slice.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: parentText(
                size: 11.5,
                weight: FontWeight.w500,
                color: ParentPalette.label,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${percentage.round()}%',
            style: parentText(size: 11.5, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String message) {
    return SizedBox(
      height: 152,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: parentText(
            size: 12.5,
            weight: FontWeight.w500,
            color: ParentPalette.label,
          ),
        ),
      ),
    );
  }

  Widget _error(String message, {required VoidCallback onRetry}) {
    return SizedBox(
      height: 152,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 26,
              color: ParentPalette.faint,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: parentText(
                size: 12,
                weight: FontWeight.w500,
                color: ParentPalette.label,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: ParentPalette.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                'Try again',
                style: parentText(size: 12, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Warm ramp for the donut: brand orange first, then amber and peach.
const List<Color> _sliceColors = [
  Color(0xFFFF6B2C),
  Color(0xFFFF8A3D),
  Color(0xFFFFA45B),
  Color(0xFFFFC247),
  Color(0xFFEFC75E),
  Color(0xFFD98324),
  Color(0xFFC084FC),
  Color(0xFFFFD3A7),
];
