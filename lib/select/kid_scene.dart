import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Kid side
class KidScene extends StatelessWidget {
  const KidScene({super.key, required this.play, required this.onEnter});

  // Entrance playhead
  final double play;
  // Enter kid side
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Home scene
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.35),
              radius: 0.95,
              colors: [Color(0xFF4C6E55), Color(0xFF2C4234), Color(0xFF17251D)],
            ),
          ),
          child: Image(
            image: AssetImage('assets/game/backgrounds/background_new.png'),
            fit: BoxFit.cover,
            alignment: Alignment(0, -0.8),
          ),
        ),
        // Scene scrim
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.46),
                Colors.black.withValues(alpha: 0.10),
                Colors.transparent,
                const Color(0xFF17251D).withValues(alpha: 0.86),
              ],
              stops: const [0.0, 0.22, 0.55, 1.0],
            ),
          ),
        ),
        const ColoredBox(color: Color(0x5917251D)),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                child: _Reveal(
                  play: play,
                  start: 0.05,
                  end: 0.4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Fulgens',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Spacer(flex: 3),
                      // Headline
                      _Reveal(
                        play: play,
                        start: 0.12,
                        end: 0.5,
                        child: Text(
                          'Saving is how\nwe play.',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.9,
                            color: Colors.white.withValues(alpha: 0.96),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Caption
                      _Reveal(
                        play: play,
                        start: 0.2,
                        end: 0.58,
                        child: Text(
                          'Fun with money starts here.',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      const Spacer(flex: 4),
                      // Enter
                      _Reveal(
                        play: play,
                        start: 0.48,
                        end: 0.86,
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: onEnter,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text(
                              'Continue as kid',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Rise in
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.play,
    required this.start,
    required this.end,
    required this.child,
  });

  // Playhead
  final double play;
  // Window start
  final double start;
  // Window end
  final double end;
  // Content
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Local window
    final double t = ((play - start) / (end - start)).clamp(0.0, 1.0);
    final double rise = const Cubic(0.23, 1, 0.32, 1).transform(t);
    return Opacity(
      opacity: rise,
      child: Transform.translate(
        offset: Offset(0, (1 - rise) * 18),
        child: child,
      ),
    );
  }
}
