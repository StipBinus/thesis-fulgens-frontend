import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Kids auth portal
class KidsAuthPortalPage extends StatelessWidget {
  const KidsAuthPortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Brand tokens
    final Color primary = Theme.of(context).colorScheme.primary;
    const Color ink = Color(0xFF1A1A1A);
    const Color sand = Color(0xFFE8E2D9);
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    // Circle span
    final d = width * 1.55;
    // Sheet cap
    final cap = height * 0.50;
    // Art height
    final artH = height - cap;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        // Stack
        child: Stack(
          children: [
            // Split arc
            Positioned(
              left: -(d - width) / 2,
              bottom: -(d - cap),
              child: SizedBox(
                width: d,
                height: d,
                child: const CustomPaint(
                  painter: _SplitPaint(),
                ),
              ),
            ),
            // Flank decor
            Positioned(
              top: 48,
              left: 0,
              right: 0,
              height: artH - 48,
              child: Stack(
                children: [
                  // Bubble blue
                  Positioned(
                    left: 24,
                    top: (artH - 48) * 0.30,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4285F4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Sparkle red
                  Positioned(
                    right: 28,
                    top: (artH - 48) * 0.22,
                    child: const _Sparkle(size: 18, color: Color(0xFF34A853)),
                  ),
                  // Diamond blue
                  Positioned(
                    right: 44,
                    top: (artH - 48) * 0.62,
                    child: Transform.rotate(
                      angle: 0.785,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4285F4),
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Welcome mascot
            Positioned(
              top: 48,
              left: 0,
              right: 0,
              height: artH - 48,
              child: Center(
                child: SizedBox(
                  width: width * 0.56,
                  child: Image.asset(
                    'assets/game/mascotIllustrations/fulgensWelcomeMascot.png',
                    fit: BoxFit.contain,
                    semanticLabel: 'Fulgens welcome mascot',
                  ),
                ),
              ),
            ),
            // Content
            Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Below curve
                        SizedBox(height: artH + 56),
                        // Title rise
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 700),
                          curve: const Interval(
                            0.1,
                            0.6,
                            curve: Cubic(0.22, 1, 0.36, 1),
                          ),
                          builder: (_, v, child) {
                            // Reduced rise
                            final reduced =
                                MediaQuery.disableAnimationsOf(context);
                            final vv = reduced ? 1.0 : v;
                            return Opacity(
                              opacity: vv,
                              child: Transform.translate(
                                offset: Offset(0, (1 - vv) * 8),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Welcome to Fulgens',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Fun with money starts here.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: const Color(0xFF8A8378),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                        const Spacer(),
                        // Button rise
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 700),
                          curve: const Interval(
                            0.25,
                            0.85,
                            curve: Cubic(0.22, 1, 0.36, 1),
                          ),
                          builder: (_, v, child) {
                            // Reduced rise
                            final reduced =
                                MediaQuery.disableAnimationsOf(context);
                            final vv = reduced ? 1.0 : v;
                            return Opacity(
                              opacity: vv,
                              child: Transform.translate(
                                offset: Offset(0, (1 - vv) * 12),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Login primer
                              FilledButton(
                                onPressed: () => context.push('/login'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text(
                                  'Sign in',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Google match
                              OutlinedButton(
                                onPressed: () => context.push('/login'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: ink,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: const StadiumBorder(),
                                  side: const BorderSide(color: sand),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/app/google_g.svg',
                                      width: 16,
                                      height: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sparkle plus
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.color});

  // Span
  final double size;
  // Tint
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bar flat
          Container(
            width: size,
            height: size * 0.32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size * 0.16),
            ),
          ),
          // Bar tall
          Container(
            width: size * 0.32,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size * 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

// Split paint
class _SplitPaint extends CustomPainter {
  const _SplitPaint();

  @override
  void paint(Canvas canvas, Size size) {
    // Arc rect
    final Rect rect = Offset.zero & size;
    const double gap = 0.07;
    // Left red
    canvas.drawArc(
      rect,
      1.5708,
      3.1416 - gap,
      false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke,
    );
    // Right green
    canvas.drawArc(
      rect,
      -1.5708 + gap,
      3.1416 - gap,
      false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

 
