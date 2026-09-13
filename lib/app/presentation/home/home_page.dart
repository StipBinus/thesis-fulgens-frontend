import 'package:flutter/material.dart';

import '../input/input_sheet.dart';
import 'log_progress_button.dart';

/// Home page — fully white, empty, button bottom-left.
/// - Uses ONLY log_progress_button.svg (single 1:1 PNG→SVG, 91KB via vtracer) as requested.
/// - Whole screen white, button anchored bottom-left, tap opens Input overlay.
/// - No AppBar, no center content — truly empty.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Empty white canvas — nothing in center
            const SizedBox.expand(),

            // Bottom-left button — single SVG, bigger + more left as requested
            Positioned(
              left: -15,
              bottom: -10,
              child: LogProgressButtonSingleSvg(
                onTap: () => showInputSheet(context),
                width: 280,
                height: 110,
              ),
            ),

            // Bottom build text — centered at very bottom, above safe area
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Fulgens • Build ${const String.fromEnvironment('BUILD_NAME', defaultValue: '1.0.0+1')} • 2026',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFBDBDBD),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
