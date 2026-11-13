import 'package:flutter/material.dart';

import '../logbook/logbook_tokens.dart';

// Kicker label above the Pockets title
class PocketHeader extends StatelessWidget {
  const PocketHeader({
    super.key,
    this.onAdd,
    this.action,
    this.eyebrow = 'SAVINGS',
    this.title = 'Pockets',
  });

  final VoidCallback? onAdd;
  final Widget? action;
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  eyebrow,
                  key: ValueKey<String>(eyebrow),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: logbookAccent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  title,
                  key: ValueKey<String>(title),
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.1,
                    color: logbookInk,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[action!, const SizedBox(width: 8)],
        if (onAdd != null)
          Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.add_rounded, size: 20, color: logbookInk),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
