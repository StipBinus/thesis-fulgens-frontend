import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

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
    this.emoji = '🎯',
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
      emoji: json['emoji'] as String? ?? '🎯',
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

class _HomePageFinState extends State<HomePageFin> {
  // Sheet positions, as fractions of the available height.
  static const double _collapsedSize = 0.18;
  static const double _expandedSize = 0.92;

  // Height of the drag handle block (5px thumb + 10px padding on each side).
  static const double _sheetHandleHeight = 25;

  // Measured sheet content, expressed as a fraction of the screen height.
  // Starts at the hard cap and shrinks to fit once the content is measured.
  double _fitSize = _expandedSize;
  final GlobalKey _sheetContentKey = GlobalKey();
  bool _measureScheduled = false;

  UserProfileData? _profile;
  EventData? _event;
  List<DailyMission> _missions = const [];
  List<UserGoal> _goals = const [];

  @override
  void initState() {
    super.initState();
    _loadHome();
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
  // Endpoints — the HTTP calls are commented out until the backend is
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
        emoji: '🚲',
      ),
      UserGoal(
        name: 'New Headphones',
        target: 1000000, // Rp 1.000.000
        saved: 500000, // Rp 500.000 -> 50%
        emoji: '🎧',
      ),
    ];
  }

  /// Measures the sheet content and caps the sheet at exactly that height.
  ///
  /// `DraggableScrollableSheet` only understands fractions of its parent, so
  /// the natural content height is converted into one. When the content is
  /// taller than [_expandedSize], the hard cap wins and the sheet scrolls.
  void _scheduleSheetMeasure(double availableHeight) {
    if (_measureScheduled ||
        !availableHeight.isFinite ||
        availableHeight <= 0) {
      return;
    }
    _measureScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;

      final renderObject = _sheetContentKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;

      final contentHeight = renderObject.size.height + _sheetHandleHeight;
      final fit = (contentHeight / availableHeight).clamp(
        _collapsedSize,
        _expandedSize,
      );

      if ((fit - _fitSize).abs() > 0.001) {
        setState(() => _fitSize = fit);
      }
    });
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

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Stack(
      children: [
        // (0) Background placeholder (forest).
        const Positioned.fill(child: _SceneBackground()),

        // (2) Panda viewing area + (3) events + streak.
        // These stay fixed behind the sheet so the sheet slides over them.
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 600,
                  child: Stack(
                    children: [
                      // Wardrobe shortcut.
                      Positioned(
                        top: 132,
                        right: 4,
                        child: _WardrobeButton(
                          onTap: () => _goPlaceholder(context),
                        ),
                      ),

                      // Character.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 34,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/app/fulgens.svg',
                            height: 250,
                            fit: BoxFit.contain,
                            placeholderBuilder:
                                (ctx) =>
                                    const SizedBox(width: 250, height: 250),
                          ),
                        ),
                      ),

                      // Featured event.
                      Positioned(
                        left: 4,
                        bottom: 0,
                        child: _EventCard(
                          event: _event,
                          onTap: () => _goPlaceholder(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 70,
                  padding: const EdgeInsets.only(right: 4),
                  alignment: Alignment.centerRight,
                  child: _StreakPill(streak: profile?.userStreak ?? 0),
                ),
              ],
            ),
          ),
        ),

        // (4) White bottom sheet: draggable, snaps open/closed.
        Positioned(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 370,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _scheduleSheetMeasure(constraints.maxHeight);

                  return DraggableScrollableSheet(
                    initialChildSize: _collapsedSize,
                    minChildSize: _collapsedSize,
                    maxChildSize: _fitSize,

                    snap: true,
                    snapSizes: [_collapsedSize, _fitSize],

                    builder: (context, scrollController) {
                      return Material(
                        color: Colors.white,
                        clipBehavior: Clip.antiAlias,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Container(
                                width: 44,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: scrollController,
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                child: Padding(
                                  key: _sheetContentKey,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    24,
                                  ),
                                  child: _buildSheetBody(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),

        // (1) Fixed top bar: profile (left) + currency (right).
        // Drawn last so it stays visible above the sheet.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 360,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _goPlaceholder(context),
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  _ProfileAvatar(
                                    pictureUrl: profile?.profilePicture,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _ProfileSummary(profile: profile),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CurrencyPill(currency: profile?.userCurrency ?? 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Sheet body
  // ------------------------------------------------------------------

  Widget _buildSheetBody(BuildContext context) {
    final profile = _profile;

    // The home sheet only previews the two missions that fit side by side.
    // Anything else is reachable from the missions page (Daily Missions tap).
    final missions = _missions.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily missions + current balance.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'Daily Missions',
                      onTap: () => _goPlaceholder(context),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < missions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: _MissionTile(mission: missions[i])),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _BalanceCard(balance: profile?.userBalance ?? 0),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Streak reminder.
        _StreakBanner(onTap: () => _goPlaceholder(context)),
        const SizedBox(height: 18),

        // Saving goals.
        Row(
          children: [
            const Text(
              'Saving Goal',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _goPlaceholder(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF7A45),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: Color(0xFFFF7A45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _goals.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _GoalCard(goal: _goals[i], onTap: () => _goPlaceholder(context)),
        ],
      ],
    );
  }
}

// ======================================================================
// Scene widgets
// ======================================================================

/// Forest placeholder until real background art is available.
class _SceneBackground extends StatelessWidget {
  const _SceneBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 0.95,
          colors: [Color(0xFF4C6E55), Color(0xFF2C4234), Color(0xFF17251D)],
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
            fontSize: 12.5,
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
                  fontSize: 9,
                  color: Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$level/${UserProfileData.xpToNextLevel} XP',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFF7A45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        _ProgressBar(value: progress.toDouble(), height: 4),
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
          const Text('🔥', style: TextStyle(fontSize: 12)),
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
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9E9E9E)),
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
              color: Color(0xFF9E9E9E),
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
                  child: Text('🔥', style: TextStyle(fontSize: 17)),
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
                        color: Color(0xFF8D8D8D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text('⭐', style: TextStyle(fontSize: 20)),
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
                              color: Color(0xFF8D8D8D),
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
