import 'package:flutter/material.dart';

import '../ui/parent_ui.dart';

// Uncomment together with the fetch bodies when the backend is ready.
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../../../core/config/api_config.dart';

// ======================================================================
// Data models
// ======================================================================

/// GET /profile
class UserProfilePageData {
  const UserProfilePageData({
    this.profilePicture,
    required this.name,
    required this.age,
    required this.level,
    required this.userLevel,
    required this.levelCap,
    required this.userStreak,
    required this.challenges,
    required this.achievements,
    required this.consistency,
    required this.parentSharing,
  });

  /// Profile picture URL. `null` renders the default initial avatar.
  final String? profilePicture;

  final String name;

  final int age;

  /// XP collected inside the current level, e.g. `5` -> "5/10 XP".
  final int level;

  /// Current level number, e.g. `1`.
  final int userLevel;

  /// Highest reachable level, e.g. `100`.
  final int levelCap;

  /// Consecutive days streak.
  final int userStreak;

  /// Completed challenges count.
  final int challenges;

  /// Unlocked achievements count.
  final int achievements;

  /// Consistency percentage, e.g. `85` -> "85%".
  final int consistency;

  /// Parent sharing level, e.g. "Low" / "Medium" / "High".
  final String parentSharing;

  /// XP needed per level (used by the XP bar).
  static const int xpToNextLevel = 10;

  factory UserProfilePageData.fromJson(Map<String, dynamic> json) {
    return UserProfilePageData(
      profilePicture: json['profilePicture'] as String?,
      name: json['name'] as String? ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      userLevel: (json['userLevel'] as num?)?.toInt() ?? 1,
      levelCap: (json['levelCap'] as num?)?.toInt() ?? 100,
      userStreak: (json['userStreak'] as num?)?.toInt() ?? 0,
      challenges: (json['challenges'] as num?)?.toInt() ?? 0,
      achievements: (json['achievements'] as num?)?.toInt() ?? 0,
      consistency: (json['consistency'] as num?)?.toInt() ?? 0,
      parentSharing: json['parentSharing'] as String? ?? '-',
    );
  }
}

// ======================================================================
// Profile page
// ======================================================================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfilePageData? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _fetchProfile();

    if (!mounted) return;

    setState(() => _profile = profile);
  }

  // ------------------------------------------------------------------
  // Endpoints — the HTTP call is commented out until the backend is
  // live. The dummy block right below mirrors the payload the endpoint
  // is expected to return, so only the comments need swapping.
  // ------------------------------------------------------------------

  Future<UserProfilePageData> _fetchProfile() async {
    // final response = await http.get(
    //   Uri.parse('${ApiConfig.backendUrl}/api/profile'),
    //   headers: {'Authorization': 'Bearer <token>'},
    // );
    //
    // if (response.statusCode == 200) {
    //   return UserProfilePageData.fromJson(
    //     jsonDecode(response.body) as Map<String, dynamic>,
    //   );
    // }
    //
    // throw Exception('Failed to load profile (${response.statusCode})');

    // Dummy data after urlComment.
    return const UserProfilePageData(
      profilePicture: null,
      name: 'Username',
      age: 11, // 11 Years Old
      level: 5, // 5/10 XP
      userLevel: 1,
      levelCap: 100,
      userStreak: 12, // 12 Days
      challenges: 24,
      achievements: 8,
      consistency: 85, // 85%
      parentSharing: 'Medium',
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final level = profile?.level ?? 0;
    final xpProgress =
        (level / UserProfilePageData.xpToNextLevel)
            .clamp(0.0, 1.0)
            .toDouble();
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: ParentPalette.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(22, 14, 22, 24 + bottomInset),
          children: [
            // Header
            Row(
              children: [
                const ParentBackButton(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile',
                        style: parentText(size: 20, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Progress and privacy',
                        style: parentText(
                          size: 12.5,
                          weight: FontWeight.w500,
                          color: ParentPalette.label,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Identity
            ParentCard(
              color: ParentPalette.raised,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ParentPalette.accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: _ProfileAvatarImage(
                      pictureUrl: profile?.profilePicture,
                      fallback: Text(
                        (profile?.name ?? '?')
                            .trim()
                            .substring(0, 1)
                            .toUpperCase(),
                        style: parentText(
                          size: 26,
                          weight: FontWeight.w700,
                          color: ParentPalette.accentDeep,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? '...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: parentText(
                            size: 20,
                            weight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${profile?.age ?? 0} years old',
                          style: parentText(
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: ParentPalette.label,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ParentPalette.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Level ${profile?.userLevel ?? 0}',
                            style: parentText(
                              size: 11.5,
                              weight: FontWeight.w700,
                              color: ParentPalette.accentDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // XP
            ParentCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Experience',
                        style: parentText(
                          size: 12,
                          weight: FontWeight.w600,
                          color: ParentPalette.label,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$level/${UserProfilePageData.xpToNextLevel} XP',
                        style: parentText(
                          size: 12,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(height: 8, color: ParentPalette.line),
                        FractionallySizedBox(
                          widthFactor: xpProgress,
                          child: Container(
                            height: 8,
                            decoration: const BoxDecoration(
                              gradient: ParentPalette.accentGradient,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // My progress
            ParentSectionHeader(title: 'My progress'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    emoji: '🔥',
                    value: '${profile?.userStreak ?? 0} days',
                    label: 'Streak',
                    tint: ParentPalette.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    emoji: '🎯',
                    value: '${profile?.challenges ?? 0}',
                    label: 'Challenges',
                    tint: const Color(0xFF2A6EA8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    emoji: '🏆',
                    value: '${profile?.achievements ?? 0}',
                    label: 'Achievements',
                    tint: const Color(0xFFB07A12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    emoji: '📊',
                    value: '${profile?.consistency ?? 0}%',
                    label: 'Consistency',
                    tint: const Color(0xFF7B4FBF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Privacy
            ParentSectionHeader(title: 'Privacy'),
            const SizedBox(height: 12),
            ParentCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Parent sharing',
                          style: parentText(
                            size: 14,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: ParentPalette.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            profile?.parentSharing ?? '-',
                            style: parentText(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: ParentPalette.label,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _LinkText(text: 'Manage', onTap: () {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Settings
            ParentSectionHeader(title: 'Settings'),
            const SizedBox(height: 12),
            ParentCard(
              color: ParentPalette.raised,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 4,
              ),
              child: Column(
                children: [
                  _SettingsTile(label: 'Notifications', onTap: () {}),
                  const Divider(height: 1, color: ParentPalette.line),
                  _SettingsTile(label: 'Account', onTap: () {}),
                  const Divider(height: 1, color: ParentPalette.line),
                  _SettingsTile(label: 'Help', onTap: () {}),
                  const Divider(height: 1, color: ParentPalette.line),
                  _SettingsTile(
                    label: 'Log out',
                    color: ParentPalette.red,
                    showArrow: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Small supporting widgets, so build() above stays readable
// ======================================================================

/// Profile picture from a URL, falling back to the initial avatar.
class _ProfileAvatarImage extends StatelessWidget {
  const _ProfileAvatarImage({this.pictureUrl, this.fallback});

  final String? pictureUrl;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final hasPicture = pictureUrl != null && pictureUrl!.isNotEmpty;
    if (!hasPicture) return fallback ?? const SizedBox.shrink();

    return Image.network(
      pictureUrl!,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) => fallback ?? const SizedBox.shrink(),
    );
  }
}

/// Emoji + value + label card used by the progress grid.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.tint,
  });

  final String emoji;
  final String value;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      color: ParentPalette.raised,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: parentText(
              size: 17,
              weight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: parentText(
              size: 12,
              weight: FontWeight.w500,
              color: ParentPalette.label,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable text link, e.g. "Manage".
class _LinkText extends StatelessWidget {
  const _LinkText({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Text(
          '$text →',
          style: parentText(
            size: 12,
            weight: FontWeight.w700,
            color: ParentPalette.accent,
          ),
        ),
      ),
    );
  }
}

/// Settings row with a chevron on the right.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    required this.onTap,
    this.color,
    this.showArrow = true,
  });

  final String label;
  final Color? color;
  final bool showArrow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: parentText(
                  size: 14,
                  weight: FontWeight.w500,
                  color: color ?? ParentPalette.ink,
                ),
              ),
            ),
            if (showArrow)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: ParentPalette.faint,
              ),
          ],
        ),
      ),
    );
  }
}
