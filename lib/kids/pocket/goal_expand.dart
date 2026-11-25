import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../finance/finance_api.dart';
import '../finance/finance_models.dart';
import '../finance/finance_repository.dart';
import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';
import 'emoji_picker.dart';
import 'activity_history.dart';
import 'pocket_expand.dart';

// What the expanded goal card sends back
enum GoalExpandResult { add, takeOut, saved }

Future<GoalExpandResult?> showGoalExpand(
  BuildContext context, {
  required ChildGoal goal,
  required Rect sourceRect,
  required int available,
  // Add / take out over the open card; returns the updated goal
  Future<ChildGoal?> Function(BuildContext context, ChildGoal goal)? onAddMoney,
  Future<ChildGoal?> Function(BuildContext context, ChildGoal goal)? onTakeOut,
}) async {
  final bool reduce = MediaQuery.disableAnimationsOf(context);
  // Live copy so the card refreshes after a money move
  final live = ValueNotifier<ChildGoal>(goal);
  var liveAvailable = available;

  return Navigator.of(context).push<GoalExpandResult>(
    PageRouteBuilder<GoalExpandResult>(
      opaque: false,
      barrierColor: null,
      transitionDuration:
          reduce
              ? const Duration(milliseconds: 1)
              : const Duration(milliseconds: 620),
      reverseTransitionDuration:
          reduce
              ? const Duration(milliseconds: 1)
              : const Duration(milliseconds: 420),
      pageBuilder: (routeContext, animation, secondaryAnimation) {
        bool done = false;
        void finish([GoalExpandResult? result]) {
          if (done) return;
          done = true;
          Navigator.of(routeContext).pop(result);
        }

        Future<void> moveHere(
          Future<ChildGoal?> Function(BuildContext, ChildGoal) move,
        ) async {
          final before = live.value;
          final updated = await move(routeContext, before);
          if (updated == null) return;
          liveAvailable -= updated.allocatedBalance - before.allocatedBalance;
          live.value = updated;
        }

        return ValueListenableBuilder<ChildGoal>(
          valueListenable: live,
          builder:
              (context, current, _) => _GoalExpandPage(
                animation: animation,
                beginRect: sourceRect,
                reduceMotion: reduce,
                goal: current,
                available: liveAvailable,
                onClose: () => finish(),
                // Money moves keep the card open when the page can handle them
                onAdd:
                    onAddMoney != null
                        ? () => moveHere(onAddMoney)
                        : () => finish(GoalExpandResult.add),
                onTakeOut:
                    onTakeOut != null
                        ? () => moveHere(onTakeOut)
                        : () => finish(GoalExpandResult.takeOut),
                onSaved: () => finish(GoalExpandResult.saved),
              ),
        );
      },
    ),
  );
}

class _GoalExpandPage extends StatefulWidget {
  const _GoalExpandPage({
    required this.animation,
    required this.beginRect,
    required this.reduceMotion,
    required this.goal,
    required this.available,
    required this.onClose,
    required this.onAdd,
    required this.onTakeOut,
    required this.onSaved,
  });

  final Animation<double> animation;
  final Rect beginRect;
  final bool reduceMotion;
  final ChildGoal goal;
  final int available;
  final VoidCallback onClose;
  final VoidCallback onAdd;
  final VoidCallback onTakeOut;
  final VoidCallback onSaved;

  @override
  State<_GoalExpandPage> createState() => _GoalExpandPageState();
}

class _GoalExpandPageState extends State<_GoalExpandPage> {
  final GlobalKey<_GoalExpandedCardState> _card = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final Rect endRect = pocketExpandedRect(context);

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final double t = widget.animation.value;
        final double eased =
            widget.reduceMotion ? 1 : pocketExpandEase.transform(t);
        final Rect rect =
            widget.reduceMotion
                ? endRect
                : Rect.lerp(widget.beginRect, endRect, eased)!;
        final double radius = 24 + 8 * eased;
        final double barT =
            widget.reduceMotion
                ? 1
                : pocketExpandEase.transform(_ramp(t, 0.42, 1));
        final double scrim =
            widget.reduceMotion
                ? 0.55
                : 0.55 * pocketExpandEase.transform(_ramp(t, 0, 0.82));

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: scrim),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: ColoredBox(
                  color: Colors.white,
                  child: _GoalExpandedCard(
                    key: _card,
                    goal: widget.goal,
                    available: widget.available,
                    animation: widget.animation,
                    onAdd: widget.onAdd,
                    onTakeOut: widget.onTakeOut,
                    onSaved: widget.onSaved,
                  ),
                ),
              ),
            ),
            Positioned(
              top: padding.top + 8,
              left: 12,
              right: 12,
              child: Opacity(
                opacity: barT,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _topButton(
                      icon: Icons.close_rounded,
                      onTap: widget.onClose,
                    ),
                    _topButton(
                      icon: Icons.check_rounded,
                      onTap: () => _card.currentState?.save(),
                      filled: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _topButton({
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 21,
            color: filled ? logbookInk : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GoalExpandedCard extends StatefulWidget {
  const _GoalExpandedCard({
    super.key,
    required this.goal,
    required this.available,
    required this.animation,
    required this.onAdd,
    required this.onTakeOut,
    required this.onSaved,
  });

  final ChildGoal goal;
  final int available;
  final Animation<double> animation;
  final VoidCallback onAdd;
  final VoidCallback onTakeOut;
  final VoidCallback onSaved;

  @override
  State<_GoalExpandedCard> createState() => _GoalExpandedCardState();
}

class _GoalExpandedCardState extends State<_GoalExpandedCard> {
  final GoalRepository _repository = LocalGoalRepository();

  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _target;
  late final TextEditingController _saved;
  late final TextEditingController _image;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.goal.goalsName);
    _desc = TextEditingController(text: widget.goal.goalsDesc ?? '');
    _target = TextEditingController(text: '${widget.goal.goalPrice}');
    _image = TextEditingController(text: widget.goal.goalImage ?? '');
    _saved = TextEditingController(
      text:
          widget.goal.allocatedBalance > 0
              ? '${widget.goal.allocatedBalance}'
              : '',
    );
  }

  // Saved amount changed from outside: refresh the field
  @override
  void didUpdateWidget(covariant _GoalExpandedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.goal.allocatedBalance;
    if (next != oldWidget.goal.allocatedBalance) {
      _saved.text = next > 0 ? '$next' : '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _target.dispose();
    _saved.dispose();
    _image.dispose();
    super.dispose();
  }

  int _amount(TextEditingController controller) {
    final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Future<void> save() async {
    if (_saving) return;

    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your goal a name first.');
      return;
    }

    final int target = _amount(_target);
    if (target <= 0) {
      setState(() => _error = 'Set a target bigger than Rp 0.');
      return;
    }

    final int allocated = _amount(_saved);
    if (allocated > widget.available) {
      setState(
        () =>
            _error =
                'You can only set aside up to '
                '${financeRupiah(widget.available)}.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _repository.updateGoal(
        goalId: widget.goal.goalId,
        name: name,
        description: _desc.text,
        allocatedBalance: allocated,
        goalPrice: target,
        image: _image.text,
      );
      if (!mounted) return;
      widget.onSaved();
    } on FinanceApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the goal. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> statsReveal = widget.animation.drive(
      CurveTween(
        curve: const Interval(0.12, 0.62, curve: pocketExpandEase),
      ),
    );
    final Animation<double> rowsReveal = widget.animation.drive(
      CurveTween(
        curve: const Interval(0.28, 0.78, curve: pocketExpandEase),
      ),
    );
    final Animation<double> sectionReveal = widget.animation.drive(
      CurveTween(
        curve: const Interval(0.48, 0.92, curve: pocketExpandEase),
      ),
    );
    final double grow = pocketExpandEase.transform(
      widget.animation.value.clamp(0.0, 1.0),
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _flagBadge(size: 44 + 4 * grow),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _liveName(size: 18 + 3 * grow),
                          const SizedBox(height: 3),
                          _liveDesc(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _hero(),
                SizeTransition(
                  sizeFactor: statsReveal,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(height: 1, color: logbookLine),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _stat(
                            'SET ASIDE',
                            financeRupiah(widget.goal.allocatedBalance),
                            logbookInk,
                          ),
                          _stat(
                            'TARGET',
                            financeRupiah(widget.goal.goalPrice),
                            logbookInk,
                          ),
                          _stat('TO GO', _toGo, logbookMuted),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(height: 1, color: logbookLine),
                    ],
                  ),
                ),
                SizeTransition(
                  sizeFactor: rowsReveal,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      _fieldRow(
                        PocketIconPicker(
                          controller: _image,
                          name: _name,
                          goal: true,
                          fieldBuilder:
                              (leading) => Row(
                                children: [
                                  if (leading != null) ...[
                                    leading,
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: _InlineField(
                                      icon: Icons.edit_outlined,
                                      label: 'Name',
                                      controller: _name,
                                      hint: 'Goal name',
                                    ),
                                  ),
                                ],
                              ),
                        ),
                        first: true,
                      ),
                      _fieldRow(
                        _InlineField(
                          icon: Icons.notes_rounded,
                          label: 'Note',
                          controller: _desc,
                          hint: 'What is this goal for?',
                        ),
                      ),
                      _fieldRow(
                        _InlineField(
                          icon: Icons.flag_outlined,
                          label: 'Target',
                          controller: _target,
                          hint: '0',
                          number: true,
                          prefix: 'Rp ',
                        ),
                      ),
                      _fieldRow(
                        _InlineField(
                          icon: Icons.savings_outlined,
                          label: 'Set aside',
                          controller: _saved,
                          hint: '0',
                          number: true,
                          prefix: 'Rp ',
                        ),
                        last: true,
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: logbookRed,
                      ),
                    ),
                  ),
                SizeTransition(
                  sizeFactor: sectionReveal,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: sectionReveal,
                    child: Column(
                      children: [
                        const SizedBox(height: 22),
                        Row(
                          children: const [
                            Text(
                              'ACTIVITY',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: logbookMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ActivityTimeline(targetId: widget.goal.goalId, limit: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _bottomBar(),
      ],
    );
  }

  String get _toGo {
    final int left = widget.goal.goalPrice - widget.goal.allocatedBalance;
    return financeRupiah(left < 0 ? 0 : left);
  }

  Widget _hero() {
    final Color tint = financePocketTint(widget.goal.goalsName, image: widget.goal.goalImage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              financeRupiah(widget.goal.allocatedBalance),
              style: const TextStyle(
                fontSize: 34,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                color: logbookInk,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'of ${financeRupiah(widget.goal.goalPrice)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: logbookFaint,
                ),
              ),
            ),
            Text(
              financePercent(widget.goal.progress),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 8, color: logbookTrack),
              FractionallySizedBox(
                widthFactor: widget.goal.progress,
                child: Container(height: 8, color: tint),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    final Color tint = financePocketTint(widget.goal.goalsName, image: widget.goal.goalImage);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: logbookLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _action(
              label: 'Add',
              icon: Icons.add_rounded,
              strong: true,
              accentTint: tint,
              onTap: widget.onAdd,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _action(
              label: 'Take out',
              icon: Icons.north_east_rounded,
              danger: true,
              enabled: widget.goal.allocatedBalance > 0,
              onTap: widget.onTakeOut,
            ),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool strong = false,
    bool enabled = true,
    bool danger = false,
    Color? accentTint,
  }) {
    final bool tinted = strong && accentTint != null;
    final Color fg =
        !enabled
            ? logbookFaint
            : (danger
                ? logbookRed
                : (tinted ? accentTint : logbookInk));
    final Color line =
        !enabled
            ? logbookLine
            : (danger
                ? logbookRed
                : (tinted
                    ? accentTint.withValues(alpha: 0.5)
                    : (strong ? logbookInk : logbookLine)));
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: line, width: strong ? 1.3 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flagBadge({required double size}) {
    final Color tint = financePocketTint(widget.goal.goalsName, image: widget.goal.goalImage);
    // Picked icon, else the flag
    final look = pocketLookFor(widget.goal.goalImage);
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          look?.icon ?? Icons.flag_rounded,
          size: size * 0.46,
          color: look?.tint ?? tint,
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: logbookFaint,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldRow(Widget field, {bool first = false, bool last = false}) {
    return Column(
      children: [
        if (!first) Container(height: 1, color: logbookLine),
        field,
        if (last) const SizedBox(height: 2),
      ],
    );
  }

  Widget _liveName({required double size}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _name,
      builder: (context, value, _) {
        final text = value.text.trim();
        return Text(
          text.isEmpty ? 'Untitled goal' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: size,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: logbookInk,
          ),
        );
      },
    );
  }

  Widget _liveDesc() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _desc,
      builder: (context, value, _) {
        final text = value.text.trim();
        return Text(
          text.isEmpty ? 'No description yet' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
            color: logbookMuted,
          ),
        );
      },
    );
  }
}

// Tappable summary row that turns into a field
class _InlineField extends StatefulWidget {
  const _InlineField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
    this.number = false,
    this.prefix,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool number;
  final String? prefix;

  @override
  State<_InlineField> createState() => _InlineFieldState();
}

class _InlineFieldState extends State<_InlineField> {
  final FocusNode _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus && _editing) {
      setState(() => _editing = false);
    }
  }

  void _start() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _editing ? null : _start,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: Icon(widget.icon, size: 18, color: logbookFaint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: logbookFaint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _editing ? _field() : _value(),
                ],
              ),
            ),
            if (!_editing)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: logbookFaint,
              ),
          ],
        ),
      ),
    );
  }

  Widget _value() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final text = value.text.trim();
        if (text.isEmpty) {
          return Text(
            widget.hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: logbookFaint,
            ),
          );
        }
        return Text(
          '${widget.prefix ?? ''}$text',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: logbookInk,
          ),
        );
      },
    );
  }

  Widget _field() {
    return Row(
      children: [
        if (widget.prefix != null)
          Text(
            widget.prefix!,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: logbookMuted,
            ),
          ),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType:
                widget.number ? TextInputType.number : TextInputType.text,
            inputFormatters:
                widget.number
                    ? <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ]
                    : null,
            textCapitalization: TextCapitalization.sentences,
            onTapOutside: (_) => _focus.unfocus(),
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: logbookInk,
            ),
            decoration: InputDecoration.collapsed(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: logbookFaint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

double _ramp(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0);
