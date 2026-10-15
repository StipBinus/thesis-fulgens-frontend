import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Parent draft
class KidsLandingParentDraft extends StatefulWidget {
  const KidsLandingParentDraft({super.key});

  @override
  State<KidsLandingParentDraft> createState() => _KidsLandingParentDraftState();
}

class _KidsLandingParentDraftState extends State<KidsLandingParentDraft>
    with TickerProviderStateMixin {
  // Entrance
  late final AnimationController _in;
  // Bob
  late final AnimationController _bob;
  // Rise
  late final Animation<Offset> _rise;
  // Fade
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    const ease = Cubic(0.23, 1, 0.32, 1);
    _rise = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _in, curve: ease));
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _in, curve: const Interval(0, 0.7, curve: ease)),
    );
    _in.forward();
    _bob.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced
    if (MediaQuery.disableAnimationsOf(context)) {
      _in.value = 1.0;
      _bob.stop();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Center
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top
                  Padding(
                    padding: const EdgeInsets.only(top: 16, right: 28),
                    child: Row(
                      children: [
                        // Back
                        Transform.translate(
                          offset: const Offset(-12, 0),
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: () => context.go('/'),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        // Title
                        Text(
                          'Kids room',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Hairline
                  const Padding(
                    padding: EdgeInsets.only(right: 28),
                    child: _Hairline(fill: 0.45),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 28),
                      child: SingleChildScrollView(
                        child: FadeTransition(
                          opacity: _fade,
                          child: SlideTransition(
                            position: _rise,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Coins
                                AnimatedBuilder(
                                  animation: _bob,
                                  builder: (_, child) {
                                    final reduced =
                                        MediaQuery.disableAnimationsOf(
                                          context,
                                        );
                                    final dy =
                                        reduced ? 0.0 : (-3 + _bob.value * 6);
                                    return Transform.translate(
                                      offset: Offset(0, dy),
                                      child: child,
                                    );
                                  },
                                  child: const _CoinCluster(),
                                ),
                                const SizedBox(height: 20),
                                // Headline
                                Text(
                                  'Save while you play',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Subtext
                                Text(
                                  'Small missions, coins add up, habits grow.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: const Color(0xFF8A8378),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Steps
                                const _StepRow(
                                  icon: Icons.play_arrow_rounded,
                                  title: 'Play a little',
                                  body: 'One short mission each day.',
                                ),
                                const SizedBox(height: 12),
                                const _StepRow(
                                  icon: Icons.savings_outlined,
                                  title: 'Coins add up',
                                  body: 'Spare pocket money becomes savings.',
                                ),
                                const SizedBox(height: 12),
                                const _StepRow(
                                  icon: Icons.trending_up_rounded,
                                  title: 'Watch it grow',
                                  body: 'Clear progress every week.',
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // CTA
                  Padding(
                    padding: const EdgeInsets.only(
                      right: 28,
                      bottom: 8,
                    ),
                    child: FilledButton(
                      onPressed: () => context.go('/game'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Start playing',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Secondary
                  Padding(
                    padding: const EdgeInsets.only(right: 28, bottom: 12),
                    child: Center(
                      child: TextButton(
                        onPressed: () => context.go('/'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1A1A1A),
                        ),
                        child: const Text(
                          'Back to home',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Hairline
class _Hairline extends StatefulWidget {
  const _Hairline({required this.fill});

  // Fill
  final double fill;

  @override
  State<_Hairline> createState() => _HairlineState();
}

class _HairlineState extends State<_Hairline>
    with SingleTickerProviderStateMixin {
  // Controller
  late final AnimationController _c;
  // Fill
  late Animation<double> _fill;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fill = Tween<double>(begin: 0.0, end: widget.fill).animate(
      CurvedAnimation(parent: _c, curve: const Cubic(0.23, 1, 0.32, 1)),
    );
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fill,
      builder:
          (_, _) => SizedBox(
            width: double.infinity,
            height: 2,
            child: Stack(
              children: [
                Container(color: const Color(0xFFE8E2D9)),
                FractionallySizedBox(
                  widthFactor: _fill.value,
                  child: Container(color: const Color(0xFF1A1A1A)),
                ),
              ],
            ),
          ),
    );
  }
}

// Coins
class _CoinCluster extends StatelessWidget {
  const _CoinCluster();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Stack(
        children: [
          // Glow
          Positioned(
            left: 0,
            top: 8,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A45).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Back coin
          Positioned(
            left: 56,
            top: 18,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE3D1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF7A45).withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.savings_outlined,
                size: 30,
                color: Color(0xFFFF7A45),
              ),
            ),
          ),
          // Front coin
          Positioned(
            left: 8,
            top: 30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A45),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE56A2E), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFFF7A45,
                    ).withValues(alpha: 0.28),
                    offset: const Offset(0, 6),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Steps
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  // Icon
  final IconData icon;
  // Title
  final String title;
  // Body
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Disc
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E6),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE8E2D9), width: 1.5),
          ),
          child: Icon(icon, size: 22, color: const Color(0xFFFF7A45)),
        ),
        const SizedBox(width: 14),
        // Texts
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF8A8378),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
