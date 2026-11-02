import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rive/rive.dart';

// Kids landing
class KidsLandingPage extends StatefulWidget {
  const KidsLandingPage({super.key});

  @override
  State<KidsLandingPage> createState() => _KidsLandingState();
}

// Landing state
class _KidsLandingState extends State<KidsLandingPage> {
  // Disc tween
  final Tween<double> _discTween = Tween(begin: 0, end: 1);
  // Headline tween
  final Tween<double> _headlineTween = Tween(begin: 0, end: 1);
  // Mascot gate
  bool _mascotVisible = false;
  // Idle gate
  bool _mascotIdle = false;
  // Mascot control
  final GlobalKey<_MascotRiveState> _mascotKey = GlobalKey<_MascotRiveState>();
  // Reveal timer
  Timer? _mascotTimer;

  @override
  void initState() {
    super.initState();
    // Disc lands
    _mascotTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _mascotVisible = true);
    });
  }

  @override
  void dispose() {
    _mascotTimer?.cancel();
    super.dispose();
  }

  // Idle report
  void _onMascotIdle(bool idle) {
    _mascotIdle = idle;
  }

  @override
  Widget build(BuildContext context) {
    // Reduced show
    final showMascot =
        MediaQuery.disableAnimationsOf(context) || _mascotVisible;
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    // Circle span
    final d = width * 1.7;
    // Visible cap
    final cap = height * 0.52;
    // Panda size
    final pandaW = width * 0.45;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        // Stack
        child: GestureDetector(
          // Tap advance
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Idle gate
            final reduced = MediaQuery.disableAnimationsOf(context);
            if (!reduced && !_mascotIdle) {
              // Tap to idle
              _mascotKey.currentState?.toIdle();
              return;
            }
            context.push('/kids/start');
          },
          child: Stack(
            children: [
              // Peeking rive
              // Rive swap
              if (showMascot)
                Positioned(
                  key: const ValueKey('mascot'),
                  left: (width - pandaW) / 2,
                  bottom: cap - pandaW * 0.55,
                  child: SizedBox(
                    width: pandaW,
                    height: pandaW,
                    child: _MascotRive(key: _mascotKey, onIdle: _onMascotIdle),
                  ),
                ),
              // Rising disc
              Positioned(
                key: const ValueKey('disc'),
                left: -(d - width) / 2,
                bottom: -(d - cap),
                child: TweenAnimationBuilder<double>(
                  tween: _discTween,
                  duration: const Duration(milliseconds: 2400),
                  curve: const Cubic(0.23, 1, 0.32, 1),
                  builder: (_, v, child) {
                    // Reduced
                    final reduced = MediaQuery.disableAnimationsOf(context);
                    final vv = reduced ? 1.0 : v;
                    return Transform.translate(
                      offset: Offset(0, (1 - vv) * 180),
                      child: Opacity(opacity: vv.clamp(0.0, 1.0), child: child),
                    );
                  },
                  child: SizedBox(
                    width: d,
                    height: d,
                    child: Stack(
                      // Overflow allow
                      clipBehavior: Clip.none,
                      children: [_Disc(size: d)],
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 72),
                        // Headline
                        Center(
                          child: Column(
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: _headlineTween,
                                duration: const Duration(milliseconds: 300),
                                builder: (_, v, label) {
                                  // Reduced
                                  final reduced =
                                      MediaQuery.disableAnimationsOf(context);
                                  return Opacity(
                                    opacity: reduced ? 1.0 : v,
                                    child: label,
                                  );
                                },
                                child: Text(
                                  'Saving is how we play.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Disc
class _Disc extends StatelessWidget {
  const _Disc({required this.size});

  // Span
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: size * 0.05,
                  sigmaY: size * 0.05,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: -size * 0.12,
                      top: -size * 0.10,
                      child: _DiscWash(
                        size: size * 0.62,
                        color: const Color(0xFF4285F4),
                        opacity: 0.38,
                      ),
                    ),
                    Positioned(
                      left: size * 0.20,
                      top: -size * 0.14,
                      child: _DiscWash(
                        size: size * 0.56,
                        color: const Color(0xFF34A853),
                        opacity: 0.36,
                      ),
                    ),
                    Positioned(
                      left: size * 0.52,
                      top: -size * 0.08,
                      child: _DiscWash(
                        size: size * 0.50,
                        color: const Color(0xFFEA4335),
                        opacity: 0.36,
                      ),
                    ),
                    // White gap
                    Positioned(
                      left: size * 0.11,
                      top: -size * 0.14,
                      child: _DiscWash(
                        size: size * 0.44,
                        color: Colors.white,
                        opacity: 0.80,
                      ),
                    ),
                    // White gap
                    Positioned(
                      left: size * 0.40,
                      top: -size * 0.06,
                      child: _DiscWash(
                        size: size * 0.44,
                        color: Colors.white,
                        opacity: 0.80,
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

// Disc wash
class _DiscWash extends StatelessWidget {
  const _DiscWash({
    required this.size,
    required this.color,
    required this.opacity,
  });

  // Span
  final double size;
  // Hue
  final Color color;
  // Softness
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            radius: 0.9,
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

// Rive peek
class _MascotRive extends StatefulWidget {
  const _MascotRive({super.key, this.onIdle});

  // Idle report
  final ValueChanged<bool>? onIdle;

  @override
  State<_MascotRive> createState() => _MascotRiveState();
}

// Slow controller
final class _SlowMascotController extends RiveWidgetController {
  _SlowMascotController(
    super.file, {
    this.idleSpeed = 0.65,
    this.peekSpeed = 0.75,
    this.onIdle,
  }) {
    // State track
    // ignore: deprecated_member_use, invalid_use_of_internal_member
    _states = stateMachine.onStateChanged((name) {
      debugPrint('mascot state: $name');
      if (name == 'idle' || name == 'peekOut') _state = name;
      onIdle?.call(name == 'idle');
    });
  }

  // Idle speed
  final double idleSpeed;
  // Peek speed
  final double peekSpeed;
  // Idle report
  final ValueChanged<bool>? onIdle;
  // Active state
  String _state = 'idle';
  // State sub
  CallbackHandler? _states;

  @override
  bool advance(double elapsedSeconds) {
    final s = _state == 'idle' ? idleSpeed : peekSpeed;
    return super.advance(elapsedSeconds * s);
  }

  // Skip peek
  void skipToIdle() {
    var guard = 0;
    // Known start
    _state = 'peekOut';
    while (_state != 'idle' && guard < 300) {
      super.advance(0.1);
      guard++;
    }
    debugPrint('mascot skip: $guard steps -> $_state');
  }

  @override
  void dispose() {
    _states?.dispose();
    super.dispose();
  }
}

// Rive state
class _MascotRiveState extends State<_MascotRive> {
  // File loader
  late final FileLoader _loader = FileLoader.fromAsset(
    'assets/game/mascotPeeking/fulgernspeekinganimation.riv',
    riveFactory: Factory.rive,
  );
  // Reset tick
  int _reset = 0;
  // Skip peek
  bool _skipPeek = false;

  // Force idle
  void toIdle() {
    widget.onIdle?.call(true);
    setState(() {
      _skipPeek = true;
      _reset += 1;
    });
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced freeze
    final reduced = MediaQuery.disableAnimationsOf(context);
    return RiveWidgetBuilder(
      key: ValueKey(_reset),
      fileLoader: _loader,
      controller:
          (file) => _SlowMascotController(
            file,
            idleSpeed: 0.65,
            peekSpeed: 0.75,
            onIdle: widget.onIdle,
          ),
      onLoaded: (s) {
        s.controller.active = !reduced;
        // Skip peek
        if (_skipPeek) {
          _skipPeek = false;
          (s.controller as _SlowMascotController).skipToIdle();
        }
      },
      builder:
          (_, state) => switch (state) {
            RiveLoaded(:final controller) => RiveWidget(
              controller: controller,
              fit: Fit.contain,
            ),
            RiveFailed(:final error) => Text(
              'Mascot failed: $error',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
            _ => const SizedBox.shrink(),
          },
    );
  }
}
