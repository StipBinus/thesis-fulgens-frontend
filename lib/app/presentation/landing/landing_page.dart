import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Parent landing
class LandingPage extends StatefulWidget {
  const LandingPage({super.key, this.showDetail = false});

  // Detail start
  final bool showDetail;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  // Cover or detail
  late bool _showDetail;
  // Swap point
  static const double _swapFrac = 0.22;
  static const double _swapBackFrac = 0.5;
  // Gen guard
  int _gen = 0;
  // Choreo driver
  late final AnimationController _choreo;
  // Title exit
  late final Animation<Offset> _titleExit;
  // Title fade
  late final Animation<double> _titleFade;
  // Link exit
  late final Animation<Offset> _linkExit;
  // Link fade
  late final Animation<double> _linkFade;
  // Report entrance
  late final Animation<Offset> _reportEnter;
  // Report fade
  late final Animation<double> _reportFade;
  // Login entrance
  late final Animation<Offset> _loginEnter;
  // Login fade
  late final Animation<double> _loginFade;

  @override
  void initState() {
    super.initState();
    _showDetail = widget.showDetail;
    // Choreo setup
    _choreo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    const Cubic ease = Cubic(0.23, 1, 0.32, 1);
    _titleExit = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0),
    ).animate(
      CurvedAnimation(
        parent: _choreo,
        curve: const Interval(0.0, 0.35, curve: ease),
      ),
    );
    _titleFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _choreo,
        curve: const Interval(0.0, 0.35, curve: ease),
      ),
    );
    _linkExit = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 0.5),
    ).animate(
      CurvedAnimation(
        parent: _choreo,
        curve: const Interval(0.08, 0.40, curve: ease),
      ),
    );
    _linkFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _choreo,
        curve: const Interval(0.08, 0.40, curve: ease),
      ),
    );
    _reportEnter = Tween<Offset>(
      begin: const Offset(0.35, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _choreo,
        curve: const Interval(0.15, 0.85, curve: ease),
      ),
    );
    _reportFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _choreo,
        curve: const Interval(0.15, 0.85, curve: ease),
      ),
    );
    _loginEnter = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _choreo,
        curve: const Interval(0.35, 0.85, curve: ease),
      ),
    );
    _loginFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _choreo,
        curve: const Interval(0.35, 0.85, curve: ease),
      ),
    );
    // Settled detail
    if (widget.showDetail) {
      _choreo.value = 1.0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion
    _choreo.duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 900);
  }

  @override
  void dispose() {
    _choreo.dispose();
    super.dispose();
  }

  // Go detail
  void _toDetail() {
    if (_showDetail) return;
    // Forward pace
    _choreo.duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 900);
    // Current gen
    final int gen = ++_gen;
    unawaited(_choreo.forward());
    Future.delayed(
      Duration(
        milliseconds: (_choreo.duration!.inMilliseconds * _swapFrac).round(),
      ),
      () {
        // Stale guard
        if (!mounted || gen != _gen) return;
        setState(() => _showDetail = true);
      },
    );
  }

  // Go cover
  void _toCover() {
    if (!_showDetail) return;
    // Reverse pace
    _choreo.duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 650);
    // Current gen
    final int gen = ++_gen;
    unawaited(_choreo.reverse());
    Future.delayed(
      Duration(
        milliseconds:
            (_choreo.duration!.inMilliseconds * _swapBackFrac).round(),
      ),
      () {
        // Stale guard
        if (!mounted || gen != _gen) return;
        setState(() => _showDetail = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Centered column
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top breath, near top on detail
                  AnimatedPadding(
                    duration:
                        _choreo.duration ??
                        const Duration(milliseconds: 900),
                    curve: const Cubic(0.23, 1, 0.32, 1),
                    // Detail rest
                    padding: EdgeInsets.only(
                      top:
                          _showDetail
                              ? 24.0
                              : MediaQuery.of(context).size.height * 0.22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo peering left
                        const _PeeringLogo(),
                        const SizedBox(height: 24),
                        // Hairline to content inset
                        Padding(
                          padding: const EdgeInsets.only(right: 28),
                          child: _HairlineBleed(
                            fill: _showDetail ? 0.62 : 0.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 2,
                    // Body rises with header
                    // Settled paint
                    child: Padding(
                      padding: const EdgeInsets.only(right: 28),
                      // Direct swap
                      child:
                          _showDetail ? _detail(context) : _cover(context),
                    ),
                  ),
                  // Pinned login
                  // Login swipe
                  Visibility(
                    visible: _showDetail,
                    maintainState: true,
                    maintainAnimation: true,
                    child: FadeTransition(
                      opacity: _loginFade,
                      child: SlideTransition(
                        position: _loginEnter,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 28),
                          child: Column(
                            children: [
                              FilledButton(
                                onPressed: () => context.push('/register'),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text(
                                  'Create an account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Account link
                              TextButton(
                                onPressed: () => context.push('/login'),
                                child: const Text(
                                  'I already have an account',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
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

  // First screen
  Widget _cover(BuildContext context) {
    return Column(
      key: const ValueKey('cover'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Title exit
        FadeTransition(
          opacity: _titleFade,
          child: SlideTransition(
            position: _titleExit,
            child: Text(
              'Tagline Placeholder',
              style: GoogleFonts.poppins(
                fontSize: 21,
                height: 1.4,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
        // Button under tagline
        const SizedBox(height: 28),
        // Cover exit
        FadeTransition(
          opacity: _titleFade,
          child: SlideTransition(
            position: _titleExit,
            child: FilledButton(
              onPressed: _toDetail,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'See how it works',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const Spacer(),
        // Child entry
        Center(
          // Link exit
          child: FadeTransition(
            opacity: _linkFade,
            child: SlideTransition(
              position: _linkExit,
              child: TextButton(
                onPressed: () => context.go('/kids'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1A1A1A),
                ),
                child: const Text(
                  'Switch to children',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Second screen
  Widget _detail(BuildContext context) {
    // Detail entrance
    return FadeTransition(
      opacity: _reportFade,
      child: SlideTransition(
        position: _reportEnter,
        child: Column(
          key: const ValueKey('detail'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                // Back arrow
                // Back edge
                Transform.translate(
                  offset: const Offset(-12, 0),
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: _toCover,
                    icon: SvgPicture.string(
                      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#1A1A1A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><path d="m12 19-7-7 7-7"/></svg>',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Report
            const _ReportBlock(),
          ],
        ),
      ),
    );
  }
}

// Peering logo
class _PeeringLogo extends StatefulWidget {
  const _PeeringLogo();

  @override
  State<_PeeringLogo> createState() => _PeeringLogoState();
}

class _PeeringLogoState extends State<_PeeringLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final curve = CurvedAnimation(
      parent: _c,
      curve: const Cubic(0.23, 1, 0.32, 1),
    );
    _opacity = curve;
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(curve);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Capped width at 85 percent
    final logoWidth = (width * 0.5 > 320 ? 320.0 : width * 0.5) * 0.85;
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        // Logo peer
        offset: const Offset(-16, 0),
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              'assets/app/fulgens_logo_parent.png',
              width: logoWidth,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// Hairline to far right
class _HairlineBleed extends StatefulWidget {
  const _HairlineBleed({required this.fill});

  // Fill target
  final double fill;

  @override
  State<_HairlineBleed> createState() => _HairlineBleedState();
}

class _HairlineBleedState extends State<_HairlineBleed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
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
  void didUpdateWidget(_HairlineBleed old) {
    super.didUpdateWidget(old);
    if (old.fill != widget.fill) {
      // Retarget fill
      _fill = Tween<double>(begin: _fill.value, end: widget.fill).animate(
        CurvedAnimation(parent: _c, curve: const Cubic(0.23, 1, 0.32, 1)),
      );
      _c.forward(from: 0.0);
    }
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

// Report
class _ReportBlock extends StatelessWidget {
  const _ReportBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This week',
          style: TextStyle(fontSize: 13, color: Color(0xFF8A8378)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'report placeholder',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'saved of Rp 100.000',
                  style: TextStyle(fontSize: 14, color: Color(0xFF8A8378)),
                ),
              ],
            ),
            const Text(
              '55%',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEC3B0A),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
