import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fuse-inspired design tokens for the parent side of the app.
///
/// Fuse keeps its wallet screens almost monochrome: a near-white canvas, flat
/// borderless cards, oversized numbers whose last digits fade to grey, and one
/// accent colour. Fulgens keeps its own warm palette, so the accent stays the
/// brand orange instead of black.
class ParentPalette {
  ParentPalette._();

  /// Warm off-white behind every parent screen.
  static const Color canvas = Color(0xFFF9F7F3);

  /// Flat card fill (Fuse uses a very light grey, Fulgens uses warm sand).
  static const Color card = Color(0xFFF7F5F1);

  /// Cards that need to sit above the canvas, e.g. the calendar sheet.
  static const Color raised = Colors.white;

  static const Color ink = Color(0xFF1A1A1A);
  static const Color label = Color(0xFF8A8378);
  static const Color faint = Color(0xFFB9AFA1);
  static const Color line = Color(0xFFEFEBE4);

  static const Color accent = Color(0xFFFF7A45);
  static const Color accentLight = Color(0xFFFF9A57);
  static const Color accentDeep = Color(0xFFFF6A3D);

  static const Color green = Color(0xFF1F7A45);
  static const Color red = Color(0xFFB3402F);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentLight, accentDeep],
  );
}

/// Poppins is the parent-side voice. The theme's `fontFamily: 'Inter'` is not
/// bundled, so every parent surface asks google_fonts directly instead.
TextStyle parentText({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = ParentPalette.ink,
  double? height,
  double? letterSpacing,
}) {
  return GoogleFonts.poppins(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

// ---------------------------------------------------------------- formatting

/// `1250000` -> `1.250.000`.
String parentGrouped(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }

  return buffer.toString();
}

/// `1250000` -> `Rp 1.250.000`.
String parentRupiah(int value) {
  return 'Rp ${value < 0 ? '-' : ''}${parentGrouped(value)}';
}

// ------------------------------------------------------------------ surfaces

/// Flat, borderless card. Fuse's cards are pure fill with a generous radius, so
/// there is no border and no hairline here either.
class ParentCard extends StatelessWidget {
  const ParentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = ParentPalette.card,
    this.radius = 24,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: ShapeDecoration(color: color, shape: shape),
        child: Padding(padding: padding, child: child),
      );
    }

    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small title above a group of cards, with an optional trailing action.
class ParentSectionHeader extends StatelessWidget {
  const ParentSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: parentText(size: 15, weight: FontWeight.w700),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// White circle with a back arrow, the way Fuse floats its back affordance.
class ParentBackButton extends StatelessWidget {
  const ParentBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ParentPalette.raised,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: ParentPalette.ink,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- numbers

/// The hero balance: label on top, then an oversized amount whose last three
/// digits fade to grey, mirroring how Fuse fades the cents of `$8.98`.
class ParentHeroBalance extends StatelessWidget {
  const ParentHeroBalance({
    super.key,
    required this.amount,
    this.label = 'Total balance',
    this.badge,
    this.caption,
    this.valueSize = 40,
  });

  final int amount;
  final String label;

  /// Small pill next to the label, e.g. the APY or a ratio.
  final String? badge;

  /// Line under the amount, e.g. the selected child's name.
  final String? caption;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final grouped = parentGrouped(amount);
    // Keep the thousands group together with the dot: 1.250.000 -> 1.250|.000
    final hasTail = grouped.length > 4;
    final head = hasTail ? grouped.substring(0, grouped.length - 4) : grouped;
    final tail = hasTail ? grouped.substring(grouped.length - 4) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: parentText(
                size: 12.5,
                weight: FontWeight.w600,
                color: ParentPalette.label,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ParentPalette.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: parentText(
                    size: 10.5,
                    weight: FontWeight.w700,
                    color: ParentPalette.green,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Rp ',
                style: parentText(
                  size: valueSize * 0.5,
                  weight: FontWeight.w700,
                  color: ParentPalette.faint,
                ),
              ),
              TextSpan(
                text: head,
                style: parentText(
                  size: valueSize,
                  weight: FontWeight.w800,
                  color: ParentPalette.ink,
                  letterSpacing: -1.4,
                ),
              ),
              if (tail.isNotEmpty)
                TextSpan(
                  text: tail,
                  style: parentText(
                    size: valueSize,
                    weight: FontWeight.w800,
                    color: ParentPalette.faint,
                    letterSpacing: -1.4,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: parentText(
              size: 12.5,
              weight: FontWeight.w500,
              color: ParentPalette.label,
            ),
          ),
        ],
      ],
    );
  }
}

/// Thin bar sparkline over a dashed baseline, the hero chart on Fuse's wallet.
class ParentSparkline extends StatelessWidget {
  const ParentSparkline({
    super.key,
    required this.values,
    this.height = 48,
    this.color = ParentPalette.accent,
    this.activeIndex,
  });

  final List<double> values;
  final double height;
  final Color color;

  /// Bar drawn at full strength; defaults to the last one.
  final int? activeIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color,
          activeIndex: activeIndex,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.color,
    this.activeIndex,
  });

  final List<double> values;
  final Color color;
  final int? activeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    // Dashed baseline first, so the bars sit on top of it.
    final baseline = Paint()
      ..color = ParentPalette.line
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, size.height - 0.7),
        Offset((x + 3).clamp(0, size.width), size.height - 0.7),
        baseline,
      );
    }

    if (values.isEmpty) return;

    final peak = values.reduce((a, b) => a > b ? a : b);
    final maxValue = peak <= 0 ? 1.0 : peak;
    final slot = size.width / values.length;
    final barWidth = slot < 6 ? slot * 0.55 : 3.2;
    final active = activeIndex ?? values.length - 1;
    final chartHeight = size.height - 6;

    for (var i = 0; i < values.length; i++) {
      final ratio = (values[i] / maxValue).clamp(0.06, 1.0);
      final barHeight = chartHeight * ratio;
      final left = slot * i + (slot - barWidth) / 2;

      final paint = Paint()
        ..color =
            i == active
                ? color
                : color.withValues(alpha: 0.32)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - 4 - barHeight, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.activeIndex != activeIndex;
  }
}

// ----------------------------------------------------------------------- tabs

/// Underline tab row, Fuse's range selector (`1D 1W 1M 6M 1Y`).
class ParentUnderlineTabs extends StatelessWidget {
  const ParentUnderlineTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i == labels.length - 1 ? 0 : 22,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: parentText(
                          size: 13,
                          weight:
                              i == index ? FontWeight.w700 : FontWeight.w500,
                          color:
                              i == index
                                  ? ParentPalette.ink
                                  : ParentPalette.label,
                        ),
                      ),
                      const SizedBox(height: 7),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        height: 2.4,
                        decoration: BoxDecoration(
                          color:
                              i == index
                                  ? ParentPalette.accent
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
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
}

// ---------------------------------------------------------------------- tiles

/// One square of the 2x2 grid: tinted icon, bold label, muted caption.
///
/// [dashed] renders the empty state, like Fuse's unused card slot.
class ParentTile extends StatelessWidget {
  const ParentTile({
    super.key,
    required this.icon,
    required this.label,
    this.caption,
    this.tint = ParentPalette.accent,
    this.dashed = false,
    this.onTap,
    this.height = 124,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final Color tint;
  final bool dashed;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 20, color: tint),
        ),
        const Spacer(),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: parentText(size: 14.5, weight: FontWeight.w700),
        ),
        if (caption != null) ...[
          const SizedBox(height: 3),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: parentText(
              size: 12,
              weight: FontWeight.w500,
              color: ParentPalette.label,
            ),
          ),
        ],
      ],
    );

    return SizedBox(
      height: height,
      child:
          dashed
              ? CustomPaint(
                foregroundPainter: _DashedBorderPainter(
                  color: ParentPalette.faint,
                  radius: 24,
                  strokeWidth: 1.2,
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: body,
                    ),
                  ),
                ),
              )
              : ParentCard(
                padding: const EdgeInsets.all(16),
                onTap: onTap,
                child: body,
              ),
    );
  }
}

// -------------------------------------------------------------------- buttons

/// Small white pill with an icon, like Fuse's floating `Swap` / `Send`.
class ParentPill extends StatelessWidget {
  const ParentPill({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Filled pills use the brand gradient for the primary action.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = const StadiumBorder();
    final foreground = filled ? Colors.white : ParentPalette.ink;

    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: ShapeDecoration(
          shape: shape,
          color: filled ? null : ParentPalette.raised,
          gradient: filled ? ParentPalette.accentGradient : null,
          shadows: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: foreground),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: parentText(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width gradient CTA.
class ParentPrimaryButton extends StatelessWidget {
  const ParentPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        height: height,
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          gradient:
              enabled
                  ? ParentPalette.accentGradient
                  : const LinearGradient(
                    colors: [Color(0xFFF0D8C8), Color(0xFFE7C8B4)],
                  ),
          shadows:
              enabled
                  ? const [
                    BoxShadow(
                      color: Color(0x33FF7A45),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ]
                  : null,
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
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
                      style: parentText(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}

/// Filled input used across the parent forms.
InputDecoration parentInputDecoration({
  String? hint,
  String? error,
  Widget? suffixIcon,
  Widget? prefixIcon,
  BoxConstraints? prefixIconConstraints,
  String? label,
}) {
  OutlineInputBorder border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: parentText(
      size: 14,
      weight: FontWeight.w500,
      color: ParentPalette.faint,
    ),
    labelStyle: parentText(
      size: 13,
      weight: FontWeight.w500,
      color: ParentPalette.label,
    ),
    filled: true,
    fillColor: ParentPalette.card,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    prefixIconConstraints: prefixIconConstraints,
    errorText: error,
    errorStyle: parentText(
      size: 11.5,
      weight: FontWeight.w500,
      color: ParentPalette.red,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: border(Colors.transparent, 1.2),
    enabledBorder: border(Colors.transparent, 1.2),
    focusedBorder: border(ParentPalette.accent, 1.4),
    errorBorder: border(ParentPalette.red, 1.2),
    focusedErrorBorder: border(ParentPalette.red, 1.4),
  );
}

// ---------------------------------------------------------------- navigation

/// Fuse's bottom row: two plain tab icons on the left, a floating gradient
/// button on the right. Index 0 is Home, index 1 is Assign task.
class ParentBottomNav extends StatelessWidget {
  const ParentBottomNav({
    super.key,
    required this.index,
    required this.onSelect,
    this.onFabPressed,
    this.fabTooltip = 'Add child',
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback? onFabPressed;
  final String fabTooltip;

  static const List<IconData> _icons = [
    Icons.home_rounded,
    Icons.assignment_turned_in_rounded,
  ];

  static const List<String> _labels = ['Home', 'Assign task'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 6, 20, 12),
        child: Row(
          children: [
            for (var i = 0; i < _icons.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 26),
                child: _NavIcon(
                  icon: _icons[i],
                  label: _labels[i],
                  selected: i == index,
                  onTap: () => onSelect(i),
                ),
              ),
            const Spacer(),
            if (onFabPressed != null)
              Tooltip(
                message: fabTooltip,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    width: 54,
                    height: 54,
                    decoration: const ShapeDecoration(
                      shape: CircleBorder(),
                      gradient: ParentPalette.accentGradient,
                      shadows: [
                        BoxShadow(
                          color: Color(0x40FF7A45),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: onFabPressed,
                      child: const Icon(
                        Icons.add_rounded,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 25,
              color: selected ? ParentPalette.ink : ParentPalette.faint,
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 14 : 0,
              height: 2.4,
              decoration: BoxDecoration(
                color: ParentPalette.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- painters

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Offset.zero & size,
              Radius.circular(radius),
            ),
          );

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = color;

    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
