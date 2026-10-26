import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
      userBalance: (json['userBalance'] as num?)?.toInt() ?? 0,
      userStreak: (json['userStreak'] as num?)?.toInt() ?? 0,
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

class HomePageFin extends StatefulWidget {
  const HomePageFin({Key? key}) : super(key: key);

  @override
  _HomePageFinState createState() => _HomePageFinState();
}

class _HomePageFinState extends State<HomePageFin>
    with SingleTickerProviderStateMixin {
  UserProfileData? _profile;
  EventData? _event;
  List<DailyMission> _missions = const [];
  List<UserGoal> _goals = const [];

  // Quick-actions popover: open state + entrance/exit animation.
  late final AnimationController _quickController;
  bool _quickActionsOpen = false;
  int _selectedNavIndex = 0;

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
  void _goPlaceholder(BuildContext context) => context.go('/');

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
      final displacement = maxPullDown * (1 - math.exp(-under / (maxPullDown * 1.1)));
      displayHeight = minHeight - displacement;
    } else if (_rawDragHeight > maxHeight) {
      // Pull up: overshoot past maxHeight by a bit more
      final over = _rawDragHeight - maxHeight;
      const maxPullUp = 110.0;
      final displacement = maxPullUp * (1 - math.exp(-over / (maxPullUp * 1.1)));
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
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final velocity = reduceMotion ? 0.0 : details.velocity.pixelsPerSecond.dy;
    // Momentum: a fast flick keeps travelling before it settles.
    final projected = (current - velocity * 0.12)
        .clamp(minHeight, maxHeight)
        .toDouble();
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
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topInset = MediaQuery.paddingOf(context).top;

    // Navbar footprint: pill height + its bottom inset.
    final navBarHeight = 62.0 + (safeBottom > 16 ? safeBottom : 16.0);

    // Sheet travel: collapsed stop up to the height its content needs.
    final minSheetHeight = screenHeight * 0.45;
    final fallbackMax = screenHeight - topInset - 8;
    final maxSheetHeight = math.max(
      minSheetHeight,
      _sheetContentHeight > 0 ? _sheetContentHeight : fallbackMax,
    );
    final sheetHeight = _sheetDragging
        ? (_sheetHeight ?? minSheetHeight)
        : (_sheetHeight ?? minSheetHeight)
              .clamp(minSheetHeight, maxSheetHeight)
              .toDouble();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncSheetContentHeight(),
    );

    final popoverWidth = (MediaQuery.sizeOf(context).width / 3).clamp(
      118.0,
      190.0,
    );
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final baseTheme = Theme.of(context);
    final poppinsTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);

    return Theme(
      data: baseTheme.copyWith(textTheme: poppinsTheme),
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle.merge(
          style: GoogleFonts.poppins(decoration: TextDecoration.none),
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
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
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
                        filled: ((profile?.level ?? 0) /
                                UserProfileData.xpToNextLevel *
                                5)
                            .round()
                            .clamp(0, 5)
                            .toInt(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _HeaderChip(
                  icon: Icons.monetization_on_rounded,
                  color: const Color(0xFFF5A524),
                  value: '${profile?.userCurrency ?? 0}',
                ),
                const SizedBox(width: 6),
                _HeaderChip(
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF7A45),
                  value: '${profile?.userStreak ?? 0}',
                ),
              ],
            ),
          ),
        ),

        // (4) White card: elastic pull-up sheet sized to its content.
        Positioned(
          left: 12,
          right: 12,
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
            child: AnimatedContainer(
              duration:
                  reduceMotion || _sheetDragging
                      ? Duration.zero
                      : _sheetSettleDuration,
              curve: const _SheetSettleCurve(),
              height: sheetHeight,
              child: _HomeSheet(
                profile: profile,
                missions: _missions,
                goals: _goals,
                footerSpace: navBarHeight,
                scrollController: _sheetScrollController,
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
                builder: (context, _) => ColoredBox(
                  color: Colors.black.withValues(
                    alpha: 0.18 * _quickController.value,
                  ),
                ),
              ),
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
                onSelectTab: (index) =>
                    setState(() => _selectedNavIndex = index),
                quickActionsOpen: _quickActionsOpen,
                onQuickAction: () =>
                    _toggleQuickActions(reduceMotion: reduceMotion),
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
              balance: profile?.userBalance ?? 0,
              animation: _quickController,
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

/// Small grabber hinting that the white card can be pulled up.
class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Segmented sheet: separate white blocks with the scene showing between them.
class _HomeSheet extends StatelessWidget {
  const _HomeSheet({
    required this.profile,
    required this.missions,
    required this.goals,
    required this.footerSpace,
    required this.scrollController,
  });

  final UserProfileData? profile;
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
                    grabber: true,
                    child: _BalanceStreakBlock(profile: profile),
                  ),
                  const SizedBox(height: 4),
                  _SheetBlock(
                    label: 'Streak',
                    child: _StreakWeekBlock(
                      streak: profile?.userStreak ?? 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _SheetBlock(
                    label: 'Panda stats',
                    labelColor: const Color(0xFF4A453E),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFFFF4EA),
                        Color(0xFFFFFBF7),
                        Color(0xFFFFFFFF),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                    child: const _PandaStatsBlock(),
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
              colors: [
                color.withOpacity(opacity),
                color.withOpacity(0),
              ],
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
    this.grabber = false,
    this.bottomPadding = 16,
    this.color = Colors.white,
    this.labelColor = const Color(0xFF4A453E),
    this.gradient,
  });

  final String? label;
  final Widget child;
  final bool grabber;
  final double bottomPadding;
  final Color color;
  final Color labelColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, bottomPadding),
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (grabber) ...[
            const _SheetGrabber(),
            const SizedBox(height: 10),
          ],
          if (label != null && label!.isNotEmpty) ...[
            Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

class _BalanceStreakBlock extends StatefulWidget {
  const _BalanceStreakBlock({required this.profile});

  final UserProfileData? profile;

  @override
  State<_BalanceStreakBlock> createState() => _BalanceStreakBlockState();
}

class _BalanceStreakBlockState extends State<_BalanceStreakBlock> {
  bool _obscureBalance = false;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Balance',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6F695F),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _obscureBalance ? 'Rp \u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022' : _rupiah(balance),
                          style: const TextStyle(
                            fontSize: 28,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _obscureBalance = !_obscureBalance),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          _obscureBalance
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: const Color(0xFF8C867A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _PocketItem(
                        icon: Icons.payments_rounded,
                        iconColor: const Color(0xFF2E7D32),
                        iconBg: const Color(0xFFE8F5E9),
                        title: 'Cash',
                        amount: _obscureBalance ? '\u2022\u2022\u2022\u2022' : 'Rp 100.000',
                      ),
                      const SizedBox(height: 6),
                      _PocketItem(
                        icon: Icons.monetization_on_rounded,
                        iconColor: const Color(0xFF1976D2),
                        iconBg: const Color(0xFFE3F2FD),
                        title: 'Snack',
                        amount: _obscureBalance ? '\u2022\u2022\u2022\u2022' : 'Rp 100.000',
                      ),
                      const SizedBox(height: 6),
                      _PocketItem(
                        icon: Icons.monetization_on_rounded,
                        iconColor: const Color(0xFFF57F17),
                        iconBg: const Color(0xFFFFF9C4),
                        title: 'Savings',
                        amount: _obscureBalance ? '\u2022\u2022\u2022\u2022' : 'Rp 50.000',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PocketItem extends StatelessWidget {
  const _PocketItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.amount,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A453E),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              amount,
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
      ],
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
        style: TextStyle(fontSize: 11.5, color: Color(0xFF6F695F)),
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
            leading: missions[i].completed
                ? const Color(0xFFEDF7EE)
                : const Color(0xFFF5F5F5),
            icon: missions[i].completed ? Icons.check : missions[i].icon,
            iconColor:
                missions[i].completed
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFFF7A45),
            title: missions[i].title,
            subtitle: missions[i].completed ? 'Completed' : 'Not yet started',
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
        style: TextStyle(fontSize: 11.5, color: Color(0xFF6F695F)),
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
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    goals[i].emoji,
                    style: const TextStyle(fontSize: 18),
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(goals[i].progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF7A45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _ProgressBar(value: goals[i].progress, height: 7),
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
  });

  final Color leading;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: leading, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: iconColor),
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
                    fontSize: 13.5,
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
                    fontSize: 11.5,
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
    final align = selectedIndex == 0
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
                duration: reduceMotion
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
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: Icon(
                  icon,
                  size: 21,
                  color: selected ? active : ink,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
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
  const _QuickActionsPanel({required this.balance, required this.animation});

  final int balance;
  final Animation<double> animation;

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
                subtitle: '0 entries',
                icon: Icons.menu_book_rounded,
                onTap: () {},
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F1F3)),
            _StaggeredReveal(
              animation: animation,
              interval: const Interval(0.32, 0.88, curve: Curves.easeOutCubic),
              child: _QuickActionRow(
                title: 'Spending',
                subtitle: _rupiah(balance),
                icon: Icons.account_balance_wallet_rounded,
                onTap: () {},
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

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.15,
                    color: Color(0xFF7A7F85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F3F5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: const Color(0xFF111111)),
            ),
          ),
        ],
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
            color: on
                ? const Color(0xFFFF5A5F)
                : Colors.white.withValues(alpha: 0.7),
            shadows: const [
              Shadow(color: Color(0x59000000), blurRadius: 10),
            ],
          ),
        );
      }),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
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
          const Text('\u{1F525}', style: TextStyle(fontSize: 12)),
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
            const Text('\u{1F525}', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Text(
              '$streak',
              style: const TextStyle(
                fontSize: 34,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'day streak',
              style: TextStyle(
                fontSize: 13,
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
                  width: 26,
                  height: 26,
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
                            size: 14,
                            color: Color(0xFF2E9E5B),
                          )
                          : null,
                ),
                const SizedBox(height: 6),
                Text(
                  _days[index],
                  style: TextStyle(
                    fontSize: 10,
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

class _PandaStatsBlock extends StatelessWidget {
  const _PandaStatsBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PandaStatRow(label: 'Hunger', value: 80, rating: 'Full'),
        SizedBox(height: 12),
        _PandaStatRow(label: 'Mood', value: 60, rating: 'Happy'),
        SizedBox(height: 12),
        _PandaStatRow(label: 'Energy', value: 40, rating: 'Low'),
        SizedBox(height: 12),
        _PandaStatRow(label: 'Hygiene', value: 20, rating: 'Dirty'),
      ],
    );
  }
}

class _PandaStatRow extends StatelessWidget {
  const _PandaStatRow({
    required this.label,
    required this.value,
    required this.rating,
  });

  final String label;
  final int value;
  final String rating;

  @override
  Widget build(BuildContext context) {
    final accent =
        value >= 70
            ? const Color(0xFF2EB872)
            : value >= 40
            ? const Color(0xFFFFA53D)
            : const Color(0xFFF26B5E);
    final accentInk =
        value >= 70
            ? const Color(0xFF1D8557)
            : value >= 40
            ? const Color(0xFFD97C10)
            : const Color(0xFFC24336);
    final filled = (value / 20).round().clamp(0, 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$value%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8C867A),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                rating,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  color: accentInk,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 4 ? 0 : 4),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: index < filled ? accent : const Color(0xFFF4EAE0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
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



