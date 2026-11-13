import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../finance/finance_models.dart';
import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';
import 'pocket_history.dart';
import 'pocket_row.dart';

// What the expanded card sends back
enum PocketExpandAction { add, edit, transfer }

// Soft ease-out: the expand glides instead of snapping
const Cubic _expandEase = Cubic(0.32, 0.72, 0, 1);

double _ramp(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0);

// Where the card lands on screen
Rect pocketExpandedRect(BuildContext context) {
  final Size size = MediaQuery.sizeOf(context);
  final EdgeInsets padding = MediaQuery.paddingOf(context);
  final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
  final double bottom = math.max(
    padding.top + 240,
    size.height - padding.bottom - 40 - keyboard,
  );
  return Rect.fromLTRB(20, padding.top + 68, size.width - 20, bottom);
}

Future<PocketExpandAction?> showPocketExpand(
  BuildContext context, {
  required ChildPocket pocket,
  required Rect sourceRect,
  required int balance,
  required int available,
}) async {
  final bool reduce = MediaQuery.disableAnimationsOf(context);

  return Navigator.of(context).push<PocketExpandAction>(
    PageRouteBuilder<PocketExpandAction>(
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
        void finish([PocketExpandAction? action]) {
          if (done) return;
          done = true;
          Navigator.of(routeContext).pop(action);
        }

        return _ExpandPage(
          animation: animation,
          beginRect: sourceRect,
          reduceMotion: reduce,
          pocket: pocket,
          balance: balance,
          available: available,
          onClose: () => finish(),
          // Placeholder: Check closes until save is wired
          onCheck: () => finish(),
          onAdd: () => finish(PocketExpandAction.add),
          onTransfer: () => finish(PocketExpandAction.transfer),
          onEdit: () => finish(PocketExpandAction.edit),
        );
      },
    ),
  );
}

class _ExpandPage extends StatelessWidget {
  const _ExpandPage({
    required this.animation,
    required this.beginRect,
    required this.reduceMotion,
    required this.pocket,
    required this.balance,
    required this.available,
    required this.onClose,
    required this.onCheck,
    required this.onAdd,
    required this.onTransfer,
    required this.onEdit,
  });

  final Animation<double> animation;
  final Rect beginRect;
  final bool reduceMotion;
  final ChildPocket pocket;
  final int balance;
  final int available;
  final VoidCallback onClose;
  final VoidCallback onCheck;
  final VoidCallback onAdd;
  final VoidCallback? onTransfer;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final Rect endRect = pocketExpandedRect(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double t = animation.value;
        final double eased = reduceMotion ? 1 : _expandEase.transform(t);
        final Rect rect =
            reduceMotion ? endRect : Rect.lerp(beginRect, endRect, eased)!;
        final double radius = 24 + 8 * eased;
        final double barT =
            reduceMotion
                ? 1
                : _expandEase.transform(_ramp(t, 0.42, 1));
        final double scrim =
            reduceMotion
                ? 0.55
                : 0.55 * _expandEase.transform(_ramp(t, 0, 0.82));

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
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
                  child: PocketExpandedCard(
                    pocket: pocket,
                    balance: balance,
                    available: available,
                    animation: animation,
                    onAdd: onAdd,
                    onTransfer: onTransfer,
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
                    _topButton(icon: Icons.close_rounded, onTap: onClose),
                    _topButton(
                      icon: Icons.check_rounded,
                      onTap: onCheck,
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
      color:
          filled ? Colors.white : Colors.white.withValues(alpha: 0.16),
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

class PocketExpandedCard extends StatefulWidget {
  const PocketExpandedCard({
    super.key,
    required this.pocket,
    required this.balance,
    required this.available,
    required this.animation,
    required this.onAdd,
    required this.onTransfer,
  });

  final ChildPocket pocket;
  final int balance;
  final int available;
  final Animation<double> animation;
  final VoidCallback onAdd;
  final VoidCallback? onTransfer;

  @override
  State<PocketExpandedCard> createState() => _PocketExpandedCardState();
}

class _PocketExpandedCardState extends State<PocketExpandedCard> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _image;
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.pocket.pocketName);
    _desc = TextEditingController(text: widget.pocket.pocketDesc ?? '');
    _image = TextEditingController(text: widget.pocket.pocketImage ?? '');
    _amount = TextEditingController(
      text:
          widget.pocket.allocatedBalance > 0
              ? '${widget.pocket.allocatedBalance}'
              : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _image.dispose();
    _amount.dispose();
    super.dispose();
  }

  int get _amountValue {
    final digits = _amount.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> statsReveal = widget.animation.drive(
      CurveTween(
        curve: const Interval(0.12, 0.62, curve: _expandEase),
      ),
    );
    final Animation<double> rowsReveal = widget.animation.drive(
      CurveTween(
        curve: const Interval(0.28, 0.78, curve: _expandEase),
      ),
    );
    final Animation<double> sectionReveal = widget.animation.drive(
      CurveTween(
        curve: const Interval(0.48, 0.92, curve: _expandEase),
      ),
    );
    final Animation<double> deleteReveal = widget.animation.drive(
      CurveTween(
        curve: const Interval(0.62, 1.0, curve: _expandEase),
      ),
    );
    final double grow = _expandEase.transform(
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
                    FinancePocketAvatar(
                      image: widget.pocket.pocketImage,
                      name: widget.pocket.pocketName,
                      size: 48,
                      background: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _liveName(size: 16 + 2 * grow),
                          const SizedBox(height: 3),
                          _liveDesc(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _amount,
                      builder:
                          (context, value, _) => Text(
                            financeRupiah(_amountValue),
                            style: TextStyle(
                              fontSize: 18 + 3 * grow,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                              color: logbookInk,
                            ),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizeTransition(
                  sizeFactor: statsReveal,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _amount,
                        builder:
                            (context, value, _) => Column(
                              children: [
                                Container(height: 1, color: logbookLine),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    _stat(
                                      'SET ASIDE',
                                      financeRupiah(_amountValue),
                                      logbookInk,
                                    ),
                                    _stat(
                                      'AVAILABLE',
                                      financeRupiah(widget.available),
                                      logbookGreen,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(height: 1, color: logbookLine),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    _stat(
                                      'BALANCE',
                                      financeRupiah(widget.balance),
                                      logbookInk,
                                    ),
                                    _stat('ENTRIES', '12', logbookMuted),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(height: 1, color: logbookLine),
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
                SizeTransition(
                  sizeFactor: rowsReveal,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      _rowFieldRow(
                        _InlineField(
                          icon: Icons.edit_outlined,
                          label: 'Name',
                          controller: _name,
                          hint: 'Pocket name',
                        ),
                        first: true,
                      ),
                      _rowFieldRow(
                        _InlineField(
                          icon: Icons.notes_rounded,
                          label: 'Note',
                          controller: _desc,
                          hint: 'What is this for?',
                        ),
                      ),
                      _rowFieldRow(
                        _InlineField(
                          icon: Icons.emoji_emotions_outlined,
                          label: 'Icon',
                          controller: _image,
                          hint: 'Emoji or image link',
                        ),
                      ),
                      _rowFieldRow(
                        _InlineField(
                          icon: Icons.savings_outlined,
                          label: 'Set aside',
                          controller: _amount,
                          hint: '0',
                          number: true,
                          prefix: 'Rp ',
                        ),
                        last: true,
                      ),
                    ],
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
                        _section('ACTIVITY'),
                        const SizedBox(height: 10),
                        const PocketDaysHistory(entries: pocketDemoHistory),
                      ],
                    ),
                  ),
                ),
                SizeTransition(
                  sizeFactor: deleteReveal,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: deleteReveal,
                    child: _deleteLine(),
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

  Widget _bottomBar() {
    final Color tint = financePocketTint(widget.pocket.pocketName);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: logbookLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PocketActionPill(
              label: 'Add',
              icon: Icons.add_rounded,
              strong: true,
              accentTint: tint,
              onTap: widget.onAdd,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PocketActionPill(
              label: 'Transfer',
              icon: Icons.swap_horiz_rounded,
              onTap: widget.onTransfer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowFieldRow(
    _InlineField field, {
    bool first = false,
    bool last = false,
  }) {
    return Column(
      children: [
        if (!first) Container(height: 1, color: logbookLine),
        field,
        if (last) const SizedBox(height: 2),
      ],
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

  Widget _section(String title, {String? trailing}) {
    return Row(
      children: [
        _label(title),
        const Spacer(),
        if (trailing != null) _label(trailing, faint: true),
      ],
    );
  }

  Widget _label(String text, {bool faint = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 8.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: faint ? logbookFaint : logbookMuted,
      ),
    );
  }

  Widget _deleteLine() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.delete_outline_rounded, size: 16, color: logbookRed),
            SizedBox(width: 6),
            Text(
              'Delete pocket',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: logbookRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveName({required double size}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _name,
      builder: (context, value, _) {
        final text = value.text.trim();
        return Text(
          text.isEmpty ? 'Untitled pocket' : text,
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
