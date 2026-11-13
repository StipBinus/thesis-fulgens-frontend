import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// Shared logbook palette (mirrors the Home sheet styling).
const Color logbookInk = Color(0xFF1A1A1A);
const Color logbookLabel = Color(0xFF4A453E);
const Color logbookMuted = Color(0xFF6F695F);
const Color logbookFaint = Color(0xFF9A948A);
const Color logbookLine = Color(0xFFF0F1F3);
const Color logbookTrack = Color(0xFFF4EDE6);
const Color logbookAccent = Color(0xFFFF7A45);
const Color logbookGreen = Color(0xFF1F7A45);
const Color logbookGreenSoft = Color(0xFFE4F4E9);
const Color logbookRed = Color(0xFFB93A3A);
const Color logbookRedSoft = Color(0xFFFDECEC);

/// Three-berry cluster drawn in code, no asset needed.
class BerryToken extends StatelessWidget {
  const BerryToken({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: const _BerryPainter());
  }
}

class _BerryPainter extends CustomPainter {
  const _BerryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final leaf =
        Path()
          ..moveTo(w * 0.5, h * 0.26)
          ..cubicTo(w * 0.62, h * 0.02, w * 0.92, h * 0.02, w * 0.94, h * 0.12)
          ..cubicTo(w * 0.78, h * 0.24, w * 0.62, h * 0.28, w * 0.5, h * 0.3)
          ..close();
    canvas.drawPath(
      leaf,
      Paint()
        ..isAntiAlias = true
        ..shader = const LinearGradient(
          colors: [Color(0xFF7CD67F), Color(0xFF2E9E5B)],
        ).createShader(Offset.zero & size),
    );

    final berries = <(double, double, double)>[
      (0.29, 0.55, 0.20),
      (0.71, 0.55, 0.20),
      (0.50, 0.70, 0.24),
    ];

    for (final berry in berries) {
      final center = Offset(w * berry.$1, h * berry.$2);
      final radius = w * berry.$3;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..isAntiAlias = true
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            colors: [Color(0xFFFF8FA3), Color(0xFFE23D5E), Color(0xFFA8203F)],
            stops: [0.0, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
      canvas.drawCircle(
        center.translate(-radius * 0.32, -radius * 0.34),
        radius * 0.22,
        Paint()..color = const Color(0x99FFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(_BerryPainter oldDelegate) => false;
}

/// Gold coin token matching the Home header.
class LogbookCoin extends StatelessWidget {
  const LogbookCoin({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: const _CoinPainter());
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    canvas.drawCircle(
      center.translate(0, radius * 0.08),
      radius,
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..isAntiAlias = true
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFCF0), Color(0xFFFFEFC2), Color(0xFFF3D287)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius * 0.98,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, radius * 0.12)
        ..color = const Color(0xFFC79B32),
    );

    final star = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius * 0.5 : radius * 0.22;
      final angle = -math.pi / 2 + i * math.pi / points;
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFF6D6));
  }

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) => false;
}

/// Dashed outline used by the no-spend card.
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.child,
    this.color = const Color(0xFFCFC9BF),
    this.radius = 18,
    this.strokeWidth = 1.4,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
        );

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = color;

    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Soft orange curtain of light, top or bottom of a sheet.
class LogbookAurora extends StatelessWidget {
  const LogbookAurora({super.key, this.flip = false});

  // Anchor
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final aurora = IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback:
            (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.transparent],
              stops: [0.0, 0.92],
            ).createShader(rect),
        child: ClipRect(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: const Stack(
              fit: StackFit.expand,
              children: [
                // Curtain
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1, 0),
                      end: Alignment(1, 0),
                      colors: [
                        Color(0x38C9714F),
                        Color(0x00D3845C),
                        Color(0x36D3845C),
                        Color(0x00E0A871),
                        Color(0x38E0A871),
                        Color(0x00C9714F),
                        Color(0x35C9714F),
                        Color(0x00E0A871),
                        Color(0x36E0A871),
                        Color(0x00D3845C),
                        Color(0x34D3845C),
                      ],
                      stops: [
                        0.0,
                        0.10,
                        0.20,
                        0.30,
                        0.40,
                        0.50,
                        0.60,
                        0.70,
                        0.80,
                        0.90,
                        1.0,
                      ],
                    ),
                  ),
                ),
                _Glow(
                  alignment: Alignment(-1.2, -1.0),
                  size: 260,
                  color: Color(0xFFC9714F),
                  opacity: 0.34,
                ),
                _Glow(
                  alignment: Alignment(-0.1, -1.15),
                  size: 240,
                  color: Color(0xFFD3845C),
                  opacity: 0.30,
                ),
                _Glow(
                  alignment: Alignment(1.05, -0.95),
                  size: 260,
                  color: Color(0xFFE0A871),
                  opacity: 0.32,
                ),
                _Glow(
                  alignment: Alignment(0.9, -0.5),
                  size: 180,
                  color: Color(0xFFE0A871),
                  opacity: 0.18,
                ),
                _Glow(
                  alignment: Alignment(0.35, -0.55),
                  size: 200,
                  color: Color(0xFFC9714F),
                  opacity: 0.22,
                ),
                _Glow(
                  alignment: Alignment(-0.45, -0.6),
                  size: 190,
                  color: Color(0xFFD3845C),
                  opacity: 0.20,
                ),
                _Glow(
                  alignment: Alignment(-0.62, -0.35),
                  size: 150,
                  color: Colors.white,
                  opacity: 0.85,
                ),
                _Glow(
                  alignment: Alignment(0.55, -0.4),
                  size: 150,
                  color: Colors.white,
                  opacity: 0.85,
                ),
                CustomPaint(painter: _AuroraBowlPainter()),
              ],
            ),
          ),
        ),
      ),
    );

    if (!flip) return aurora;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(1, -1, 1),
      child: aurora,
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.alignment,
    required this.size,
    required this.color,
    required this.opacity,
  });

  // Anchor
  final Alignment alignment;
  // Span
  final double size;
  // Hue
  final Color color;
  // Softness
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuroraBowlPainter extends CustomPainter {
  const _AuroraBowlPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path =
        Path()
          ..moveTo(0, h * 0.44)
          ..cubicTo(w * 0.14, h * 0.58, w * 0.30, h * 0.88, w * 0.57, h * 0.83)
          ..cubicTo(w * 0.76, h * 0.79, w * 0.88, h * 0.60, w, h * 0.47)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  @override
  bool shouldRepaint(_AuroraBowlPainter oldDelegate) => false;
}

/// Fade + lift used to stagger the sheet sections in.
class LogbookReveal extends StatelessWidget {
  const LogbookReveal({
    super.key,
    required this.animation,
    required this.interval,
    required this.child,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: interval);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
