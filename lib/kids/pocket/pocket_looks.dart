import 'package:flutter/material.dart';

import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';

// Page looks for the Pockets page
enum PocketLook { today, forest }

// Forest art header with a white sheet lip at the bottom
class PocketForestHeader extends StatelessWidget {
  const PocketForestHeader({
    super.key,
    required this.savedTotal,
    required this.pocketCount,
    required this.goalCount,
    required this.cash,
    this.action,
    this.onAdd,
  });

  final int savedTotal;
  final int pocketCount;
  final int goalCount;
  final int cash;
  final Widget? action;
  final VoidCallback? onAdd;

  String get _countLine {
    final parts = <String>[
      pocketCount == 1 ? '1 pocket' : '$pocketCount pockets',
      if (goalCount > 0) goalCount == 1 ? '1 goal' : '$goalCount goals',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + 296,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/game/backgrounds/background_new.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.35),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x1A000000),
                  Color(0x59000000),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: top + 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _titleBlock()),
                if (action != null) action!,
                if (action != null && onAdd != null) const SizedBox(width: 8),
                if (onAdd != null) _addButton(),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    financeRupiah(savedTotal),
                    style: const TextStyle(
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _glassChip('$_countLine · ${financeRupiah(cash)} cash'),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            child: Container(
              height: 30,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAVINGS',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pockets',
          style: TextStyle(
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.1,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _glassChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _addButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
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
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onAdd,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.add_rounded, size: 20, color: logbookAccent),
          ),
        ),
      ),
    );
  }
}
