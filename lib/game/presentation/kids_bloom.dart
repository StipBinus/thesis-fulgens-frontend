import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

// Kids bloom
class KidsBloom extends StatelessWidget {
  const KidsBloom({super.key, required this.progress});

  // Bloom driver
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: progress,
        builder:
            (context, _) => SizedBox.expand(
              child: CustomPaint(painter: _BloomPainter(progress.value)),
            ),
      ),
    );
  }
}

// Bloom painter
class _BloomPainter extends CustomPainter {
  _BloomPainter(this.t);

  // Timeline
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double w = size.width;
    final double h = size.height;
    // Appear
    final double appear = Curves.easeInOutCubic.transform(
      (t / 0.34).clamp(0.0, 1.0),
    );
    // Drift
    final double drift = Curves.easeInOutCubic.transform(
      (t / 0.82).clamp(0.0, 1.0),
    );
    // Zones
    const List<Color> zones = [
      Color(0xFF9DBDF0),
      Color(0xFFE8A79C),
      Color(0xFFA8D5B5),
    ];
    // Field anchors
    const List<Offset> from = [
      Offset(0.10, 0.06),
      Offset(0.56, 0.02),
      Offset(0.96, 0.08),
      Offset(0.86, 0.52),
      Offset(0.04, 0.52),
      Offset(0.46, 0.88),
    ];
    // Field targets
    const List<Offset> to = [
      Offset(0.30, 0.40),
      Offset(0.40, 0.28),
      Offset(0.70, 0.38),
      Offset(0.62, 0.62),
      Offset(0.30, 0.72),
      Offset(0.50, 0.66),
    ];
    // Field radii
    const List<double> radii = [0.86, 0.76, 0.82, 0.72, 0.70, 0.74];
    // Field zones
    const List<int> zone = [0, 0, 1, 1, 2, 2];
    // Field weights
    const List<double> weight = [0.30, 0.28, 0.30, 0.26, 0.18, 0.16];
    final double alpha = appear;
    // Veil thinning
    final double thin = Curves.easeInOutCubic.transform(
      ((t / 0.34 - 0.68) / 0.32).clamp(0.0, 1.0),
    );
    final double veilAlpha = alpha * (1.0 - thin);
    if (veilAlpha <= 0) return;
    // Veil base
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFCDE0F8).withValues(alpha: 0.94 * veilAlpha),
            const Color(0xFFCFE8D8).withValues(alpha: 0.94 * veilAlpha),
          ],
        ).createShader(rect),
    );
    canvas.saveLayer(
      rect,
      Paint()
        ..imageFilter = ImageFilter.blur(
          sigmaX: w * 0.085,
          sigmaY: w * 0.085,
        ),
    );
    for (int i = 0; i < from.length; i++) {
      final Offset c =
          Offset.lerp(
            Offset(w * from[i].dx, h * from[i].dy),
            Offset(w * to[i].dx, h * to[i].dy),
            drift,
          )!;
      final double r = w * radii[i] * (0.92 + 0.16 * drift);
      canvas.drawCircle(
        c,
        r,
        Paint()..color = zones[zone[i]].withValues(alpha: weight[i] * veilAlpha),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BloomPainter old) => old.t != t;
}
