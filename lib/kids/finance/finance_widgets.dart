import 'package:flutter/material.dart';
import 'package:thesis_fulgens_mobile/core/config/api_config.dart';

import '../logbook/logbook_tokens.dart';

// ======================================================================
// Formatting
// ======================================================================

/// 250000 -> "Rp 250.000"
String financeRupiah(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }

  final sign = value < 0 ? '-' : '';
  return '${sign}Rp $buffer';
}

String financePercent(double value) => '${(value * 100).round()}%';

// ======================================================================
// Pocket look
// ======================================================================

// One source: picked icon first, else the name, from the same catalog
IconData financePocketIcon(String name, {String? image}) =>
    (pocketLookFor(image) ?? pocketLookByName(name))?.icon ??
    Icons.account_balance_wallet_rounded;

Color financePocketTint(String name, {String? image}) =>
    (pocketLookFor(image) ?? pocketLookByName(name))?.tint ?? logbookAccent;

// Name match: the original keyword order first, then the rest
const List<String> _nameOrder = [
  'cash', 'food', 'savings', 'travel', 'school', 'game', 'gift', 'book',
];

PocketIconLook? pocketLookByName(String name) {
  final key = name.toLowerCase();
  if (key.trim().isEmpty) return null;
  final ordered = [
    for (final k in _nameOrder) kPocketLooks.firstWhere((l) => l.key == k),
    for (final l in kPocketLooks)
      if (!_nameOrder.contains(l.key)) l,
  ];
  for (final look in ordered) {
    if (look.words.any(key.contains)) return look;
  }
  return null;
}

// Pickable icon: stored as "icon:<key>"
class PocketIconLook {
  const PocketIconLook(this.key, this.label, this.icon, this.tint, this.words);

  final String key;
  final String label;
  final IconData icon;
  final Color tint;
  final List<String> words;

  String get value => 'icon:$key';
}

// Icon catalog, same look as the name-based icons
const List<PocketIconLook> kPocketLooks = [
  PocketIconLook('wallet', 'Wallet', Icons.account_balance_wallet_rounded, logbookAccent, ['wallet', 'dompet']),
  PocketIconLook('savings', 'Savings', Icons.savings_rounded, Color(0xFFB07A12), ['saving', 'tabung']),
  PocketIconLook('cash', 'Cash', Icons.payments_rounded, Color(0xFF2E7D32), ['cash', 'uang', 'tunai']),
  PocketIconLook('food', 'Food', Icons.fastfood_rounded, Color(0xFF1976D2), ['food', 'snack', 'makan', 'jajan']),
  PocketIconLook('school', 'School', Icons.school_rounded, Color(0xFF2A6EA8), ['school', 'sekolah', 'study', 'education']),
  PocketIconLook('book', 'Books', Icons.menu_book_rounded, Color(0xFF3F7D6E), ['book', 'buku', 'read']),
  PocketIconLook('game', 'Games', Icons.sports_esports_rounded, Color(0xFFC2477A), ['game', 'main', 'play']),
  PocketIconLook('gift', 'Gifts', Icons.redeem_rounded, Color(0xFFB03A48), ['gift', 'hadiah', 'birthday']),
  PocketIconLook('travel', 'Travel', Icons.flight_takeoff_rounded, Color(0xFF7B4FBF), ['travel', 'trip', 'libur', 'jalan']),
  PocketIconLook('toy', 'Toys', Icons.toys_rounded, Color(0xFFE07A2E), ['toy', 'mainan', 'lego']),
  PocketIconLook('sport', 'Sports', Icons.sports_soccer_rounded, Color(0xFF2F8F4E), ['sport', 'ball', 'bola', 'olahraga']),
  PocketIconLook('music', 'Music', Icons.music_note_rounded, Color(0xFF8A4FBF), ['music', 'musik', 'song']),
  PocketIconLook('clothes', 'Clothes', Icons.checkroom_rounded, Color(0xFFD0568A), ['clothes', 'baju', 'shoe', 'sepatu']),
  PocketIconLook('phone', 'Gadgets', Icons.smartphone_rounded, Color(0xFF4A5A70), ['phone', 'hp', 'gadget', 'tablet']),
  PocketIconLook('bike', 'Bike', Icons.pedal_bike_rounded, Color(0xFF16808A), ['bike', 'sepeda']),
  PocketIconLook('pet', 'Pets', Icons.pets_rounded, Color(0xFF8D6440), ['pet', 'cat', 'dog', 'kucing', 'anjing']),
  PocketIconLook('art', 'Art', Icons.palette_rounded, Color(0xFFCC5A2E), ['art', 'draw', 'gambar']),
  PocketIconLook('movie', 'Movies', Icons.movie_rounded, Color(0xFFB5382F), ['movie', 'film', 'bioskop']),
  PocketIconLook('heart', 'Charity', Icons.volunteer_activism_rounded, Color(0xFFD4486A), ['charity', 'donate', 'sedekah']),
  PocketIconLook('star', 'Dream', Icons.star_rounded, Color(0xFFC99A0E), ['dream', 'wish', 'impian']),
];

// Picked icon from a stored value, if any
PocketIconLook? pocketLookFor(String? value) {
  final v = value?.trim() ?? '';
  if (!v.startsWith('icon:')) return null;
  final key = v.substring(5);
  for (final look in kPocketLooks) {
    if (look.key == key) return look;
  }
  return null;
}

/// Round pocket badge: image URL, emoji, or the falls-back icon.
class FinancePocketAvatar extends StatelessWidget {
  const FinancePocketAvatar({
    super.key,
    required this.image,
    required this.name,
    this.size = 48,
    this.background = true,
  });

  final String? image;
  final String name;
  final bool background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = image?.trim() ?? '';
    final isHttp = value.startsWith('http://') || value.startsWith('https://');
    final imageUrl =
        isHttp
            ? value
            : (value.startsWith('/')
                ? '${ApiConfig().getBackendUrl()}$value'
                : null);
    // Picked icon wins over the name-based one
    final look = pocketLookFor(value);
    final tint = financePocketTint(name, image: value);
    final fallback = Icon(
      financePocketIcon(name, image: value),
      size: size * 0.5,
      color: tint,
    );

    final Widget content;
    if (look != null) {
      content = fallback;
    } else if (imageUrl != null) {
      content = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else if (value.isNotEmpty) {
      content = Text(
        value,
        style: TextStyle(fontSize: size * 0.45),
        textAlign: TextAlign.center,
      );
    } else {
      content = fallback;
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background ? tint.withValues(alpha: 0.12) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Center(child: content),
    );
  }
}

// ======================================================================
// Page chrome
// ======================================================================

class FinanceHeader extends StatelessWidget {
  const FinanceHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: logbookInk,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: logbookInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: logbookMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FinanceAddButton extends StatelessWidget {
  const FinanceAddButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: logbookAccent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinanceCard extends StatelessWidget {
  const FinanceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const ShapeBorder shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(48)),
    );

    return Container(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class FinanceProgressBar extends StatelessWidget {
  const FinanceProgressBar({super.key, required this.value, this.height = 9});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: logbookTrack),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFA06B), logbookAccent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceEmptyState extends StatelessWidget {
  const FinanceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFF7F3EE),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: logbookFaint),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: logbookInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: logbookMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceErrorState extends StatelessWidget {
  const FinanceErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 30, color: logbookFaint),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: logbookMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: logbookAccent),
            child: const Text(
              'Try again',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Editor sheet parts
// ======================================================================

class FinanceSheet extends StatelessWidget {
  const FinanceSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3DED7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: logbookInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: logbookMuted,
                  ),
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the child's balance and the amount still free to allocate.
class FinanceAllocationInfo extends StatelessWidget {
  const FinanceAllocationInfo({
    super.key,
    required this.balance,
    required this.available,
  });

  final int balance;
  final int available;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AllocationStat(
              label: 'Balance',
              value: financeRupiah(balance),
              color: logbookInk,
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0xFFE7E1D8)),
          const SizedBox(width: 14),
          Expanded(
            child: _AllocationStat(
              label: 'Available',
              value: financeRupiah(available),
              color: logbookGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationStat extends StatelessWidget {
  const _AllocationStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10.5,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: logbookFaint,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

InputDecoration financeInputDecoration({
  required String label,
  String? hint,
  String? prefixText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    filled: true,
    fillColor: const Color(0xFFF7F5F1),
    labelStyle: const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: logbookMuted,
    ),
    hintStyle: const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      color: logbookFaint,
    ),
    prefixStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: logbookInk,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: logbookAccent, width: 1.4),
    ),
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: logbookRed, width: 1.2),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: const BorderSide(color: logbookRed, width: 1.4),
    ),
  );
}

class FinancePrimaryButton extends StatelessWidget {
  const FinancePrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: logbookAccent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onTap,
          child: Center(
            child:
                loading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                    : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}

class FinanceDangerButton extends StatelessWidget {
  const FinanceDangerButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: logbookRed,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: const Icon(Icons.delete_outline_rounded, size: 19),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Error line shown inside an editor sheet.
class FinanceFormError extends StatelessWidget {
  const FinanceFormError({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: logbookRedSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message!,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: logbookRed,
        ),
      ),
    );
  }
}
