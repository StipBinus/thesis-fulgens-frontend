import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
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
                                'Username',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                              Text(
                                '11 Years Old',
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
                          'Level ' + '1',
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
                                    widthFactor: 0.5,
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
                            '5/10 XP',
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
                      const _Section(
                        title: 'MY PROGRESS',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _StatItem(
                                    emoji: '🔥',
                                    value: '12 Days',
                                    label: 'Streak',
                                  ),
                                ),
                                Expanded(
                                  child: _StatItem(
                                    emoji: '🎯',
                                    value: '24',
                                    label: 'Challenges',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatItem(
                                    emoji: '🏆',
                                    value: '8',
                                    label: 'Achievements',
                                  ),
                                ),
                                Expanded(
                                  child: _StatItem(
                                    emoji: '📊',
                                    value: '85%',
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
                                const Text(
                                  'Medium',
                                  style: TextStyle(fontSize: 12),
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
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
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
