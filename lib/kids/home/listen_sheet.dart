import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../pocket/elastic_sheet.dart';

/// Voice card whose bars follow the microphone level.
Future<void> showListenSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    enableDrag: false,
    builder: (_) => const _ListenSheet(),
  );
}

class _ListenSheet extends StatefulWidget {
  const _ListenSheet();

  @override
  State<_ListenSheet> createState() => _ListenSheetState();
}

class _ListenSheetState extends State<_ListenSheet>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final ValueNotifier<double> _level = ValueNotifier<double>(0);
  // Smooth glide
  final ValueNotifier<double> _shown = ValueNotifier<double>(0);
  // Mic baseline settled
  final ValueNotifier<bool> _ready = ValueNotifier<bool>(false);

  late final AnimationController _breath;
  StreamSubscription<Amplitude>? _sub;
  Timer? _readyFallback;

  // Time based glide
  final Stopwatch _clock = Stopwatch()..start();
  double _lastTick = 0;
  double _drift = 0;
  double _heardAt = -1;

  // Room baseline
  double _floor = -60;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _breath.addListener(_glide);
    _readyFallback = Timer(const Duration(milliseconds: 2500), _markReady);
    _start();
  }

  // Glide step
  void _glide() {
    final now = _clock.elapsedMicroseconds / 1000000;
    final dt = now - _lastTick;
    _lastTick = now;
    if (dt <= 0 || dt > 0.25) return;

    // Hold the wave still until the room baseline has settled
    final age = _heardAt < 0 ? 0.0 : now - _heardAt;
    final target = _level.value * (age / 1.5).clamp(0.0, 1.0);

    // Ease the level: fast rise, slow fall
    final tau = target > _shown.value ? 0.06 : 0.3;
    final k = 1 - math.exp(-dt / tau);
    _shown.value += (target - _shown.value) * k;

    // Advance the wave instead of rescaling it
    _drift += dt * 3.5 * (0.15 + 0.85 * _shown.value);

    if (!_ready.value && _heardAt >= 0 && age >= 1.5) _markReady();
  }

  void _markReady() {
    if (!mounted || _ready.value) return;
    _ready.value = true;
  }

  @override
  void dispose() {
    _readyFallback?.cancel();
    _sub?.cancel();
    _recorder.cancel();
    _recorder.dispose();
    _breath.dispose();
    _level.dispose();
    _shown.dispose();
    _ready.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) return;
      await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: 44100,
        ),
      );
      _sub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 60))
          .listen(_onAmplitude);
    } catch (error) {
      debugPrint('listen: start failed $error');
      return;
    }
  }

  void _onAmplitude(Amplitude amplitude) {
    final double db = amplitude.current;
    if (_heardAt < 0) _heardAt = _clock.elapsedMicroseconds / 1000000;
    // Floor drops fast, creeps up slowly
    _floor = db < _floor ? db : _floor + (db - _floor) * 0.02;
    // Speech range above the floor
    final double norm = ((db - _floor - 6) / 34).clamp(0.0, 1.0);
    _level.value = norm < 0.04 ? 0.0 : norm;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return ElasticSheetDrag(
      onDismiss: () => Navigator.of(context).maybePop(),
      child: Container(
        height: 380,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFF6F0)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _breath,
                builder: (context, _) {
                  return ValueListenableBuilder<double>(
                    valueListenable: _shown,
                    builder: (context, level, _) {
                      return CustomPaint(
                        painter: _AuroraPainter(
                          level: level,
                          phase: _drift,
                          motion: !reduceMotion,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              right: 4,
              child: _DoneCheck(onTap: () => Navigator.of(context).maybePop()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFE3DA),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 36),
                    _PromptLine(ready: _ready, reduceMotion: reduceMotion),
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

class _PromptLine extends StatelessWidget {
  const _PromptLine({required this.ready, required this.reduceMotion});

  static const Color _ink = Color(0xFFA08A7D);

  final ValueListenable<bool> ready;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ready,
      builder: (context, isReady, _) {
        return AnimatedSwitcher(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder:
              (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
          child: Text(
            isReady ? 'Tell me what you spent' : 'Just a moment…',
            key: ValueKey(isReady),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.2,
              color: _ink,
              height: 1.25,
            ),
          ),
        );
      },
    );
  }
}

class _DoneCheck extends StatelessWidget {
  const _DoneCheck({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Done',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(painter: _CheckPainter()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFF7A45);

    final path =
        Path()
          ..moveTo(size.width * 0.14, size.height * 0.54)
          ..lineTo(size.width * 0.40, size.height * 0.80)
          ..lineTo(size.width * 0.88, size.height * 0.20);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({
    required this.level,
    required this.phase,
    required this.motion,
  });

  static const List<Color> _colours = [
    Color(0xFFFF7A00),
    Color(0xFFFF9E1B),
    Color(0xFFFFC35C),
  ];
  static const List<double> _strength = [0.26, 0.20, 0.15];

  final double level;
  final double phase;
  final bool motion;

  @override
  void paint(Canvas canvas, Size size) {
    final energy = Curves.easeOutCubic.transform(level.clamp(0.0, 1.0));
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFF9E1B).withValues(alpha: 0.0),
            const Color(0xFFFFB13B).withValues(alpha: 0.03 + 0.07 * energy),
            const Color(0xFFFF7A00).withValues(alpha: 0.08 + 0.16 * energy),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    for (var layer = _colours.length - 1; layer >= 0; layer--) {
      final colour = _colours[layer];
      final strength = _strength[layer] * (0.6 + 0.6 * energy);
      final base = size.height * (0.64 - 0.08 * energy + layer * 0.075);
      final amp = size.height * (0.03 + 0.16 * energy) * (1 - layer * 0.14);

      final crest = _crestPath(size, base, amp, layer);
      final body =
          Path.from(crest)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close();

      canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colour.withValues(alpha: 0.0),
              colour.withValues(alpha: strength * 0.45),
              colour.withValues(alpha: strength * 0.85),
              colour.withValues(alpha: strength),
            ],
            stops: const [0.0, 0.5, 0.85, 1.0],
          ).createShader(rect),
      );

      if (layer == 0) {
        canvas.drawPath(
          crest,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(
              0xFFFF7A00,
            ).withValues(alpha: 0.10 + 0.22 * energy),
        );
      }
    }
  }

  Path _crestPath(Size size, double base, double amp, int layer) {
    final path = Path();
    for (var x = 0.0; x <= size.width; x += 3) {
      final y = _crest(x, size, base, amp, layer);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  double _crest(double x, Size size, double base, double amp, int layer) {
    final nx = size.width == 0 ? 0.0 : x / size.width;
    final drift = motion ? phase * (0.8 + layer * 0.25) : 0.0;
    final a = math.sin(nx * 6.283 * (0.7 + layer * 0.3) + drift);
    final b = math.sin(nx * 12.6 - drift * 1.35 + layer);
    final c = math.sin(nx * 2.4 + drift * 0.55 + layer * 1.4);
    return (base - amp * (0.5 * a + 0.3 * b + 0.2 * c)).clamp(0.0, size.height);
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.phase != phase ||
        oldDelegate.motion != motion;
  }
}
