import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Log progress button
class LogProgressButton extends StatelessWidget {
  const LogProgressButton({
    super.key,
    required this.onTap,
    this.countText = '779',
    this.width = 220,
    this.height = 78,
  });

  final VoidCallback onTap;
  final String countText;
  final double width;
  final double height;

  static const String bgSvg = 'assets/app/log_progress_bg.svg';
  static const String fulgensSvg = 'assets/app/fulgens.svg';
  static const String singleSvg = 'assets/app/log_progress_button.svg';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SvgPicture.asset(
                bgSvg,
                width: width,
                height: height,
                fit: BoxFit.fill,
                placeholderBuilder: (ctx) => Container(
                  width: width,
                  height: height,
                  color: const Color(0xFFF5F2ED),
                ),
              ),
            ),
            // Label
            const Positioned(
              left: 78,
              top: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log Progress',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9E9E9E),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'TAP TO LOG',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            // Count pill
            Positioned(
              left: 82,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_outlined, size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      countText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              right: 10,
              bottom: 6,
              child: Icon(Icons.chevron_right, size: 16, color: Colors.white70),
            ),
            // Character
            Positioned(
              left: -2,
              bottom: 18,
              child: SvgPicture.asset(
                fulgensSvg,
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                placeholderBuilder: (ctx) => const SizedBox(width: 72, height: 72),
              ),
            ),
            // Gift icon
            Positioned(
              right: 42,
              top: -8,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.card_giftcard, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Log progress button single SVG
class LogProgressButtonSingleSvg extends StatelessWidget {
  const LogProgressButtonSingleSvg({super.key, required this.onTap, this.width = 220, this.height = 78});
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SvgPicture.asset(
          'assets/app/log_progress_button.svg',
          width: width,
          height: height,
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}
