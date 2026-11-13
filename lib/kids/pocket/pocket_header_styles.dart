import 'package:flutter/material.dart';

import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';

// Header placements for the pockets page
enum PocketHeaderStyle { inFlow, sticky, card, centered, band, capsule, split }

const List<String> pocketHeaderStyleLabels = <String>[
  'In-flow',
  'Sticky bar',
  'Header card',
  'Centered',
  'Tinted band',
  'Floating pill',
  'Split row',
];

const TextStyle _kicker = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.6,
  color: logbookAccent,
);

const TextStyle _title = TextStyle(
  fontSize: 30,
  height: 1,
  fontWeight: FontWeight.w900,
  letterSpacing: -1.1,
  color: logbookInk,
);

const TextStyle _label = TextStyle(
  fontSize: 9.5,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.2,
  color: logbookMuted,
);

class PocketAddCircle extends StatelessWidget {
  const PocketAddCircle({super.key, required this.onTap, this.flat = false});

  final VoidCallback? onTap;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: flat ? Border.all(color: logbookLine, width: 1.2) : null,
        boxShadow:
            flat
                ? null
                : [
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
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.add_rounded, size: 20, color: logbookInk),
          ),
        ),
      ),
    );
  }
}

class PocketHeaderActions extends StatelessWidget {
  const PocketHeaderActions({
    super.key,
    required this.onAdd,
    this.action,
    this.flat = false,
  });

  final VoidCallback? onAdd;
  final Widget? action;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (action != null) ...[action!, const SizedBox(width: 8)],
        if (onAdd != null) PocketAddCircle(onTap: onAdd, flat: flat),
      ],
    );
  }
}

// Title and total live in one white card
class PocketHeaderCard extends StatelessWidget {
  const PocketHeaderCard({
    super.key,
    required this.total,
    required this.count,
    required this.onAdd,
    this.action,
  });

  final int total;
  final int count;
  final VoidCallback? onAdd;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SAVINGS', style: _kicker),
                    SizedBox(height: 6),
                    Text('Pockets', style: _title),
                  ],
                ),
              ),
              PocketHeaderActions(onAdd: onAdd, action: action),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: logbookLine),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL SAVED', style: _label),
                  const SizedBox(height: 3),
                  Text(
                    financeRupiah(total),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: logbookInk,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '$count savings',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: logbookMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Centered hero with the total underneath
class PocketHeaderCentered extends StatelessWidget {
  const PocketHeaderCentered({
    super.key,
    required this.total,
    required this.onAdd,
    this.action,
  });

  final int total;
  final VoidCallback? onAdd;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('SAVINGS', style: _kicker),
        const SizedBox(height: 6),
        const Text('Pockets', style: _title),
        const SizedBox(height: 10),
        Text(
          financeRupiah(total),
          style: const TextStyle(
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            color: logbookInk,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'set aside so far',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: logbookMuted,
          ),
        ),
        const SizedBox(height: 14),
        PocketHeaderActions(onAdd: onAdd, action: action),
      ],
    );
  }
}

// Title left, total right, actions in a tight row below
class PocketHeaderSplit extends StatelessWidget {
  const PocketHeaderSplit({
    super.key,
    required this.total,
    required this.onAdd,
    this.action,
  });

  final int total;
  final VoidCallback? onAdd;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SAVINGS', style: _kicker),
                  SizedBox(height: 4),
                  Text(
                    'Pockets',
                    style: TextStyle(
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: logbookInk,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('TOTAL SAVED', style: _label),
                const SizedBox(height: 3),
                Text(
                  financeRupiah(total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: logbookInk,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        PocketHeaderActions(onAdd: onAdd, action: action),
      ],
    );
  }
}

// Header that sits on the tinted band
class PocketHeaderBand extends StatelessWidget {
  const PocketHeaderBand({
    super.key,
    required this.total,
    required this.onAdd,
    this.action,
  });

  final int total;
  final VoidCallback? onAdd;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SAVINGS', style: _kicker),
                  SizedBox(height: 6),
                  Text('Pockets', style: _title),
                ],
              ),
            ),
            PocketHeaderActions(onAdd: onAdd, action: action),
          ],
        ),
        const SizedBox(height: 14),
        const Text('TOTAL SAVED', style: _label),
        const SizedBox(height: 2),
        Text(
          financeRupiah(total),
          style: const TextStyle(
            fontSize: 28,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            color: logbookInk,
          ),
        ),
      ],
    );
  }
}

// Pill that floats over the list
class PocketHeaderCapsule extends StatelessWidget {
  const PocketHeaderCapsule({
    super.key,
    required this.count,
    required this.onAdd,
    this.action,
  });

  final int count;
  final VoidCallback? onAdd;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Pockets',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: logbookInk,
            ),
          ),
          const SizedBox(width: 7),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: logbookMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: logbookMuted,
            ),
          ),
          const Spacer(),
          PocketHeaderActions(onAdd: onAdd, action: action, flat: true),
        ],
      ),
    );
  }
}

// Slim bar that pins after the big header scrolls away
class PocketHeaderCompactBar extends StatelessWidget {
  const PocketHeaderCompactBar({super.key, required this.onAdd, this.action});

  final VoidCallback? onAdd;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: logbookLine, width: 1)),
      ),
      child: Row(
        children: [
          const Text(
            'Pockets',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: logbookInk,
            ),
          ),
          const Spacer(),
          PocketHeaderActions(onAdd: onAdd, action: action, flat: true),
        ],
      ),
    );
  }
}
