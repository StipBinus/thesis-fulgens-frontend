import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logbook/logbook_tokens.dart';

// Palette
const Color _line2 = Color(0xFFE6E2DA);
const Color _accentDeep = Color(0xFFC4552A);
const Curve _easeOut = Cubic(0.23, 1, 0.32, 1);

// Dummy chore
class _Chore {
  const _Chore({
    required this.id,
    required this.title,
    required this.hint,
    required this.tab,
    required this.reward,
  });

  final String id;
  final String title;
  final String hint;
  final String tab;
  final int reward;
}

// Chore tabs
const List<String> _tabs = ['All', 'Saving', 'Spending', 'Kind'];

// Dummy tasks
const List<_Chore> _chores = [
  _Chore(
    id: 'log',
    title: "Log today's spending",
    hint: 'Write down what you bought',
    tab: 'Spending',
    reward: 5,
  ),
  _Chore(
    id: 'pocket',
    title: 'Put 5 coins in a pocket',
    hint: 'Save a little for later',
    tab: 'Saving',
    reward: 10,
  ),
  _Chore(
    id: 'goal',
    title: 'Check your savings goal',
    hint: 'See how close you are',
    tab: 'Saving',
    reward: 3,
  ),
  _Chore(
    id: 'needs',
    title: 'Sort a need vs a want',
    hint: 'Pick one thing you bought',
    tab: 'Spending',
    reward: 5,
  ),
  _Chore(
    id: 'compare',
    title: 'Compare two prices',
    hint: 'Find the better deal',
    tab: 'Spending',
    reward: 5,
  ),
  _Chore(
    id: 'thanks',
    title: 'Say thanks for a gift',
    hint: 'Tell someone you are grateful',
    tab: 'Kind',
    reward: 3,
  ),
  _Chore(
    id: 'share',
    title: 'Share a snack',
    hint: 'Give a friend something small',
    tab: 'Kind',
    reward: 3,
  ),
];

// Dummy reflection
const String _reflectionQuestion =
    "What's one thing you bought this week that made you happy?";
const int _reflectionReward = 15;

// Dummy week: days with everything done
const Set<int> _doneDays = {DateTime.monday};

// One AI question a day, generated from the child's transaction log.
class KidsTasksPage extends StatefulWidget {
  const KidsTasksPage({super.key});

  @override
  State<KidsTasksPage> createState() => _KidsTasksPageState();
}

class _KidsTasksPageState extends State<KidsTasksPage> {
  final TextEditingController _answer = TextEditingController();
  final Set<String> _done = {};
  bool _open = false;
  bool _sent = false;
  String? _sentText;
  String _tab = 'All';

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  int get _total => _chores.length + 1;
  int get _doneCount => _done.length + (_sent ? 1 : 0);
  int get _earned =>
      _chores
          .where((c) => _done.contains(c.id))
          .fold<int>(0, (sum, c) => sum + c.reward) +
      (_sent ? _reflectionReward : 0);

  void _toggle(_Chore chore) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_done.remove(chore.id)) _done.add(chore.id);
    });
  }

  void _send() {
    final text = _answer.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _sent = true;
      _sentText = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final now = DateTime.now();
    final shown = _tab == 'All'
        ? _chores
        : _chores.where((c) => c.tab == _tab).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 16, 20, 108 + bottomInset),
          children: [
            _WeekStrip(today: now),
            const SizedBox(height: 18),
            _GreetingPill(
              greeting: _greeting(now),
              done: _doneCount,
              total: _total,
              earned: _earned,
            ),
            const SizedBox(height: 16),
            _ReflectionCard(
              index: 1,
              total: _total,
              open: _open,
              sent: _sent,
              sentText: _sentText,
              controller: _answer,
              onToggle: () => setState(() => _open = !_open),
              onChanged: () => setState(() {}),
              onSend: _send,
            ),
            const SizedBox(height: 26),
            _Tabs(
              selected: _tab,
              onSelect: (t) {
                HapticFeedback.selectionClick();
                setState(() => _tab = t);
              },
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0)
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 42),
                  color: logbookLine,
                ),
              _ChoreRow(
                key: ValueKey(shown[i].id),
                chore: shown[i],
                done: _done.contains(shown[i].id),
                onTap: () => _toggle(shown[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'GOOD MORNING';
    if (now.hour < 18) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }
}

// Week strip
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (var d = 1; d <= 7; d++)
          Expanded(
            child: Column(
              children: [
                Text(
                  letters[d - 1],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: d == today.weekday
                        ? FontWeight.w900
                        : FontWeight.w600,
                    letterSpacing: 0.6,
                    color: d == today.weekday
                        ? logbookInk
                        : d < today.weekday
                            ? logbookMuted
                            : logbookFaint,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: d == today.weekday ? 14 : 5,
                  height: d == today.weekday ? 2.5 : 5,
                  decoration: BoxDecoration(
                    color: d == today.weekday
                        ? logbookInk
                        : _doneDays.contains(d) && d < today.weekday
                            ? logbookAccent
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Greeting pill
class _GreetingPill extends StatelessWidget {
  const _GreetingPill({
    required this.greeting,
    required this.done,
    required this.total,
    required this.earned,
  });

  final String greeting;
  final int done;
  final int total;
  final int earned;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _line2, width: 1.2),
      ),
      child: Row(
        children: [
          Text(
            greeting,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: logbookInk,
            ),
          ),
          const Text(
            '  ·  ',
            style: TextStyle(fontSize: 12, color: logbookFaint),
          ),
          Expanded(
            child: Text(
              '$done of $total done',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: logbookMuted,
              ),
            ),
          ),
          CoinToken(size: 15),
          const SizedBox(width: 5),
          Text(
            '$earned',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: logbookInk,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// Big reflection card: the only expandable task
class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({
    required this.index,
    required this.total,
    required this.open,
    required this.sent,
    required this.sentText,
    required this.controller,
    required this.onToggle,
    required this.onChanged,
    required this.onSend,
  });

  final int index;
  final int total;
  final bool open;
  final bool sent;
  final String? sentText;
  final TextEditingController controller;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final motion = reduce ? Duration.zero : const Duration(milliseconds: 340);
    final canSend = controller.text.trim().isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AC4552A),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Container(
              height: 330,
              color: Colors.white,
              child: Stack(
                children: [
                  // Orange corner glows
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.0,
                          colors: [Color(0xFFFFD2B5), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.bottomRight,
                          radius: 0.9,
                          colors: [Color(0xFFFFC9A6), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sent ? 'REFLECTION · DONE' : 'REFLECTION',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                  color: logbookInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'With Fulgens · +$_reflectionReward coins',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: logbookLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: logbookInk.withValues(alpha: 0.7),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            '$index OF $total',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: logbookInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 92,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "TODAY'S QUESTION",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: _accentDeep,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          _reflectionQuestion,
                          style: TextStyle(
                            fontSize: 21,
                            height: 1.24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: logbookInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 20,
                    child: _PencilButton(
                      open: open,
                      sent: sent,
                      onTap: onToggle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: motion,
            curve: _easeOut,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: sent
                        ? _CoinMoment(
                            reward: _reflectionReward,
                            answer: sentText,
                          )
                        : Column(
                            children: [
                              _AnswerField(
                                controller: controller,
                                onChanged: onChanged,
                              ),
                              const SizedBox(height: 12),
                              _Press(
                                onTap: canSend ? onSend : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: canSend
                                        ? logbookAccent
                                        : const Color(0xFFFFE3D3),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    'Send to Fulgens',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: canSend
                                          ? Colors.white
                                          : const Color(0xFFE0A788),
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
    );
  }
}

// Chore tabs
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in _tabs)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(t),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 24, 8),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        t == selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.3,
                    color: t == selected ? logbookInk : logbookFaint,
                  ),
                  child: Text(t),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Flat chore row: tap toggles done, never expands
class _ChoreRow extends StatefulWidget {
  const _ChoreRow({
    super.key,
    required this.chore,
    required this.done,
    required this.onTap,
  });

  final _Chore chore;
  final bool done;
  final VoidCallback onTap;

  @override
  State<_ChoreRow> createState() => _ChoreRowState();
}

class _ChoreRowState extends State<_ChoreRow> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.done;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _down ? 0.6 : 1,
        duration: const Duration(milliseconds: 90),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              _CheckDot(done: done),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: done ? logbookFaint : logbookInk,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: logbookFaint,
                      ),
                      child: Text(widget.chore.title),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.chore.hint,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: logbookFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CoinToken(size: 14),
              const SizedBox(width: 4),
              Text(
                '+${widget.chore.reward}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: done ? logbookGreen : logbookMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  const _CheckDot({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedContainer(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      curve: _easeOut,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: done ? logbookAccent : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: done ? logbookAccent : _line2, width: 2),
      ),
      child: AnimatedScale(
        scale: done ? 1 : 0,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      ),
    );
  }
}

// Scale on press
class _Press extends StatefulWidget {
  const _Press({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.onTap != null;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: live ? (_) => _set(true) : null,
      onTapUp: live ? (_) => _set(false) : null,
      onTapCancel: live ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && !reduce ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// Reflection pencil: solid white chip so the action pops off the glow
class _PencilButton extends StatelessWidget {
  const _PencilButton({
    required this.open,
    required this.sent,
    required this.onTap,
  });

  final bool open;
  final bool sent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Press(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x24FF7A45),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Transform.translate(
            key: ValueKey('$open-$sent'),
            offset: const Offset(-0.5, 1),
            child: Icon(
              open
                  ? Icons.close_rounded
                  : sent
                      ? Icons.check_rounded
                      : Icons.edit_rounded,
              size: 22,
              color: logbookAccent,
            ),
          ),
        ),
      ),
    );
  }
}

// Coin moment after the reflection is sent
class _CoinMoment extends StatelessWidget {
  const _CoinMoment({required this.reward, required this.answer});

  final int reward;
  final String? answer;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      children: [
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: reduce ? 1 : 0, end: 1),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 650),
          curve: Curves.easeOutBack,
          builder: (_, t, child) => Transform.scale(
            scale: 0.6 + 0.4 * t,
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
          ),
          child: const _BigCoin(size: 104),
        ),
        const SizedBox(height: 18),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: reduce ? reward : 0, end: reward),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            '+$v ${reward == 1 ? 'coin' : 'coins'}',
            style: const TextStyle(
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: Color(0xFFD48806),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Fulgens loved that! New reflection tomorrow',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: logbookMuted,
          ),
        ),
        if (answer != null && answer!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F3EC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR ANSWER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: logbookFaint,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  answer!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: logbookLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BigCoin extends StatelessWidget {
  const _BigCoin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    // Home coin with a soft gold glow
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x55EFC257),
            blurRadius: 36,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: CoinToken(size: size),
    );
  }
}

class _AnswerField extends StatelessWidget {
  const _AnswerField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final round = BorderRadius.circular(18);
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      onChanged: (_) => onChanged(),
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: logbookInk,
      ),
      cursorColor: logbookAccent,
      decoration: InputDecoration(
        hintText: 'Type your answer…',
        hintStyle: const TextStyle(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: logbookFaint,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        border: OutlineInputBorder(
          borderRadius: round,
          borderSide: const BorderSide(color: _line2, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: round,
          borderSide: const BorderSide(color: _line2, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: round,
          borderSide: const BorderSide(color: logbookAccent, width: 2),
        ),
      ),
    );
  }
}
