import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

// Kids aurora
class KidsAurora extends StatelessWidget {
  const KidsAurora({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                return Stack(
                  children: [
                    // Blob sky
                    Positioned(
                      left: -width * 0.34,
                      top: -width * 0.30,
                      child: _blob(
                        width * 0.68,
                        width * 0.68,
                        const Color(0xFFD2E3FC).withValues(alpha: 0.55),
                      ),
                    ),
                    // Blob green
                    Positioned(
                      left: -width * 0.20,
                      top: height * 0.10,
                      child: _blob(
                        width * 0.42,
                        width * 0.42,
                        const Color(0xFF34A853).withValues(alpha: 0.18),
                      ),
                    ),
                    // Blob ember
                    Positioned(
                      right: -width * 0.22,
                      top: height * 0.06,
                      child: _blob(
                        width * 0.46,
                        width * 0.34,
                        const Color(0xFFEA4335).withValues(alpha: 0.22),
                      ),
                    ),
                    // Blob blue
                    Positioned(
                      right: -width * 0.14,
                      top: height * 0.26,
                      child: _blob(
                        width * 0.34,
                        width * 0.34,
                        const Color(0xFF4285F4).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Fade out
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.42, 0.92],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Aurora dot
  Widget _blob(double w, double h, Color color) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
      ),
    );
  }
}
