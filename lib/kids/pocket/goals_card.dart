import 'package:flutter/material.dart';

import '../finance/finance_models.dart';
import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';
import 'history_timeline.dart';

// Placeholder goal activity until the backend sends real history
const List<HistoryEntry> _goalHistory = <HistoryEntry>[
  HistoryEntry('Added money', 25000, 'Today', true),
  HistoryEntry('Added money', 10000, 'Today', true),
];

// Goal card: pocket-style card with the ring wrapped around the flag
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.onAdd,
    required this.onTransfer,
    required this.onEdit,
  });

  final ChildGoal goal;
  final VoidCallback onAdd;
  final VoidCallback? onTransfer;
  final VoidCallback onEdit;

  String get _desc {
    final value = (goal.goalsDesc ?? '').trim();
    return value.isEmpty ? 'No description yet' : value;
  }

  @override
  Widget build(BuildContext context) {
    final Color tint = financePocketTint(goal.goalsName);
    final String target = financeRupiah(goal.goalPrice);
    final String percent = financePercent(goal.progress);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value: goal.progress,
                          strokeWidth: 4.5,
                          strokeCap: StrokeCap.round,
                          backgroundColor: logbookTrack,
                          color: logbookAccent,
                        ),
                      ),
                      Icon(Icons.flag_rounded, size: 18, color: tint),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.goalsName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                          color: logbookInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: logbookMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        financeRupiah(goal.allocatedBalance),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: logbookInk,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$percent of $target',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: logbookFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const HistoryTimeline(entries: _goalHistory),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _action(
                    label: 'Add',
                    icon: Icons.add_rounded,
                    strong: true,
                    accentTint: tint,
                    onTap: onAdd,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _action(
                    label: 'Transfer',
                    icon: Icons.swap_horiz_rounded,
                    onTap: onTransfer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _action(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    onTap: onEdit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _action({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool strong = false,
    Color? accentTint,
  }) {
    final bool tinted = strong && accentTint != null;
    final Color fg = tinted ? accentTint : logbookInk;
    final Color line =
        tinted
            ? accentTint.withValues(alpha: 0.5)
            : (strong ? logbookInk : logbookLine);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: line, width: strong ? 1.3 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
