import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../finance/finance_models.dart';
import '../finance/finance_widgets.dart';
import 'logbook_models.dart';
import 'logbook_money.dart';
import 'logbook_provider.dart';
import 'logbook_tokens.dart';
// import 'pocket_style.dart';

Future<void> showEntryFormSheet(
  BuildContext context, {
  required String dateKey,
  LogbookEntry? existing,
  ValueChanged<LogbookEntry>? onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x52000000),
    builder:
        (_) => EntryFormSheet(
          dateKey: dateKey,
          existing: existing,
          onDelete: onDelete,
        ),
  );
}

class EntryFormSheet extends ConsumerStatefulWidget {
  const EntryFormSheet({
    super.key,
    required this.dateKey,
    this.existing,
    this.onDelete,
  });

  final String dateKey;
  final LogbookEntry? existing;
  final ValueChanged<LogbookEntry>? onDelete;

  @override
  ConsumerState<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends ConsumerState<EntryFormSheet> {
  late LogbookEntryType _type;
  late LogbookCategory _category;
  // late PocketSlot _pocket;
  int? _pocketId;

  final TextEditingController _amount = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  String? _error;
  int _step = 0;
  bool _keypadOpen = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? LogbookEntryType.expense;
    _category = existing?.category ?? logbookCategoriesFor(_type).first;
    // _pocket = existing?.pocket ?? PocketSlot.cash;
    // Pockets come from `fetchPockets`; keep the entry's pocket id and let the
    // selector fall back to the first fetched pocket.
    _pocketId = existing?.pocketId;
    if (existing != null) {
      _step = 1;
      _amount.text = logbookGroup(existing.amount);
      _title.text = existing.title;
      _note.text = existing.note;
    }
    _amountFocus.addListener(_handleAmountFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _amount.selection = const TextSelection.collapsed(offset: 0);
      _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountFocus.dispose();
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _handleAmountFocus() {
    if (mounted) setState(() {});
  }

  int get _parsedAmount =>
      int.tryParse(_amount.text.replaceAll('.', '').trim()) ?? 0;

  /// Picks the selected backend pocket, falling back to Cash.
  ChildPocket? _resolvePocket(List<ChildPocket> pockets) {
    if (pockets.isEmpty) return null;
    for (final pocket in pockets) {
      if (pocket.pocketId == _pocketId) return pocket;
    }
    return pockets.first;
  }

  // Cash is not a DB pocket, but it should always be selectable.
  static const int _cashPocketId = -1;

  ChildPocket? _cashPocket(LogbookMoney? money) {
    if (money == null) return null;
    return ChildPocket(
      pocketId: _cashPocketId,
      childId: '',
      pocketName: 'Cash',
      userBalance: money.balance ?? 0,
      allocatedBalance: financeAvailableCash(
        balance: money.balance ?? 0,
        pockets: money.pockets.map((pocket) => pocket.allocatedBalance),
        goals: [money.goals],
      ),
    );
  }

  // DB pockets plus the always-present Cash tile.
  List<ChildPocket> _withCash(LogbookMoney? money) {
    final pockets = money?.pockets ?? const <ChildPocket>[];
    final cash = _cashPocket(money);
    if (cash == null) return pockets;
    return [cash, ...pockets];
  }

  /// Pockets used for validation. Uses the loaded list when available and only
  /// waits for `fetchPockets` on a cold start.
  Future<List<ChildPocket>> _pockets() async {
    final loaded = ref.read(logbookMoneyProvider).value;
    if (loaded != null) return _withCash(loaded);

    try {
      final money = await ref.read(logbookMoneyProvider.future);
      return _withCash(money);
    } catch (_) {
      return const <ChildPocket>[];
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final amount = _parsedAmount;
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount first.');
      return;
    }

    // was: availableFor(dateKey, _pocket) reading the old local wallet.
    final pockets = await _pockets();
    if (!mounted) return;
    final pocket = _resolvePocket(pockets);
    if (pocket == null) {
      setState(
        () => _error = 'Create a pocket first, then log where the money went.',
      );
      return;
    }

    // The limit is that pocket's real `allocatedBalance` from `fetchPockets`.
    final available = pocket.allocatedBalance;

    if (_type == LogbookEntryType.expense && amount > available) {
      setState(
        () =>
            _error = 'Only ${logbookRupiah(available)} left in ${pocket.pocketName}.',
      );
      return;
    }

    final entry = LogbookEntry(
      id:
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      amount: amount,
      category: _category,
      // pocket: _pocket,
      pocketId: pocket.pocketId,
      pocketName: pocket.pocketName,
      title: _title.text.trim(),
      note: _note.text.trim(),
    );

    setState(() {
      _saving = true;
      _error = null;
    });

    final notifier = ref.read(logbookProvider.notifier);
    final ok =
        await (_isEditing
            ? notifier.updateEntry(widget.dateKey, entry)
            : notifier.addEntry(widget.dateKey, entry));

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _saving = false;
        _error = 'Could not save this entry. Please try again.';
      });
      return;
    }

    Navigator.of(context).pop();
  }

  void _goNext() {
    if (_parsedAmount <= 0) {
      setState(() => _error = 'Enter an amount first.');
      return;
    }
    _amountFocus.unfocus();
    setState(() {
      _error = null;
      _step = 1;
      _keypadOpen = false;
    });
  }

  void _typeAmount(String digits) {
    final raw = '${_amount.text.replaceAll('.', '')}$digits';
    if (raw.length > 9) return;
    final next = logbookGroup(int.parse(raw));
    setState(() {
      _error = null;
      _amount.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });
  }

  void _backspaceAmount() {
    final raw = _amount.text.replaceAll('.', '');
    if (raw.isEmpty) return;
    final kept = raw.substring(0, raw.length - 1);
    final next = kept.isEmpty ? '' : logbookGroup(int.parse(kept));
    setState(() {
      _error = null;
      _amount.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });
  }

  Future<void> _editNote() async {
    final result = await showNoteCardSheet(context, initial: _note.text);
    if (!mounted || result == null) return;
    setState(() => _note.text = result);
  }

  // Delete edited entry
  void _deleteExisting() {
    final existing = widget.existing;
    if (existing == null) return;
    widget.onDelete?.call(existing);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Ignore keyboard while the note card is on top
    final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final viewInsets =
        isTopRoute ? MediaQuery.viewInsetsOf(context) : EdgeInsets.zero;
    final media = MediaQuery.sizeOf(context);
    final maxHeight =
        media.height -
        viewInsets.bottom -
        MediaQuery.paddingOf(context).top -
        28;

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Pockets shown here are the real ones plus the always-present Cash tile.
    final money = ref.watch(logbookMoneyProvider);
    final pockets = _withCash(money.value);
    final selectedPocket = _resolvePocket(pockets);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, viewInsets.bottom + 14),
      child: PopScope(
        canPop: !_keypadOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_keypadOpen) setState(() => _keypadOpen = false);
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const ShapeDecoration(
              color: Colors.white,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(48)),
              ),
              shadows: [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 3,
                  child: ClipRect(
                    child: AnimatedFractionallySizedBox(
                      duration:
                          reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      widthFactor: _step == 0 ? 0.45 : 1,
                      heightFactor: 1,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0x8CE08A5B), Color(0x14E08A5B)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: TextField(
                                    controller: _title,
                                    maxLines: 1,
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      height: 1.0,
                                      fontWeight: FontWeight.w700,
                                      color: logbookInk,
                                    ),
                                    cursorColor: logbookAccent,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'What was it?',
                                      hintStyle: TextStyle(
                                        fontSize: 20,
                                        height: 1.0,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFC9C3BA),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: logbookFaint,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _friendlyDate(widget.dateKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.0,
                              fontWeight: FontWeight.w500,
                              color: logbookFaint,
                            ),
                          ),
                          _SheetClose(onTap: () => Navigator.of(context).pop()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AnimatedSize(
                        duration:
                            reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration:
                              reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder:
                              (currentChild, previousChildren) => Stack(
                                alignment: Alignment.topLeft,
                                children: [
                                  ...previousChildren.map(
                                    (child) => Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: child,
                                    ),
                                  ),
                                  if (currentChild != null) currentChild,
                                ],
                              ),
                          child: Column(
                            key: ValueKey(_step),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_step == 0 || _isEditing)
                                _Segment(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Amount',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: logbookMuted,
                                            ),
                                          ),
                                          const Spacer(),
                                          _TypeToggle(
                                            type: _type,
                                            onChanged:
                                                (type) => setState(() {
                                                  _type = type;
                                                  _error = null;
                                                  final categories =
                                                      logbookCategoriesFor(
                                                        type,
                                                      );
                                                  if (!categories.contains(
                                                    _category,
                                                  )) {
                                                    _category =
                                                        categories.first;
                                                  }
                                                }),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 9,
                                              ),
                                              child: _AmountSign(
                                                up:
                                                    _type ==
                                                    LogbookEntryType.income,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Padding(
                                            padding: EdgeInsets.only(bottom: 8),
                                            child: Text(
                                              'Rp',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: logbookFaint,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: _amount,
                                              focusNode: _amountFocus,
                                              readOnly: true,
                                              showCursor: _amountFocus.hasFocus,
                                              onTap:
                                                  () => setState(
                                                    () => _keypadOpen = true,
                                                  ),
                                              autofocus: false,
                                              keyboardType:
                                                  TextInputType.number,
                                              cursorColor: logbookAccent,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                  9,
                                                ),
                                              ],
                                              onChanged:
                                                  (_) => setState(
                                                    () => _error = null,
                                                  ),
                                              style: const TextStyle(
                                                fontSize: 30,
                                                height: 1.1,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.6,
                                                color: logbookInk,
                                              ),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                hintText: '0',
                                                hintStyle: TextStyle(
                                                  fontSize: 30,
                                                  height: 1.1,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.6,
                                                  color: Color(0xFFD8D3CB),
                                                ),
                                                border: UnderlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: logbookLine,
                                                  ),
                                                ),
                                                focusedBorder:
                                                    UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: logbookAccent,
                                                        width: 1.6,
                                                      ),
                                                    ),
                                                enabledBorder:
                                                    UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: logbookLine,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              if (_keypadOpen) ...[
                                const SizedBox(height: 6),
                                _AmountKeypad(
                                  onKey: _typeAmount,
                                  onBackspace: _backspaceAmount,
                                ),
                              ],
                              if (_step == 1)
                                _Segment(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_isEditing)
                                        const SizedBox(height: 14),
                                      const Text(
                                        'Category',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: logbookMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRect(
                                        child: TweenAnimationBuilder<double>(
                                          key: ValueKey(_type),
                                          tween: Tween(begin: 0, end: 1),
                                          duration:
                                              reduceMotion
                                                  ? Duration.zero
                                                  : const Duration(
                                                    milliseconds: 150,
                                                  ),
                                          curve: Curves.easeOutCubic,
                                          builder:
                                              (
                                                context,
                                                t,
                                                child,
                                              ) => Transform.translate(
                                                offset: Offset(
                                                  (_type ==
                                                              LogbookEntryType
                                                                  .income
                                                          ? 16
                                                          : -16) *
                                                      (1 - t),
                                                  0,
                                                ),
                                                child: Opacity(
                                                  opacity: 0.4 + 0.6 * t,
                                                  child: child,
                                                ),
                                              ),
                                          child: _CategoryIcons(
                                            type: _type,
                                            selected: _category,
                                            compact: _isEditing,
                                            onSelected:
                                                (category) => setState(
                                                  () => _category = category,
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Pocket',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: logbookMuted,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    _PocketSelector(
                                      selectedId: selectedPocket?.pocketId,
                                      pockets: pockets,
                                      loading: money.isLoading,
                                      onSelected: (pocket) => setState(() {
                                        _pocketId = pocket.pocketId;
                                        _error = null;
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              if (_step == 1) const SizedBox(height: 12),
                              if (_step == 1)
                                _NoteSlot(
                                  note: _note.text,
                                  onTap: _editNote,
                                  onClear: () => setState(_note.clear),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: logbookRed,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 46,
                        child: Row(
                          children: [
                            AnimatedSize(
                              duration:
                                  reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              child:
                                  _step == 1 && !_isEditing
                                      ? Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: _SheetBack(
                                          onTap:
                                              () => setState(() {
                                                _step = 0;
                                                _error = null;
                                              }),
                                        ),
                                      )
                                      : const SizedBox.shrink(),
                            ),
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    _saving
                                        ? null
                                        : (_step == 0 ? _goNext : _save),
                                style: FilledButton.styleFrom(
                                  backgroundColor: logbookAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(23),
                                  ),
                                ),
                                child: AnimatedSwitcher(
                                  duration:
                                      reduceMotion
                                          ? Duration.zero
                                          : const Duration(milliseconds: 200),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder:
                                      (child, animation) => FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: Tween<double>(
                                            begin: 0.92,
                                            end: 1,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      ),
                                  child: Text(
                                    _saving
                                        ? 'Saving...'
                                        : _step == 0
                                        ? 'Next'
                                        : (_isEditing
                                            ? 'Save changes'
                                            : 'Add entry'),
                                    key: ValueKey('$_step-$_saving'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_step == 1 &&
                                _isEditing &&
                                widget.onDelete != null) ...[
                              const SizedBox(width: 8),
                              _SheetDelete(onTap: _deleteExisting),
                            ],
                          ],
                        ),
                      ),
                    ],
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

class _AmountKeypad extends StatelessWidget {
  const _AmountKeypad({required this.onKey, required this.onBackspace});

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  static const List<List<String>> _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['000', '0', 'x'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < _rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var c = 0; c < _rows[r].length; c++) ...[
                if (c > 0) const SizedBox(width: 8),
                Expanded(
                  child:
                      _rows[r][c] == 'x'
                          ? _KeypadKey(
                            label: '',
                            icon: Icons.backspace_rounded,
                            onTap: onBackspace,
                          )
                          : _KeypadKey(
                            label: _rows[r][c],
                            onTap: () => onKey(_rows[r][c]),
                          ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _KeypadKey extends StatefulWidget {
  const _KeypadKey({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_KeypadKey> createState() => _KeypadKeyState();
}

class _KeypadKeyState extends State<_KeypadKey> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F3EE),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              widget.icon != null
                  ? Icon(widget.icon, size: 22, color: logbookInk)
                  : Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: logbookInk,
                    ),
                  ),
        ),
      ),
    );
  }
}

class _SheetBack extends StatelessWidget {
  const _SheetBack({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: Color(0xFFF4F1EC),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 20,
          color: logbookInk,
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.type, required this.onChanged});

  final LogbookEntryType type;
  final ValueChanged<LogbookEntryType> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final align =
        type == LogbookEntryType.expense
            ? const Alignment(-1, 0)
            : const Alignment(1, 0);

    return Container(
      width: 122,
      height: 25,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedAlign(
            duration:
                reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: align,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: AnimatedContainer(
                duration:
                    reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 5,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _TypePill(
                  label: 'Spent',
                  selected: type == LogbookEntryType.expense,
                  color: logbookRed,
                  onTap: () => onChanged(LogbookEntryType.expense),
                ),
              ),
              Expanded(
                child: _TypePill(
                  label: 'Earned',
                  selected: type == LogbookEntryType.income,
                  color: logbookGreen,
                  onTap: () => onChanged(LogbookEntryType.income),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? color : logbookMuted,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// Sheet delete
class _SheetDelete extends StatelessWidget {
  const _SheetDelete({required this.onTap});

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
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Color(0xFFF6DCD3),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: Color(0xFFEFD5CB)),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            size: 19,
            color: logbookRed,
          ),
        ),
      ),
    );
  }
}

// Sheet close
class _SheetClose extends StatelessWidget {
  const _SheetClose({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.close_rounded, size: 24, color: logbookFaint),
        ),
      ),
    );
  }
}

// Friendly date
String _friendlyDate(String dateKey) {
  final date = DateTime.tryParse(dateKey);
  if (date == null) return dateKey;
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
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
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

// Amount sign
class _AmountSign extends StatefulWidget {
  const _AmountSign({required this.up});

  final bool up;

  @override
  State<_AmountSign> createState() => _AmountSignState();
}

class _AmountSignState extends State<_AmountSign>
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
  void didUpdateWidget(covariant _AmountSign oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.up != widget.up) _play();
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
          final local = (_roll.value / 0.4).clamp(0.0, 1.0);
          final eased = Curves.easeOutBack.transform(local);
          return Transform.translate(
            offset: Offset(0, 24 * (1 - eased)),
            child: Opacity(
              opacity: (0.15 + 0.85 * local).clamp(0.0, 1.0),
              child: Center(
                child: Text(
                  widget.up ? '+' : '\u2212',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: widget.up ? logbookGreen : logbookRed,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Category icons
class _CategoryIcons extends StatefulWidget {
  const _CategoryIcons({
    required this.type,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final LogbookEntryType type;
  final LogbookCategory selected;
  final ValueChanged<LogbookCategory> onSelected;
  final bool compact;

  @override
  State<_CategoryIcons> createState() => _CategoryIconsState();
}

class _CategoryIconsState extends State<_CategoryIcons> {
  final ScrollController _scroll = ScrollController();
  double _progress = 0;
  double _viewport = 0;
  double _maxExtent = 0;
  bool _barVisible = false;
  bool _revealAnimating = false;
  Timer? _barTimer;

  List<LogbookCategory> get _categories => logbookCategoriesFor(widget.type);

  double get _rowHeight => widget.compact ? 40 : 52;

  double get _stepSize => _rowHeight + (widget.compact ? 1 : 2);

  void _bumpBar() {
    if (_revealAnimating) return;
    _barTimer?.cancel();
    if (!_barVisible) setState(() => _barVisible = true);
    _barTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _barVisible = false);
    });
  }

  void _track(ScrollMetrics metrics) {
    _progress =
        metrics.maxScrollExtent <= 0
            ? 0
            : (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0);
    _viewport = metrics.viewportDimension;
    _maxExtent = metrics.maxScrollExtent;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(covariant _CategoryIcons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelected();
  }

  @override
  void dispose() {
    _barTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _revealSelected() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final start = _categories.indexOf(widget.selected) * _stepSize;
    final end = start + _rowHeight;
    final viewStart = position.pixels;
    final viewEnd = viewStart + position.viewportDimension;
    const margin = 12.0;

    double? target;
    if (start - margin < viewStart) {
      target = start - margin;
    } else if (end + margin > viewEnd) {
      target = end + margin - position.viewportDimension;
    }
    if (target == null) return;

    _revealAnimating = true;
    _scroll
        .animateTo(
          target.clamp(0.0, position.maxScrollExtent),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _revealAnimating = false);
  }

  @override
  Widget build(BuildContext context) {
    final scrolled = _progress * _maxExtent;
    final topVeil = _maxExtent <= 0 ? 0.0 : (scrolled / 24).clamp(0.0, 1.0);
    final bottomVeil =
        _maxExtent <= 0 ? 0.0 : ((_maxExtent - scrolled) / 48).clamp(0.0, 1.0);

    return SizedBox(
      height: widget.compact ? 128 : 196,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          final fadeTop = _maxExtent > 0 && _progress > 0.002;
          final fadeBottom = _maxExtent > 0 && _progress < 0.998;
          final edge = Colors.white.withValues(alpha: 0);
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fadeTop ? edge : Colors.white,
              Colors.white,
              Colors.white,
              fadeBottom ? edge : Colors.white,
            ],
            stops: const [0.0, 0.08, 0.82, 1.0],
          ).createShader(rect);
        },
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            setState(() => _track(notification.metrics));
            return false;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification ||
                  notification is ScrollUpdateNotification) {
                _bumpBar();
              }
              setState(() => _track(notification.metrics));
              return false;
            },
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          for (final category in _categories) ...[
                            _CategoryIcon(
                              category: category,
                              selected: widget.selected == category,
                              compact: widget.compact,
                              onTap: () => widget.onSelected(category),
                            ),
                            if (category != _categories.last)
                              SizedBox(height: widget.compact ? 1 : 2),
                          ],
                        ],
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        left: 0,
                        top:
                            _categories.indexOf(widget.selected) * _stepSize +
                            (widget.compact ? 10 : 14),
                        child: Container(
                          width: 3,
                          height: widget.compact ? 18 : 24,
                          decoration: BoxDecoration(
                            color: _categoryColor(widget.selected),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_maxExtent > 0) ...[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 24,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: topVeil,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Color(0x00FFFFFF)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 48,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: bottomVeil,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.white, Color(0x00FFFFFF)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_maxExtent > 0)
                  Positioned(
                    right: 0,
                    top: (_viewport - _barHeight) * _progress,
                    child: AnimatedOpacity(
                      opacity: _barVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        width: 2,
                        height: _barHeight,
                        decoration: BoxDecoration(
                          color: logbookFaint.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(2),
                        ),
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

  double get _barHeight {
    if (_viewport <= 0) return 0;
    final ratio = _viewport / (_viewport + _maxExtent);
    return (_viewport * ratio).clamp(18.0, _viewport);
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({
    required this.category,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final LogbookCategory category;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      button: true,
      selected: selected,
      label: category.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: compact ? 40 : 52,
          child: Row(
            children: [
              SizedBox(width: compact ? 10 : 12),
              AnimatedContainer(
                duration:
                    reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: compact ? 28 : 34,
                height: compact ? 28 : 34,
                decoration: BoxDecoration(
                  color:
                      selected
                          ? _categoryColor(category).withValues(alpha: 0.14)
                          : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedScale(
                    duration:
                        reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    scale: selected ? 1.15 : 1.0,
                    child: Icon(
                      _categoryIcon(category),
                      size: compact ? 17 : 20,
                      color: _categoryColor(category),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration:
                      reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? logbookInk : logbookLabel,
                  ),
                  child: Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

IconData _categoryIcon(LogbookCategory category) {
  switch (category) {
    case LogbookCategory.foodAndBeverage:
      return Icons.restaurant_rounded;
    case LogbookCategory.transport:
      return Icons.directions_bus_rounded;
    case LogbookCategory.entertainment:
      return Icons.movie_rounded;
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

Color _categoryColor(LogbookCategory category) {
  switch (category) {
    case LogbookCategory.foodAndBeverage:
      return const Color(0xFFE8873B);
    case LogbookCategory.transport:
      return const Color(0xFF3B7BE8);
    case LogbookCategory.entertainment:
      return const Color(0xFF8B5CF6);
    case LogbookCategory.school:
      return const Color(0xFF17A2A2);
    case LogbookCategory.hobby:
      return const Color(0xFFE0559B);
    case LogbookCategory.other:
      return const Color(0xFF8C867A);
    case LogbookCategory.allowance:
      return logbookGreen;
    case LogbookCategory.gift:
      return const Color(0xFFE0559B);
  }
}

// Pocket selector
// Note slot
class _NoteSlot extends StatelessWidget {
  const _NoteSlot({
    required this.note,
    required this.onTap,
    required this.onClear,
  });

  final String note;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = note.trim();
    final hasNote = text.isNotEmpty;

    if (hasNote) {
      return Row(
        children: [
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: logbookLabel,
                ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClear,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Icon(Icons.close_rounded, size: 14, color: logbookFaint),
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: logbookTrack.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_rounded, size: 16, color: logbookFaint),
              SizedBox(width: 4),
              Text(
                'Add note',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: logbookMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Note card
Future<String?> showNoteCardSheet(BuildContext context, {String initial = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x52000000),
    builder: (_) => _NoteCardSheet(initial: initial),
  );
}

class _NoteCardSheet extends StatefulWidget {
  const _NoteCardSheet({required this.initial});

  final String initial;

  @override
  State<_NoteCardSheet> createState() => _NoteCardSheetState();
}

class _NoteCardSheetState extends State<_NoteCardSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(14, 0, 14, keyboard + 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Note',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: logbookInk,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: logbookInk,
              ),
              decoration: const InputDecoration(
                isDense: true,
                counterText: '',
                hintText: 'What was this for?',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: logbookFaint,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: logbookLine),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: logbookLine),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: logbookAccent, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      foregroundColor: logbookMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(21),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        () =>
                            Navigator.of(context).pop(_controller.text.trim()),
                    style: FilledButton.styleFrom(
                      backgroundColor: logbookInk,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(21),
                      ),
                    ),
                    child: const Text(
                      'Save note',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

// Pocket chips now list the real pockets from `fetchPockets` (name, image,
// allocatedBalance) instead of the fixed PocketSlot enum + local PocketWallet.
// Old implementation kept below for reference.
//
// class _PocketSelector extends StatelessWidget {
//   const _PocketSelector({
//     required this.selected,
//     required this.pockets,
//     required this.onSelected,
//   });
//
//   final PocketSlot selected;
//   final PocketWallet pockets;
//   final ValueChanged<PocketSlot> onSelected;
//
//   // Button metrics
//   static const double _chipWidth = 100;
//   static const double _gap = 6;
//
//   @override
//   Widget build(BuildContext context) {
//     final slots = PocketSlot.values;
//     final stretches = slots.length <= 3;
//
//     final items = <Widget>[];
//     for (var i = 0; i < slots.length; i++) {
//       if (i > 0) items.add(const SizedBox(width: _gap));
//       final tile = SizedBox(
//         height: 52,
//         child: _PocketTile(
//           slot: slots[i],
//           balance: pockets.of(slots[i]),
//           selected: selected == slots[i],
//           onTap: () => onSelected(slots[i]),
//         ),
//       );
//       items.add(
//         stretches
//             ? Expanded(child: tile)
//             : SizedBox(width: _chipWidth, child: tile),
//       );
//     }
//
//     if (stretches) {
//       return Row(children: items);
//     }
//
//     return ScrollConfiguration(
//       behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         physics: const ClampingScrollPhysics(),
//         child: Row(children: items),
//       ),
//     );
//   }
// }

class _PocketSelector extends StatelessWidget {
  const _PocketSelector({
    required this.selectedId,
    required this.pockets,
    required this.onSelected,
    this.loading = false,
  });

  final int? selectedId;
  final List<ChildPocket> pockets;
  final ValueChanged<ChildPocket> onSelected;

  /// True while `fetchPockets` is still running.
  final bool loading;

  // Button metrics
  static const double _chipWidth = 122;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    if (pockets.isEmpty) {
      return Container(
        height: 52,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: logbookTrack),
        ),
        child: Text(
          loading
              ? 'Loading your pockets…'
              : 'No pockets yet. Create one in Pockets first.',
          maxLines: 2,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: logbookFaint,
          ),
        ),
      );
    }

    final stretches = pockets.length <= 3;

    final items = <Widget>[];
    for (var i = 0; i < pockets.length; i++) {
      if (i > 0) items.add(const SizedBox(width: _gap));
      final pocket = pockets[i];
      final tile = SizedBox(
        height: 52,
        child: _PocketTile(
          pocket: pocket,
          selected: pocket.pocketId == selectedId,
          onTap: () => onSelected(pocket),
        ),
      );
      items.add(
        stretches
            ? Expanded(child: tile)
            : SizedBox(width: _chipWidth, child: tile),
      );
    }

    if (stretches) {
      return Row(children: items);
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(children: items),
      ),
    );
  }
}

// Old tile tied to the fixed PocketSlot enum. Replaced by the version below,
// which renders a backend pocket (image/emoji, name, allocatedBalance).
//
// class _PocketTile extends StatelessWidget {
//   const _PocketTile({
//     required this.slot,
//     required this.balance,
//     required this.selected,
//     required this.onTap,
//   });
//
//   final PocketSlot slot;
//   final int balance;
//   final bool selected;
//   final VoidCallback onTap;
//
//   @override
//   Widget build(BuildContext context) {
//     final reduceMotion =
//         MediaQuery.maybeOf(context)?.disableAnimations ?? false;
//     final tint = pocketColor(slot);
//
//     Widget surface = AnimatedContainer(
//       duration: reduceMotion
//           ? Duration.zero
//           : const Duration(milliseconds: 200),
//       curve: Curves.easeOutCubic,
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: selected ? tint.withValues(alpha: 0.12) : Colors.transparent,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(
//           color: selected ? tint.withValues(alpha: 0.35) : logbookTrack,
//         ),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             height: 20,
//             child: Row(
//               children: [
//                 AnimatedScale(
//                   scale: selected ? 1.3 : 1.0,
//                   alignment: Alignment.centerLeft,
//                   duration: reduceMotion
//                       ? Duration.zero
//                       : const Duration(milliseconds: 260),
//                   curve: Curves.easeOutBack,
//                   child: Icon(pocketIcon(slot), size: 15, color: tint),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: AnimatedDefaultTextStyle(
//                     duration: reduceMotion
//                         ? Duration.zero
//                         : const Duration(milliseconds: 200),
//                     curve: Curves.easeOutCubic,
//                     style: TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w700,
//                       color: selected ? tint : logbookLabel,
//                     ),
//                     child: AnimatedSlide(
//                       offset: selected ? const Offset(-0.03, 0) : Offset.zero,
//                       duration: reduceMotion
//                           ? Duration.zero
//                           : const Duration(milliseconds: 260),
//                       curve: Curves.easeOutCubic,
//                       child: Text(
//                         slot.label,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 3),
//           Text(
//             logbookRupiah(balance),
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontSize: 10.5,
//               height: 1.15,
//               fontWeight: FontWeight.w500,
//               color: selected ? tint : logbookFaint,
//             ),
//           ),
//         ],
//       ),
//     );
//
//     return Semantics(
//       button: true,
//       selected: selected,
//       label: '${slot.label}, ${logbookRupiah(balance)}',
//       child: GestureDetector(
//         behavior: HitTestBehavior.opaque,
//         onTap: onTap,
//         child: surface,
//       ),
//     );
//   }
// }

class _PocketTile extends StatelessWidget {
  const _PocketTile({
    required this.pocket,
    required this.selected,
    required this.onTap,
  });

  final ChildPocket pocket;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // Same tint/icon rules the Pockets page uses, so both screens match.
    final tint = financePocketTint(pocket.pocketName);

    Widget surface = AnimatedContainer(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? tint.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? tint.withValues(alpha: 0.35) : logbookTrack,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 20,
            child: Row(
              children: [
                AnimatedScale(
                  scale: selected ? 1.15 : 1.0,
                  alignment: Alignment.centerLeft,
                  duration:
                      reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: FinancePocketAvatar(
                    image: pocket.pocketImage,
                    name: pocket.pocketName,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration:
                        reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? tint : logbookLabel,
                    ),
                    child: AnimatedSlide(
                      offset: selected ? const Offset(-0.03, 0) : Offset.zero,
                      duration:
                          reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: Text(
                        pocket.pocketName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            logbookRupiah(pocket.allocatedBalance),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.15,
              fontWeight: FontWeight.w500,
              color: selected ? tint : logbookFaint,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '${pocket.pocketName}, ${logbookRupiah(pocket.allocatedBalance)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: surface,
      ),
    );
  }
}
