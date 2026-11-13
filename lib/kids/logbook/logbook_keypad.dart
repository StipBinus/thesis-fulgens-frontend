import 'package:flutter/material.dart';

import 'logbook_tokens.dart';

// Bare number pad shared by the logbook entry and pocket transfer sheets
class LogbookKeypad extends StatelessWidget {
  const LogbookKeypad({
    super.key,
    required this.onKey,
    required this.onBackspace,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  static const List<List<String>> _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['000', '0', 'x'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < _rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var c = 0; c < _rows[r].length; c++) ...[
                if (c > 0) const SizedBox(width: 8),
                Expanded(
                  child:
                      _rows[r][c] == 'x'
                          ? _KeypadKey(
                            label: '',
                            icon: Icons.backspace_rounded,
                            onTap: onBackspace,
                          )
                          : _KeypadKey(
                            label: _rows[r][c],
                            onTap: () => onKey(_rows[r][c]),
                          ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _KeypadKey extends StatefulWidget {
  const _KeypadKey({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_KeypadKey> createState() => _KeypadKeyState();
}

class _KeypadKeyState extends State<_KeypadKey> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _down ? const Color(0x141A1A1A) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child:
              widget.icon != null
                  ? Icon(widget.icon, size: 22, color: logbookInk)
                  : Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.0,
                      fontWeight: FontWeight.w600,
                      color: logbookInk,
                    ),
                  ),
        ),
      ),
    );
  }
}
