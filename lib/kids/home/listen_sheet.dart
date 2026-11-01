import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// Voice card whose bars follow the microphone level.
Future<void> showListenSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
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

  late final AnimationController _breath;
  StreamSubscription<Amplitude>? _sub;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.cancel();
    _recorder.dispose();
    _breath.dispose();
    _level.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) return;
      await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits),
      );
      _sub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 110))
          .listen(_onAmplitude);
    } catch (_) {
      return;
    }
  }

  void _onAmplitude(Amplitude amplitude) {
    final normalised = ((amplitude.current + 50) / 45).clamp(0.0, 1.0);
    _level.value = _level.value * 0.55 + normalised * 0.45;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bottomSpace = MediaQuery.maybeOf(context)?.padding.bottom ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomSpace),
      child: Container(
        height: 208,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFF6F0)],
          ),
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
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
                    valueListenable: _level,
                    builder: (context, level, _) {
                      return CustomPaint(
                        painter: _AuroraPainter(
                          level: level,
                          phase: _breath.value,
                          motion: !reduceMotion,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFE3DA),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Row(
                    children: [
                      const Spacer(),
                      _DoneCircle(
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneCircle extends StatelessWidget {
  const _DoneCircle({required this.onTap});

  static const Color _orange = Color(0xFFFF7A45);

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Done',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(side: BorderSide(color: _orange, width: 1.6)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.check_rounded, color: _orange, size: 22),
          ),
        ),
      ),
    );
  }
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
  static const List<double> _strength = [0.22, 0.17, 0.13];

  final double level;
  final double phase;
  final bool motion;

  @override
  void paint(Canvas canvas, Size size) {
    final energy = Curves.easeOutCubic.transform(level.clamp(0.0, 1.0));
    final t = phase * 2 * math.pi;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFF9E1B).withValues(alpha: 0.0),
            const Color(0xFFFFB13B).withValues(alpha: 0.04 + 0.09 * energy),
            const Color(0xFFFF7A00).withValues(alpha: 0.12 + 0.20 * energy),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    for (var layer = _colours.length - 1; layer >= 0; layer--) {
      final colour = _colours[layer];
      final strength = _strength[layer] * (0.6 + 0.6 * energy);
      final base = size.height * (0.20 + layer * 0.11);
      final amp = size.height * (0.09 + 0.15 * energy) * (1 - layer * 0.16);

      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 3) {
        path.lineTo(x, _crest(x, size, base, amp, t, layer));
      }
      path
        ..lineTo(size.width, size.height)
        ..close();

      canvas.drawPath(
        path,
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
    }
  }

  double _crest(
    double x,
    Size size,
    double base,
    double amp,
    double t,
    int layer,
  ) {
    final nx = size.width == 0 ? 0.0 : x / size.width;
    final drift = motion ? t * (0.5 + layer * 0.2) : 0.0;
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
