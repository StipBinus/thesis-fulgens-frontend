import 'package:flutter/material.dart';

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

  /// Profile picture URL. `null` renders the default red avatar.
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
        (level / UserProfilePageData.xpToNextLevel).clamp(0.0, 1.0).toDouble();

    // Ruang oranye di atas kartu (avatar setengah masuk ke area ini)
    const double topSpace = 100;
    const double avatarSize = 200;
    final double screenHeight = MediaQuery.of(context).size.height;

    // TODO: implement build
    return Material(
      // Inget buat apus material pas scaffold selsai
      color: Colors.deepOrange,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: topSpace),

            Stack(
              clipBehavior: Clip.none, // supaya avatar boleh keluar dari kartu
              alignment: Alignment.topCenter,
              children: [
                // ================= KARTU PUTIH =================
                Container(
                  width: double.infinity,
                  // minimal setinggi sisa layar, supaya tidak ada oranye di bawah
                  constraints: BoxConstraints(
                    minHeight: screenHeight - topSpace,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  // atas 120 = ruang untuk setengah bagian bawah avatar
                  padding: const EdgeInsets.fromLTRB(40, 120, 40, 40),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 60,
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                profile?.name ?? '...',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                              Text(
                                '${profile?.age ?? 0} Years Old',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Container(
                        height: 20,
                        padding: EdgeInsets.only(left: 10),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Level ${profile?.userLevel ?? 0}',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ),

                      Row(
                        children: [
                          // Expanded menggantikan SizedBox(width: 250)
                          // supaya tidak overflow di layar sempit
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  Container(height: 15, color: Colors.grey),
                                  FractionallySizedBox(
                                    widthFactor: xpProgress,
                                    child: Container(
                                      height: 15,
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            '$level/${UserProfilePageData.xpToNextLevel} XP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      Container(
                        height: 20,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey, width: 1),
                          ),
                        ),
                      ),

                      // ================= MY PROGRESS =================
                      _Section(
                        title: 'MY PROGRESS',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _StatItem(
                                    emoji: '🔥',
                                    value: '${profile?.userStreak ?? 0} Days',
                                    label: 'Streak',
                                  ),
                                ),
                                Expanded(
                                  child: _StatItem(
                                    emoji: '🎯',
                                    value: '${profile?.challenges ?? 0}',
                                    label: 'Challenges',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatItem(
                                    emoji: '🏆',
                                    value: '${profile?.achievements ?? 0}',
                                    label: 'Achievements',
                                  ),
                                ),
                                Expanded(
                                  child: _StatItem(
                                    emoji: '📊',
                                    value: '${profile?.consistency ?? 0}%',
                                    label: 'Consistency',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const _SectionDivider(),

                      // ================= PRIVACY =================
                      _Section(
                        title: 'PRIVACY',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Parent sharing',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  profile?.parentSharing ?? '-',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _LinkText(text: 'Manage →', onTap: () {}),
                            ),
                          ],
                        ),
                      ),
                      const _SectionDivider(),

                      // ================= SETTINGS =================
                      _Section(
                        title: 'SETTINGS',
                        child: Column(
                          children: [
                            _SettingsTile(label: 'Notifications', onTap: () {}),
                            _SettingsTile(label: 'Account', onTap: () {}),
                            _SettingsTile(label: 'Help', onTap: () {}),
                            _SettingsTile(
                              label: 'Log out',
                              color: Colors.red,
                              showArrow: false,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ================= PROFILE PICTURE =================
                // Nempel di atas kartu, setengahnya keluar ke area oranye
                Positioned(
                  top: -(avatarSize / 2),
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: _ProfileAvatarImage(
                      pictureUrl: profile?.profilePicture,
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

// ======================================================================
// Widget kecil pendukung (biar build() di atas tetap rapi)
// ======================================================================

/// Foto profil dari URL. Kalau `pictureUrl` kosong, area merah di belakangnya
/// yang tampil (perilaku lama).
class _ProfileAvatarImage extends StatelessWidget {
  final String? pictureUrl;

  const _ProfileAvatarImage({this.pictureUrl});

  @override
  Widget build(BuildContext context) {
    final hasPicture = pictureUrl != null && pictureUrl!.isNotEmpty;
    if (!hasPicture) return const SizedBox.shrink();

    return Image.network(
      pictureUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// Judul section (di tengah) + isinya.
class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Colors.deepOrange,
              ),
            ),
          ),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Garis pemisah antar section.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Colors.grey);
  }
}

/// Item statistik: emoji + angka + label (dipakai di MY PROGRESS).
class _StatItem extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _StatItem({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$emoji $value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

/// Progress bar bulat (value 0.0 - 1.0), gaya sama dengan XP bar di atas.
class _ProgressBar extends StatelessWidget {
  final double value;

  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(height: 12, color: Colors.grey[300]),
          FractionallySizedBox(
            widthFactor: value,
            child: Container(height: 12, color: Colors.deepOrange),
          ),
        ],
      ),
    );
  }
}

/// Teks yang bisa diklik, misal "See all →" / "Manage →".
class _LinkText extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _LinkText({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
      ),
    );
  }
}

/// Kotak emoji untuk achievement.
class _AchievementBadge extends StatelessWidget {
  final String emoji;

  const _AchievementBadge({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepOrange.shade100),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 26)),
    );
  }
}

/// Baris menu settings dengan panah ">" di kanan.
class _SettingsTile extends StatelessWidget {
  final String label;
  final Color? color;
  final bool showArrow;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.label,
    required this.onTap,
    this.color,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, color: color)),
            ),
            if (showArrow)
              Icon(Icons.chevron_right, color: color ?? Colors.grey),
          ],
        ),
      ),
    );
  }
}
