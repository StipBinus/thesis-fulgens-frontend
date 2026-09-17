import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Preview page
class FulgensPreviewPage extends StatelessWidget {
  const FulgensPreviewPage({super.key});

  static const String assetPath = 'assets/app/fulgens.png';
  static const String bgPath = 'assets/app/log_bg.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      appBar: AppBar(
        title: const Text('Fulgens Preview — Iterasi A'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          TextButton(
            onPressed: () => _showApprovalDialog(context),
            child: const Text('Approve?'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD6BF)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Iterasi A — GPT Exact (JPG→SVG via vtracer, 1:1)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Button: 1570x1001 → 3KB SVG (outside git converter) • Fulgens: 1254x1254 → 27KB SVG\n'
                    'Opsi A: Fulgens hanya di putih (bottom:22), bar ijo bersih • Status: DRAFT preview, belum ke Homepage',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6D4C41), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Preview 1
            const Text('1. Karakter Only (Transparent) — 512x512',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E0D8)),
                // Checkerboard
              ),
              child: Stack(
                children: [
                  // Checkerboard bg
                  Positioned.fill(
                    child: CustomPaint(painter: _CheckerPainter()),
                  ),
                  Center(
                    child: Image.asset(
                      assetPath,
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text('Background transparan — siap pakai di card ijo-putih nanti. Ukuran 512px, SVG vector (2kb).',
                style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
            const SizedBox(height: 20),

            // Preview 2
            const Text('2. Di Card Putih (Preview Clean)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E0D8)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Center(
                child: Image.asset(assetPath, width: 160, height: 160, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),

            // Preview 3
            const Text('3. Mock — Log Progress Button OPSI A (Fulgens Hanya di Putih)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Fulgens nongol cuma dari putih (bottom:22), bar ijo bawah tetap bersih. Tap card = buka Input overlay.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFFF0E6), borderRadius: BorderRadius.circular(8)),
              child: const Text('Opsi A — Exactly like AFK, bottom 22px (tinggi bar ijo)',
                  style: TextStyle(fontSize: 10, color: Color(0xFFE65100), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            // Card mock
            Center(child: _LogProgressCardMock(assetPath: assetPath, bgPath: bgPath, fulgensBottom: 18, fulgensLeft: -2, fulgensSize: 72)),
            const SizedBox(height: 12),
            const Text('Varian: Opsi A (white-only). Sebelumnya top:-18 menutup ijo, sekarang bottom:22 hanya putih.',
                style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
            const SizedBox(height: 12),
            // Comparison
            const Text('Perbandingan: Sebelum (top:-18) vs Opsi A (bottom:22)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF616161))),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Column(
                    children: [
                      Text('Sebelum', style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                      SizedBox(height: 4),
                      _LogProgressCardMock(assetPath: assetPath, bgPath: bgPath, fulgensBottom: null, fulgensLeft: -6, fulgensTop: -18, fulgensSize: 72, label: 'SEBELUM'),
                    ],
                  ),
                  SizedBox(width: 16),
                  Column(
                    children: [
                      Text('Opsi A', style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      _LogProgressCardMock(assetPath: assetPath, bgPath: bgPath, fulgensBottom: 18, fulgensLeft: -2, fulgensSize: 72, highlight: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Preview 4
            const Text('4. Size Test (kecil di HP 1080p)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sizeBox('48px', 48),
                _sizeBox('64px', 64),
                _sizeBox('80px', 80),
                _sizeBox('120px', 120),
              ],
            ),
            const SizedBox(height: 24),

            // Approval
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gate Approval — Kamu yang pick:',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2E7D32))),
                  const SizedBox(height: 8),
                  const Text('• Jika OKE: bilang "Approve v1" → aku akan tempel card ini ke Homepage (pojok kiri bawah) + build.',
                      style: TextStyle(fontSize: 11, height: 1.4)),
                  const Text('• Jika REVISI: bilang "Revisi: pensil lebih gede / ekor lebih fluffy / mata lebih bulat" → aku bikin v2.',
                      style: TextStyle(fontSize: 11, height: 1.4)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showApprovalDialog(context),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
                          child: const Text('Lihat Detail File'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _showApprovalDialog(context),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF7A45)),
                          child: const Text('Approve v1'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Homepage tetap blank — card belum ditempel sampai kamu approve.\nAsset: fulgens_gpt.svg (27KB) + log_progress_bg.svg (3KB) — converter di tools/svg-converter (outside git)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFFBDBDBD)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sizeBox(String label, double size) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          padding: const EdgeInsets.all(4),
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF757575))),
      ],
    );
  }

  void _showApprovalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approval Gate'),
        content: const Text(
          'Ini preview Iterasi A.\n\n'
          '• Bilang "Approve v1" di chat → aku tempel ke Homepage.\n'
          '• Bilang "Revisi: ..." → aku bikin v2.\n\n'
          'Homepage masih blank sampai kamu approve (sesuai requestmu).',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ],
      ),
    );
  }
}

class _LogProgressCardMock extends StatelessWidget {
  const _LogProgressCardMock({
    required this.assetPath,
    required this.bgPath,
    this.fulgensBottom,
    this.fulgensLeft = -4,
    this.fulgensTop,
    this.fulgensSize = 88,
    this.highlight = false,
    this.label,
  });
  final String assetPath;
  final String bgPath;
  final double? fulgensBottom;
  final double fulgensLeft;
  final double? fulgensTop;
  final double fulgensSize;
  final bool highlight;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isOpsiA = fulgensBottom != null;
    return Container(
      height: 78,
      width: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlight ? const Color(0xFF4CAF50) : const Color(0xFFE0E0E0), width: highlight ? 2 : 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(bgPath, width: 220, height: 78, fit: BoxFit.fill),
          ),
          // Label
          const Positioned(
            left: 78,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log Progress', style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                SizedBox(height: 1),
                Text('TAP TO LOG', style: TextStyle(fontSize: 13, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              ],
            ),
          ),
          // Count
          Positioned(
            left: 82,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_outlined, size: 10, color: Colors.white),
                  SizedBox(width: 3),
                  Text('779', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          // Chevron
          const Positioned(right: 10, bottom: 6, child: Icon(Icons.chevron_right, size: 16, color: Colors.white70)),
          // Character
          Positioned(
            left: fulgensLeft,
            top: fulgensTop,
            bottom: fulgensBottom,
            child: Image.asset(assetPath, width: fulgensSize, height: fulgensSize, fit: BoxFit.contain),
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
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: const Icon(Icons.card_giftcard, size: 14, color: Colors.white),
            ),
          ),
          if (label != null)
            Positioned(
              top: -10,
              left: 60,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOpsiA ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(label!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double s = 16;
    final paintLight = Paint()..color = const Color(0xFFF5F5F5);
    final paintDark = Paint()..color = const Color(0xFFE0E0E0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintLight);
    for (double y = 0; y < size.height; y += s) {
      for (double x = 0; x < size.width; x += s) {
        if (((x / s).floor() + (y / s).floor()) % 2 == 1) {
          canvas.drawRect(Rect.fromLTWH(x, y, s, s), paintDark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
