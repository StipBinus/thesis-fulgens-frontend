import 'package:flutter/material.dart';

import '../finance/finance_models.dart';
import '../finance/finance_widgets.dart';
import '../logbook/logbook_keypad.dart';
import '../logbook/logbook_tokens.dart';
import 'elastic_sheet.dart';

Future<int?> showPocketAddSheet(
  BuildContext context, {
  required ChildPocket pocket,
  required int balance,
  required int available,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x52000000),
    builder:
        (_) => PocketAddSheet(
          pocket: pocket,
          balance: balance,
          available: available,
        ),
  );
}

class PocketAddSheet extends StatefulWidget {
  const PocketAddSheet({
    super.key,
    required this.pocket,
    required this.balance,
    required this.available,
  });

  final ChildPocket pocket;
  final int balance;
  final int available;

  @override
  State<PocketAddSheet> createState() => _PocketAddSheetState();
}

class _PocketAddSheetState extends State<PocketAddSheet> {
  String _digits = '';

  int get _amount => int.tryParse(_digits) ?? 0;

  bool get _over => _amount > widget.available;

  bool get _ready => _amount > 0 && !_over;

  Color get _tint => financePocketTint(widget.pocket.pocketName);

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
    if (pct >= 1) return widget.available;
    final int raw = (widget.available * pct).floor();
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
                  child: _body(),
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

  Widget _body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add money',
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
          'How much of your cash goes to ${widget.pocket.pocketName}?',
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.3,
            fontWeight: FontWeight.w500,
            color: logbookMuted,
          ),
        ),
        const SizedBox(height: 16),
        _amountDisplay(),
        const SizedBox(height: 3),
        Text(
          '${financeRupiah(widget.available)} available',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: logbookFaint,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final double pct in const [0.25, 0.5, 0.75, 1.0]) ...[
              if (pct > 0.25) const SizedBox(width: 8),
              Expanded(
                child: _PercentChip(
                  label: pct >= 1 ? 'Max' : '${(pct * 100).round()}%',
                  selected: _amount > 0 && _amount == _pctValue(pct),
                  tint: _tint,
                  onTap: () => _pickPct(pct),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        LogbookKeypad(onKey: _typeKey, onBackspace: _backspace),
        _note(),
        const SizedBox(height: 14),
        _confirmButton(),
      ],
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

  Widget _note() {
    if (widget.available <= 0) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text(
          'No cash left to add right now.',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: logbookMuted,
          ),
        ),
      );
    }
    if (!_over) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'Only ${financeRupiah(widget.available)} is free to add.',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: logbookRed,
        ),
      ),
    );
  }

  Widget _confirmButton() {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: _ready ? _confirm : null,
        style: FilledButton.styleFrom(
          backgroundColor: logbookAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFEDEAE4),
          disabledForegroundColor: logbookFaint,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          _ready ? 'Add ${financeRupiah(_amount)}' : 'Add money',
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
    final bool reduce = MediaQuery.disableAnimationsOf(context);

    return Material(
      color:
          selected
              ? tint.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? tint : logbookLine,
              width: selected ? 1.5 : 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? tint : logbookInk,
            ),
          ),
        ),
      ),
    );
  }
}
