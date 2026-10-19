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
  final PageController _pages = PageController();

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    Expanded(
                      child: PageView(
                        controller: _pages,
                        children: [
                          // Parent page
                          _Poster(
                            statement: 'Track savings and progress.',
                            sub: 'Support their today, brighter tomorrow.',
                            play: t,
                            action: "I'm a parent",
                            onAction: () => context.push('/'),
                            // Parent preview
                            art: _PreviewSettle(
                              index: 0,
                              pages: _pages,
                              reduced: reduced,
                              child: const _ArtFrame(
                                tilt: 0.05,
                                image:
                                    'assets/app/SelectionPage/ParentPreview.png',
                                label: 'Parent overview preview',
                              ),
                            ),
                          ),
                          // Kid page
                          _Poster(
                            statement: 'Play, save, and grow.',
                            sub: 'Turn good habits into big adventures.',
                            play: t,
                            action: "I'm a kid",
                            onAction: () => context.push('/kids'),
                            // Kids preview
                            art: _PreviewSettle(
                              index: 1,
                              pages: _pages,
                              reduced: reduced,
                              child: const _ArtFrame(
                                tilt: -0.05,
                                image:
                                    'assets/app/SelectionPage/ChildrenPreview.png',
                                label: 'Saving report preview',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dots
                    _Rise(
                      play: t,
                      start: 0.5,
                      end: 0.9,
                      child: _Dots(pages: _pages, reduced: reduced),
                    ),
                    const SizedBox(height: 18),
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

// Role poster
class _Poster extends StatelessWidget {
  const _Poster({
    required this.statement,
    required this.sub,
    required this.play,
    required this.action,
    required this.onAction,
    required this.art,
  });

  // Big line
  final String statement;
  // Support line
  final String sub;
  // Enter playhead
  final double play;
  // Button label
  final String action;
  // Button action
  final VoidCallback onAction;
  // Poster art
  final Widget art;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Headline rise
          _Rise(
            play: play,
            start: 0.14,
            end: 0.48,
            child: Text(
              statement,
              style: GoogleFonts.poppins(
                fontSize: 30,
                height: 1.22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Support rise
          _Rise(
            play: play,
            start: 0.22,
            end: 0.56,
            child: Text(
              sub,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.5,
                color: Color(0xFF8A8378),
              ),
            ),
          ),
          // Art rise
          Expanded(child: _Rise(play: play, start: 0.3, end: 0.7, child: art)),
          // Button rise
          _Rise(
            play: play,
            start: 0.42,
            end: 0.8,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: Text(
                action,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

// Preview settle
class _PreviewSettle extends StatelessWidget {
  const _PreviewSettle({
    required this.index,
    required this.pages,
    required this.reduced,
    required this.child,
  });

  // Page index
  final int index;
  // Swipe control
  final PageController pages;
  // Reduced motion
  final bool reduced;
  // Art
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pages,
      builder: (context, child) {
        // Live page
        final double p = pages.hasClients ? (pages.page ?? 0.0) : 0.0;
        // Settle 0 to 1
        final double s = (1 - (p - index).abs()).clamp(0.0, 1.0);
        final double eased = reduced ? 1.0 : Curves.easeOutCubic.transform(s);
        return Transform.translate(
          offset: Offset(0, (1 - eased) * 14),
          child: Transform.scale(scale: 0.94 + 0.06 * eased, child: child),
        );
      },
      child: child,
    );
  }
}

// Art frame
class _ArtFrame extends StatelessWidget {
  const _ArtFrame({
    required this.tilt,
    required this.image,
    required this.label,
  });

  // Tilt angle
  final double tilt;
  // Preview image
  final String image;
  // Screen reader label
  final String label;

  @override
  Widget build(BuildContext context) {
    // Blob tint
    final Color primary = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, c) {
        // Blob size
        final double blobW = c.maxWidth * 0.86;
        final double blobH = c.maxHeight * 0.86;
        final double blob = blobW < blobH ? blobW : blobH;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Blob glow
            Align(
              alignment: const Alignment(0, 0.36),
              child: Container(
                width: blob,
                height: blob,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Soft dots
            Align(
              alignment: const Alignment(-0.93, -0.12),
              child: _SoftDots(color: primary),
            ),
            // Tilted phone
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Transform.rotate(
                angle: tilt,
                child: Image.asset(
                  image,
                  fit: BoxFit.contain,
                  semanticLabel: label,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Soft dots
class _SoftDots extends StatelessWidget {
  const _SoftDots({required this.color});

  // Tint
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 30,
      child: Stack(
        children: [
          // Big dot
          Positioned(left: 0, top: 0, child: _dot(9, 0.6)),
          // Mid dot
          Positioned(left: 15, top: 9, child: _dot(6, 0.42)),
          // Small dot
          Positioned(left: 6, top: 22, child: _dot(4, 0.28)),
        ],
      ),
    );
  }

  // One dot
  Widget _dot(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        shape: BoxShape.circle,
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
