import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Kids auth portal
class KidsAuthPortalPage extends StatefulWidget {
  const KidsAuthPortalPage({super.key});

  @override
  State<KidsAuthPortalPage> createState() => _KidsAuthPortalPageState();
}

class _KidsAuthPortalPageState extends State<KidsAuthPortalPage> {
  @override
  Widget build(BuildContext context) {
    return _buildHalo(context);
  }


  // Shared aurora stage
  Widget _stage(BuildContext context, Widget content) {
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, box) {
          final auroraH = (box.maxHeight - topInset) * 0.62 + topInset;
          // Rise headroom
          final reduced = MediaQuery.disableAnimationsOf(context);
          final rise = reduced ? 0.0 : 18.0;
          return Stack(
            children: [
              Positioned(
                top: -rise,
                left: 0,
                right: 0,
                height: auroraH + rise,
                child: _AuroraIn(
                  rise: rise,
                  child: _Aurora(width: size.width, height: auroraH + rise),
                ),
              ),
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: content,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Headline block
  Widget _headline({
    required double size,
    required double tracking,
    required double height,
    TextAlign align = TextAlign.start,
    CrossAxisAlignment cross = CrossAxisAlignment.start,
    double subSize = 14,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        Text(
          'Welcome to Fulgens',
          textAlign: align,
          style: GoogleFonts.poppins(
            fontSize: size,
            height: height,
            fontWeight: FontWeight.w700,
            letterSpacing: tracking,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Fun with money starts here.',
          textAlign: align,
          style: GoogleFonts.poppins(
            fontSize: subSize,
            height: 1.5,
            color: const Color(0xFF6F695F),
          ),
        ),
      ],
    );
  }

  // Spotlight old
  Widget _buildHalo(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final size = MediaQuery.sizeOf(context);

    return _stage(
      context,
      Column(
        children: [
          Expanded(
            child: Center(
              child: _Halo(
                size: size.width * 0.92,
                child: SizedBox(
                  width: size.width * 0.54,
                  child: const _Mascot(),
                ),
              ),
            ),
          ),
          _Rise(
            delay: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _headline(
                size: 30,
                tracking: -0.9,
                height: 1.2,
                align: TextAlign.center,
                cross: CrossAxisAlignment.center,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Rise(
              delay: 120,
              child: _Glass(
                child: _AuthActions(primary: primary, height: 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// Aurora arrival
class _AuroraIn extends StatelessWidget {
  const _AuroraIn({required this.child, this.rise = 0});

  // Wash
  final Widget child;
  // Headroom
  final double rise;

  @override
  Widget build(BuildContext context) {
    // Reduced motion
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced || rise == 0) return child;
    // Slow fade
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      curve: const Cubic(0.4, 0, 0.2, 1),
      builder: (_, fade, inner) => Opacity(opacity: fade, child: inner),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: const Cubic(0.22, 1, 0.36, 1),
        builder: (_, v, inner) => Transform.translate(
          offset: Offset(0, (1 - v) * rise),
          child: inner,
        ),
        child: child,
      ),
    );
  }
}

// Aurora wash
class _Aurora extends StatelessWidget {
  const _Aurora({required this.width, required this.height});

  // Field width
  final double width;
  // Field height
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: Stack(
              children: [
                // Blob sky
                Positioned(
                  left: -width * 0.34,
                  top: -width * 0.30,
                  child: Container(
                    width: width * 0.68,
                    height: width * 0.68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2E3FC).withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Blob green
                Positioned(
                  left: -width * 0.20,
                  top: height * 0.10,
                  child: Container(
                    width: width * 0.42,
                    height: width * 0.42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34A853).withValues(alpha: 0.34),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Blob peach
                Positioned(
                  right: -width * 0.22,
                  top: height * 0.06,
                  child: Container(
                    width: width * 0.46,
                    height: width * 0.34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA4335).withValues(alpha: 0.40),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Blob blue
                Positioned(
                  right: -width * 0.14,
                  top: height * 0.26,
                  child: Container(
                    width: width * 0.34,
                    height: width * 0.34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.26),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
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
                  stops: const [0.0, 0.55, 0.94],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Welcome mascot
class _Mascot extends StatelessWidget {
  const _Mascot();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/game/mascotIllustrations/fulgensWelcomeMascot.png',
      fit: BoxFit.contain,
      semanticLabel: 'Fulgens welcome mascot',
    );
  }
}

// Soft halo
class _Halo extends StatelessWidget {
  const _Halo({required this.size, required this.child});

  // Glow span
  final double size;
  // Mascot
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xE6FFFFFF), Color(0x00FFFFFF)],
          stops: [0.35, 1],
        ),
      ),
      child: child,
    );
  }
}

// Glass sheet
class _Glass extends StatelessWidget {
  const _Glass({required this.child});

  // Content
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: reduced ? 0 : 18,
          sigmaY: reduced ? 0 : 18,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Auth actions
class _AuthActions extends StatelessWidget {
  const _AuthActions({required this.primary, required this.height});

  // Brand color
  final Color primary;
  // Button height
  final double height;

  @override
  Widget build(BuildContext context) {
    final h = height - 4;
    final radius = BorderRadius.circular(h / 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Login primer
        _PressScale(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: () => context.push('/kids/login'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                minimumSize: Size.fromHeight(h),
                shape: const StadiumBorder(),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
              ),
              child: const Text(
                'Sign in',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Google match
        _PressScale(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 20,
                  spreadRadius: -2,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => context.push('/parent/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A1A1A),
                minimumSize: Size.fromHeight(h),
                shape: const StadiumBorder(),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Entrance rise
class _Rise extends StatelessWidget {
  const _Rise({required this.child, this.delay = 0});

  // Content
  final Widget child;
  // Stagger offset
  final int delay;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    // Reduced rise
    if (reduced) return child;
    final start = (delay / 700).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Interval(start, 1, curve: const Cubic(0.22, 1, 0.36, 1)),
      builder: (_, v, inner) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: inner),
      ),
      child: child,
    );
  }
}

// Press scale
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  // Content
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  // Held
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    // Reduced motion
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => setState(() => _held = true),
      onPointerUp: (_) => setState(() => _held = false),
      onPointerCancel: (_) => setState(() => _held = false),
      child: AnimatedScale(
        scale: _held ? 0.97 : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
