import 'package:flutter/material.dart';

import '../finance/finance_models.dart';
import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';
import 'history_timeline.dart';

// Placeholder activity until the backend sends real history
const List<HistoryEntry> _todayHistory = <HistoryEntry>[
  HistoryEntry('Added money', 25000, 'Today', true),
  HistoryEntry('Spent', 8000, 'Today', false),
];

// Pocket card: white surface, compact timeline, outline actions
class PocketRow extends StatelessWidget {
  const PocketRow({
    super.key,
    required this.pocket,
    required this.onAdd,
    required this.onTransfer,
    required this.onEdit,
    this.onOpen,
  });

  final ChildPocket pocket;
  final VoidCallback onAdd;
  final VoidCallback? onTransfer;
  final VoidCallback onEdit;
  final ValueChanged<Rect>? onOpen;

  String get _desc {
    final value = (pocket.pocketDesc ?? '').trim();
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
    final Color tint = financePocketTint(pocket.pocketName);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen == null ? null : () => _open(context),
      child: Container(
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
                  FinancePocketAvatar(
                    image: pocket.pocketImage,
                    name: pocket.pocketName,
                    size: 48,
                    background: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pocket.pocketName,
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
                  Text(
                    financeRupiah(pocket.allocatedBalance),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: logbookInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const HistoryTimeline(entries: _todayHistory),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PocketActionPill(
                      label: 'Add',
                      icon: Icons.add_rounded,
                      strong: true,
                      accentTint: tint,
                      onTap: onAdd,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PocketActionPill(
                      label: 'Transfer',
                      icon: Icons.swap_horiz_rounded,
                      onTap: onTransfer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PocketActionPill(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      onTap:
                          onOpen == null ? onEdit : () => _open(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Rounded action pill used by pocket cards
class PocketActionPill extends StatelessWidget {
  const PocketActionPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.strong = false,
    this.accentTint,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool strong;
  final Color? accentTint;

  @override
  Widget build(BuildContext context) {
    final bool tinted = strong && accentTint != null;
    final Color fg = tinted ? accentTint! : logbookInk;
    final Color line =
        tinted
            ? accentTint!.withValues(alpha: 0.5)
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
