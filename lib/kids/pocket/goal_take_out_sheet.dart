import 'package:flutter/material.dart';

import '../finance/finance_models.dart';
import '../finance/finance_widgets.dart';
import '../logbook/logbook_keypad.dart';
import '../logbook/logbook_tokens.dart';
import 'elastic_sheet.dart';

Future<int?> showGoalTakeOutSheet(
  BuildContext context, {
  required ChildGoal goal,
  required int cash,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x52000000),
    builder: (_) => _TakeOutSheet(goal: goal, cash: cash),
  );
}

class _TakeOutSheet extends StatefulWidget {
  const _TakeOutSheet({required this.goal, required this.cash});

  final ChildGoal goal;
  final int cash;

  @override
  State<_TakeOutSheet> createState() => _TakeOutSheetState();
}

class _TakeOutSheetState extends State<_TakeOutSheet> {
  String _digits = '';

  int get _amount => int.tryParse(_digits) ?? 0;

  bool get _over => _amount > widget.goal.allocatedBalance;

  bool get _ready => _amount > 0 && !_over;

  Color get _tint => financePocketTint(widget.goal.goalsName, image: widget.goal.goalImage);

  double get _now => widget.goal.progress;

  double get _after {
    final int left = widget.goal.allocatedBalance - _amount;
    if (left <= 0 || widget.goal.goalPrice <= 0) return 0;
    return (left / widget.goal.goalPrice).clamp(0.0, 1.0);
  }

  int get _lostPercent => ((_now - _after) * 100).round();

  void _typeKey(String key) {
    final String next = '$_digits$key';
    if (next.length > 9) return;
    setState(() => _digits = next);
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  int _pctValue(double pct) {
    final int total = widget.goal.allocatedBalance;
    if (pct >= 1) return total;
    final int raw = (total * pct).floor();
    final int rounded = (raw ~/ 1000) * 1000;
    return rounded > 0 ? rounded : raw;
  }

  void _pickPct(double pct) {
    final int value = _pctValue(pct);
    setState(() => _digits = value <= 0 ? '' : '$value');
  }

  void _confirm() {
    if (!_ready) return;
    Navigator.of(context).pop(_amount);
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return ElasticSheetDrag(
      onDismiss: () => Navigator.of(context).pop(),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _handle(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Take out money',
                        style: const TextStyle(
                          fontSize: 21,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: logbookInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How much comes back to your cash?',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: logbookMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _route(),
                      const SizedBox(height: 16),
                      _amountDisplay(),
                      const SizedBox(height: 3),
                      Text(
                        '${financeRupiah(widget.goal.allocatedBalance)} in this goal',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: logbookFaint,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ghostPreview(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (final double pct in const [0.25, 0.5, 0.75, 1.0]) ...[
                            if (pct > 0.25) const SizedBox(width: 8),
                            Expanded(
                              child: _PercentChip(
                                label: pct >= 1 ? 'Max' : '${(pct * 100).round()}%',
                                selected:
                                    _amount > 0 && _amount == _pctValue(pct),
                                tint: _tint,
                                onTap: () => _pickPct(pct),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      LogbookKeypad(onKey: _typeKey, onBackspace: _backspace),
                      if (_over)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Only ${financeRupiah(widget.goal.allocatedBalance)} '
                            'is in this goal.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: logbookRed,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      _confirmButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: logbookLine,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _route() {
    return Row(
      children: [
        _routeSide(
          icon:
              pocketLookFor(widget.goal.goalImage)?.icon ?? Icons.flag_rounded,
          name: widget.goal.goalsName,
          detail: 'Goal',
          tint: _tint,
          alignEnd: false,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: logbookLine, width: 1.2),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: logbookMuted,
            ),
          ),
        ),
        _routeSide(
          icon: Icons.account_balance_wallet_rounded,
          name: 'Cash',
          detail: financeRupiah(widget.cash),
          tint: logbookGreen,
          alignEnd: true,
        ),
      ],
    );
  }

  Widget _routeSide({
    required IconData icon,
    required String name,
    required String detail,
    required Color tint,
    required bool alignEnd,
  }) {
    final Widget badge = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 15, color: tint),
    );
    final Widget text = Flexible(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: logbookInk,
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: logbookFaint,
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: Row(
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children:
            alignEnd
                ? [text, const SizedBox(width: 8), badge]
                : [badge, const SizedBox(width: 8), text],
      ),
    );
  }

  Widget _amountDisplay() {
    final bool empty = _amount <= 0;
    return Text(
      financeRupiah(_amount),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 44,
        height: 1.05,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.4,
        color: empty ? const Color(0xFFCFC9BF) : logbookInk,
      ),
    );
  }

  // Lost part of the bar turns red behind the new fill
  Widget _ghostPreview() {
    return Column(
      children: [
        _bar(height: 10),
        const SizedBox(height: 7),
        Row(
          children: [
            Text(
              '${financePercent(_now)} → ${financePercent(_after)}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: logbookMuted,
              ),
            ),
            const Spacer(),
            Text(
              '−$_lostPercent%',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: logbookRed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bar({required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: logbookTrack),
          FractionallySizedBox(
            widthFactor: _now,
            child: Container(
              height: height,
              color: logbookRed.withValues(alpha: 0.45),
            ),
          ),
          FractionallySizedBox(
            widthFactor: _after,
            child: Container(height: height, color: _tint),
          ),
        ],
      ),
    );
  }

  Widget _confirmButton() {
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: _ready ? _confirm : null,
        style: FilledButton.styleFrom(
          backgroundColor: logbookRed,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(23),
          ),
        ),
        child: Text(
          _ready ? 'Take out ${financeRupiah(_amount)}' : 'Take out',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _PercentChip extends StatelessWidget {
  const _PercentChip({
    required this.label,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tint.withValues(alpha: 0.12) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? tint : logbookLine,
          width: selected ? 1.4 : 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? tint : logbookMuted,
            ),
          ),
        ),
      ),
    );
  }
}
