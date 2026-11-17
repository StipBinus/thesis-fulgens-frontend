import 'package:flutter/material.dart';
import 'package:thesis_fulgens_mobile/kids/logbook/logbook_tokens.dart';

// Page indicator
class PagingDots extends StatelessWidget {
  const PagingDots({super.key, required this.t, required this.onTap});

  // Scene progress
  final double t;
  // Jump to side
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final Color tone = Color.lerp(logbookInk, Colors.white, t)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 2; i++)
          Semantics(
            button: true,
            selected: (t < 0.5) == (i == 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 10,
                ),
                child: AnimatedContainer(
                  duration:
                      reduced ? Duration.zero : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: (t < 0.5) == (i == 0) ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: tone.withValues(
                      alpha: (t < 0.5) == (i == 0) ? 0.9 : 0.28,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
