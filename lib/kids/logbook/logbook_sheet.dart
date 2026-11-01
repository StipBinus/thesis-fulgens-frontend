import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'entry_form_sheet.dart';
import 'logbook_models.dart';
import 'logbook_provider.dart';
import 'logbook_tokens.dart';

// Header only
const bool _logbookOtherCards = true;

Future<void> showLogbookSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x52000000),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 680),
      reverseDuration: Duration(milliseconds: 420),
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (_) => const LogbookSheet(),
  );
}

class LogbookSheet extends ConsumerStatefulWidget {
  const LogbookSheet({super.key});

  @override
  ConsumerState<LogbookSheet> createState() => _LogbookSheetState();
}

class _LogbookSheetState extends ConsumerState<LogbookSheet>
    with TickerProviderStateMixin {
  late DateTime _selected;
  int _dayDir = 1;
  late final AnimationController _intro;
  late final AnimationController _burst;
  late final CurvedAnimation _aurora;
  late final LogbookNotifier _notifier;

  final TextEditingController _note = TextEditingController();
  final FocusNode _noteFocus = FocusNode();

  Timer? _noteDebounce;
  Timer? _undoTimer;
  LogbookEntry? _pendingDelete;
  bool _startedIntro = false;
  bool _sheetDragging = false;
  double _sheetFraction = 0.58;
  double _resolvedHeight = 0;
  double? _fitHeight;
  int _slide = 0;
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _weekKey = GlobalKey();
  final GlobalKey _bodyKey = GlobalKey();

  String get _dayKey => logbookDateKey(_selected);

  bool get _isToday => _dayKey == LogbookState.todayKey;

  // Day before the selected one, for the balance comparison line.
  String get _previousDayKey => logbookDateKey(
    DateTime(_selected.year, _selected.month, _selected.day - 1),
  );

  void _startSheetDrag(DragStartDetails details, double space) {
    setState(() {
      _sheetDragging = true;
      _sheetFraction = (_resolvedHeight / space).clamp(0.14, 0.94);
    });
  }

  void _updateSheetDrag(DragUpdateDetails details, double space) {
    setState(() {
      _sheetFraction = (_sheetFraction - details.delta.dy / space).clamp(
        0.14,
        0.94,
      );
    });
  }

  void _endSheetDrag(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity > 900 || _sheetFraction < 0.24) {
      Navigator.of(context).pop();
      return;
    }
    // Release and settle back to the height the content needs.
    setState(() => _sheetDragging = false);
  }

  // Measure chrome + content so the sheet can size itself to fit.
  void _measureSheetFit() {
    final header = _headerKey.currentContext?.size?.height;
    final week = _weekKey.currentContext?.size?.height;
    final body = _bodyKey.currentContext?.size?.height;
    if (header == null || week == null || body == null) return;

    final next = 14 + header + 10 + week + 6 + body + 18;
    final current = _fitHeight;
    if (current != null && (current - next).abs() < 0.5) return;
    setState(() => _fitHeight = next);
  }

  @override
  void initState() {
    super.initState();
    _selected = DateTime.now();
    _dayDir = 1;
    _notifier = ref.read(logbookProvider.notifier);
    _note.text = ref.read(logbookProvider).dayFor(_dayKey).note;

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _aurora = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.72, curve: Curves.easeInOutSine),
    );
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) {
        _flushNote();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_startedIntro) {
      _startedIntro = true;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _intro.value = 1;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future<void>.delayed(const Duration(milliseconds: 320), () {
            if (mounted) _intro.forward();
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _noteDebounce?.cancel();
    _undoTimer?.cancel();
    _notifier.setNote(_dayKey, _note.text);
    _aurora.dispose();
    _intro.dispose();
    _burst.dispose();
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _flushNote() {
    _noteDebounce?.cancel();
    _noteDebounce = null;
    if (_note.text != ref.read(logbookProvider).dayFor(_dayKey).note) {
      _notifier.setNote(_dayKey, _note.text);
    }
  }

  void _onNoteChanged(String value) {
    _noteDebounce?.cancel();
    _noteDebounce = Timer(const Duration(milliseconds: 260), () {
      _notifier.setNote(_dayKey, value);
    });
  }

  void _selectDay(DateTime date) {
    _flushNote();
    setState(() {
      _dayDir = date.isAfter(_selected) ? 1 : -1;
      _selected = date;
      _slide = 0;
      _note.text = ref.read(logbookProvider).dayFor(_dayKey).note;
    });
  }

  void _openEntryForm({LogbookEntry? existing}) {
    showEntryFormSheet(
      context,
      dateKey: _dayKey,
      existing: existing,
      onDelete: existing == null ? null : _deleteEntry,
    );
  }

  void _deleteEntry(LogbookEntry entry) {
    final removed = _notifier.deleteEntry(_dayKey, entry.id);
    if (removed == null) return;

    _undoTimer?.cancel();
    setState(() => _pendingDelete = removed);
    _undoTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _pendingDelete = null);
    });
  }

  void _undoDelete() {
    final removed = _pendingDelete;
    if (removed == null) return;

    _undoTimer?.cancel();
    _notifier.addEntry(_dayKey, removed);
    setState(() => _pendingDelete = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(logbookProvider);
    final day = state.dayFor(_dayKey);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final media = MediaQuery.of(context);
    // Ignore keyboard while another route (entry form) is on top
    final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final keyboard = isTopRoute ? media.viewInsets.bottom : 0.0;
    final sheetSpace = media.size.height - media.padding.top - keyboard;
    final fittedHeight = (_fitHeight ?? sheetSpace * 0.58).clamp(
      sheetSpace * 0.3,
      sheetSpace * 0.9,
    );
    final contentFits = (_fitHeight ?? 0) <= sheetSpace * 0.9;
    final sheetHeight =
        _sheetDragging ? sheetSpace * _sheetFraction : fittedHeight;
    _resolvedHeight = sheetHeight;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureSheetFit();
    });

    ref.listen(logbookProvider, (previous, next) {
      if (previous != null) {
        final wasLogged = previous.dayFor(_dayKey).rewardClaimed;
        final isLogged = next.dayFor(_dayKey).rewardClaimed;
        if (!wasLogged && isLogged && !reduceMotion) {
          _burst.forward(from: 0);
        }
      }

      if (!_noteFocus.hasFocus) {
        final persisted = next.dayFor(_dayKey).note;
        if (_note.text != persisted) _note.text = persisted;
      }
    });

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (details) => _startSheetDrag(details, sheetSpace),
        onVerticalDragUpdate:
            (details) => _updateSheetDrag(details, sheetSpace),
        onVerticalDragEnd: _endSheetDrag,
        child: AnimatedContainer(
          duration:
              _sheetDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 560),
          curve: Curves.easeOutCubic,
          height: sheetHeight,
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(52)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Aurora veil
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 330,
                  child: AnimatedBuilder(
                    animation: _aurora,
                    builder: (context, child) =>
                        Opacity(opacity: _aurora.value, child: child),
                    child: const RepaintBoundary(child: LogbookAurora()),
                  ),
                ),
                Column(
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        key: _headerKey,
                        children: [
                          _ButtonReveal(
                            animation: _intro,
                            interval: const Interval(
                              0.26,
                              0.72,
                              curve: Curves.easeOutCubic,
                            ),
                            child: _CircleButton(
                              icon: Icons.close_rounded,
                              background: Colors.white,
                              foreground: logbookInk,
                              tooltip: 'Close logbook',
                              size: 42,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LogbookReveal(
                              animation: _intro,
                              interval: const Interval(
                                0.34,
                                0.96,
                                curve: Curves.easeOutCubic,
                              ),
                              child: _Header(
                                selected: _selected,
                                isToday: _isToday,
                                direction: _dayDir,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ButtonReveal(
                            animation: _intro,
                            interval: const Interval(
                              0.32,
                              0.78,
                              curve: Curves.easeOutCubic,
                            ),
                            child: _CircleButton(
                              icon: Icons.check_rounded,
                              background: logbookAccent,
                              foreground: Colors.white,
                              tooltip: 'Done',
                              size: 42,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    LogbookReveal(
                      animation: _intro,
                      interval: const Interval(
                        0.5,
                        1,
                        curve: Curves.easeOutCubic,
                      ),
                      child: Padding(
                        key: _weekKey,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _WeekStrip(
                          selected: _selected,
                          state: state,
                          onSelect: _selectDay,
                        ),
                      ),
                    ),
                    ...[
                      const SizedBox(height: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            18,
                            0,
                            18,
                            contentFits ? 0 : 56,
                          ),
                          child: Column(
                            key: _bodyKey,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              if (_isToday) ...[
                                LogbookReveal(
                                  animation: _intro,
                                  interval: const Interval(
                                    0.36,
                                    0.8,
                                    curve: Curves.easeOutCubic,
                                  ),
                                  child: _SlideToggle(
                                    index: _slide,
                                    onChanged:
                                        (index) =>
                                            setState(() => _slide = index),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              AnimatedSwitcher(
                                duration:
                                    reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                layoutBuilder:
                                    (current, previous) => Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        ...previous.map(
                                          (child) => Positioned(
                                            top: 0,
                                            left: 0,
                                            right: 0,
                                            child: child,
                                          ),
                                        ),
                                        if (current != null) current,
                                      ],
                                    ),
                                transitionBuilder: (child, animation) {
                                  final incoming =
                                      child.key == ValueKey(_slide);
                                  final direction = _slide == 1 ? 1 : -1;
                                  final begin = Offset(
                                    (incoming ? direction : -direction) * 0.06,
                                    0,
                                  );
                                  return SlideTransition(
                                    position: Tween(
                                      begin: begin,
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                  child: Column(
                                    key: ValueKey(_slide),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (!_isToday || _slide == 0)
                                        LogbookReveal(
                                          animation: _intro,
                                          interval: const Interval(
                                            0.46,
                                            0.88,
                                            curve: Curves.easeOutCubic,
                                          ),
                                          child: _MoneyCard(
                                            day: day,
                                            isToday: _isToday,
                                            balance: state.balanceOn(_dayKey),
                                            yesterday:
                                                state.dayFor(_previousDayKey),
                                            dayKey: _dayKey,
                                            onAdd:
                                                _isToday
                                                    ? () => _openEntryForm()
                                                    : null,
                                            onZeroSpend:
                                                () => _notifier.toggleZeroSpend(
                                                  _dayKey,
                                                ),
                                            onEdit:
                                                (entry) => _openEntryForm(
                                                  existing: entry,
                                                ),
                                            onDelete: _deleteEntry,
                                          ),
                                        ),
                                      if (!_isToday &&
                                          _logbookOtherCards)
                                        const SizedBox(height: 20),
                                      if (_logbookOtherCards &&
                                          (!_isToday || _slide == 1))
                                        LogbookReveal(
                                          animation: _intro,
                                          interval: const Interval(
                                            0.62,
                                            1,
                                            curve: Curves.easeOutCubic,
                                          ),
                                          child: _DiaryCard(
                                            note: day.note,
                                            editable: _isToday,
                                            controller: _note,
                                            focusNode: _noteFocus,
                                            onChanged: _onNoteChanged,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!reduceMotion)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _burst,
                        builder: (context, _) {
                          final t = _burst.value;
                          if (t == 0 || t == 1) return const SizedBox.shrink();
                          return Center(
                            child: Opacity(
                              opacity: (1 - t).clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, -60 * t),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _TokenChip(
                                      token: const LogbookCoin(size: 26),
                                      label: '+$logbookCoinsPerDay',
                                      color: const Color(0xFF9A7420),
                                      background: const Color(0xFFFFF6DA),
                                    ),
                                    const SizedBox(width: 8),
                                    _TokenChip(
                                      token: const BerryToken(size: 26),
                                      label: '+$logbookBerriesPerDay',
                                      color: const Color(0xFFB02745),
                                      background: const Color(0xFFFFE7EC),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child:
                        _pendingDelete == null
                            ? const SizedBox.shrink()
                            : _UndoBar(
                              key: const ValueKey('undo'),
                              onUndo: _undoDelete,
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.selected,
    required this.isToday,
    required this.direction,
  });

  final DateTime selected;
  final bool isToday;
  final int direction;

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final label =
        '${_weekdays[selected.weekday - 1]}, ${selected.day} ${_months[selected.month - 1]} ${selected.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Logbook',
            style: TextStyle(
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2A150A),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder:
                (current, previous) => Stack(
                  alignment: Alignment.center,
                  children: [...previous, if (current != null) current],
                ),
            transitionBuilder: (child, animation) {
              final incoming = child.key == ValueKey(label);
              final begin = Offset(
                (incoming ? direction : -direction) * 0.32,
                0,
              );
              return SlideTransition(
                position: Tween(
                  begin: begin,
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Text(
              isToday ? '$label \u00B7 Today' : label,
              key: ValueKey(label),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4A2410),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({
    required this.token,
    required this.label,
    required this.color,
    required this.background,
  });

  final Widget token;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          token,
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selected,
    required this.state,
    required this.onSelect,
  });

  final DateTime selected;
  final LogbookState state;
  final ValueChanged<DateTime> onSelect;

  static const List<String> _labels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = logbookDateKey(today);
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));

    return Row(
      children: List.generate(7, (index) {
        final date = monday.add(Duration(days: index));
        final key = logbookDateKey(date);
        final day = state.dayFor(key);
        final isSelected = key == logbookDateKey(selected);
        final isToday = key == todayKey;
        final isFuture = date.isAfter(
          DateTime(today.year, today.month, today.day),
        );
        final filled = day.isLogged || day.hasMoneyRecord;
        final doneToday = day.qualifies || day.isLogged;
        final isMissed = !filled && !isToday && !isFuture;

        // Ring tone
        final ring =
            isToday
                ? doneToday
                    ? logbookGreen
                    : logbookAccent
                : filled
                ? logbookGreen
                : isMissed
                ? logbookRed
                : const Color(0xFFEDE8E2);

        return Expanded(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: isFuture ? null : () => onSelect(date),
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isSelected)
                    const Positioned.fill(child: _SelectionCard()),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _labels[index],
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: FontWeight.w500,
                            color:
                                isFuture
                                    ? const Color(0xFFB3A79A)
                                    : const Color(0xFF6E6055),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _DayRing(
                          selected: isSelected,
                          color: ring,
                          stroke: isToday ? 2.6 : 2.2,
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.1,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                              color:
                                  isFuture
                                      ? const Color(0xFFB3A79A)
                                      : logbookInk,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          width: 4,
                          height: 4,
                          child:
                              isToday
                                  ? const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF2E9C6A),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// Dashed ring
class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tau = 6.283185307179586;
    final radius = size.shortestSide / 2 - 1.5;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    const dash = 3.6;
    const gap = 2.8;
    final circumference = tau * radius;
    final count = (circumference / (dash + gap)).floor();
    for (var i = 0; i < count; i++) {
      canvas.drawArc(
        rect,
        i * (dash + gap) / radius - tau / 4,
        dash / radius,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

// Day ring
class _DayRing extends StatefulWidget {
  const _DayRing({
    required this.selected,
    required this.color,
    required this.stroke,
    required this.child,
  });

  final bool selected;
  final Color color;
  final double stroke;
  final Widget child;

  @override
  State<_DayRing> createState() => _DayRingState();
}

class _DayRingState extends State<_DayRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _DayRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _morph.forward();
      } else {
        _morph.reverse();
      }
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _morph,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_morph.value);
        return SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: (1 - t) * 2.4,
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: CustomPaint(
                    size: const Size.square(36),
                    painter: _DashedRingPainter(color: widget.color),
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.84 + 0.16 * t,
                child: Opacity(
                  opacity: t,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color,
                        width: widget.stroke,
                      ),
                    ),
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

// Selection card
class _SelectionCard extends StatelessWidget {
  const _SelectionCard();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F7A4A2A),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6EE).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Balance hero
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.balance,
    required this.day,
    required this.dayKey,
    required this.onZeroSpend,
  });

  final int balance;
  final LogbookDay day;
  final String dayKey;
  final VoidCallback onZeroSpend;

  @override
  Widget build(BuildContext context) {
    final move = day.totalEarned - day.totalSpent;
    final shownBalance = balance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'BALANCE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: logbookFaint,
              ),
            ),
            const Spacer(),
            _ZeroSpendChip(
              active: day.zeroSpend,
              onTap: onZeroSpend,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _RollingBalance(
                        value: shownBalance,
                        dayKey: dayKey,
                        style: const TextStyle(
                          fontSize: 34,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                          color: logbookInk,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BalanceDelta(delta: move, dayKey: dayKey),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _BalanceStat(
                label: 'Earned',
                amount: day.totalEarned,
                color: logbookGreen,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _BalanceStat(
                label: 'Spent',
                amount: day.totalSpent,
                color: logbookRed,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Balance change indicator
class _BalanceDelta extends StatefulWidget {
  const _BalanceDelta({required this.delta, required this.dayKey});

  final int delta;
  final String dayKey;

  @override
  State<_BalanceDelta> createState() => _BalanceDeltaState();
}

class _BalanceDeltaState extends State<_BalanceDelta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(covariant _BalanceDelta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayKey != widget.dayKey || oldWidget.delta != widget.delta) {
      _play();
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  void _play() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _roll.value = 1;
    } else {
      _roll.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flat = widget.delta == 0;
    final up = widget.delta > 0;
    final tone = flat
        ? logbookFaint
        : up
        ? logbookGreen
        : logbookRed;
    final text = flat
        ? '\u2013'
        : '${up ? '+' : '\u2212'}${logbookRupiah(widget.delta.abs())}';
    final textStyle = TextStyle(
      fontSize: flat ? 15 : 11,
      height: flat ? 1 : null,
      fontWeight: FontWeight.w600,
      color: tone,
    );

    return Semantics(
      label: flat
          ? 'No change from yesterday'
          : 'Balance ${up ? 'up' : 'down'} ${logbookRupiah(widget.delta.abs())} from yesterday',
      child: ExcludeSemantics(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _roll,
            builder: (context, _) {
              final progress = _roll.value;
              final chars = text.split('');
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!flat) ...[
                    _WaveIcon(
                      progress: progress,
                      index: 0,
                      child: Icon(
                        up
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 15,
                        color: tone,
                      ),
                    ),
                    const SizedBox(width: 3),
                  ],
                  for (var i = 0; i < chars.length; i++)
                    _WaveGlyph(
                      glyph: chars[i],
                      index: flat ? i : i + 1,
                      progress: progress,
                      style: textStyle,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Wave icon
class _WaveIcon extends StatelessWidget {
  const _WaveIcon({
    required this.progress,
    required this.index,
    required this.child,
  });

  final double progress;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.03).clamp(0.0, 0.55);
    final local = ((progress - start) / 0.4).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(local);

    return Transform.translate(
      offset: Offset(0, 24 * (1 - eased)),
      child: Opacity(
        opacity: (0.15 + 0.85 * local).clamp(0.0, 1.0),
        child: child,
      ),
    );
  }
}

// Quick add entry
// Add entry pill
class _AddEntryPill extends StatelessWidget {
  const _AddEntryPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add entry',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: logbookInk,
            borderRadius: BorderRadius.circular(23),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Add entry',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Zero spend chip
class _ZeroSpendChip extends StatelessWidget {
  const _ZeroSpendChip({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      button: true,
      selected: active,
      label: 'Nothing today',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration:
              reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? logbookGreenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: active ? Colors.transparent : logbookLine,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: logbookGreen,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                'Nothing today',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? logbookGreen : logbookFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Rolling balance
class _RollingBalance extends StatefulWidget {
  const _RollingBalance({
    required this.value,
    required this.dayKey,
    required this.style,
  });

  final int value;
  final String dayKey;
  final TextStyle style;

  @override
  State<_RollingBalance> createState() => _RollingBalanceState();
}

class _RollingBalanceState extends State<_RollingBalance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(covariant _RollingBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayKey != widget.dayKey || oldWidget.value != widget.value) {
      _play();
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  void _play() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _roll.value = 1;
    } else {
      _roll.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _roll,
        builder: (context, _) {
          final chars = logbookRupiah(widget.value).split('');
          final progress = _roll.value;

          return Semantics(
            label: logbookRupiah(widget.value),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < chars.length; i++)
                    _WaveGlyph(
                      glyph: chars[i],
                      index: i,
                      progress: progress,
                      style: widget.style,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// One glyph of the wave
class _WaveGlyph extends StatelessWidget {
  const _WaveGlyph({
    required this.glyph,
    required this.index,
    required this.progress,
    required this.style,
  });

  final String glyph;
  final int index;
  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.03).clamp(0.0, 0.55);
    final local = ((progress - start) / 0.4).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(local);

    return Transform.translate(
      offset: Offset(0, 24 * (1 - eased)),
      child: Opacity(
        opacity: (0.15 + 0.85 * local).clamp(0.0, 1.0),
        child: Text(glyph, maxLines: 1, style: style),
      ),
    );
  }
}

// Rolling figure
class _CountValue extends StatelessWidget {
  const _CountValue({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder:
          (context, animated, _) => Text(
            logbookRupiah(animated.round()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        _CountValue(
          value: amount,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: logbookInk,
          ),
        ),
      ],
    );
  }
}

// Slide toggle
class _SlideToggle extends StatefulWidget {
  const _SlideToggle({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  State<_SlideToggle> createState() => _SlideToggleState();
}

class _SlideToggleState extends State<_SlideToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.index.toDouble(),
  );

  @override
  void didUpdateWidget(covariant _SlideToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _slide.value = widget.index.toDouble();
    } else {
      _slide.animateTo(widget.index.toDouble(), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: logbookTrack,
        borderRadius: BorderRadius.circular(30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _slide,
              builder: (context, child) {
                final t = _slide.value.clamp(0.0, 1.0);
                final eased = Curves.easeOutBack.transform(t);
                final align = (-1 + 2 * eased).clamp(-1.04, 1.04);
                return Align(
                  alignment: Alignment(align, 0),
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: child,
                  ),
                );
              },
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A1A1A1A),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _SlideTab(
                    label: 'Money',
                    selected: widget.index == 0,
                    onTap: () => widget.onChanged(0),
                  ),
                ),
                Expanded(
                  child: _SlideTab(
                    label: 'Diary',
                    selected: widget.index == 1,
                    onTap: () => widget.onChanged(1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideTab extends StatelessWidget {
  const _SlideTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration:
                reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? logbookInk : logbookMuted,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.day,
    required this.isToday,
    required this.balance,
    required this.yesterday,
    required this.dayKey,
    required this.onAdd,
    required this.onZeroSpend,
    required this.onEdit,
    required this.onDelete,
  });

  final LogbookDay day;
  final bool isToday;
  final int balance;
  final LogbookDay yesterday;
  final String dayKey;
  final VoidCallback? onAdd;
  final VoidCallback onZeroSpend;
  final ValueChanged<LogbookEntry> onEdit;
  final ValueChanged<LogbookEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BalanceHero(
            balance: balance,
            day: day,
            dayKey: dayKey,
            onZeroSpend: onZeroSpend,
          ),
          if (day.entries.isNotEmpty) ...[
            const SizedBox(height: 26),
            for (var i = 0; i < day.entries.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              if (isToday)
                _SwipeDeleteRow(
                  key: ValueKey(day.entries[i].id),
                  entry: day.entries[i],
                  onTap: () => onEdit(day.entries[i]),
                  onDelete: () => onDelete(day.entries[i]),
                )
              else
                _EntryRow(entry: day.entries[i]),
            ],
          ],
          if (isToday && onAdd != null) ...[
            const SizedBox(height: 22),
            _AddEntryPill(onTap: onAdd!),
          ],
        ],
      ),
    );
  }
}

// Swipe to reveal delete
class _SwipeDeleteRow extends StatefulWidget {
  const _SwipeDeleteRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final LogbookEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_SwipeDeleteRow> createState() => _SwipeDeleteRowState();
}

class _SwipeDeleteRowState extends State<_SwipeDeleteRow>
    with SingleTickerProviderStateMixin {
  static const double _revealWidth = 38;
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _dragBy(double dx) {
    _slide.value = (_slide.value - dx / _revealWidth).clamp(0.0, 1.0);
  }

  void _settle() {
    final target = _slide.value > 0.4 ? 1.0 : 0.0;
    if (_reduceMotion) {
      _slide.value = target;
      return;
    }
    _slide.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleTap() {
    if (_slide.value > 0) {
      _settle();
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _slide.stop(),
      onHorizontalDragUpdate: (details) => _dragBy(details.primaryDelta ?? 0),
      onHorizontalDragEnd: (_) => _settle(),
      onHorizontalDragCancel: _settle,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _slide,
          builder: (context, _) {
            final reveal = _slide.value;
            return Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ClipRect(
                      child: SizedBox(
                        width: _revealWidth * reveal,
                        height: 30,
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: _revealWidth,
                          maxWidth: _revealWidth,
                          minHeight: 30,
                          maxHeight: 30,
                          child: Opacity(
                            opacity: reveal.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.86 + 0.14 * reveal,
                              child: _RowDelete(onTap: widget.onDelete),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(-_revealWidth * reveal, 0),
                  child: _EntryRow(
                    entry: widget.entry,
                    onTap: _handleTap,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Row delete button
class _RowDelete extends StatelessWidget {
  const _RowDelete({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Delete entry',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: Color(0xFFF6DCD3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(0xFFEFD5CB)),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            size: 16,
            color: logbookRed,
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, this.onTap});

  final LogbookEntry entry;
  final VoidCallback? onTap;

  static IconData _iconFor(LogbookCategory category) {
    switch (category) {
      case LogbookCategory.foodAndBeverage:
        return Icons.restaurant_rounded;
      case LogbookCategory.transport:
        return Icons.directions_bus_rounded;
      case LogbookCategory.entertainment:
        return Icons.sports_esports_rounded;
      case LogbookCategory.school:
        return Icons.school_rounded;
      case LogbookCategory.hobby:
        return Icons.palette_rounded;
      case LogbookCategory.other:
        return Icons.more_horiz_rounded;
      case LogbookCategory.allowance:
        return Icons.savings_rounded;
      case LogbookCategory.gift:
        return Icons.card_giftcard_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = entry.isExpense;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: expense ? logbookRedSoft : logbookGreenSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _iconFor(entry.category),
                size: 16,
                color: expense ? logbookRed : logbookGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isEmpty ? entry.category.label : entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: logbookLabel,
                    ),
                  ),
                  if (entry.note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      entry.note,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                        color: logbookMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${expense ? '-' : '+'} ${logbookRupiah(entry.amount)}',
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: expense ? logbookRed : logbookGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({
    required this.note,
    required this.editable,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final String note;
  final bool editable;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Diary',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: logbookLabel,
                ),
              ),
              const Spacer(),
              if (editable)
                Text(
                  '${controller.text.length}/500',
                  style: const TextStyle(fontSize: 10.5, color: logbookFaint),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (editable)
            TextField(
              controller: controller,
              focusNode: focusNode,
              maxLength: 500,
              minLines: 3,
              maxLines: null,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: logbookInk,
              ),
              decoration: InputDecoration(
                hintText: 'What happened today?',
                hintStyle: const TextStyle(fontSize: 11.5, color: logbookFaint),
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                counterText: '',
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            )
          else
            Text(
              note.isEmpty ? 'No note written.' : note,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                fontStyle: note.isEmpty ? FontStyle.italic : FontStyle.normal,
                color: note.isEmpty ? logbookFaint : logbookInk,
              ),
            ),
        ],
      ),
    );
  }
}

class _UndoBar extends StatelessWidget {
  const _UndoBar({super.key, required this.onUndo});

  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Entry deleted',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFFB38F),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Undo',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// Circle button
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.tooltip,
    required this.size,
    required this.onTap,
  });

  // Glyph
  final IconData icon;
  // Fill
  final Color background;
  // Glyph tint
  final Color foreground;
  // Label
  final String tooltip;
  // Span
  final double size;
  // Tap
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x40000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: foreground, size: size * 0.52),
          ),
        ),
      ),
    );
  }
}

// Button reveal
class _ButtonReveal extends StatelessWidget {
  const _ButtonReveal({
    required this.animation,
    required this.interval,
    required this.child,
  });

  // Driver
  final Animation<double> animation;
  // Window
  final Interval interval;
  // Target
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: interval);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.82 + 0.18 * t,
            child: Transform.translate(
              offset: Offset(0, 6 * (1 - t)),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
