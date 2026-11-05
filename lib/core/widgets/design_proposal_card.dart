import 'package:flutter/material.dart';

// Floating design proposal panel, reusable across screens
class DesignProposalCard extends StatefulWidget {
  const DesignProposalCard({
    super.key,
    required this.title,
    required this.options,
    required this.onSelect,
    required this.onClose,
    this.initialIndex = 0,
    this.initialLeft = 16,
    this.initialBottom = 140,
  });

  final String title;
  final List<String> options;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;
  final int initialIndex;
  final double initialLeft;
  final double initialBottom;

  @override
  State<DesignProposalCard> createState() => _DesignProposalCardState();
}

class _DesignProposalCardState extends State<DesignProposalCard> {
  late int _selected = widget.initialIndex;
  bool _open = true;
  late Offset _pos = Offset(widget.initialLeft, widget.initialBottom);

  void _move(Offset delta) {
    final size = MediaQuery.sizeOf(context);
    final maxX = (size.width - 224).clamp(8.0, double.infinity);
    final maxY = (size.height - 160).clamp(8.0, double.infinity);
    setState(() {
      _pos = Offset(
        (_pos.dx + delta.dx).clamp(8.0, maxX),
        (_pos.dy - delta.dy).clamp(8.0, maxY),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _pos.dx,
      bottom: _pos.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => _move(details.delta),
        child: Container(
          width: _open ? 216 : 108,
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1512),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _open ? widget.title : 'STYLE',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Color(0x99FFFFFF),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _open = !_open),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.palette_outlined,
                        size: 15,
                        color: Color(0xCCFFFFFF),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: Color(0xCCFFFFFF),
                      ),
                    ),
                  ),
                ],
              ),
              if (_open) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (var i = 0; i < widget.options.length; i++)
                      _ProposalTag(
                        label: widget.options[i],
                        selected: _selected == i,
                        onTap: () {
                          setState(() => _selected = i);
                          widget.onSelect(i);
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalTag extends StatelessWidget {
  const _ProposalTag({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color:
                  selected ? const Color(0xFF1B1512) : const Color(0xCCFFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

// Overlay handle
class DesignProposalHandle {
  DesignProposalHandle._(this._entry);

  final OverlayEntry _entry;

  void close() {
    if (_entry.mounted) _entry.remove();
  }
}

// Show above everything
DesignProposalHandle showDesignProposalCard(
  BuildContext context, {
  required String title,
  required List<String> options,
  required ValueChanged<int> onSelect,
  int initialIndex = 0,
  double initialLeft = 16,
  double initialBottom = 140,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder:
        (_) => Stack(
          children: [
            DesignProposalCard(
              title: title,
              options: options,
              initialIndex: initialIndex,
              initialLeft: initialLeft,
              initialBottom: initialBottom,
              onSelect: onSelect,
              onClose: () {
                if (entry.mounted) entry.remove();
              },
            ),
          ],
        ),
  );
  overlay.insert(entry);
  return DesignProposalHandle._(entry);
}
