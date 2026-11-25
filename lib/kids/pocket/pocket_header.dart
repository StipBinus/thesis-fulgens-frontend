import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';

// Kicker label above the Pockets title
class PocketHeader extends StatelessWidget {
  const PocketHeader({
    super.key,
    this.onAdd,
    this.onArrange,
    this.action,
    this.eyebrow = 'SAVINGS',
    this.title = 'Pockets',
    this.style = 0,
    this.savedTotal = 0,
    this.pocketCount = 0,
    this.cash = 0,
    this.arranging = false,
  });

  final VoidCallback? onAdd;
  final VoidCallback? onArrange;
  final Widget? action;
  final String eyebrow;
  final String title;
  final int style;
  final int savedTotal;
  final int pocketCount;
  final int cash;
  final bool arranging;

  String get _countLabel =>
      pocketCount == 1 ? '1 pocket' : '$pocketCount pockets';

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      11 => _waveInset(),
      12 => _waveFull(),
      13 => _waveOverlap(),
      14 => _waveActions(),
      15 => _waveCashChip(),
      _ => _classic(),
    };
  }

  Widget _classic() {
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
        ..._actionChildren(),
      ],
    );
  }

  // Rounded band, keeps the page margins
  Widget _waveInset() {
    return _band(
      clipped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bandTopRow(),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _bandAmount(30),
          const SizedBox(height: 4),
          _bandNote('$_countLabel · ${financeRupiah(cash)} cash left'),
        ],
      ),
    );
  }

  // Edge to edge band
  Widget _waveFull() {
    return _band(
      clipped: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bandTopRow(),
          const SizedBox(height: 14),
          _bandAmount(36),
          const SizedBox(height: 6),
          _bandNote('$_countLabel · ${financeRupiah(cash)} cash left'),
        ],
      ),
    );
  }

  // Band with a white cash card straddling the lip
  Widget _waveOverlap() {
    return Column(
      children: [
        _band(
          clipped: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bandTopRow(),
              const SizedBox(height: 12),
              _bandAmount(36),
              const SizedBox(height: 4),
              _bandNote(_countLabel),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -22),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: logbookGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 19,
                    color: logbookGreen,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash left',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: logbookInk,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'not in a pocket yet',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: logbookMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  financeRupiah(cash),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: logbookInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Two labelled buttons live inside the band
  Widget _waveActions() {
    return _band(
      clipped: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'SAVINGS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: Color(0xD9FFFFFF),
                ),
              ),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 12),
          _bandAmount(36),
          const SizedBox(height: 6),
          _bandNote('$_countLabel · ${financeRupiah(cash)} cash left'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _onBandPill(
                  label: 'Add money',
                  icon: Icons.add_rounded,
                  solid: true,
                  onTap: onAdd,
                ),
              ),
              const SizedBox(width: 10),
              _onBandPill(
                label: arranging ? 'Done' : 'Arrange',
                icon: arranging ? Icons.check_rounded : Icons.swap_vert_rounded,
                solid: false,
                onTap: onArrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Cash shown as a chip inside the band
  Widget _waveCashChip() {
    return _band(
      clipped: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bandTopRow(),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _bandAmount(36)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${financeRupiah(cash)} cash',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _bandNote(_countLabel),
        ],
      ),
    );
  }

  Widget _band({required bool clipped, required Widget child}) {
    return ClipPath(
      clipper: clipped ? const _BandClipper(radius: 26) : const _BandClipper(),
      child: Container(
        color: logbookAccent,
        padding: EdgeInsets.fromLTRB(
          clipped ? 18 : 20,
          clipped ? 16 : 18,
          clipped ? 14 : 16,
          clipped ? 30 : 34,
        ),
        child: child,
      ),
    );
  }

  Widget _bandTopRow() {
    return Row(
      children: [
        const Text(
          'SAVINGS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: Color(0xD9FFFFFF),
          ),
        ),
        const Spacer(),
        if (action != null) action!,
        if (action != null && onAdd != null) const SizedBox(width: 8),
        if (onAdd != null) _whiteCircle(),
      ],
    );
  }

  Widget _bandAmount(double size) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        financeRupiah(savedTotal),
        style: TextStyle(
          fontSize: size,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.4,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _bandNote(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xE6FFFFFF),
      ),
    );
  }

  Widget _onBandPill({
    required String label,
    required IconData icon,
    required bool solid,
    required VoidCallback? onTap,
  }) {
    final Color fg = solid ? logbookInk : Colors.white;
    return Material(
      color: solid ? Colors.white : Colors.white.withValues(alpha: 0.16),
      shape: StadiumBorder(
        side:
            solid
                ? BorderSide.none
                : const BorderSide(color: Color(0x66FFFFFF), width: 1.2),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actionChildren() {
    return [
      if (action != null) action!,
      if (action != null && onAdd != null) const SizedBox(width: 8),
      if (onAdd != null) _addCircle(),
    ];
  }

  Widget _addCircle() {
    return Container(
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
    );
  }

  Widget _whiteCircle() {
    return Material(
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
    );
  }
}

// Band silhouette: rounded top, wave along the bottom
class _BandClipper extends CustomClipper<Path> {
  const _BandClipper({this.radius = 0});

  final double radius;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const base = 16.0;
    final path = Path();

    if (radius > 0) {
      path
        ..moveTo(0, radius)
        ..quadraticBezierTo(0, 0, radius, 0)
        ..lineTo(w - radius, 0)
        ..quadraticBezierTo(w, 0, w, radius);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(w, 0);
    }

    path.lineTo(w, h - base);

    const step = 26.0;
    var x = w;
    var down = true;
    while (x > 0.5) {
      final next = math.max(0.0, x - step);
      path.quadraticBezierTo(
        (x + next) / 2,
        down ? h + 5 : h - base * 2 - 5,
        next,
        h - base,
      );
      x = next;
      down = !down;
    }

    if (radius > 0) {
      path.lineTo(0, radius);
    } else {
      path.lineTo(0, 0);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_BandClipper oldClipper) => oldClipper.radius != radius;
}
