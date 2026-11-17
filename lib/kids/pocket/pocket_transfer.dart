import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../finance/finance_widgets.dart';
import '../logbook/logbook_keypad.dart';
import '../logbook/logbook_models.dart';
import '../logbook/logbook_tokens.dart';
import 'elastic_sheet.dart';

// One side of a transfer: a pocket or a goal
class TransferSide {
  const TransferSide({
    required this.id,
    required this.name,
    required this.balance,
    this.image,
  });

  final String id;
  final String name;
  final int balance;
  final String? image;
}

// What the transfer sheet sends back
class TransferResult {
  const TransferResult({required this.amount, required this.swapped});

  final int amount;
  final bool swapped;
}

Future<TransferResult?> showTransferAmount(
  BuildContext context, {
  required TransferSide from,
  required TransferSide to,
  required bool canSwap,
}) {
  return showGeneralDialog<TransferResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Transfer',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      final Animation<double> eased = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return _TransferPanel(
        from: from,
        to: to,
        canSwap: canSwap,
        animation: eased,
      );
    },
  );
}

class _TransferPanel extends StatefulWidget {
  const _TransferPanel({
    required this.from,
    required this.to,
    required this.canSwap,
    required this.animation,
  });

  final TransferSide from;
  final TransferSide to;
  final bool canSwap;
  final Animation<double> animation;

  @override
  State<_TransferPanel> createState() => _TransferPanelState();
}

class _TransferPanelState extends State<_TransferPanel> {
  late TransferSide _from = widget.from;
  late TransferSide _to = widget.to;
  late int _available = widget.from.balance;

  String _digits = '';
  int _swapCount = 0;
  int _wave = 0;
  bool _keypadOpen = false;

  int get _value => int.tryParse(_digits) ?? 0;

  bool get _valid => _value > 0 && _value <= _available;

  void _typeKey(String key) {
    final String next = '$_digits$key';
    if (next.length > 9) return;
    setState(() => _digits = next);
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  // Swap source and target, keeping the available limit in sync
  void _swap() {
    if (!widget.canSwap) return;
    setState(() {
      final TransferSide previous = _from;
      _from = _to;
      _to = previous;
      _available = _from.balance;
      _digits = '';
      _swapCount += 1;
      _wave += 1;
    });
  }

  // Blocked swap: the arrow waves, the sides stay put
  void _nudge() {
    setState(() => _wave += 1);
  }

  void _confirm() {
    if (!_valid) return;
    Navigator.of(
      context,
    ).pop(TransferResult(amount: _value, swapped: _swapCount.isOdd));
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final double maxHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).top -
        28 -
        MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: !_keypadOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_keypadOpen) return;
        setState(() => _keypadOpen = false);
      },
      child: Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: widget.animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(widget.animation),
              child: ElasticSheetDrag(
                onDismiss: () => Navigator.of(context).pop(),
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                          child: Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: logbookLine,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _route(reduce),
                                const SizedBox(height: 18),
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
                                    Text(
                                      'Available ${financeRupiah(_available)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: logbookFaint,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap:
                                      () => setState(
                                        () => _keypadOpen = !_keypadOpen,
                                      ),
                                  child: _amountDisplay(),
                                ),
                                const SizedBox(height: 12),
                                _suggestions(),
                                AnimatedSize(
                                  duration:
                                      reduce
                                          ? Duration.zero
                                          : const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child:
                                      _keypadOpen
                                          ? Padding(
                                            padding: const EdgeInsets.only(
                                              top: 10,
                                            ),
                                            child: LogbookKeypad(
                                              onKey: _typeKey,
                                              onBackspace: _backspace,
                                            ),
                                          )
                                          : const SizedBox(
                                            width: double.infinity,
                                          ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: 46,
                                  child: FilledButton(
                                    onPressed: _valid ? _confirm : null,
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
                                          reduce
                                              ? Duration.zero
                                              : const Duration(
                                                milliseconds: 200,
                                              ),
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
                                        _valid
                                            ? 'Transfer ${financeRupiah(_value)}'
                                            : 'Transfer',
                                        key: ValueKey<bool>(_valid),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _route(bool reduce) {
    final Duration names =
        reduce ? Duration.zero : const Duration(milliseconds: 240);

    return Row(
      children: [
        Expanded(child: _routeSide(_from, false, names)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _swapControl(reduce),
        ),
        Expanded(child: _routeSide(_to, true, names)),
      ],
    );
  }

  Widget _swapControl(bool reduce) {
    final Widget circle = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: logbookLine, width: 1.2),
      ),
      child: _swapArrow(reduce),
    );
    if (!widget.canSwap) {
      return Semantics(
        button: true,
        label: 'Pockets and goals stay in place',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _nudge,
          child: circle,
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Swap pockets',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _swap,
        child: circle,
      ),
    );
  }

  Widget _swapArrow(bool reduce) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(_wave),
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final double wave = math.sin(math.pi * t);
        return Transform.translate(offset: Offset(6 * wave, 0), child: child);
      },
      child: const Icon(
        Icons.swap_horiz_rounded,
        size: 17,
        color: logbookMuted,
      ),
    );
  }

  Widget _routeSide(TransferSide side, bool alignEnd, Duration duration) {
    final Widget avatar = FinancePocketAvatar(
      image: side.image,
      name: side.name,
      size: 28,
      background: false,
    );
    final Widget name = Flexible(
      child: Text(
        side.name,
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
    );

    final double beginX = alignEnd ? -0.35 : 0.35;

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final Animation<double> curved = animation.drive(
          CurveTween(curve: Curves.easeOutCubic),
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(beginX, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Row(
        key: ValueKey<String>(side.id),
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children:
            alignEnd
                ? [name, const SizedBox(width: 8), avatar]
                : [avatar, const SizedBox(width: 8), name],
      ),
    );
  }

  Widget _amountDisplay() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _keypadOpen ? logbookAccent : logbookLine,
            width: _keypadOpen ? 1.6 : 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 1),
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
            child: Text(
              _digits.isEmpty ? '0' : logbookGroup(_value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: _digits.isEmpty ? const Color(0xFFD8D3CB) : logbookInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestions() {
    final int available = _available;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('25%', available * 25 ~/ 100),
        _chip('50%', available * 50 ~/ 100),
        _chip('75%', available * 75 ~/ 100),
        _chip('Max', available),
      ],
    );
  }

  Widget _chip(String label, int value) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: logbookLine, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: value > 0 ? () => setState(() => _digits = '$value') : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: value > 0 ? logbookMuted : logbookLine,
            ),
          ),
        ),
      ),
    );
  }
}
