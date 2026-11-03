import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logbook/entry_form_sheet.dart';
import '../logbook/logbook_models.dart';
import '../logbook/logbook_provider.dart';
import '../logbook/logbook_sheet.dart';
import '../logbook/logbook_tokens.dart';
import '../logbook/pocket_style.dart';
import 'listen_sheet.dart';

// Uncomment together with the fetch bodies when the backend is ready.
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../../../core/config/api_config.dart';

// ======================================================================
// Data models
// ======================================================================

/// GET /home/profile
class UserProfileData {
  const UserProfileData({
    this.profilePicture,
    required this.name,
    required this.level,
    required this.userLevel,
    required this.levelCap,
    required this.userCurrency,
    required this.userShine,
    required this.userBalance,
    required this.userStreak,
  });

  /// Profile picture URL. `null` renders the default person icon.
  final String? profilePicture;

  final String name;

  /// XP collected inside the current level, e.g. `5` -> "5/10 XP".
  final int level;

  /// Current level number, e.g. `26`.
  final int userLevel;

  /// Highest reachable level, e.g. `100`.
  final int levelCap;

  /// Premium currency (coins), shown in the top-right pill.
  final int userCurrency;

  /// Shop currency (Shine), spent in the parent shop.
  final int userShine;

  /// Money balance in Rupiah, shown in the sheet.
  final int userBalance;

  /// Consecutive days streak.
  final int userStreak;

  /// XP needed per level (used by the small progress bar).
  static const int xpToNextLevel = 10;

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      profilePicture: json['profilePicture'] as String?,
      name: json['name'] as String? ?? '',
      level: (json['level'] as num?)?.toInt() ?? 0,
      userLevel: (json['userLevel'] as num?)?.toInt() ?? 1,
      levelCap: (json['levelCap'] as num?)?.toInt() ?? 100,
      userCurrency: (json['userCurrency'] as num?)?.toInt() ?? 0,
      userShine: (json['userShine'] as num?)?.toInt() ?? 0,
      userBalance: (json['userBalance'] as num?)?.toInt() ?? 0,
      userStreak: (json['userStreak'] as num?)?.toInt() ?? 0,
    );
  }

  // Local overlays (logbook rewards / pockets) keep the dummy profile intact.
  UserProfileData copyWith({
    int? userCurrency,
    int? userBalance,
    int? userStreak,
  }) {
    return UserProfileData(
      profilePicture: profilePicture,
      name: name,
      level: level,
      userLevel: userLevel,
      levelCap: levelCap,
      userCurrency: userCurrency ?? this.userCurrency,
      userShine: userShine,
      userBalance: userBalance ?? this.userBalance,
      userStreak: userStreak ?? this.userStreak,
    );
  }
}

/// GET /home/event
class EventData {
  const EventData({required this.eventName, required this.endsIn});

  final String eventName;
  final String endsIn;

  factory EventData.fromJson(Map<String, dynamic> json) {
    return EventData(
      eventName: json['eventName'] as String? ?? 'No event',
      endsIn: json['endsIn'] as String? ?? '-',
    );
  }
}

/// GET /home/missions
class DailyMission {
  const DailyMission({
    required this.title,
    required this.completed,
    this.icon = Icons.edit_outlined,
  });

  final String title;
  final bool completed;
  final IconData icon;

  factory DailyMission.fromJson(Map<String, dynamic> json) {
    return DailyMission(
      title: json['title'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      icon: Icons.edit_outlined,
    );
  }
}

/// GET /home/goals
class UserGoal {
  const UserGoal({
    required this.name,
    required this.target,
    required this.saved,
    this.emoji = '\u{1F3AF}',
  });

  final String name;
  final int target;
  final int saved;
  final String emoji;

  double get progress =>
      target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0).toDouble();

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      name: json['name'] as String? ?? '',
      target: (json['target'] as num?)?.toInt() ?? 0,
      saved: (json['saved'] as num?)?.toInt() ?? 0,
      emoji: json['emoji'] as String? ?? 'Ã°Å¸Å½Â¯',
    );
  }
}

// ======================================================================
// Home page
// ======================================================================

class HomePageFin extends ConsumerStatefulWidget {
  const HomePageFin({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePageFin> createState() => _HomePageFinState();
}

class _HomePageFinState extends ConsumerState<HomePageFin>
    with TickerProviderStateMixin {
  UserProfileData? _profile;
  EventData? _event;
  List<DailyMission> _missions = const [];
  List<UserGoal> _goals = const [];

  // Quick-actions popover: open state + entrance/exit animation.
  late final AnimationController _quickController;
  bool _quickActionsOpen = false;
  int _selectedNavIndex = 0;

  // Coin HUD target for the reward burst
  final GlobalKey _coinAnchor = GlobalKey();
  final GlobalKey _berryAnchor = GlobalKey();

  // Card lift on a new entry
  late final AnimationController _liftController;
  late final Animation<double> _lift;
  int _lastEntryCount = 0;

  // White card: pull-up state.
  double? _sheetHeight;
  Duration _sheetSettleDuration = const Duration(milliseconds: 560);
  double _rawDragHeight = 0;
  double _sheetContentHeight = 0;
  bool _sheetDragging = false;
  final ScrollController _sheetScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _quickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _liftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _lift = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -7.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -7.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
    ]).animate(_liftController);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncSheetContentHeight(),
    );
    _loadHome();
  }

  @override
  void reassemble() {
    super.reassemble();
    _loadHome();
  }

  @override
  void dispose() {
    _quickController.dispose();
    _liftController.dispose();
    _sheetScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHome() async {
    final results = await Future.wait<Object>([
      _fetchProfile(),
      _fetchEvent(),
      _fetchMissions(),
      _fetchGoals(),
    ]);

    if (!mounted) return;

    setState(() {
      _profile = results[0] as UserProfileData;
      _event = results[1] as EventData;
      _missions = results[2] as List<DailyMission>;
      _goals = results[3] as List<UserGoal>;
    });
  }

  // ------------------------------------------------------------------
  // Endpoints Ã¢â‚¬â€ the HTTP calls are commented out until the backend is
  // live. The dummy block right below each one mirrors the payload the
  // endpoint is expected to return, so only the comments need swapping.
  // ------------------------------------------------------------------

  Future<UserProfileData> _fetchProfile() async {
    // final response = await http.get(
    //   Uri.parse('${ApiConfig.backendUrl}/api/home/profile'),
    //   headers: {'Authorization': 'Bearer <token>'},
    // );
    //
    // if (response.statusCode == 200) {
    //   return UserProfileData.fromJson(
    //     jsonDecode(response.body) as Map<String, dynamic>,
    //   );
    // }
    //
    // throw Exception('Failed to load profile (${response.statusCode})');

    // Dummy data after urlComment.
    return const UserProfileData(
      profilePicture: null,
      name: 'Nama',
      level: 5, // 5/10 XP
      userLevel: 26,
      levelCap: 100,
      userCurrency: 26, // coins
      userShine: 120, // shine
      userBalance: 250000, // Rp 250.000
      userStreak: 5, // 5 days
    );
  }

  Future<EventData> _fetchEvent() async {
    // final response = await http.get(
    //   Uri.parse('${ApiConfig.backendUrl}/api/home/event'),
    // );
    //
    // if (response.statusCode == 200) {
    //   return EventData.fromJson(
    //     jsonDecode(response.body) as Map<String, dynamic>,
    //   );
    // }
    //
    // throw Exception('Failed to load event (${response.statusCode})');

    // Dummy data after urlComment.
    return const EventData(eventName: 'Spring Festival', endsIn: '2d 14h');
  }

  Future<List<DailyMission>> _fetchMissions() async {
    // final response = await http.get(
    //   Uri.parse('${ApiConfig.backendUrl}/api/home/missions'),
    // );
    //
    // if (response.statusCode == 200) {
    //   final body = jsonDecode(response.body) as Map<String, dynamic>;
    //   final list = body['missions'] as List<dynamic>? ?? [];
    //   return list
    //       .map((e) => DailyMission.fromJson(e as Map<String, dynamic>))
    //       .toList();
    // }
    //
    // throw Exception('Failed to load missions (${response.statusCode})');

    // Dummy data after urlComment.
    return const [
      DailyMission(
        title: 'Logging',
        completed: true,
        icon: Icons.edit_outlined,
      ),
      DailyMission(
        title: 'View History',
        completed: false,
        icon: Icons.history,
      ),
    ];
  }

  Future<List<UserGoal>> _fetchGoals() async {
    // final response = await http.get(
    //   Uri.parse('${ApiConfig.backendUrl}/api/home/goals'),
    // );
    //
    // if (response.statusCode == 200) {
    //   final body = jsonDecode(response.body) as Map<String, dynamic>;
    //   final list = body['goals'] as List<dynamic>? ?? [];
    //   return list
    //       .map((e) => UserGoal.fromJson(e as Map<String, dynamic>))
    //       .toList();
    // }
    //
    // throw Exception('Failed to load goals (${response.statusCode})');

    // Dummy data after urlComment.
    return const [
      UserGoal(
        name: 'New Bicycle',
        target: 1000000, // Rp 1.000.000
        saved: 300000, // Rp 300.000 -> 30%
        emoji: '\u{1F6B2}',
      ),
      UserGoal(
        name: 'New Headphones',
        target: 1000000, // Rp 1.000.000
        saved: 500000, // Rp 500.000 -> 50%
        emoji: '\u{1F3A7}',
      ),
    ];
  }

  // ------------------------------------------------------------------
  // Navigation
  // ------------------------------------------------------------------
  /// Every tap goes to '/' for now.
  ///
  /// TODO: swap for the real destinations once the pages exist:
  ///   profile  -> context.go('/profile')
  ///   wardrobe -> context.go('/wardrobe')
  ///   events   -> context.go('/events')
  ///   goals    -> context.go('/goals-and-tasks')
  void _goPlaceholder(BuildContext context) => context.go('/kids/home');

  void _toggleQuickActions({required bool reduceMotion}) {
    setState(() => _quickActionsOpen = !_quickActionsOpen);
    if (reduceMotion) {
      _quickController.value = _quickActionsOpen ? 1 : 0;
    } else if (_quickActionsOpen) {
      _quickController.forward(from: 0);
    } else {
      _quickController.reverse();
    }
  }

  void _closeQuickActions() {
    if (!_quickActionsOpen) return;
    setState(() => _quickActionsOpen = false);
    _quickController.reverse();
  }

  // Measures the sheet's natural content height so the max stop fits it.
  void _syncSheetContentHeight() {
    if (!mounted || !_sheetScrollController.hasClients) return;
    final position = _sheetScrollController.position;
    if (position.maxScrollExtent <= 0.5) return;
    final contentHeight = position.maxScrollExtent + position.viewportDimension;
    if ((contentHeight - _sheetContentHeight).abs() > 0.5) {
      setState(() => _sheetContentHeight = contentHeight);
    }
  }

  void _startSheetDrag(double minHeight) {
    _rawDragHeight = _sheetHeight ?? minHeight;
    setState(() {
      _sheetDragging = true;
      _sheetHeight ??= minHeight;
    });
  }

  void _updateSheetDrag(
    DragUpdateDetails details,
    double minHeight,
    double maxHeight,
  ) {
    _rawDragHeight -= details.delta.dy;

    final double displayHeight;
    if (_rawDragHeight < minHeight) {
      // Pull down: allow pulling until halfway down with smooth rubber-band resistance
      final under = minHeight - _rawDragHeight;
      final maxPullDown = minHeight * 0.6;
      final displacement =
          maxPullDown * (1 - math.exp(-under / (maxPullDown * 1.1)));
      displayHeight = minHeight - displacement;
    } else if (_rawDragHeight > maxHeight) {
      // Pull up: overshoot past maxHeight by a bit more
      final over = _rawDragHeight - maxHeight;
      const maxPullUp = 110.0;
      final displacement =
          maxPullUp * (1 - math.exp(-over / (maxPullUp * 1.1)));
      displayHeight = maxHeight + displacement;
    } else {
      displayHeight = _rawDragHeight;
    }

    setState(() => _sheetHeight = displayHeight);
  }

  void _endSheetDrag(
    DragEndDetails details,
    double minHeight,
    double maxHeight,
  ) {
    final current = _sheetHeight ?? minHeight;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final velocity = reduceMotion ? 0.0 : details.velocity.pixelsPerSecond.dy;
    // Momentum: a fast flick keeps travelling before it settles.
    final projected =
        (current - velocity * 0.12).clamp(minHeight, maxHeight).toDouble();
    final double? target;
    if (current < minHeight || projected <= minHeight) {
      target = minHeight;
    } else if (current > maxHeight || projected >= maxHeight) {
      target = maxHeight;
    } else {
      target = projected;
    }
    _sheetSettleDuration = Duration(
      milliseconds: (560 - velocity.abs() / 12).clamp(200, 560).round(),
    );
    setState(() {
      _sheetDragging = false;
      if (target != null) _sheetHeight = target;
    });
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final logbook = ref.watch(logbookProvider);
    final recentEntries = _recentEntries(logbook);

    // Card lift on a new entry
    final entryCount = logbook.today.entries.length;
    if (entryCount != _lastEntryCount) {
      final added = entryCount > _lastEntryCount && _lastEntryCount > 0;
      _lastEntryCount = entryCount;
      if (added) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final reduceMotion =
              MediaQuery.maybeOf(context)?.disableAnimations ?? false;
          if (reduceMotion) return;
          _liftController.forward(from: 0);
        });
      }
    }

    final claimedToday = logbook.today.rewardClaimed;
    final pendingClaimKey = logbook.pendingClaimKey;
    final effectiveProfile = profile?.copyWith(
      userBalance: logbook.pockets.total,
      userCurrency: (profile?.userCurrency ?? 0) + logbook.coinsEarned,
      userStreak: logbook.streak,
    );
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topInset = MediaQuery.paddingOf(context).top;

    // Navbar footprint: pill height + its bottom inset.
    final navBarHeight = 62.0 + (safeBottom > 16 ? safeBottom : 16.0);

    // Sheet travel: collapsed stop up to the height its content needs.
    final minSheetHeight = screenHeight * 0.42;
    final fallbackMax = screenHeight - topInset - 8;
    final maxSheetHeight = math.max(
      minSheetHeight,
      _sheetContentHeight > 0 ? _sheetContentHeight : fallbackMax,
    );
    final sheetHeight =
        _sheetDragging
            ? (_sheetHeight ?? minSheetHeight)
            : (_sheetHeight ?? minSheetHeight)
                .clamp(minSheetHeight, maxSheetHeight)
                .toDouble();

    // Lift past the resting stop fades the reward row out.
    final double rowFade = ((sheetHeight - minSheetHeight) / 90).clamp(
      0.0,
      1.0,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncSheetContentHeight(),
    );

    final popoverWidth = (MediaQuery.sizeOf(context).width * 0.62).clamp(
      220.0,
      300.0,
    );
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle.merge(
          style: const TextStyle(decoration: TextDecoration.none),
          child: Stack(
            children: [
              // (0) Background placeholder (forest), shifted up so the ground sits
              // higher and clear of the white card.
              Positioned.fill(child: _SceneBackground()),

              // (1) BitePal-style header: name + heart pips, coin/streak chips.
              Positioned(
                left: 20,
                right: 20,
                top: 0,
                child: SafeArea(
                  bottom: false,
                  minimum: const EdgeInsets.only(top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fulgens',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 27,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0x59000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            _HeartPips(
                              filled:
                                  ((profile?.level ?? 0) /
                                          UserProfileData.xpToNextLevel *
                                          5)
                                      .round()
                                      .clamp(0, 5)
                                      .toInt(),
                            ),
                          ],
                        ),
                      ),
                      // HUD currency
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HudTag(
                              token: const _ShineGem(size: 18),
                              value: _group(effectiveProfile?.userShine ?? 0),
                            ),
                            const SizedBox(width: 14),
                            KeyedSubtree(
                              key: _berryAnchor,
                              child: _HudTag(
                                token: const BerryToken(size: 18),
                                value: _group(logbook.berries),
                              ),
                            ),
                            const SizedBox(width: 14),
                            KeyedSubtree(
                              key: _coinAnchor,
                              child: _HudTag(
                                token: const _CoinToken(size: 18),
                                value: _group(
                                  effectiveProfile?.userCurrency ?? 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // (3b) Wardrobe / shop / events stack, sits under the white card.
              Positioned(
                right: 16,
                top: 150 + MediaQuery.paddingOf(context).top,
                child: const _RightControlStack(),
              ),

              // (4) White card: elastic pull-up sheet sized to its content.
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => _startSheetDrag(minSheetHeight),
                  onVerticalDragUpdate:
                      (details) => _updateSheetDrag(
                        details,
                        minSheetHeight,
                        maxSheetHeight,
                      ),
                  onVerticalDragEnd:
                      (details) => _endSheetDrag(
                        details,
                        minSheetHeight,
                        maxSheetHeight,
                      ),
                  child: AnimatedBuilder(
                    animation: _lift,
                    builder:
                        (context, child) => Transform.translate(
                          offset: Offset(0, _lift.value),
                          child: child,
                        ),
                    child: AnimatedContainer(
                      duration:
                          reduceMotion || _sheetDragging
                              ? Duration.zero
                              : _sheetSettleDuration,
                      curve: const _SheetSettleCurve(),
                      height: sheetHeight,
                      child: _HomeSheet(
                        profile: effectiveProfile,
                        pockets: logbook.pockets,
                        recent: recentEntries,
                        todayEntries: logbook.today.entries,
                        missions: _missions,
                        goals: _goals,
                        footerSpace: navBarHeight,
                        scrollController: _sheetScrollController,
                      ),
                    ),
                  ),
                ),
              ),

              // (4b) Reward ends resting on the card's top edge, panda between.
              AnimatedPositioned(
                duration:
                    reduceMotion || _sheetDragging
                        ? Duration.zero
                        : _sheetSettleDuration,
                curve: const _SheetSettleCurve(),
                left: 8,
                right: 8,
                bottom: 8 + sheetHeight,
                child: AnimatedBuilder(
                  animation: _lift,
                  builder:
                      (context, child) => Transform.translate(
                        offset: Offset(0, _lift.value),
                        child: child,
                      ),
                  child: IgnorePointer(
                    ignoring: rowFade > 0.2,
                    child: AnimatedOpacity(
                      duration:
                          reduceMotion || _sheetDragging
                              ? Duration.zero
                              : _sheetSettleDuration,
                      curve: Curves.easeOutCubic,
                      opacity: (1 - rowFade).clamp(0.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 22, right: 22),
                        child: _RewardFloat(
                          claimedToday: claimedToday,
                          claimable: pendingClaimKey != null,
                          coinAnchor: _coinAnchor,
                          berryAnchor: _berryAnchor,
                          onClaim: (coins, berries) {
                            if (pendingClaimKey == null) return;
                            ref
                                .read(logbookProvider.notifier)
                                .claimReward(
                                  pendingClaimKey,
                                  coins: coins,
                                  berries: berries,
                                );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // (5) Focus scrim: darkens background + white card; nav bar (painted
              // above this layer) stays bright.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_quickActionsOpen,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeQuickActions,
                    child: AnimatedBuilder(
                      animation: _quickController,
                      builder: (context, _) {
                        final t = _quickController.value.clamp(0.0, 1.0);
                        if (t == 0) return const SizedBox.expand();
                        return ClipRect(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: 4.5 * t,
                              sigmaY: 4.5 * t,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        );
                      },
                    ),
                    // Darkening scrim, parked while the blur is on trial.
                    // color: Colors.black.withValues(
                    //   alpha: 0.18 * _quickController.value,
                    // ),
                  ),
                ),
              ),

              // (6) Floating navigation, drawn above the scrim so it stays bright.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: _BottomNav(
                      selectedIndex: _selectedNavIndex,
                      onSelectTab:
                          (index) => setState(() => _selectedNavIndex = index),
                      quickActionsOpen: _quickActionsOpen,
                      onQuickAction:
                          () => _toggleQuickActions(reduceMotion: reduceMotion),
                    ),
                  ),
                ),
              ),

              // (5b) Quick-actions popover, anchored just above the + button (topmost).
              Positioned(
                right: 16,
                bottom: (safeBottom > 10 ? safeBottom : 10) + 86,
                width: popoverWidth,
                child: IgnorePointer(
                  ignoring: !_quickActionsOpen,
                  child: _QuickActionsPanel(
                    animation: _quickController,
                    entriesToday: logbook.todayEntryCount,
                    onLogbook: () {
                      _closeQuickActions();
                      showLogbookSheet(context);
                    },
                    onNewEntry: () {
                      _closeQuickActions();
                      showEntryFormSheet(
                        context,
                        dateKey: LogbookState.todayKey,
                      );
                    },
                    onSpeak: () {
                      _closeQuickActions();
                      showListenSheet(context);
                    },
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

// ======================================================================
// Scene widgets
// ======================================================================

/// Forest background art.
class _SceneBackground extends StatelessWidget {
  const _SceneBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.35),
              radius: 0.95,
              colors: [Color(0xFF4C6E55), Color(0xFF2C4234), Color(0xFF17251D)],
            ),
          ),
          child: Image(
            image: AssetImage('assets/game/backgrounds/background_new.png'),
            fit: BoxFit.cover,
            alignment: Alignment(0, -0.8),
          ),
        ),
        // Top scrim: keeps header and right-side buttons legible over the art.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.38),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.18, 0.42],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.0, 0.05),
          child: Image.asset(
            'assets/game/mascotIllustrations/fulgensMascotSitting.webp',
            width: 140,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

/// Segmented sheet: separate white blocks with the scene showing between them.
class _HomeSheet extends StatelessWidget {
  const _HomeSheet({
    required this.profile,
    required this.pockets,
    required this.recent,
    required this.todayEntries,
    required this.missions,
    required this.goals,
    required this.footerSpace,
    required this.scrollController,
  });

  final UserProfileData? profile;
  final PocketWallet pockets;
  final List<LogbookEntry> recent;
  final List<LogbookEntry> todayEntries;
  final List<DailyMission> missions;
  final List<UserGoal> goals;
  final double footerSpace;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: scrollController,
          physics: const NeverScrollableScrollPhysics(),
          child: IntrinsicHeight(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetBlock(
                  label: 'Balance',
                  labelGap: 12,
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
                  child: _BalanceStreakBlock(
                    profile: profile,
                    pockets: pockets,
                    recent: recent,
                    todayEntries: todayEntries,
                  ),
                ),
                const SizedBox(height: 4),
                _SheetBlock(
                  label: 'Streak',
                  child: _StreakWeekBlock(streak: profile?.userStreak ?? 0),
                ),
                const SizedBox(height: 4),
                _SheetBlock(
                  label: 'Daily missions',
                  child: _MissionsBlock(missions: missions),
                ),
                const SizedBox(height: 4),
                _SheetBlock(
                  label: 'Goals',
                  bottomPadding: footerSpace,
                  child: _GoalsBlock(goals: goals),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Gentle overshoot so the sheet settles with an elastic bounce.
class _SheetSettleCurve extends Curve {
  const _SheetSettleCurve();

  @override
  double transformInternal(double t) {
    const double c1 = 1.6;
    const double c3 = c1 + 1;
    final double p = t - 1;
    return 1 + c3 * p * p * p + c1 * p * p;
  }
}

/// Soft organic accent used as a background motif.
class _SoftBlob extends StatelessWidget {
  const _SoftBlob({
    required this.size,
    this.opacity = 0.12,
    this.color = const Color(0xFFFFD9A8),
    this.flipped = false,
  });

  final double size;
  final double opacity;
  final Color color;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    final double big = size * 0.46;
    final double small = size * 0.12;
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(flipped ? small : big),
              topRight: Radius.circular(flipped ? big : small),
              bottomLeft: Radius.circular(flipped ? big : small),
              bottomRight: Radius.circular(flipped ? small : big),
            ),
            gradient: RadialGradient(
              center: Alignment(flipped ? 0.3 : -0.3, -0.35),
              radius: 0.95,
              colors: [color.withOpacity(opacity), color.withOpacity(0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// One white block of the segmented sheet.
class _SheetBlock extends StatelessWidget {
  const _SheetBlock({
    this.label,
    required this.child,
    this.bottomPadding = 22,
    this.color = Colors.white,
    this.labelColor = const Color(0xFF8A8A8F),
    this.labelGap = 8,
    this.gradient,
    this.padding,
  });

  final String? label;
  final Widget child;
  final double bottomPadding;
  final Color color;
  final Color labelColor;
  final double labelGap;
  final Gradient? gradient;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.fromLTRB(22, 20, 22, bottomPadding),
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: const BorderRadius.all(Radius.circular(34)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null && label!.isNotEmpty) ...[
            Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            SizedBox(height: labelGap),
          ],
          child,
        ],
      ),
    );
  }
}

/// Primogem-style Shine gem: four-point star with a faceted core.
class _ShineGem extends StatelessWidget {
  const _ShineGem({this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _ShineGemPainter(),
    );
  }
}

class _ShineGemPainter extends CustomPainter {
  const _ShineGemPainter();

  Path _stone(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.52, h * 0.05)
      ..cubicTo(w * 0.76, h * 0.03, w * 0.95, h * 0.22, w * 0.93, h * 0.46)
      ..cubicTo(w * 0.91, h * 0.70, w * 0.75, h * 0.92, w * 0.54, h * 0.94)
      ..cubicTo(w * 0.33, h * 0.96, w * 0.08, h * 0.78, w * 0.07, h * 0.52)
      ..cubicTo(w * 0.06, h * 0.28, w * 0.28, h * 0.07, w * 0.52, h * 0.05)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final star = _stone(size);
    canvas.drawPath(
      star,
      Paint()
        ..isAntiAlias = true
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD6F6FF), Color(0xFF6FC8F5), Color(0xFF4A5FE0)],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.5);
    canvas.scale(0.48);
    canvas.translate(-size.width * 0.5, -size.height * 0.5);
    canvas.drawPath(star, Paint()..color = const Color(0x88FFFFFF));
    canvas.restore();
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.07,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_ShineGemPainter oldDelegate) => false;
}

/// Gold coin token: raised rim, gradient face, embossed star.
class _CoinToken extends StatelessWidget {
  const _CoinToken({this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: const _CoinPainter());
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);
    final radius = s / 2;

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFEFC257));

    canvas.drawCircle(
      center,
      radius * 0.86,
      Paint()..color = const Color(0xFFFBE7B0),
    );

    canvas.drawCircle(
      center,
      radius * 0.74,
      Paint()..color = const Color(0xFFF3C75B),
    );

    final slot = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: s * 0.18, height: s * 0.42),
      Radius.circular(s * 0.09),
    );
    canvas.drawRRect(slot, Paint()..color = const Color(0xFFFBF0CE));
  }

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) => false;
}

class _HudTag extends StatelessWidget {
  const _HudTag({required this.token, required this.value});

  final Widget token;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        token,
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Color(0x73000000),
                blurRadius: 10,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceStreakBlock extends StatefulWidget {
  const _BalanceStreakBlock({
    required this.profile,
    required this.pockets,
    required this.recent,
    required this.todayEntries,
  });

  final UserProfileData? profile;
  final PocketWallet pockets;
  final List<LogbookEntry> recent;
  final List<LogbookEntry> todayEntries;

  @override
  State<_BalanceStreakBlock> createState() => _BalanceStreakBlockState();
}

class _BalanceStreakBlockState extends State<_BalanceStreakBlock>
    with SingleTickerProviderStateMixin {
  bool _obscureBalance = false;
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  List<_ConfettiBit> _bits = const [];
  int _lastBalance = 0;

  @override
  void initState() {
    super.initState();
    _lastBalance = widget.profile?.userBalance ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pop());
  }

  @override
  void didUpdateWidget(covariant _BalanceStreakBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.profile?.userBalance ?? 0;
    if (next > _lastBalance) _pop();
    _lastBalance = next;
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  // Confetti burst over the balance amount
  void _pop() {
    if (!mounted) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    setState(() => _bits = _makeConfetti());
    _confetti.forward(from: 0);
  }

  List<_ConfettiBit> _makeConfetti() {
    final rnd = math.Random();
    const colors = <Color>[
      Color(0xFF3E9A64),
      Color(0xFF4553A8),
      Color(0xFF9A7420),
      Color(0xFFD2594C),
      Color(0xFFE0A63A),
    ];
    return List<_ConfettiBit>.generate(20, (i) {
      return _ConfettiBit(
        origin: Offset(
          0.15 + rnd.nextDouble() * 0.7,
          0.4 + rnd.nextDouble() * 0.25,
        ),
        drift: (rnd.nextDouble() * 2 - 1) * 0.55,
        lift: -1.1 - rnd.nextDouble() * 1.3,
        width: 3 + rnd.nextDouble() * 4,
        height: 2.5 + rnd.nextDouble() * 3.5,
        rotation: rnd.nextDouble() * math.pi,
        spin: (rnd.nextDouble() * 2 - 1) * 7,
        color: colors[i % colors.length],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.profile?.userBalance ?? 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Text(
                                    _obscureBalance
                                        ? 'Rp \u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022'
                                        : _rupiah(balance),
                                    style: const TextStyle(
                                      fontSize: 34,
                                      height: 1.15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.6,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedBuilder(
                                        animation: _confetti,
                                        builder:
                                            (context, _) => CustomPaint(
                                              painter: _ConfettiPainter(
                                                t: _confetti.value,
                                                bits: _bits,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap:
                                () => setState(
                                  () => _obscureBalance = !_obscureBalance,
                                ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                _obscureBalance
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: const Color(0xFFA0A0A6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _PocketStats(pockets: widget.pockets, obscure: _obscureBalance),
                _TodayHistory(entries: widget.recent),
                _TodayNet(entries: widget.todayEntries),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Reward panda visibility
const bool _showRewardPanda = false;

// Reward row text over the scene.
const TextStyle _rewardInk = TextStyle(
  fontSize: 16,
  height: 1.1,
  fontWeight: FontWeight.w800,
  color: Colors.white,
  fontFeatures: [ui.FontFeature.tabularFigures()],
  shadows: [
    Shadow(color: Color(0x99000000), blurRadius: 8),
    Shadow(color: Color(0x77000000), offset: Offset(0, 1), blurRadius: 2),
  ],
);

// Reward row pinned to the top of the balance card.
class _RewardFloat extends ConsumerStatefulWidget {
  const _RewardFloat({
    required this.claimedToday,
    required this.claimable,
    required this.coinAnchor,
    required this.berryAnchor,
    required this.onClaim,
  });

  final bool claimedToday;
  final bool claimable;
  final GlobalKey coinAnchor;
  final GlobalKey berryAnchor;
  final void Function(int coins, int berries) onClaim;

  @override
  ConsumerState<_RewardFloat> createState() => _RewardFloatState();
}

class _RewardFloatState extends ConsumerState<_RewardFloat> {
  // Idle gold
  Timer? _goldTicker;
  int _idleGold = 1;

  // Idle berries
  Timer? _berryTicker;
  int _idleBerries = 0;

  // Claim cooldown
  Timer? _cooldown;
  bool _cooling = false;

  @override
  void initState() {
    super.initState();
    _goldTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _idleGold += 1);
    });
    _berryTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() => _idleBerries += 1);
    });
  }

  @override
  void dispose() {
    _goldTicker?.cancel();
    _berryTicker?.cancel();
    _cooldown?.cancel();
    super.dispose();
  }

  void _claim() {
    if (_cooling) return;
    if (!widget.claimable) {
      showLogbookSheet(context);
      return;
    }

    widget.onClaim(_idleGold, _idleBerries);
    _burst();
    setState(() {
      _idleGold = 1;
      _idleBerries = 0;
      _cooling = true;
    });
    _cooldown?.cancel();
    _cooldown = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _cooling = false);
    });
  }

  // Coins and berries fly to the HUD counters
  void _burst() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return;

    final overlay = Overlay.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null) return;

    final from = box.localToGlobal(Offset(box.size.width - 26, 16));
    final top = MediaQuery.paddingOf(context).top + 56;
    final width = MediaQuery.sizeOf(context).width;

    void fly(GlobalKey key, Offset fallback, Widget Function(double) token) {
      final anchor = key.currentContext?.findRenderObject() as RenderBox?;
      final to =
          anchor != null
              ? anchor.localToGlobal(anchor.size.center(Offset.zero))
              : fallback;

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder:
            (_) => _CoinBurst(
              from: from,
              to: to,
              token: token,
              onDone: () {
                if (entry.mounted) entry.remove();
              },
            ),
      );
      overlay.insert(entry);
    }

    fly(
      widget.coinAnchor,
      Offset(width - 44, top),
      (size) => _CoinToken(size: size),
    );
    if (_idleBerries > 0) {
      fly(
        widget.berryAnchor,
        Offset(width - 120, top),
        (size) => BerryToken(size: size),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final claimed = widget.claimedToday && !widget.claimable;
    final done = _cooling || claimed;

    return Semantics(
      button: true,
      label: 'Logbook reward',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _claim,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              if (_showRewardPanda) ...[
                _RunningPanda(
                  size: 40,
                  color: Colors.white,
                  animate: !reduceMotion,
                ),
                const SizedBox(width: 10),
              ],
              _PopOnChange(
                value: _idleGold,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _CoinToken(size: 24),
                    const SizedBox(width: 7),
                    Text('$_idleGold', style: _rewardInk),
                  ],
                ),
              ),
              if (_idleBerries > 0) ...[
                const SizedBox(width: 14),
                _PopOnChange(
                  value: _idleBerries,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BerryToken(size: 22),
                      const SizedBox(width: 7),
                      Text('$_idleBerries', style: _rewardInk),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              _ClaimPill(
                label: done ? 'Claimed' : widget.claimable ? 'Claim' : 'Unlock',
                enabled: !done,
                showCheck: done,
                shakeWhenDisabled: claimed,
                onTap: _claim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bumps when its value changes.
class _PopOnChange extends StatefulWidget {
  const _PopOnChange({required this.value, required this.child});

  final int value;
  final Widget child;

  @override
  State<_PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<_PopOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.05,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.05,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 70,
    ),
  ]).animate(_pop);

  @override
  void didUpdateWidget(covariant _PopOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

// Claim CTA over the scene.
class _ClaimPill extends StatefulWidget {
  const _ClaimPill({
    required this.label,
    required this.enabled,
    required this.showCheck,
    required this.shakeWhenDisabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool showCheck;
  final bool shakeWhenDisabled;
  final VoidCallback onTap;

  @override
  State<_ClaimPill> createState() => _ClaimPillState();
}

class _ClaimPillState extends State<_ClaimPill>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  // Nudge when already claimed
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  late final Animation<double> _shake = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0), weight: 20),
    TweenSequenceItem(tween: Tween(begin: -3.0, end: 3.0), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 3.0, end: -2.0), weight: 30),
    TweenSequenceItem(tween: Tween(begin: -2.0, end: 0.0), weight: 20),
  ]).animate(_nudge);

  void _setPressed(bool value) => setState(() => _pressed = value);

  void _handleTap() {
    if (widget.enabled) {
      widget.onTap();
      return;
    }
    if (!widget.shakeWhenDisabled) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) _nudge.forward(from: 0);
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Claim logbook reward',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedBuilder(
          animation: _shake,
          builder:
              (context, child) => Transform.translate(
                offset: Offset(_shake.value, 0),
                child: child,
              ),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showCheck) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Color(0xFF3E9A64),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    widget.label,
                    style: _rewardInk.copyWith(
                      fontSize: 13,
                      color:
                          widget.enabled
                              ? const Color(0xFF1F3B2A)
                              : const Color(0xFF8A8A8F),
                      shadows: const [],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Coins flying to the HUD counter.
class _CoinBurst extends StatefulWidget {
  const _CoinBurst({
    required this.from,
    required this.to,
    required this.token,
    required this.onDone,
  });

  final Offset from;
  final Offset to;
  final Widget Function(double size) token;
  final VoidCallback onDone;

  @override
  State<_CoinBurst> createState() => _CoinBurstState();
}

class _BurstCoin {
  const _BurstCoin({
    required this.delay,
    required this.spread,
    required this.lift,
    required this.size,
  });

  final double delay;
  final double spread;
  final double lift;
  final double size;
}

class _CoinBurstState extends State<_CoinBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );

  late final List<_BurstCoin> _coins = List<_BurstCoin>.generate(6, (i) {
    final rnd = math.Random(i + 11);
    return _BurstCoin(
      delay: i * 0.04,
      spread: (rnd.nextDouble() * 2 - 1) * 28,
      lift: 40 + rnd.nextDouble() * 80,
      size: 12 + rnd.nextDouble() * 6,
    );
  });

  @override
  void initState() {
    super.initState();
    _run.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _run.forward();
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  Offset _at(_BurstCoin coin, double t) {
    final p0 = widget.from;
    final p2 = widget.to;
    final p1 = Offset(
      (p0.dx + p2.dx) / 2 + coin.spread,
      math.min(p0.dy, p2.dy) - coin.lift,
    );
    final u = 1 - t;
    return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
  }

  List<Widget> _pieces() {
    final out = <Widget>[];
    for (final coin in _coins) {
      final raw =
          ((_run.value - coin.delay) / (1 - coin.delay)).clamp(0.0, 1.0);
      if (raw <= 0) continue;
      final eased = Curves.easeOutCubic.transform(raw);
      final pos = _at(coin, eased);
      final fade = raw < 0.82 ? 1.0 : 1 - (raw - 0.82) / 0.18;
      out.add(
        Positioned(
          left: pos.dx - coin.size / 2,
          top: pos.dy - coin.size / 2,
          child: Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1 - 0.4 * eased,
              child: widget.token(coin.size),
            ),
          ),
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _run,
          builder: (context, _) => Stack(children: _pieces()),
        ),
      ),
    );
  }
}

// White running panda silhouette.
class _RunningPanda extends StatefulWidget {
  const _RunningPanda({
    this.size = 40,
    this.color = Colors.white,
    this.animate = true,
  });

  final double size;
  final Color color;
  final bool animate;

  @override
  State<_RunningPanda> createState() => _RunningPandaState();
}

class _RunningPandaState extends State<_RunningPanda>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _run.repeat();
  }

  @override
  void didUpdateWidget(covariant _RunningPanda oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _run.repeat();
    } else {
      _run
        ..stop()
        ..value = 0.15;
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _run,
        builder:
            (context, _) => CustomPaint(
              size: Size(widget.size * 1.14, widget.size),
              painter: _RunningPandaPainter(t: _run.value, color: widget.color),
            ),
      ),
    );
  }
}

class _RunningPandaPainter extends CustomPainter {
  const _RunningPandaPainter({required this.t, required this.color});

  final double t;
  final Color color;

  void _leg(
    Canvas canvas,
    Offset hip,
    double length,
    double thick,
    double angle,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(hip.dx, hip.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-thick / 2, 0, thick, length),
        Radius.circular(thick / 2),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final near = Paint()..color = color;
    final far = Paint()..color = color.withValues(alpha: 0.7);

    // Stride
    final stride = math.sin(t * math.pi * 4);
    final bob = -1.4 * (0.5 + 0.5 * math.cos(t * math.pi * 4));

    canvas.save();
    canvas.translate(0, bob);

    // Speed streaks
    final glow = 0.28 + 0.22 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
    final trail = Paint()..color = color.withValues(alpha: glow);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.01, h * 0.46, w * 0.16, h * 0.055),
        Radius.circular(h * 0.03),
      ),
      trail,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * 0.03, h * 0.63, w * 0.19, h * 0.055),
        Radius.circular(h * 0.03),
      ),
      trail,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.04, h * 0.80, w * 0.12, h * 0.05),
        Radius.circular(h * 0.025),
      ),
      trail,
    );

    // Far legs
    _leg(
      canvas,
      Offset(w * 0.44, h * 0.66),
      h * 0.30,
      h * 0.10,
      -stride * 0.45,
      far,
    );
    _leg(
      canvas,
      Offset(w * 0.66, h * 0.66),
      h * 0.30,
      h * 0.10,
      stride * 0.45,
      far,
    );

    // Tail
    canvas.drawCircle(Offset(w * 0.19, h * 0.54), h * 0.12, near);

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.34, w * 0.54, h * 0.40),
        Radius.circular(h * 0.20),
      ),
      near,
    );

    // Head
    canvas.drawCircle(Offset(w * 0.75, h * 0.40), h * 0.21, near);
    // Ears
    canvas.drawCircle(Offset(w * 0.64, h * 0.24), h * 0.085, near);
    canvas.drawCircle(Offset(w * 0.87, h * 0.25), h * 0.085, near);

    // Near legs
    _leg(
      canvas,
      Offset(w * 0.34, h * 0.66),
      h * 0.30,
      h * 0.115,
      stride * 0.5,
      near,
    );
    _leg(
      canvas,
      Offset(w * 0.57, h * 0.66),
      h * 0.30,
      h * 0.115,
      -stride * 0.5,
      near,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RunningPandaPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.color != color;
  }
}

class _ConfettiBit {
  const _ConfettiBit({
    required this.origin,
    required this.drift,
    required this.lift,
    required this.width,
    required this.height,
    required this.rotation,
    required this.spin,
    required this.color,
  });

  final Offset origin;
  final double drift;
  final double lift;
  final double width;
  final double height;
  final double rotation;
  final double spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.bits});

  final double t;
  final List<_ConfettiBit> bits;

  @override
  void paint(Canvas canvas, Size size) {
    if (bits.isEmpty || t <= 0 || t >= 1) return;
    final fade = (1 - t).clamp(0.0, 1.0);
    final paint = Paint();
    for (final bit in bits) {
      final x = size.width * (bit.origin.dx + bit.drift * t);
      final y = size.height * (bit.origin.dy + bit.lift * t + 2.1 * t * t);
      paint.color = bit.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(bit.rotation + bit.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: bit.width,
            height: bit.height,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.bits != bits;
  }
}

class _RecentSummary extends StatelessWidget {
  const _RecentSummary({required this.entries});

  final List<LogbookEntry> entries;

  @override
  Widget build(BuildContext context) {
    final spent = entries
        .where((entry) => entry.isExpense)
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final saved = entries
        .where((entry) => !entry.isExpense)
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final net = saved - spent;

    return _RecentStat(
      label: net >= 0 ? 'You saved' : 'You spent',
      amount: net.abs(),
      color: const Color(0xFF8A8A8F),
      alignEnd: false,
    );
  }
}

class _RecentStat extends StatelessWidget {
  const _RecentStat({
    required this.label,
    required this.amount,
    required this.color,
    required this.alignEnd,
  });

  final String label;
  final int amount;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label ${_rupiah(amount)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: 12.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showLogbookSheet(context),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F1EC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 16,
              color: Color(0xFF9A958C),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Nothing logged today yet',
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6F695F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSplit extends StatelessWidget {
  const _RecentSplit({required this.entries});

  final List<LogbookEntry> entries;

  @override
  Widget build(BuildContext context) {
    return _RecentSummary(entries: entries);
  }
}

List<LogbookEntry> _recentEntries(LogbookState state, {int limit = 6}) {
  final entries = state.today.entries;
  final out = <LogbookEntry>[];
  for (var i = entries.length - 1; i >= 0 && out.length < limit; i--) {
    out.add(entries[i]);
  }
  return out;
}

class _PocketStats extends StatefulWidget {
  const _PocketStats({required this.pockets, required this.obscure});

  final PocketWallet pockets;
  final bool obscure;

  @override
  State<_PocketStats> createState() => _PocketStatsState();
}

class _PocketStatsState extends State<_PocketStats>
    with SingleTickerProviderStateMixin {
  // Pocket rail
  final ScrollController _rail = ScrollController();

  // Settle hint
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  // Settle travel
  late final Animation<double> _slide = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: -14.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 38,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -14.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 62,
    ),
  ]).animate(_settle);

  // Edge fades
  bool _edgeStart = false;
  bool _edgeEnd = true;

  static const double _gap = 14;
  static const double _peek = 30;

  @override
  void initState() {
    super.initState();
    _rail.addListener(_syncEdges);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncEdges();
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (mounted) _settle.forward(from: 0);
      });
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    _rail.dispose();
    super.dispose();
  }

  // Edge sync
  void _syncEdges() {
    if (!_rail.hasClients) return;
    final double max = _rail.position.maxScrollExtent;
    final double at = _rail.position.pixels;
    final bool start = at > 1;
    final bool end = at < max - 1;
    if (start == _edgeStart && end == _edgeEnd) return;
    setState(() {
      _edgeStart = start;
      _edgeEnd = end;
    });
  }

  // Pocket tile
  Widget _tile(PocketSlot slot) {
    return _PressSquish(
      child: _PocketStat(
        icon: pocketIcon(slot),
        tint: pocketColor(slot),
        title: slot.label,
        amount:
            widget.obscure
                ? '\u2022\u2022\u2022\u2022'
                : _shortRupiah(widget.pockets.of(slot)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = PocketSlot.values;

    if (slots.length <= 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < slots.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(child: _tile(slots[i])),
          ],
        ],
      );
    }

    final double width =
        ((MediaQuery.sizeOf(context).width - 60 - 3 * _gap - _peek) / 3)
            .clamp(64.0, 120.0)
            .toDouble();

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: ClipRect(
        child: ShaderMask(
          shaderCallback: (rect) {
            final double f = 18 / rect.width;
            return LinearGradient(
              colors: [
                _edgeStart ? Colors.transparent : Colors.white,
                Colors.white,
                Colors.white,
                _edgeEnd ? Colors.transparent : Colors.white,
              ],
              stops: [0.0, f, 1.0 - f, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: AnimatedBuilder(
            animation: _slide,
            builder:
                (context, child) => Transform.translate(
                  offset: Offset(_slide.value, 0),
                  child: child,
                ),
            child: SingleChildScrollView(
              controller: _rail,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < slots.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    SizedBox(width: width, child: _tile(slots[i])),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Press squish
class _PressSquish extends StatefulWidget {
  const _PressSquish({required this.child, this.scale = 0.95});

  final Widget child;
  final double scale;

  @override
  State<_PressSquish> createState() => _PressSquishState();
}

class _PressSquishState extends State<_PressSquish> {
  bool _pressed = false;

  void _set(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        alignment: Alignment.centerLeft,
        child: widget.child,
      ),
    );
  }
}

class _PocketStat extends StatelessWidget {
  const _PocketStat({
    required this.icon,
    required this.tint,
    required this.title,
    required this.amount,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: tint),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: Color(0xFF6E6E73),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFA0A0A6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayHistory extends StatefulWidget {
  const _TodayHistory({required this.entries});

  final List<LogbookEntry> entries;

  @override
  State<_TodayHistory> createState() => _TodayHistoryState();
}

class _TodayHistoryState extends State<_TodayHistory> {
  // Ids already on screen
  final Set<String> _seen = <String>{};

  @override
  void initState() {
    super.initState();
    _seen.addAll(widget.entries.map((entry) => entry.id));
  }

  @override
  Widget build(BuildContext context) {
    final recent = widget.entries.take(3).toList(growable: false);
    final fresh = <String>{
      for (final entry in recent)
        if (!_seen.contains(entry.id)) entry.id,
    };
    _seen.addAll(recent.map((entry) => entry.id));

    if (recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Text(
          'Nothing logged yet today',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: Color(0xFFA0A0A6),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 26),
        Row(
          children: [
            const Text(
              'Today',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A8A8F),
              ),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showLogbookSheet(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6E6E73),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < recent.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _EntryIn(
            key: ValueKey(recent[i].id),
            animate: fresh.contains(recent[i].id),
            child: _EntryRow(entry: recent[i]),
          ),
        ],
      ],
    );
  }
}

// Reveals a row when it first arrives
class _EntryIn extends StatefulWidget {
  const _EntryIn({
    super.key,
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  State<_EntryIn> createState() => _EntryInState();
}

class _EntryInState extends State<_EntryIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in;
  late final Animation<double> _eased;
  late final Animation<Offset> _slide;

  bool _started = false;
  Timer? _startDelay;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.animate ? 0 : 1,
    );
    _eased = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);
    _slide = Tween(
      begin: const Offset(0, 0.55),
      end: Offset.zero,
    ).animate(_eased);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return;
    _startDelay = Timer(const Duration(milliseconds: 200), () {
      if (mounted) _in.forward();
    });
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _eased,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _eased,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final LogbookEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color tint = _spendTint(entry.category);
    final String typed = entry.title.trim();
    final String title = typed.isEmpty ? entry.category.label : typed;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_spendIcon(entry.category), size: 17, color: tint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: entry.isExpense ? logbookRed : logbookGreen,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.pocket.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFA0A0A6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${entry.isExpense ? '-' : '+'} ${_rupiah(entry.amount)}',
          style: TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: entry.isExpense ? logbookRed : logbookGreen,
          ),
        ),
      ],
    );
  }
}

// Spend icon
IconData _spendIcon(LogbookCategory category) {
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

// Spend tint
Color _spendTint(LogbookCategory category) {
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

class _TodayNet extends StatelessWidget {
  const _TodayNet({required this.entries});

  final List<LogbookEntry> entries;

  @override
  Widget build(BuildContext context) {
    final int spent = entries
        .where((entry) => entry.isExpense)
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final int saved = entries
        .where((entry) => !entry.isExpense)
        .fold<int>(0, (sum, entry) => sum + entry.amount);

    if (spent == 0 && saved == 0) return const SizedBox.shrink();

    final int net = saved - spent;
    final String line =
        net >= 0
            ? 'You saved ${_rupiah(net)} today'
            : 'You spent ${_rupiah(-net)} today';

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text(
        line,
        style: const TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: Color(0xFFA0A0A6),
        ),
      ),
    );
  }
}

class _MissionsBlock extends StatelessWidget {
  const _MissionsBlock({required this.missions});

  final List<DailyMission> missions;

  @override
  Widget build(BuildContext context) {
    if (missions.isEmpty) {
      return const Text(
        'No missions yet',
        style: TextStyle(fontSize: 13, color: Color(0xFF6F695F)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < missions.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
          _SheetRow(
            leading:
                missions[i].completed
                    ? const Color(0xFFEDF7EE)
                    : const Color(0xFFF5F5F5),
            icon: missions[i].completed ? Icons.check : missions[i].icon,
            iconColor:
                missions[i].completed
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFFF7A45),
            title: missions[i].title,
            subtitle: missions[i].completed ? 'Completed' : 'Not yet started',
            onTap:
                missions[i].title == 'View History'
                    ? () => showLogbookSheet(context)
                    : null,
          ),
        ],
      ],
    );
  }
}

class _GoalsBlock extends StatelessWidget {
  const _GoalsBlock({required this.goals});

  final List<UserGoal> goals;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return const Text(
        'No goals yet',
        style: TextStyle(fontSize: 13, color: Color(0xFF6F695F)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < goals.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    goals[i].emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goals[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(goals[i].progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF7A45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _ProgressBar(value: goals[i].progress, height: 9),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.leading,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final Color leading;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: leading, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6F695F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: Color(0xFFBDBDBD),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating bottom navigation, styled after the reference bar.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onSelectTab,
    required this.onQuickAction,
    required this.quickActionsOpen,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onQuickAction;
  final bool quickActionsOpen;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final align =
        selectedIndex == 0
            ? const Alignment(-1.0, 0.0)
            : (selectedIndex == 1
                ? const Alignment(0.0, 0.0)
                : const Alignment(1.0, 0.0));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 276,
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(31),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration:
                    reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: align,
                child: FractionallySizedBox(
                  widthFactor: 1 / 3,
                  heightFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEDED),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: selectedIndex == 0,
                    onTap: () => onSelectTab(0),
                  ),
                  _NavItem(
                    icon: Icons.fact_check_rounded,
                    label: 'Tasks',
                    selected: selectedIndex == 1,
                    onTap: () => onSelectTab(1),
                  ),
                  _NavItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Pockets',
                    selected: selectedIndex == 2,
                    onTap: () => onSelectTab(2),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _NavCircleButton(open: quickActionsOpen, onTap: onQuickAction),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const Color active = Color(0xFF2F6BFF);
    const Color ink = Color(0xFF111111);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration:
                    reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: Icon(icon, size: 24, color: selected ? active : ink),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration:
                    reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? active : ink,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  const _NavCircleButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) {
            return RotationTransition(
              turns: Tween<double>(begin: 0.55, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(
            open ? Icons.close_rounded : Icons.add_rounded,
            key: ValueKey<bool>(open),
            size: 25,
            color: const Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}

/// Compact white quick-action card anchored above the pencil button.
class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({
    required this.animation,
    required this.entriesToday,
    required this.onLogbook,
    required this.onNewEntry,
    required this.onSpeak,
  });

  final Animation<double> animation;
  final int entriesToday;
  final VoidCallback onLogbook;
  final VoidCallback onNewEntry;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final panel = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: panel,
      builder: (context, child) {
        final t = panel.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: Transform.scale(
              scale: 0.92 + 0.08 * t,
              alignment: Alignment.bottomRight,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StaggeredReveal(
              animation: animation,
              interval: const Interval(0.18, 0.72, curve: Curves.easeOutCubic),
              child: _QuickActionRow(
                title: 'Logbook',
                subtitle:
                    entriesToday == 0
                        ? 'No entries today'
                        : '$entriesToday ${entriesToday == 1 ? 'entry' : 'entries'} today',
                icon: Icons.menu_book_rounded,
                onTap: onLogbook,
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F1F3)),
            _StaggeredReveal(
              animation: animation,
              interval: const Interval(0.32, 0.88, curve: Curves.easeOutCubic),
              child: _QuickActionRow(
                title: 'New entry',
                subtitle: 'Speak it or type it',
                icon: Icons.edit_note_rounded,
                onTap: onNewEntry,
                secondaryIcon: Icons.mic_rounded,
                onSecondaryTap: onSpeak,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and lifts a child in, timed by an [Interval] of the panel animation.
class _StaggeredReveal extends StatelessWidget {
  const _StaggeredReveal({
    required this.animation,
    required this.interval,
    required this.child,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = CurvedAnimation(
          parent: animation,
          curve: interval,
        ).value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _QuickActionRow extends StatefulWidget {
  const _QuickActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.secondaryIcon,
    this.onSecondaryTap,
    this.secondaryEnabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondaryTap;
  final bool secondaryEnabled;

  @override
  State<_QuickActionRow> createState() => _QuickActionRowState();
}

class _QuickActionRowState extends State<_QuickActionRow> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setDown(true) : null,
      onTapUp: enabled ? (_) => _setDown(false) : null,
      onTapCancel: enabled ? () => _setDown(false) : null,
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color:
                            enabled
                                ? const Color(0xFF111111)
                                : const Color(0xFF9AA0A6),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7A7F85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (widget.secondaryIcon != null) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.secondaryEnabled ? widget.onSecondaryTap : null,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7F8F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.secondaryIcon,
                      size: 21,
                      color:
                          widget.secondaryEnabled
                              ? const Color(0xFF111111)
                              : const Color(0xFFB4B9BE),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      _down ? const Color(0xFFE6EAEE) : const Color(0xFFF1F3F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 21,
                  color:
                      enabled
                          ? const Color(0xFF111111)
                          : const Color(0xFF9AA0A6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.pictureUrl});

  final String? pictureUrl;

  @override
  Widget build(BuildContext context) {
    final hasPicture = pictureUrl != null && pictureUrl!.isNotEmpty;

    return Container(
      width: 34,
      height: 34,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFFF2EEE8),
        shape: BoxShape.circle,
      ),
      child:
          hasPicture
              ? Image.network(
                pictureUrl!,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => const _DefaultAvatarIcon(),
              )
              : const _DefaultAvatarIcon(),
    );
  }
}

class _DefaultAvatarIcon extends StatelessWidget {
  const _DefaultAvatarIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.person, size: 20, color: Color(0xFF8D8378));
  }
}

class _HeartPips extends StatelessWidget {
  const _HeartPips({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final on = index < filled;
        return Padding(
          padding: EdgeInsets.only(right: index == 4 ? 0 : 4),
          child: Icon(
            on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 16,
            color:
                on
                    ? const Color(0xFFFF5A5F)
                    : Colors.white.withValues(alpha: 0.7),
            shadows: const [Shadow(color: Color(0x59000000), blurRadius: 10)],
          ),
        );
      }),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({this.profile});

  final UserProfileData? profile;

  @override
  Widget build(BuildContext context) {
    final level = profile?.level ?? 0;
    final userLevel = profile?.userLevel ?? 0;
    final levelCap = profile?.levelCap ?? 0;
    final progress = (level / UserProfileData.xpToNextLevel).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile?.name ?? '...',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                'Lv $userLevel/$levelCap',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF6F695F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$level/${UserProfileData.xpToNextLevel} XP',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFF7A45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        _ProgressBar(value: progress.toDouble(), height: 5),
      ],
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.currency});

  final int currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.amber.shade200,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.toll, size: 13, color: Color(0xFFB8860B)),
          ),
          const SizedBox(width: 5),
          Text(
            '$currency',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5C4300),
            ),
          ),
        ],
      ),
    );
  }
}

class _WardrobeButton extends StatelessWidget {
  const _WardrobeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      elevation: 3,
      shadowColor: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: Icon(Icons.checkroom, size: 20, color: Color(0xFF4A4039)),
        ),
      ),
    );
  }
}

class _RightControlStack extends StatelessWidget {
  const _RightControlStack();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ControlPill(
          actions: [
            _StackAction(icon: Icons.pets),
            _StackAction(icon: Icons.storefront_rounded),
          ],
        ),
        SizedBox(height: 8),
        _ControlPill(actions: [_StackAction(icon: Icons.celebration_rounded)]),
      ],
    );
  }
}

class _ControlPill extends StatelessWidget {
  const _ControlPill({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0.14),
            ],
          ),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.45),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }
}

class _StackAction extends StatelessWidget {
  const _StackAction({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {},
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Icon(
          icon,
          size: 19,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final EventData? event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 210,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2F5540), Color(0xFF3E6B4E)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  size: 18,
                  color: Color(0xFFFFD98A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event?.eventName ?? 'Event',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ends in ${event?.endsIn ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9A57), Color(0xFFFF6A3D)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _FlameIcon(size: 12),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Flat cartoon flame
class _FlameIcon extends StatelessWidget {
  const _FlameIcon({this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.78, size),
      painter: const _FlamePainter(),
    );
  }
}

class _FlamePainter extends CustomPainter {
  const _FlamePainter();

  Path _flame(Size s) {
    final w = s.width;
    final h = s.height;
    return Path()
      ..moveTo(w * 0.54, h * 0.01)
      ..cubicTo(w * 0.74, h * 0.18, w * 0.99, h * 0.40, w * 0.96, h * 0.64)
      ..cubicTo(w * 0.93, h * 0.87, w * 0.76, h * 0.99, w * 0.50, h * 0.99)
      ..cubicTo(w * 0.24, h * 0.99, w * 0.04, h * 0.86, w * 0.04, h * 0.63)
      ..cubicTo(w * 0.04, h * 0.45, w * 0.17, h * 0.37, w * 0.27, h * 0.23)
      ..cubicTo(w * 0.31, h * 0.35, w * 0.38, h * 0.40, w * 0.44, h * 0.35)
      ..cubicTo(w * 0.46, h * 0.23, w * 0.47, h * 0.10, w * 0.54, h * 0.01)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final flame = _flame(size);
    canvas.drawPath(flame, Paint()..color = const Color(0xFFFF7B33));
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.72);
    canvas.scale(0.58);
    canvas.translate(-size.width * 0.5, -size.height * 0.72);
    canvas.drawPath(flame, Paint()..color = const Color(0xFFFFC155));
    canvas.restore();
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.86);
    canvas.scale(0.26);
    canvas.translate(-size.width * 0.5, -size.height * 0.86);
    canvas.drawPath(flame, Paint()..color = const Color(0xFFFFE8A8));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => false;
}

class _StreakWeekBlock extends StatelessWidget {
  const _StreakWeekBlock({required this.streak});

  final int streak;

  static const List<String> _days = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  @override
  Widget build(BuildContext context) {
    final todayIndex = DateTime.now().weekday % 7;
    final filled = streak.clamp(0, 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _FlameIcon(size: 40),
            const SizedBox(width: 8),
            Text(
              '$streak',
              style: const TextStyle(
                fontSize: 40,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'day streak',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6F695F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_days.length, (index) {
            final daysAgo = (todayIndex - index + 7) % 7;
            final on = daysAgo < filled;
            final isToday = daysAgo == 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        on ? const Color(0xFFE4F4E9) : const Color(0xFFF4F5F7),
                    shape: BoxShape.circle,
                  ),
                  child:
                      on
                          ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Color(0xFF2E9E5B),
                          )
                          : null,
                ),
                const SizedBox(height: 6),
                Text(
                  _days[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color:
                        isToday
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFF9A958C),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// ======================================================================
// Sheet widgets
// ======================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6F695F)),
          ],
        ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission});

  final DailyMission mission;

  @override
  Widget build(BuildContext context) {
    final done = mission.completed;

    return Container(
      height: 78,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFEDF7EE) : const Color(0xFFF7F5F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done ? const Color(0xFFCDE8D0) : const Color(0xFFEDE8E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check : mission.icon,
                  size: 14,
                  color:
                      done ? const Color(0xFF2E7D32) : const Color(0xFFFF7A45),
                ),
              ),
              const Spacer(),
              if (done)
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Color(0xFF2E7D32),
                ),
            ],
          ),
          const Spacer(),
          Text(
            mission.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            done ? 'Completed' : 'Not yet started',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF6F695F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF2FF), Color(0xFFDCE9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 12,
                color: Color(0xFF3B6FB6),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Current Balance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B7BA6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _rupiah(balance),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F3A5F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE8EF), Color(0xFFFFF2E2)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('Ã°Å¸â€Â¥', style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Keep your streak going!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Log your transactions for 3 days to unlock a reward!',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF6F695F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text('Ã¢Â­Â', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final UserGoal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = (goal.progress * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F4FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDE7FB)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(goal.emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF7A45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _ProgressBar(value: goal.progress, height: 8),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_rupiah(goal.saved)} / ${_rupiah(goal.target)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF6F695F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: Color(0xFFBDBDBD),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded progress bar (value 0.0 - 1.0).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, this.height = 8});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: const Color(0xFFE0DCE6)),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFA06B), Color(0xFFFF7A45)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Helpers
// ======================================================================

String _group(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }

  final sign = value < 0 ? '-' : '';
  return '$sign$buffer';
}

/// 955000 -> "955rb", 1400000 -> "1,4jt"
String _shortRupiah(int value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs < 1000) return '$sign$abs';
  if (abs < 1000000) return '$sign${_shortNumber(abs / 1000)}rb';
  return '$sign${_shortNumber(abs / 1000000)}jt';
}

String _shortNumber(double value) {
  final text = value.toStringAsFixed(1);
  if (text.endsWith('.0')) return text.substring(0, text.length - 2);
  return text.replaceAll('.', ',');
}

/// 250000 -> "Rp 250.000"
String _rupiah(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }

  final sign = value < 0 ? '-' : '';
  return '$sign'
      'Rp $buffer';
}
