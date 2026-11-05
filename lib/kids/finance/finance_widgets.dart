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

IconData financePocketIcon(String name) {
  final key = name.toLowerCase();

  if (key.contains('cash') || key.contains('tunai') || key.contains('uang')) {
    return Icons.payments_rounded;
  }
  if (key.contains('snack') ||
      key.contains('food') ||
      key.contains('makan') ||
      key.contains('jajan')) {
    return Icons.fastfood_rounded;
  }
  if (key.contains('saving') || key.contains('tabung')) {
    return Icons.savings_rounded;
  }
  if (key.contains('travel') ||
      key.contains('trip') ||
      key.contains('libur') ||
      key.contains('jalan')) {
    return Icons.flight_takeoff_rounded;
  }
  if (key.contains('school') ||
      key.contains('sekolah') ||
      key.contains('education')) {
    return Icons.school_rounded;
  }
  if (key.contains('game') || key.contains('main')) {
    return Icons.sports_esports_rounded;
  }
  if (key.contains('gift') || key.contains('hadiah')) {
    return Icons.redeem_rounded;
  }
  if (key.contains('book') || key.contains('buku')) {
    return Icons.menu_book_rounded;
  }

  return Icons.account_balance_wallet_rounded;
}

Color financePocketTint(String name) {
  final key = name.toLowerCase();

  if (key.contains('cash') || key.contains('tunai') || key.contains('uang')) {
    return const Color(0xFF2E7D32);
  }
  if (key.contains('snack') ||
      key.contains('food') ||
      key.contains('makan') ||
      key.contains('jajan')) {
    return const Color(0xFF1976D2);
  }
  if (key.contains('saving') || key.contains('tabung')) {
    return const Color(0xFFB07A12);
  }
  if (key.contains('travel') ||
      key.contains('trip') ||
      key.contains('libur') ||
      key.contains('jalan')) {
    return const Color(0xFF7B4FBF);
  }
  if (key.contains('school') || key.contains('sekolah')) {
    return const Color(0xFF2A6EA8);
  }
  if (key.contains('game') || key.contains('main')) {
    return const Color(0xFFC2477A);
  }
  if (key.contains('gift') || key.contains('hadiah')) {
    return const Color(0xFFB03A48);
  }

  return logbookAccent;
}

/// Round pocket badge: image URL, emoji, or the falls-back icon.
class FinancePocketAvatar extends StatelessWidget {
  const FinancePocketAvatar({
    super.key,
    required this.image,
    required this.name,
    this.size = 48,
  });

  final String? image;
  final String name;
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
    final tint = financePocketTint(name);
    final fallback = Icon(
      financePocketIcon(name),
      size: size * 0.5,
      color: tint,
    );

    final Widget content;
    if (imageUrl != null) {
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
        color: tint.withValues(alpha: 0.12),
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
        child: Padding(
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
