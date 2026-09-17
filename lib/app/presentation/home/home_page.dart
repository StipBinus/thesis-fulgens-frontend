import 'package:flutter/material.dart';

import '../input/input_sheet.dart';
import 'log_progress_button.dart';

// Home page
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Empty canvas
            const SizedBox.expand(),

            // Log progress button
            Positioned(
              left: -15,
              bottom: -10,
              child: LogProgressButtonSingleSvg(
                onTap: () => showInputSheet(context),
                width: 280,
                height: 110,
              ),
            ),

            // Build info
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
