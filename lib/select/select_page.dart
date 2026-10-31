import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Role select
class SelectPage extends StatefulWidget {
  const SelectPage({super.key});

  @override
  State<SelectPage> createState() => _SelectPageState();
}

// Select state
class _SelectPageState extends State<SelectPage> {
  // Swipe pages
  final PageController _pages = PageController(viewportFraction: 0.86);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration:
                  reduced ? Duration.zero : const Duration(milliseconds: 750),
              builder: (context, v, _) {
                // Settled playhead
                final double t = reduced ? 1.0 : v;
                return Column(
                  children: [
                    const SizedBox(height: 26),
                    // Header nudge
                    Transform.translate(
                      offset: const Offset(0, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Headline rise
                          _Rise(
                            play: t,
                            start: 0.12,
                            end: 0.46,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "Hi! Who'll be using Fulgens",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    height: 1.22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.7,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Support rise
                          _Rise(
                            play: t,
                            start: 0.18,
                            end: 0.52,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 28),
                              child: Text(
                                'Choose a profile to get started.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  height: 1.5,
                                  color: Color(0xFF8A8378),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Carousel rise
                    Expanded(
                      child: _Rise(
                        play: t,
                        start: 0.26,
                        end: 0.64,
                        child: PageView(
                          controller: _pages,
                          children: [
                            // Parent slide
                            _Slide(
                              index: 0,
                              pages: _pages,
                              reduced: reduced,
                              image:
                                  'assets/app/SelectionPage/parentsSelection.png',
                              label: 'Parent overview preview',
                            ),
                            // Kid slide
                            _Slide(
                              index: 1,
                              pages: _pages,
                              reduced: reduced,
                              image:
                                  'assets/app/SelectionPage/kidsSelection.png',
                              label: 'Saving report preview',
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pages,
                      builder: (context, _) {
                        // Live page
                        final double p =
                            _pages.hasClients ? (_pages.page ?? 0.0) : 0.0;
                        final int sel = p.round();
                        return Column(
                          children: [
                            // Caption rise
                            _Rise(
                              play: t,
                              start: 0.36,
                              end: 0.7,
                              child: AnimatedSwitcher(
                                duration:
                                    reduced
                                        ? Duration.zero
                                        : const Duration(milliseconds: 220),
                                child: Column(
                                  key: ValueKey<int>(sel),
                                  children: [
                                    Text(
                                      sel == 0 ? 'Parent' : 'Kid',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.3,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sel == 0
                                          ? 'Track savings and progress.'
                                          : 'Play, save, and grow.',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        color: Color(0xFF8A8378),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Dots and action rise
                            _Rise(
                              play: t,
                              start: 0.44,
                              end: 0.78,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                ),
                                child: Column(
                                  children: [
                                    _Dots(pages: _pages, reduced: reduced),
                                    const SizedBox(height: 26),
                                    FilledButton(
                                      onPressed:
                                          sel == 0
                                              ? () => context.push('/parent')
                                              : () => context.push('/kids'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(48),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: AnimatedSwitcher(
                                        duration:
                                            reduced
                                                ? Duration.zero
                                                : const Duration(
                                                  milliseconds: 160,
                                                ),
                                        child: Text(
                                          sel == 0
                                              ? "I'm a parent"
                                              : "I'm a kid",
                                          key: ValueKey<int>(sel),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Rise in
class _Rise extends StatelessWidget {
  const _Rise({
    required this.play,
    required this.start,
    required this.end,
    required this.child,
  });

  // Playhead
  final double play;
  // Window in
  final double start;
  // Window out
  final double end;
  // Content
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Window local
    final double t = ((play - start) / (end - start)).clamp(0.0, 1.0);
    final double rise = const Cubic(0.23, 1, 0.32, 1).transform(t);
    return Opacity(
      opacity: rise,
      child: Transform.translate(
        offset: Offset(0, (1 - rise) * 14),
        child: child,
      ),
    );
  }
}

// Slide
class _Slide extends StatelessWidget {
  const _Slide({
    required this.index,
    required this.pages,
    required this.reduced,
    required this.image,
    required this.label,
  });

  // Page index
  final int index;
  // Swipe control
  final PageController pages;
  // Reduced motion
  final bool reduced;
  // Slide image
  final String image;
  // Screen reader label
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap to select
      onTap:
          () => pages.animateToPage(
            index,
            duration:
                reduced ? Duration.zero : const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          ),
      // Whole slide tappable
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: pages,
        builder: (context, child) {
          // Live page
          final double p = pages.hasClients ? (pages.page ?? 0.0) : 0.0;
          // Settle 0 to 1
          final double s = (1 - (p - index).abs()).clamp(0.0, 1.0);
          final double eased = reduced ? 1.0 : Curves.easeOutCubic.transform(s);
          return Transform.translate(
            offset: Offset(0, (1 - eased) * 10),
            child: Transform.scale(scale: 0.9 + 0.1 * eased, child: child),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          // Trim margins
          child: Transform.scale(
            scale: 0.96,
            child: Image.asset(
              image,
              fit: BoxFit.contain,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}

// Swipe dots
class _Dots extends StatelessWidget {
  const _Dots({required this.pages, required this.reduced});

  // Swipe control
  final PageController pages;
  // Reduced motion
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: pages,
        builder: (context, _) {
          // Live page
          final double p = pages.hasClients ? (pages.page ?? 0.0) : 0.0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(active: p <= 0.5, reduced: reduced),
              const SizedBox(width: 6),
              _Dot(active: p > 0.5, reduced: reduced),
            ],
          );
        },
      ),
    );
  }
}

// One dot
class _Dot extends StatelessWidget {
  const _Dot({required this.active, required this.reduced});

  // On current
  final bool active;
  // Reduced motion
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: active ? 18 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1A1A1A) : const Color(0xFFCBC2B1),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
    );
  }
}
