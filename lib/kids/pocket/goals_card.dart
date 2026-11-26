import 'package:flutter/material.dart';

import '../finance/finance_models.dart';
import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';
import 'activity_history.dart';
import 'pocket_row.dart';
import 'savings_row_look.dart';

// Goal card: amount first, target and progress under it
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.onAdd,
    required this.onTransfer,
    required this.onEdit,
    this.onOpen,
    this.look = SavingsRowLook.card,
    this.first = false,
  });

  final ChildGoal goal;
  final VoidCallback onAdd;
  final VoidCallback? onTransfer;
  final VoidCallback onEdit;
  final ValueChanged<Rect>? onOpen;
  final SavingsRowLook look;
  final bool first;

  String get _desc {
    final value = (goal.goalsDesc ?? '').trim();
    return value.isEmpty ? 'No description yet' : value;
  }

  void _open(BuildContext context) {
    final callback = onOpen;
    if (callback == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    callback(box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) {
    final Color tint = financePocketTint(goal.goalsName, image: goal.goalImage);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen == null ? null : () => _open(context),
      child: _shell(_content(context, tint)),
    );
  }

  // Container around the row, picked by the proposal look
  Widget _shell(Widget content) {
    return switch (look) {
      SavingsRowLook.card => Container(
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
        child: Padding(padding: const EdgeInsets.all(18), child: content),
      ),
      SavingsRowLook.bare => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 6, bottom: 6),
        child: content,
      ),
      SavingsRowLook.airy => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 12, bottom: 12),
        child: content,
      ),
      SavingsRowLook.ruled => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 16, bottom: 16),
        child: content,
      ),
    };
  }

  Widget _content(BuildContext context, Color tint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Picked icon, else the flag
            Icon(
              pocketLookFor(goal.goalImage)?.icon ?? Icons.flag_rounded,
              size: 15,
              color: pocketLookFor(goal.goalImage)?.tint ?? tint,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                goal.goalsName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: logbookInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _percentChip(tint),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Text(
            _desc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: logbookMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              financeRupiah(goal.allocatedBalance),
              style: const TextStyle(
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: logbookInk,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'of ${financeRupiah(goal.goalPrice)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: logbookFaint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 4, color: logbookTrack),
              FractionallySizedBox(
                widthFactor: goal.progress,
                child: Container(height: 4, color: tint),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ActivityTimeline(targetId: goal.goalId),
        const SizedBox(height: 14),
        _actions(context, tint),
      ],
    );
  }

  Widget _actions(BuildContext context, Color tint) {
    switch (look) {
      case SavingsRowLook.card:
      case SavingsRowLook.bare:
        return Row(
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
                label: 'Take out',
                icon: Icons.north_east_rounded,
                danger: true,
                onTap: onTransfer,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _action(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onTap: onOpen == null ? onEdit : () => _open(context),
              ),
            ),
          ],
        );
      case SavingsRowLook.airy:
      case SavingsRowLook.ruled:
        return SavingsActionRow(
          add: SavingsActionSpec(
            label: 'Add',
            icon: Icons.add_rounded,
            tint: tint,
            onTap: onAdd,
          ),
          transfer: SavingsActionSpec(
            label: 'Take out',
            icon: Icons.north_east_rounded,
            onTap: onTransfer,
          ),
          edit: SavingsActionSpec(
            label: 'Edit',
            icon: Icons.edit_outlined,
            onTap: onOpen == null ? onEdit : () => _open(context),
          ),
        );
    }
  }

  Widget _percentChip(Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        financePercent(goal.progress),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: tint,
        ),
      ),
    );
  }

  Widget _action({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool strong = false,
    bool enabled = true,
    bool danger = false,
    Color? accentTint,
  }) {
    final bool tinted = strong && accentTint != null;
    final Color fg =
        !enabled
            ? logbookFaint
            : (danger ? logbookRed : (tinted ? accentTint : logbookInk));
    final Color line =
        !enabled
            ? logbookLine
            : (danger
                ? logbookRed
                : (tinted
                    ? accentTint.withValues(alpha: 0.5)
                    : (strong ? logbookInk : logbookLine)));
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
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
