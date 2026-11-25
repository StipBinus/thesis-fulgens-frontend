import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile/child_profile.dart';
import '../../core/profile/child_profile_store.dart';
import '../../core/db/local_data.dart';
import '../finance/finance_api.dart';
import '../finance/finance_models.dart';
import '../finance/finance_repository.dart';
import '../finance/finance_widgets.dart';
import '../logbook/logbook_money.dart';
import '../logbook/logbook_tokens.dart';
import '../shell/kids_nav_state.dart';
import 'elastic_sheet.dart';
import 'emoji_picker.dart';
import 'goals_card.dart';
import 'goal_expand.dart';
import 'goal_take_out_sheet.dart';
import 'pocket_add_sheet.dart';
import 'kids_order_store.dart';
import 'pocket_expand.dart';
import 'pocket_header.dart';
import 'pocket_looks.dart';
import 'pocket_mode.dart';
import 'pocket_row.dart';
import 'pocket_transfer.dart';
import 'savings_row_look.dart';

// Transfer intro animation styles
enum TransferIntro { settle, rise, bloom }

// Pockets page, total card only
class KidsPocketsPage extends ConsumerStatefulWidget {
  const KidsPocketsPage({super.key, this.highlightGoalId});

  final String? highlightGoalId;

  @override
  ConsumerState<KidsPocketsPage> createState() => _KidsPocketsPageState();
}

class _KidsPocketsPageState extends ConsumerState<KidsPocketsPage>
    with TickerProviderStateMixin {
  PocketRepository get _repository => ref.read(pocketRepositoryProvider);
  GoalRepository get _goalRepo => ref.read(goalRepositoryProvider);
  final KidsOrderStore _orderStore = KidsOrderStore();

  late final AnimationController _barRise;
  late final AnimationController _intro;
  final ScrollController _scroll = ScrollController();
  final TransferIntro _introStyle = TransferIntro.settle;

  List<ChildPocket> _pockets = const [];
  List<ChildGoal> _goals = const [];
  List<_SavingsEntry> _entries = <_SavingsEntry>[];
  ChildProfile? _profile;
  bool _loading = true;
  String? _error;

  final GlobalKey _highlightKey = GlobalKey();
  bool _glow = false;
  bool _highlightDone = false;
  Timer? _glowTimer;

  // Header style being previewed
  int _headerStyle = 0;

  static const List<int> _headerStyles = <int>[0, 11, 12, 13, 14, 15];

  // Page look being previewed
  final PocketLook _look = PocketLook.forest;

  // How each entry sits on the white sheet
  final SavingsRowLook _rowLook = SavingsRowLook.ruled;

  bool get _headerBleed => _headerStyle >= 12 || _look == PocketLook.forest;

  bool get _arranging => _mode.arranges;
  ChildPocket? _transferFrom;
  ChildPocket? _transferLeaving;
  bool get _transferVisible =>
      _transferFrom != null || _transferLeaving != null;
  final PocketModeController _mode = PocketModeController();

  @override
  void initState() {
    super.initState();
    _barRise = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _mode.addListener(_onModeChanged);
    _load();
  }

  void _onModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mode.removeListener(_onModeChanged);
    _mode.dispose();
    _barRise.dispose();
    _intro.dispose();
    _scroll.dispose();
    _glowTimer?.cancel();
    kidsNavHidden.value = false;
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait<Object>([
        _repository.fetchPockets(),
        _goalRepo.fetchGoals(),
        ChildProfileStore.instance.ensure(),
        _orderStore.load(),
      ]);
      if (!mounted) return;
      final pockets = results[0] as List<ChildPocket>;
      final goals = results[1] as List<ChildGoal>;
      setState(() {
        _pockets = pockets;
        _goals = goals;
        _entries = _ordered(pockets, goals, results[3] as List<String>);
        _profile = results[2] as ChildProfile;
        _loading = false;
        _error = null;
      });
      _runHighlight();
    } on FinanceApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your pockets. Please try again.';
        _loading = false;
      });
    }
  }

  // Same balance source as Home
  int get _balance =>
      ref.read(logbookMoneyProvider).value?.balance ??
      _profile?.userBalance ??
      0;

  int get _savedTotal {
    var total = 0;
    for (final goal in _goals) {
      total += goal.allocatedBalance;
    }
    for (final pocket in _pockets) {
      total += pocket.allocatedBalance;
    }
    return total;
  }

  VoidCallback? get _headerOnAdd =>
      _arranging || _transferFrom != null ? null : _openEditor;

  Widget? get _headerAction => _transferFrom != null ? null : _orbButton();

  int _availableFor({String? excludePocketId}) {
    var allocated = 0;
    for (final goal in _goals) {
      allocated += goal.allocatedBalance;
    }
    for (final pocket in _pockets) {
      if (pocket.pocketId == excludePocketId) continue;
      allocated += pocket.allocatedBalance;
    }
    final left = _balance - allocated;
    return left < 0 ? 0 : left;
  }

  int _availableForGoal({String? excludeGoalId}) {
    var allocated = 0;
    for (final goal in _goals) {
      if (goal.goalId == excludeGoalId) continue;
      allocated += goal.allocatedBalance;
    }
    for (final pocket in _pockets) {
      allocated += pocket.allocatedBalance;
    }
    final left = _balance - allocated;
    return left < 0 ? 0 : left;
  }

  Future<void> _openEditor() async {
    final profile = _profile;
    if (profile == null) return;

    _mode.edit(true);
    try {
      final changed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: const Color(0x52000000),
        builder:
            (_) => PocketEditorSheet(
              balance: _balance,
              available: _availableFor(),
            ),
      );

      if (changed == true) await _load();
    } finally {
      _mode.reset();
    }
  }

  Future<void> _editPocket(ChildPocket pocket) async {
    final profile = _profile;
    if (profile == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x52000000),
      builder:
          (_) => PocketEditorSheet(
            pocket: pocket,
            balance: _balance,
            available: _availableFor(excludePocketId: pocket.pocketId),
          ),
    );

    if (changed == true) await _load();
  }

  Future<void> _addMoney(ChildPocket pocket) async {
    final profile = _profile;
    if (profile == null) return;

    _mode.edit(true);
    try {
      final int? amount = await showPocketAddSheet(
        context,
        name: pocket.pocketName,
        image: pocket.pocketImage,
        balance: _balance,
        available: _availableFor(excludePocketId: pocket.pocketId),
      );
      if (amount == null || amount <= 0 || !mounted) return;

      try {
        await _repository.updatePocket(
          pocketId: pocket.pocketId,
          name: pocket.pocketName,
          description: pocket.pocketDesc,
          image: pocket.pocketImage,
          allocatedBalance: pocket.allocatedBalance + amount,
        );
        await _load();
      } on FinanceApiException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add the money. Try again.')),
        );
      }
    } finally {
      _mode.reset();
    }
  }

  Future<void> _editGoal(ChildGoal goal) async {
    final profile = _profile;
    if (profile == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x52000000),
      builder:
          (_) => GoalEditorSheet(
            goal: goal,
            balance: _balance,
            available: _availableForGoal(excludeGoalId: goal.goalId),
          ),
    );

    if (changed == true) await _load();
  }

  List<_SavingsEntry> _ordered(
    List<ChildPocket> pockets,
    List<ChildGoal> goals,
    List<String> order,
  ) {
    final rank = <String, int>{};
    for (var i = 0; i < order.length; i++) {
      rank[order[i]] = i;
    }
    final entries = <_SavingsEntry>[
      for (final pocket in pockets) _SavingsEntry(pocket: pocket),
      for (final goal in goals) _SavingsEntry(goal: goal),
    ];
    final ranked = <MapEntry<int, _SavingsEntry>>[];
    for (var i = 0; i < entries.length; i++) {
      ranked.add(MapEntry(rank[entries[i].key] ?? 100000 + i, entries[i]));
    }
    ranked.sort((a, b) => a.key.compareTo(b.key));
    return [for (final item in ranked) item.value];
  }

  void _setArranging(bool value) {
    _mode.arrange(value);

    if (value) {
      _riseBar();
    } else {
      _barRise.value = 0;
    }
  }

  void _toggleArrange() => _setArranging(!_arranging);

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final entry = _entries.removeAt(oldIndex);
    setState(() => _entries.insert(newIndex, entry));
    await _orderStore.save([for (final item in _entries) item.key]);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Rebuild when the shared balance changes
    ref.watch(logbookMoneyProvider);

    ref.listen(localDataProvider, (_, __) {
      if (mounted && !_loading && !_mode.active) unawaited(_load(quiet: true));
    });

    return PopScope(
      canPop: !_mode.active,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitModes();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: _look != PocketLook.forest,
          bottom: false,
          child:
              _arranging
                  ? _arrangeBody(bottomInset)
                  : _transferBody(bottomInset),
        ),
      ),
    );
  }

  Widget _plainBody(double bottomInset, {double pad = 108}) {
    final bool bleed = _headerBleed;
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        bleed ? 0 : 20,
        bleed ? 0 : 20,
        bleed ? 0 : 20,
        pad + bottomInset,
      ),
      children: [
        _topBlock(),
        if (_entries.isNotEmpty) SizedBox(height: bleed ? 0 : 14),
        if (bleed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _entryChildren(),
            ),
          )
        else
          ..._entryChildren(),
      ],
    );
  }

  List<Widget> _entryChildren() {
    return [
      if (_transferVisible)
        _introCash(
          Padding(
            padding: EdgeInsets.only(bottom: _entries.isNotEmpty ? 12 : 0),
            child: _cashCard(),
          ),
        ),
      for (var i = 0; i < _entries.length; i++) ...[
        if (i > 0) _entryGap(),
        _introCard(
          _entries[i],
          i,
          _highlightWrap(_entries[i], _entryCard(_entries[i], first: i == 0)),
        ),
      ],
      ..._stateChildren(),
    ];
  }

  // Air or hairline between two entries
  Widget _entryGap() {
    if (_rowLook == SavingsRowLook.ruled) {
      return Container(height: 1, color: logbookLine);
    }
    return SizedBox(height: savingsEntryGap(_rowLook));
  }

  // Scroll to the goal the home sheet asked for, then glow it once
  void _runHighlight() {
    final goalId = widget.highlightGoalId;
    if (goalId == null || _highlightDone) return;
    final bool found = _entries.any((entry) => entry.goal?.goalId == goalId);
    if (!found) return;
    _highlightDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final target = _highlightKey.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.25,
        );
      }
      if (!mounted) return;
      setState(() => _glow = true);
      _glowTimer?.cancel();
      _glowTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _glow = false);
      });
    });
  }

  Widget _highlightWrap(_SavingsEntry entry, Widget child) {
    final goal = entry.goal;
    if (goal == null || goal.goalId != widget.highlightGoalId) return child;
    final Color tint = financePocketTint(goal.goalsName, image: goal.goalImage);
    return AnimatedContainer(
      key: _highlightKey,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: _glow ? 0.30 : 0.0),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _arrangeBody(double bottomInset) {
    final bool bleed = _headerBleed;
    return Stack(
      children: [
        ReorderableListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            bleed ? 0 : 20,
            bleed ? 0 : 20,
            bleed ? 0 : 20,
            140 + bottomInset,
          ),
          buildDefaultDragHandles: false,
          proxyDecorator: _liftCard,
          header: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _topBlock(),
          ),
          itemCount: _entries.length,
          onReorderItem: _onReorder,
          itemBuilder: (context, index) => _arrangeItem(index),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 10 + bottomInset,
          child: _barRiseIn(_floatBar()),
        ),
      ],
    );
  }

  Widget _topBlock() {
    if (_look == PocketLook.forest) {
      return PocketForestHeader(
        savedTotal: _savedTotal,
        pocketCount: _pockets.length,
        goalCount: _goals.length,
        cash: _availableFor(),
        onAdd: _arranging || _transferVisible ? null : _openEditor,
        action:
            _transferVisible
                ? const SizedBox(width: 44, height: 44)
                : _orbButton(),
      );
    }
    return PocketHeader(
      style: _headerStyle,
      savedTotal: _savedTotal,
      pocketCount: _pockets.length,
      cash: _availableFor(),
      arranging: _arranging,
      onArrange: _toggleArrange,
      onAdd: _arranging || _transferVisible ? null : _openEditor,
      action:
          _transferVisible
              ? const SizedBox(width: 44, height: 44)
              : _orbButton(),
    );
  }

  Widget _barRiseIn(Widget child) {
    return AnimatedBuilder(
      animation: _barRise,
      builder: (context, child) {
        final double t = const Interval(
          0.55,
          1,
          curve: Curves.easeOutCubic,
        ).transform(_barRise.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  void _riseBar() {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _barRise.value = 1;
    } else {
      _barRise.forward(from: 0);
    }
  }

  Duration get _introDuration => switch (_introStyle) {
    TransferIntro.settle => const Duration(milliseconds: 360),
    TransferIntro.rise => const Duration(milliseconds: 460),
    TransferIntro.bloom => const Duration(milliseconds: 600),
  };

  void _playIntro() {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _intro.duration = _introDuration;
    if (reduce) {
      _intro.value = 1;
    } else {
      _intro.forward(from: 0);
    }
    _riseBar();
  }

  // Scroll distances and glow for one card during the transfer intro
  (double, double, double) _introMotion(int index) {
    final double raw = _intro.value;
    final double start = switch (_introStyle) {
      TransferIntro.settle => 0,
      TransferIntro.rise => (index * 0.05).clamp(0.0, 0.35),
      TransferIntro.bloom => (index * 0.07).clamp(0.0, 0.42),
    };
    final double local = ((raw - start) / (1 - start)).clamp(0.0, 1.0);
    final double t = Curves.easeOutCubic.transform(local);
    final double glow = math.sin(math.pi * local).clamp(0.0, 1.0);
    return switch (_introStyle) {
      TransferIntro.settle => (6 * (1 - t), 1 - 0.008 * (1 - t), glow),
      TransferIntro.rise => (14 * (1 - t), 1 - 0.010 * (1 - t), glow),
      TransferIntro.bloom => (10 * (1 - t), 1 - 0.006 * (1 - t), glow),
    };
  }

  Widget _introCard(_SavingsEntry entry, int index, Widget child) {
    if (!_transferVisible) return child;
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        final from = _transferFrom ?? _transferLeaving;
        if (from == null || reduce) return child;
        final (double y, double scale, double glow) = _introMotion(index);
        final bool source = entry.pocket?.pocketId == from.pocketId;
        final Widget placed = Transform.translate(
          offset: Offset(0, y + (source ? -6 * glow : 0)),
          child: Transform.scale(scale: scale, child: child),
        );
        if (!source) return placed;
        final Color tint = financePocketTint(
          entry.pocket!.pocketName,
          image: entry.pocket!.pocketImage,
        );
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.16 * glow),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: placed,
        );
      },
      child: child,
    );
  }

  Widget _introCash(Widget child) {
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, child) {
        if (!_transferVisible) return const SizedBox.shrink();
        if (reduce) return child!;
        final double raw = _intro.value;
        final double t = const Interval(
          0.0,
          0.7,
          curve: Curves.easeOutCubic,
        ).transform(raw);
        final double shown = t.clamp(0.0, 1.0);
        final double y = switch (_introStyle) {
          TransferIntro.settle => 14 * (1 - t),
          TransferIntro.rise => 22 * (1 - t),
          TransferIntro.bloom => 0,
        };
        final double scale = switch (_introStyle) {
          TransferIntro.settle => 1,
          TransferIntro.rise => 0.98 + 0.02 * t,
          TransferIntro.bloom =>
            0.94 + 0.06 * Curves.easeOutBack.transform(raw),
        };
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: shown,
            child: Opacity(
              opacity: shown,
              child: Transform.translate(
                offset: Offset(0, y),
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget _floatBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.drag_indicator_rounded,
            size: 17,
            color: logbookMuted,
          ),
          const SizedBox(width: 7),
          const Expanded(
            child: Text(
              'Drag to rearrange',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: logbookMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: logbookInk,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _toggleArrange,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orbButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _arranging ? logbookInk : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggleArrange,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder:
                  (child, animation) => ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.85,
                      end: 1,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
              child: Icon(
                _arranging ? Icons.check_rounded : Icons.swap_vert_rounded,
                key: ValueKey<bool>(_arranging),
                size: 20,
                color: _arranging ? Colors.white : logbookInk,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _liftCard(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double t = Curves.easeOutCubic.transform(animation.value);
        return Transform.translate(
          offset: Offset(0, -4 * t),
          child: Transform.scale(
            scale: 1 + 0.03 * t,
            child: Material(color: Colors.transparent, child: child),
          ),
        );
      },
    );
  }

  Widget _arrangeItem(int index) {
    final entry = _entries[index];
    final double side = _headerBleed ? 20 : 0;
    return Padding(
      key: ValueKey(entry.key),
      padding: EdgeInsets.fromLTRB(side, 0, side, 12),
      child: _HoldBobble(
        child: _QuickDragListener(
          index: index,
          child: _ModeEnter(
            key: ValueKey(entry.key),
            index: index,
            child: AbsorbPointer(
              child: Opacity(opacity: 0.92, child: _entryCard(entry)),
            ),
          ),
        ),
      ),
    );
  }

  void _enterTransfer(ChildPocket pocket) {
    _intro.stop();
    setState(() {
      _transferFrom = pocket;
      _transferLeaving = null;
    });
    _mode.transfer(true);
    _playIntro();
    if (_scroll.hasClients) {
      final bool reduce =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduce) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _exitTransfer() {
    final from = _transferFrom;
    if (from == null) return;
    setState(() {
      _transferFrom = null;
      _transferLeaving = from;
    });
    _mode.reset();

    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _finishExitTransfer();
      return;
    }
    _barRise.animateBack(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInCubic,
    );
    _intro.duration = const Duration(milliseconds: 280);
    _intro.reverse().whenCompleteOrCancel(() {
      if (mounted && _transferFrom == null) _finishExitTransfer();
    });
  }

  void _finishExitTransfer() {
    if (!mounted) return;
    setState(() {
      _transferLeaving = null;
      _barRise.value = 0;
      _intro.value = 0;
    });
  }

  // Back button in any mode: leave the mode, never leave the nav hidden
  void _exitModes() {
    if (_mode.arranges) _setArranging(false);
    if (_transferFrom != null) {
      _exitTransfer();
      return;
    }
    _transferFrom = null;
    _transferLeaving = null;
    _mode.reset();
    _barRise.value = 0;
    _intro.value = 0;
    setState(() {});
  }

  Future<void> _expandPocket(ChildPocket pocket, Rect sourceRect) async {
    PocketExpandAction? action;

    _mode.expand(true);
    try {
      action = await showPocketExpand(
        context,
        pocket: pocket,
        sourceRect: sourceRect,
        balance: _balance,
        available: _availableFor(excludePocketId: pocket.pocketId),
        onAddMoney: _addMoneyOver,
      );
    } finally {
      _mode.reset();
    }

    if (!mounted || action == null) return;
    if (action == PocketExpandAction.transfer) {
      _enterTransfer(pocket);
      return;
    }
    if (action == PocketExpandAction.add) {
      await _addMoney(pocket);
      return;
    }
    await _editPocket(pocket);
  }

  Future<void> _expandGoal(ChildGoal goal, Rect sourceRect) async {
    GoalExpandResult? result;

    _mode.expand(true);
    try {
      result = await showGoalExpand(
        context,
        goal: goal,
        sourceRect: sourceRect,
        available:
            _availableForGoal(excludeGoalId: goal.goalId) +
            goal.allocatedBalance,
        onAddMoney: _addGoalMoneyOver,
        onTakeOut: _takeOutGoalOver,
      );
    } finally {
      _mode.reset();
    }

    if (!mounted || result == null) return;
    if (result == GoalExpandResult.saved) {
      await _load();
      return;
    }
    if (result == GoalExpandResult.takeOut) {
      await _takeOutGoal(goal);
      return;
    }
    await _addGoalMoney(goal);
  }

  // Add money over an open pocket card; the card stays open
  Future<ChildPocket?> _addMoneyOver(
    BuildContext sheetContext,
    ChildPocket pocket,
  ) async {
    final int? amount = await showPocketAddSheet(
      sheetContext,
      name: pocket.pocketName,
      image: pocket.pocketImage,
      balance: _balance,
      available: _availableFor(excludePocketId: pocket.pocketId),
    );
    if (amount == null || amount <= 0 || !mounted) return null;
    try {
      final updated = await _repository.updatePocket(
        pocketId: pocket.pocketId,
        name: pocket.pocketName,
        description: pocket.pocketDesc,
        image: pocket.pocketImage,
        allocatedBalance: pocket.allocatedBalance + amount,
      );
      await _load(quiet: true);
      return updated;
    } catch (_) {
      _moneyError('Could not add the money. Try again.');
      return null;
    }
  }

  // Add money over an open goal card
  Future<ChildGoal?> _addGoalMoneyOver(
    BuildContext sheetContext,
    ChildGoal goal,
  ) async {
    final int? amount = await showPocketAddSheet(
      sheetContext,
      name: goal.goalsName,
      image: goal.goalImage,
      balance: _balance,
      available: _availableForGoal(excludeGoalId: goal.goalId),
    );
    if (amount == null || amount <= 0 || !mounted) return null;
    return _moveGoal(
      goal,
      goal.allocatedBalance + amount,
      'Could not add the money. Try again.',
    );
  }

  // Take out over an open goal card
  Future<ChildGoal?> _takeOutGoalOver(
    BuildContext sheetContext,
    ChildGoal goal,
  ) async {
    final int? amount = await showGoalTakeOutSheet(
      sheetContext,
      goal: goal,
      cash: _availableFor(),
    );
    if (amount == null || amount <= 0 || !mounted) return null;
    return _moveGoal(
      goal,
      goal.allocatedBalance - amount,
      'Could not take out the money. Try again.',
    );
  }

  Future<ChildGoal?> _moveGoal(
    ChildGoal goal,
    int allocated,
    String error,
  ) async {
    try {
      final updated = await _goalRepo.updateGoal(
        goalId: goal.goalId,
        name: goal.goalsName,
        description: goal.goalsDesc,
        allocatedBalance: allocated,
        goalPrice: goal.goalPrice,
      );
      await _load(quiet: true);
      return updated;
    } catch (_) {
      _moneyError(error);
      return null;
    }
  }

  void _moneyError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _takeOutGoal(ChildGoal goal) async {
    _mode.edit(true);
    try {
      final int? amount = await showGoalTakeOutSheet(
        context,
        goal: goal,
        cash: _availableFor(),
      );
      if (amount == null || amount <= 0 || !mounted) return;

      try {
        await _goalRepo.updateGoal(
          goalId: goal.goalId,
          name: goal.goalsName,
          description: goal.goalsDesc,
          allocatedBalance: goal.allocatedBalance - amount,
          goalPrice: goal.goalPrice,
        );
        await _load();
      } on FinanceApiException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not take out the money. Try again.'),
          ),
        );
      }
    } finally {
      _mode.reset();
    }
  }

  Future<void> _addGoalMoney(ChildGoal goal) async {
    final profile = _profile;
    if (profile == null) return;

    _mode.edit(true);
    try {
      final int? amount = await showPocketAddSheet(
        context,
        name: goal.goalsName,
        image: goal.goalImage,
        balance: _balance,
        available: _availableForGoal(excludeGoalId: goal.goalId),
      );
      if (amount == null || amount <= 0 || !mounted) return;

      try {
        await _goalRepo.updateGoal(
          goalId: goal.goalId,
          name: goal.goalsName,
          description: goal.goalsDesc,
          allocatedBalance: goal.allocatedBalance + amount,
          goalPrice: goal.goalPrice,
        );
        await _load();
      } on FinanceApiException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add the money. Try again.')),
        );
      }
    } finally {
      _mode.reset();
    }
  }

  Widget _transferBody(double bottomInset) {
    return Stack(
      children: [
        _plainBody(bottomInset, pad: _transferVisible ? 150 : 108),
        if (_transferVisible)
          Positioned(
            left: 20,
            right: 20,
            bottom: 10 + bottomInset,
            child: _barRiseIn(_transferBar()),
          ),
      ],
    );
  }

  Widget _transferBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 17, color: logbookMuted),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Tap a pocket, goal, or Cash',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: logbookMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            shape: const StadiumBorder(
              side: BorderSide(color: logbookLine, width: 1.2),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => _exitTransfer(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: logbookInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTransferTo(ChildPocket to) async {
    final from = _transferFrom;
    if (from == null) return;

    final TransferResult? result = await showTransferAmount(
      context,
      from: _sideOf(from),
      to: _sideOf(to),
      canSwap: true,
    );
    if (!mounted || result == null) return;

    final ChildPocket source = result.swapped ? to : from;
    final ChildPocket target = result.swapped ? from : to;
    await _moveMoney(from: source, toPocket: target, amount: result.amount);
  }

  Future<void> _pickTransferToGoal(ChildGoal goal) async {
    final from = _transferFrom;
    if (from == null) return;

    final TransferResult? result = await showTransferAmount(
      context,
      from: _sideOf(from),
      to: TransferSide(
        id: goal.goalId,
        name: goal.goalsName,
        balance: goal.allocatedBalance,
      ),
      canSwap: false,
    );
    if (!mounted || result == null) return;
    await _moveMoney(from: from, toGoal: goal, amount: result.amount);
  }

  Future<void> _pickTransferToCash() async {
    final from = _transferFrom;
    if (from == null) return;

    final TransferResult? result = await showTransferAmount(
      context,
      from: _sideOf(from),
      to: TransferSide(id: 'cash', name: 'Cash', balance: _availableFor()),
      canSwap: true,
    );
    if (!mounted || result == null) return;
    if (result.swapped) {
      await _cashToPocket(to: from, amount: result.amount);
      return;
    }
    await _moveMoney(from: from, amount: result.amount);
  }

  // Cash into a pocket: the pocket grows, cash shrinks by the same amount
  Future<void> _cashToPocket({
    required ChildPocket to,
    required int amount,
  }) async {
    try {
      await _repository.updatePocket(
        pocketId: to.pocketId,
        name: to.pocketName,
        description: to.pocketDesc,
        image: to.pocketImage,
        allocatedBalance: to.allocatedBalance + amount,
      );
      await _load();
      if (!mounted) return;
      _exitTransfer();
    } on FinanceApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not move the money. Try again.')),
      );
    }
  }

  Widget _cashCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickTransferToCash,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: logbookGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 24,
                color: logbookGreen,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: logbookInk,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tap to move money back',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: logbookMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              financeRupiah(_availableFor()),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: logbookInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TransferSide _sideOf(ChildPocket pocket) {
    return TransferSide(
      id: pocket.pocketId,
      name: pocket.pocketName,
      image: pocket.pocketImage,
      balance: pocket.allocatedBalance,
    );
  }

  Future<void> _moveMoney({
    required ChildPocket from,
    ChildPocket? toPocket,
    ChildGoal? toGoal,
    required int amount,
  }) async {
    try {
      // History labels for both sides of the move
      final toName = toPocket?.pocketName ?? toGoal?.goalsName ?? 'cash';
      await _repository.updatePocket(
        pocketId: from.pocketId,
        name: from.pocketName,
        description: from.pocketDesc,
        image: from.pocketImage,
        allocatedBalance: from.allocatedBalance - amount,
        note: 'To $toName',
      );
      if (toPocket != null) {
        await _repository.updatePocket(
          pocketId: toPocket.pocketId,
          name: toPocket.pocketName,
          description: toPocket.pocketDesc,
          image: toPocket.pocketImage,
          allocatedBalance: toPocket.allocatedBalance + amount,
          note: 'From ${from.pocketName}',
        );
      }
      if (toGoal != null) {
        await _goalRepo.updateGoal(
          goalId: toGoal.goalId,
          name: toGoal.goalsName,
          description: toGoal.goalsDesc,
          allocatedBalance: toGoal.allocatedBalance + amount,
          goalPrice: toGoal.goalPrice,
          note: 'From ${from.pocketName}',
        );
      }
      await _load();
      if (!mounted) return;
      _exitTransfer();
    } on FinanceApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not move the money. Try again.')),
      );
    }
  }

  Widget _entryCard(_SavingsEntry entry, {bool first = false}) {
    final pocket = entry.pocket;
    final goal = entry.goal;

    if (pocket != null) {
      final from = _transferFrom ?? _transferLeaving;
      if (from != null) {
        final bool source = from.pocketId == pocket.pocketId;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: source ? 0.55 : 1,
          child: PocketRow(
            pocket: pocket,
            onOpen: source ? null : (rect) => _pickTransferTo(pocket),
            onAdd: () {},
            onTransfer: null,
            onEdit: () {},
            look: _rowLook,
            first: first,
          ),
        );
      }
      return PocketRow(
        pocket: pocket,
        onOpen: (rect) => _expandPocket(pocket, rect),
        onAdd: () => _addMoney(pocket),
        onTransfer: () => _enterTransfer(pocket),
        onEdit: () => _editPocket(pocket),
        look: _rowLook,
        first: first,
      );
    }

    final ChildGoal target = goal!;
    if (_transferFrom != null || _transferLeaving != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pickTransferToGoal(target),
        child: AbsorbPointer(
          child: GoalCard(
            goal: target,
            onAdd: () {},
            onTransfer: null,
            onEdit: () {},
            look: _rowLook,
            first: first,
          ),
        ),
      );
    }
    return GoalCard(
      goal: target,
      onOpen: (rect) => _expandGoal(target, rect),
      onAdd: () => _addGoalMoney(target),
      onTransfer: () => _takeOutGoal(target),
      onEdit: () => _editGoal(target),
      look: _rowLook,
      first: first,
    );
  }

  List<Widget> _stateChildren() {
    if (_loading && _profile == null) {
      return const [
        SizedBox(height: 18),
        FinanceCard(
          padding: EdgeInsets.symmetric(vertical: 44),
          child: Center(child: CircularProgressIndicator(color: logbookAccent)),
        ),
      ];
    }

    if (_error != null && _profile == null) {
      return [
        const SizedBox(height: 18),
        FinanceErrorState(message: _error!, onRetry: _load),
      ];
    }

    if (_entries.isEmpty) {
      return const [
        SizedBox(height: 28),
        Text(
          'No pockets yet. Tap + to start one.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: logbookMuted,
          ),
        ),
      ];
    }

    return const [];
  }
}

// One card on the savings page: a pocket or a goal
class _SavingsEntry {
  const _SavingsEntry({this.pocket, this.goal});

  final ChildPocket? pocket;
  final ChildGoal? goal;

  String get key =>
      pocket != null
          ? KidsOrderStore.pocketKey(pocket!.pocketId)
          : KidsOrderStore.goalKey(goal!.goalId);
}

// Drag starts after a short hold instead of the stock long press
class _QuickDragListener extends ReorderableDragStartListener {
  const _QuickDragListener({required super.child, required super.index});

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: const Duration(milliseconds: 180),
      debugOwner: this,
    );
  }
}

// Nudge feedback while the finger is held down
class _HoldBobble extends StatefulWidget {
  const _HoldBobble({required this.child});

  final Widget child;

  @override
  State<_HoldBobble> createState() => _HoldBobbleState();
}

class _HoldBobbleState extends State<_HoldBobble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 170),
  );

  void _down(PointerDownEvent _) => _hold.forward(from: 0);

  void _up(PointerEvent _) => _hold.value = 0;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Listener(
      onPointerDown: reduce ? null : _down,
      onPointerUp: reduce ? null : _up,
      onPointerCancel: reduce ? null : _up,
      child: AnimatedBuilder(
        animation: _hold,
        builder: (context, child) {
          final double press = math.sin(_hold.value * math.pi);
          return Transform.translate(
            offset: Offset(0, 1.5 * press),
            child: Transform.scale(scale: 1 - 0.012 * press, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}

// Jiggle entrance for the arrange mode cards
class _ModeEnter extends StatefulWidget {
  const _ModeEnter({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_ModeEnter> createState() => _ModeEnterState();
}

class _ModeEnterState extends State<_ModeEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    final int step = widget.index.clamp(0, 10);
    final int total = 260 + step * 45;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    )..forward();
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(step * 45 / total, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final double t = reduce ? 1 : _curve.value;
        final double wobble =
            math.sin(t * math.pi) * (widget.index.isEven ? 1 : -1);
        return Transform.rotate(
          angle: wobble * 0.008,
          child: Transform.scale(
            scale: 1 + wobble.abs() * 0.012,
            child: Opacity(opacity: 0.45 + 0.55 * t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ----------------------------------------------------------------------
// Pocket editor
// ----------------------------------------------------------------------

// Create type for the pocket sheet
enum _SheetKind { savings, goal }

class PocketEditorSheet extends ConsumerStatefulWidget {
  const PocketEditorSheet({
    super.key,
    this.pocket,
    required this.balance,
    required this.available,
  });

  final ChildPocket? pocket;
  final int balance;
  final int available;

  @override
  ConsumerState<PocketEditorSheet> createState() => _PocketEditorSheetState();
}

class _PocketEditorSheetState extends ConsumerState<PocketEditorSheet> {
  PocketRepository get _repository => ref.read(pocketRepositoryProvider);

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _image;
  late final TextEditingController _allocated;
  late final TextEditingController _target;

  // Create-only type picker
  _SheetKind _kind = _SheetKind.savings;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _noteFocus = FocusNode();
  final FocusNode _iconFocus = FocusNode();

  bool _saving = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.pocket != null;
  bool get _isGoal => !_isEditing && _kind == _SheetKind.goal;

  @override
  void initState() {
    super.initState();
    final pocket = widget.pocket;
    _name = TextEditingController(text: pocket?.pocketName ?? '');
    _description = TextEditingController(text: pocket?.pocketDesc ?? '');
    _image = TextEditingController(text: pocket?.pocketImage ?? '');
    _allocated = TextEditingController(
      text: _amountText(pocket?.allocatedBalance),
    );
    _target = TextEditingController();

    _nameFocus.addListener(_onFocus);
    _noteFocus.addListener(_onFocus);
    _iconFocus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  void _setKind(_SheetKind kind) {
    if (_kind == kind) return;
    setState(() {
      _kind = kind;
      _error = null;
    });
  }

  Widget _fadeGrow({required bool show, required Widget child}) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final double target = show ? 1 : 0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: target, end: target),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      builder:
          (context, t, child) => ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: t,
              child: Opacity(opacity: t, child: child),
            ),
          ),
      child: child,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    _allocated.dispose();
    _target.dispose();
    _nameFocus.dispose();
    _noteFocus.dispose();
    _iconFocus.dispose();
    super.dispose();
  }

  String _amountText(int? value) {
    if (value == null || value <= 0) return '';
    return '$value';
  }

  int _amount(TextEditingController controller) {
    final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _save() async {
    final name = _name.text.trim();

    if (name.isEmpty) {
      setState(
        () =>
            _error =
                _isGoal
                    ? 'Give your goal a name first.'
                    : 'Give your pocket a name first.',
      );
      return;
    }

    final int target = _amount(_target);
    if (_isGoal && target <= 0) {
      setState(() => _error = 'Set a target bigger than Rp 0.');
      return;
    }

    final allocated = _amount(_allocated);
    if (allocated > widget.available) {
      setState(
        () =>
            _error =
                'You can only allocate up to ${financeRupiah(widget.available)}. '
                'Lower the amount.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await _repository.updatePocket(
          pocketId: widget.pocket!.pocketId,
          name: name,
          description: _description.text,
          image: _image.text,
          allocatedBalance: allocated,
        );
      } else if (_isGoal) {
        await ref
            .read(goalRepositoryProvider)
            .createGoal(
              name: name,
              description: _description.text,
              allocatedBalance: allocated,
              goalPrice: target,
              image: _image.text,
            );
      } else {
        await _repository.createPocket(
          name: name,
          description: _description.text,
          image: _image.text,
          allocatedBalance: allocated,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
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
        _error =
            _isGoal
                ? 'Could not save your goal. Please try again.'
                : 'Could not save your pocket. Please try again.';
      });
    }
  }

  Future<void> _delete() async {
    final pocket = widget.pocket;
    if (pocket == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                title: const Text('Delete pocket?'),
                content: Text(
                  '"${pocket.pocketName}" and the money set aside for it '
                  'will move back to cash.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: TextButton.styleFrom(foregroundColor: logbookRed),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await _repository.deletePocket(pocket.pocketId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FinanceApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Could not delete this pocket. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget sheet = FinanceSheet(
      title: _isEditing ? 'Edit pocket' : 'New Pocket',
      subtitle:
          _isEditing
              ? 'Adjust the name, amount, or details.'
              : (_isGoal
                  ? 'Save up for something you want.'
                  : 'Anything you set aside, no limit.'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isEditing) ...[_kindToggle(), const SizedBox(height: 18)],
          _fadeGrow(
            show: _isGoal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel('TARGET'),
                _bigTarget(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          _sectionLabel('IDENTITY'),
          // Icon lives on the name row
          PocketIconPicker(
            controller: _image,
            name: _name,
            goal: _isGoal,
            onChanged: (_) {
              _clearError();
              setState(() {});
            },
            fieldBuilder:
                (leading) => _SheetRow(
                  icon: Icons.edit_outlined,
                  leading: leading,
                  label: 'Name',
                  controller: _name,
                  focusNode: _nameFocus,
                  hint: 'e.g. Snacks',
                  onChanged: (_) {
                    _clearError();
                    setState(() {});
                  },
                ),
          ),
          _rule(active: _nameFocus.hasFocus),
          _SheetRow(
            icon: Icons.notes_rounded,
            label: 'Note',
            controller: _description,
            focusNode: _noteFocus,
            hint: 'What is it for?',
            maxLines: 2,
          ),
          _rule(active: _noteFocus.hasFocus),
          const SizedBox(height: 20),
          _sectionLabel('MONEY'),
          _moneySummary(),
          _SheetRow(
            icon: Icons.savings_outlined,
            label: 'Set aside',
            controller: _allocated,
            hint: '0',
            number: true,
            prefix: 'Rp',
            onChanged: (_) => _clearError(),
          ),
          FinanceFormError(message: _error),
          const SizedBox(height: 18),
          if (_isEditing)
            FinancePrimaryButton(
              label: 'Save changes',
              onTap: _deleting ? null : _save,
              loading: _saving,
            )
          else
            _createButton(),
          if (_isEditing) ...[
            const SizedBox(height: 2),
            FinanceDangerButton(
              label: _deleting ? 'Deleting...' : 'Delete pocket',
              onTap: _deleting ? null : _delete,
            ),
          ],
        ],
      ),
    );

    // Create sheet only: same pull-to-dismiss as the transfer panel
    return ElasticSheetDrag(
      enabled: !_isEditing,
      onDismiss: () => Navigator.of(context).pop(),
      child: sheet,
    );
  }

  Widget _createButton() {
    final String label = _isGoal ? 'Create Goal' : 'Create Savings';
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _saving ? null : _save,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: logbookAccent,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33FF7A45),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child:
              _saving
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _kindToggle() {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Alignment align =
        _kind == _SheetKind.savings
            ? const Alignment(-1, 0)
            : const Alignment(1, 0);

    return Container(
      height: 28,
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
                child: _kindPill('Savings', _SheetKind.savings, logbookGreen),
              ),
              Expanded(
                child: _kindPill('Goal', _SheetKind.goal, logbookAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kindPill(String label, _SheetKind kind, Color color) {
    final bool selected = _kind == kind;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setKind(kind),
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
    );
  }

  Widget _bigTarget() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 8, bottom: 5),
          child: Text(
            'Rp',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: logbookMuted,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.8,
              color: logbookInk,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 40,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.8,
                color: logbookFaint,
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
      ],
    );
  }

  // Balance and available on the same grid as the rows below, no box
  Widget _moneySummary() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _moneyStat('Balance', financeRupiah(widget.balance))),
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: logbookLine,
          ),
          Expanded(
            child: _moneyStat(
              'Available',
              financeRupiah(widget.available),
              color: logbookGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyStat(String label, String value, {Color color = logbookInk}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: logbookMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: logbookMuted,
        ),
      ),
    );
  }

  Widget _rule({bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 54),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 1,
        color: active ? logbookAccent : logbookLine,
      ),
    );
  }
}

// One editable line, same language as the pocket card
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    this.icon,
    this.leading,
    required this.label,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.number = false,
    this.prefix,
    this.maxLines = 1,
    this.onChanged,
  });

  final IconData? icon;
  final Widget? leading;
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final bool number;
  final String? prefix;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Center(
            child: leading ?? Icon(icon, size: 17, color: logbookMuted),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: logbookMuted,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (prefix != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Text(
                          prefix!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: logbookInk,
                          ),
                        ),
                      ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: maxLines,
                        keyboardType:
                            number ? TextInputType.number : TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters:
                            number
                                ? [FilteringTextInputFormatter.digitsOnly]
                                : null,
                        onChanged: onChanged,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: logbookInk,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: hint,
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB9B4AA),
                          ),
                          contentPadding: const EdgeInsets.only(
                            top: 2,
                            bottom: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Popup used for both creating and editing a goal.
class GoalEditorSheet extends StatefulWidget {
  const GoalEditorSheet({
    super.key,
    this.goal,
    required this.balance,
    required this.available,
  });

  final ChildGoal? goal;

  /// Child balance, shown for context.
  final int balance;

  /// Money that can still be allocated to this goal.
  final int available;

  @override
  State<GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<GoalEditorSheet> {
  final GoalRepository _repository = LocalGoalRepository();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _saved;
  late final TextEditingController _target;
  late final TextEditingController _image;

  bool _saving = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _name = TextEditingController(text: goal?.goalsName ?? '');
    _description = TextEditingController(text: goal?.goalsDesc ?? '');
    _saved = TextEditingController(text: _amountText(goal?.allocatedBalance));
    _target = TextEditingController(text: _amountText(goal?.goalPrice));
    _image = TextEditingController(text: goal?.goalImage ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _saved.dispose();
    _target.dispose();
    _image.dispose();
    super.dispose();
  }

  String _amountText(int? value) {
    if (value == null || value <= 0) return '';
    return '$value';
  }

  int _amount(TextEditingController controller) {
    final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _save() async {
    final name = _name.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Give your goal a name first.');
      return;
    }

    final target = _amount(_target);
    if (target <= 0) {
      setState(() => _error = 'Set a target bigger than Rp 0.');
      return;
    }

    final allocated = _amount(_saved);
    if (allocated > widget.available) {
      setState(
        () =>
            _error =
                'You can only allocate up to ${financeRupiah(widget.available)}. '
                'Lower the saved amount.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await _repository.updateGoal(
          goalId: widget.goal!.goalId,
          name: name,
          description: _description.text,
          allocatedBalance: allocated,
          goalPrice: target,
          image: _image.text,
        );
      } else {
        await _repository.createGoal(
          name: name,
          description: _description.text,
          allocatedBalance: allocated,
          goalPrice: target,
          image: _image.text,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
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
        _error = 'Could not save your goal. Please try again.';
      });
    }
  }

  Future<void> _delete() async {
    final goal = widget.goal;
    if (goal == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                title: const Text('Delete goal?'),
                content: Text(
                  '"${goal.goalsName}" and the money saved for it will be removed.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: TextButton.styleFrom(foregroundColor: logbookRed),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await _repository.deleteGoal(goal.goalId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FinanceApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Could not delete this goal. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FinanceSheet(
      title: _isEditing ? 'Edit goal' : 'New goal',
      subtitle:
          _isEditing
              ? 'Adjust the target, savings, or details.'
              : 'What are you saving for?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinanceAllocationInfo(
            balance: widget.balance,
            available: widget.available,
          ),
          const SizedBox(height: 14),
          PocketIconPicker(
            controller: _image,
            name: _name,
            goal: true,
            fieldBuilder:
                (leading) => Row(
                  children: [
                    if (leading != null) ...[
                      leading,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _clearError(),
                        decoration: financeInputDecoration(
                          label: 'Goal name',
                          hint: 'e.g. New bicycle',
                        ),
                      ),
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: financeInputDecoration(
              label: 'Description (optional)',
              hint: 'Why do you want it?',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _clearError(),
                  decoration: financeInputDecoration(
                    label: 'Target',
                    hint: '0',
                    prefixText: 'Rp ',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _saved,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _clearError(),
                  decoration: financeInputDecoration(
                    label: 'Saved',
                    hint: '0',
                    prefixText: 'Rp ',
                  ),
                ),
              ),
            ],
          ),
          FinanceFormError(message: _error),
          const SizedBox(height: 18),
          FinancePrimaryButton(
            label: _isEditing ? 'Save changes' : 'Create goal',
            onTap: _deleting ? null : _save,
            loading: _saving,
          ),
          if (_isEditing) ...[
            const SizedBox(height: 2),
            FinanceDangerButton(
              label: _deleting ? 'Deleting...' : 'Delete goal',
              onTap: _deleting ? null : _delete,
            ),
          ],
        ],
      ),
    );
  }
}
