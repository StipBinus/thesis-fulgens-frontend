import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/profile/child_profile.dart';
import '../../core/profile/child_profile_store.dart';
import '../../core/widgets/design_proposal_card.dart';
import '../finance/finance_api.dart';
import '../finance/finance_models.dart';
import '../finance/finance_repository.dart';
import '../finance/finance_widgets.dart';
import '../goals/goals_page.dart';
import '../logbook/logbook_tokens.dart';
import '../shell/kids_nav_state.dart';
import 'elastic_sheet.dart';
import 'goals_card.dart';
import 'pocket_add_sheet.dart';
import 'kids_order_store.dart';
import 'pocket_expand.dart';
import 'pocket_header.dart';
import 'pocket_header_styles.dart';
import 'pocket_mode.dart';
import 'pocket_row.dart';
import 'pocket_transfer.dart';

// Pockets page, total card only
class KidsPocketsPage extends StatefulWidget {
  const KidsPocketsPage({super.key});

  @override
  State<KidsPocketsPage> createState() => _KidsPocketsPageState();
}

class _KidsPocketsPageState extends State<KidsPocketsPage>
    with SingleTickerProviderStateMixin {
  final ChildPocketRepository _repository = ChildPocketRepository();
  final KidsOrderStore _orderStore = KidsOrderStore();

  late final AnimationController _barRise;

  List<ChildPocket> _pockets = const [];
  List<ChildGoal> _goals = const [];
  List<_SavingsEntry> _entries = <_SavingsEntry>[];
  ChildProfile? _profile;
  bool _loading = true;
  String? _error;

  bool get _arranging => _mode.arranges;
  ChildPocket? _transferFrom;
  final PocketModeController _mode = PocketModeController();
  final ValueNotifier<PocketHeaderStyle> _headerStyle = ValueNotifier(
    PocketHeaderStyle.inFlow,
  );
  final ScrollController _scroll = ScrollController();
  DesignProposalHandle? _headerCard;
  bool _headerCardShown = false;
  bool _stickyCollapsed = false;

  @override
  void initState() {
    super.initState();
    _barRise = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _mode.addListener(_onModeChanged);
    _headerStyle.addListener(_onHeaderStyle);
    _scroll.addListener(_onScroll);
    _load();
  }

  void _onModeChanged() {
    if (mounted) setState(() {});
  }

  void _onHeaderStyle() {
    if (mounted) setState(() => _stickyCollapsed = false);
  }

  void _onScroll() {
    final bool collapsed = _scroll.hasClients && _scroll.offset > 28;
    if (collapsed != _stickyCollapsed) {
      setState(() => _stickyCollapsed = collapsed);
    }
  }

  void _showHeaderProposals() {
    if (!mounted) return;
    _headerCard?.close();
    _headerCard = showDesignProposalCard(
      context,
      title: 'HEADER',
      options: pocketHeaderStyleLabels,
      initialIndex: _headerStyle.value.index,
      initialLeft: 16,
      initialBottom: 150,
      onSelect: (index) => _headerStyle.value = PocketHeaderStyle.values[index],
    );
  }

  @override
  void dispose() {
    _headerCard?.close();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _headerStyle.removeListener(_onHeaderStyle);
    _headerStyle.dispose();
    _mode.removeListener(_onModeChanged);
    _mode.dispose();
    _barRise.dispose();
    kidsNavHidden.value = false;
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<Object>([
        _repository.fetchPockets(),
        ChildGoalRepository().fetchGoals(),
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
      });
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

  int get _balance => _profile?.userBalance ?? 0;

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

  int _availableFor({int? excludePocketId}) {
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

  int _availableForGoal({int? excludeGoalId}) {
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
              balance: profile.userBalance,
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
            balance: profile.userBalance,
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
        pocket: pocket,
        balance: profile.userBalance,
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
            balance: profile.userBalance,
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
    if (!_headerCardShown) {
      _headerCardShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showHeaderProposals();
      });
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: !_mode.active,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitModes();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child:
              _arranging
                  ? _arrangeBody(bottomInset)
                  : _transferFrom != null
                  ? _transferBody(bottomInset)
                  : _plainBody(bottomInset),
        ),
      ),
    );
  }

  Widget _plainBody(double bottomInset, {double pad = 108}) {
    final PocketHeaderStyle style = _headerStyle.value;
    if (style == PocketHeaderStyle.sticky) {
      return _stickyBody(bottomInset, pad);
    }
    if (style == PocketHeaderStyle.capsule) {
      return _capsuleBody(bottomInset, pad);
    }
    if (style == PocketHeaderStyle.band) {
      return _bandBody(bottomInset, pad);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 20, 20, pad + bottomInset),
      children: [
        _headerFor(style),
        if (_entries.isNotEmpty) const SizedBox(height: 14),
        ..._entryChildren(),
      ],
    );
  }

  Widget _headerFor(PocketHeaderStyle style) {
    switch (style) {
      case PocketHeaderStyle.card:
        return PocketHeaderCard(
          total: _savedTotal,
          count: _entries.length,
          onAdd: _headerOnAdd,
          action: _headerAction,
        );
      case PocketHeaderStyle.centered:
        return PocketHeaderCentered(
          total: _savedTotal,
          onAdd: _headerOnAdd,
          action: _headerAction,
        );
      case PocketHeaderStyle.split:
        return PocketHeaderSplit(
          total: _savedTotal,
          onAdd: _headerOnAdd,
          action: _headerAction,
        );
      default:
        return _topBlock();
    }
  }

  List<Widget> _entryChildren() {
    return [
      for (var i = 0; i < _entries.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        _entryCard(_entries[i]),
      ],
      ..._stateChildren(),
    ];
  }

  Widget _stickyBody(double bottomInset, double pad) {
    final bool reduce = MediaQuery.disableAnimationsOf(context);

    return Stack(
      children: [
        ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, pad + bottomInset),
          children: [
            _topBlock(),
            if (_entries.isNotEmpty) const SizedBox(height: 14),
            ..._entryChildren(),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_stickyCollapsed,
            child: AnimatedOpacity(
              opacity: _stickyCollapsed ? 1 : 0,
              duration:
                  reduce ? Duration.zero : const Duration(milliseconds: 160),
              child: AnimatedSlide(
                offset: _stickyCollapsed ? Offset.zero : const Offset(0, -0.4),
                duration:
                    reduce ? Duration.zero : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: PocketHeaderCompactBar(
                  onAdd: _headerOnAdd,
                  action: _headerAction,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _capsuleBody(double bottomInset, double pad) {
    return Stack(
      children: [
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 86, 20, pad + bottomInset),
          children: _entryChildren(),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 86,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 20,
          right: 20,
          child: PocketHeaderCapsule(
            count: _entries.length,
            onAdd: _headerOnAdd,
            action: _headerAction,
          ),
        ),
      ],
    );
  }

  Widget _bandBody(double bottomInset, double pad) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 240,
          child: Container(
            decoration: BoxDecoration(
              color: logbookAccent.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
          ),
        ),
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 158, 20, pad + bottomInset),
          children: _entryChildren(),
        ),
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: PocketHeaderBand(
            total: _savedTotal,
            onAdd: _headerOnAdd,
            action: _headerAction,
          ),
        ),
      ],
    );
  }

  Widget _arrangeBody(double bottomInset) {
    return Stack(
      children: [
        ReorderableListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, 140 + bottomInset),
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
    return PocketHeader(
      onAdd: _arranging || _transferFrom != null ? null : _openEditor,
      action:
          _transferFrom != null
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
    return Padding(
      key: ValueKey(entry.key),
      padding: const EdgeInsets.only(bottom: 12),
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
    setState(() => _transferFrom = pocket);
    _mode.transfer(true);
    _riseBar();
  }

  void _exitTransfer() {
    setState(() => _transferFrom = null);
    _mode.reset();
    _barRise.value = 0;
  }

  // Back button in any mode: leave the mode, never leave the nav hidden
  void _exitModes() {
    if (_mode.arranges) _setArranging(false);
    _transferFrom = null;
    _mode.reset();
    _barRise.value = 0;
    setState(() {});
  }

  Future<void> _expandPocket(ChildPocket pocket, Rect sourceRect) async {
    final profile = _profile;
    PocketExpandAction? action;

    _mode.expand(true);
    try {
      action = await showPocketExpand(
        context,
        pocket: pocket,
        sourceRect: sourceRect,
        balance: profile?.userBalance ?? 0,
        available: _availableFor(excludePocketId: pocket.pocketId),
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

  Widget _transferBody(double bottomInset) {
    return Stack(
      children: [
        _plainBody(bottomInset, pad: 150),
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
              'Tap a pocket to move money into',
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

    final bool? done = await showTransferAmount(
      context,
      from: from,
      to: to,
      available: from.allocatedBalance,
    );
    if (!mounted) return;
    if (done == true) _exitTransfer();
  }

  Widget _entryCard(_SavingsEntry entry) {
    final pocket = entry.pocket;
    if (pocket != null) {
      final from = _transferFrom;
      if (from != null) {
        final bool source = from.pocketId == pocket.pocketId;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: source ? 0.35 : 1,
          child: PocketRow(
            pocket: pocket,
            onOpen: source ? null : (rect) => _pickTransferTo(pocket),
            onAdd: () {},
            onTransfer: null,
            onEdit: () {},
          ),
        );
      }
      return PocketRow(
        pocket: pocket,
        onOpen: (rect) => _expandPocket(pocket, rect),
        onAdd: () => _addMoney(pocket),
        onTransfer: () => _enterTransfer(pocket),
        onEdit: () => _editPocket(pocket),
      );
    }
    final goal = entry.goal!;
    final Widget card = GoalCard(
      goal: goal,
      onAdd: () => _editGoal(goal),
      onTransfer: null,
      onEdit: () => _editGoal(goal),
    );
    if (_transferFrom != null) {
      return Opacity(opacity: 0.35, child: AbsorbPointer(child: card));
    }
    return card;
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

class PocketEditorSheet extends StatefulWidget {
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
  State<PocketEditorSheet> createState() => _PocketEditorSheetState();
}

class _PocketEditorSheetState extends State<PocketEditorSheet> {
  final ChildPocketRepository _repository = ChildPocketRepository();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _image;
  late final TextEditingController _allocated;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _noteFocus = FocusNode();
  final FocusNode _iconFocus = FocusNode();

  bool _saving = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.pocket != null;

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

    _nameFocus.addListener(_onFocus);
    _noteFocus.addListener(_onFocus);
    _iconFocus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    _allocated.dispose();
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
      setState(() => _error = 'Give your pocket a name first.');
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
        _error = 'Could not save your pocket. Please try again.';
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
      title: _isEditing ? 'Edit pocket' : 'New pocket',
      subtitle:
          _isEditing
              ? 'Adjust the name, amount, or details.'
              : 'What are you putting money aside for?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('IDENTITY'),
          _SheetRow(
            leading: FinancePocketAvatar(
              image: _image.text.trim(),
              name: _name.text,
              size: 42,
              background: false,
            ),
            label: 'Name',
            controller: _name,
            focusNode: _nameFocus,
            hint: 'e.g. Snacks',
            onChanged: (_) {
              _clearError();
              setState(() {});
            },
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
          _SheetRow(
            icon: Icons.emoji_emotions_outlined,
            label: 'Icon',
            controller: _image,
            focusNode: _iconFocus,
            hint: 'Emoji or image link',
            onChanged: (_) {
              _clearError();
              setState(() {});
            },
          ),
          _rule(active: _iconFocus.hasFocus),
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
          FinancePrimaryButton(
            label: _isEditing ? 'Save changes' : 'Create pocket',
            onTap: _deleting ? null : _save,
            loading: _saving,
          ),
          if (_isEditing) ...[
            const SizedBox(height: 2),
            FinanceDangerButton(
              label: _deleting ? 'Deleting…' : 'Delete pocket',
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
