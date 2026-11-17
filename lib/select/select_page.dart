import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thesis_fulgens_mobile/core/auth/session_manager.dart';
import 'package:thesis_fulgens_mobile/kids/logbook/logbook_tokens.dart';
import 'package:thesis_fulgens_mobile/select/kid_scene.dart';
import 'package:thesis_fulgens_mobile/select/paging_dots.dart';

// Role select
class SelectPage extends StatefulWidget {
  const SelectPage({super.key});

  @override
  State<SelectPage> createState() => _SelectPageState();
}

// Select state
class _SelectPageState extends State<SelectPage>
    with TickerProviderStateMixin {
  // Full-bleed pages
  final PageController _pages = PageController();

  final SessionManager sessionManager = SessionManager.instance;

  bool _checkingSession = true;

  // Kid side arrival
  late final AnimationController _sideIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  // Entrance playhead
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  // Parent colors
  static const Color _cream = Color(0xFFF9F7F3);

  @override
  void initState() {
    super.initState();

    // Restore the previous session and skip the login screen when possible.
    _checkingSession = false;
    _pages.addListener(_onPageChanged);
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) unawaited(_redirectIfAuthenticated());
    // });
  }

  Future<void> _redirectIfAuthenticated() async {
    final token = await sessionManager.getValidToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() => _checkingSession = false);
      return;
    }

    final role = sessionManager.getUserRole(token);
    if (!mounted) return;

    if (role == 'PARENT') {
      context.go('/parent/home');
      return;
    }
    if (role == 'USER') {
      context.go('/kids/home');
      return;
    }

    setState(() => _checkingSession = false);
  }

  @override
  void dispose() {
    _pages.removeListener(_onPageChanged);
    _sideIn.dispose();
    _reveal.dispose();
    _pages.dispose();
    super.dispose();
  }

  // Kid arrival
  void _onPageChanged() {
    if (!_pages.hasClients) return;
    final double page = _pages.page ?? 0;
    if (page >= 0.5) {
      if (!_sideIn.isAnimating && _sideIn.value == 0) {
        _sideIn.forward();
      }
    } else {
      _sideIn.value = 0;
    }
  }

  // Jump to side
  void _goToPage(int i) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _pages.jumpToPage(i);
      return;
    }
    _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 320),
      curve: const Cubic(0.23, 1, 0.32, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: _cream,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    // Reduced motion
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: _cream,
      body: AnimatedBuilder(
        animation: Listenable.merge([_pages, _reveal, _sideIn]),
        builder: (context, _) {
          // Live page
          final double raw = _pages.hasClients ? (_pages.page ?? 0.0) : 0.0;
          final double t = raw.clamp(0.0, 1.0);
          // Scene weight
          final double scene = Curves.easeInOut.transform(t);
          // Bleed color
          final Color bg = Color.lerp(_cream, const Color(0xFF17251D), scene)!;
          // Entrance playhead
          final double play = reduced ? 1.0 : _reveal.value;
          // Kid playhead
          final double kidPlay =
              play *
              (reduced
                  ? 1.0
                  : const Cubic(0.23, 1, 0.32, 1).transform(_sideIn.value));
          return Container(
            color: bg,
            child: Stack(
              children: [
                PageView(
                  controller: _pages,
                  children: [
                    // Parent side
                    _Depth(
                      depth: reduced ? 0 : t,
                      child: _ParentSide(
                        play: play,
                        onEnter: () => context.push('/parent'),
                      ),
                    ),
                    // Kid side
                    _Depth(
                      depth: reduced ? 0 : 1 - t,
                      child: KidScene(
                        play: kidPlay,
                        onEnter: () => context.push('/kids'),
                      ),
                    ),
                  ],
                ),
                // Paging dots
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: PagingDots(t: scene, onTap: _goToPage),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Page depth on the swipe
class _Depth extends StatelessWidget {
  const _Depth({required this.depth, required this.child});

  // 0 front, 1 pushed back
  final double depth;
  // Page content
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 1 - depth * 0.12,
      child: Transform.scale(scale: 1 - depth * 0.05, child: child),
    );
  }
}

// Parent side
class _ParentSide extends StatelessWidget {
  const _ParentSide({required this.play, required this.onEnter});

  // Entrance playhead
  final double play;
  // Enter parent
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wordmark
            _Reveal(
              play: play,
              start: 0.05,
              end: 0.4,
              child: Row(
                children: [
                  Text(
                    'Fulgens',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: logbookInk,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Headline
            _Reveal(
              play: play,
              start: 0.12,
              end: 0.5,
              child: Text(
                'Parent overview',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: logbookInk,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Support
            _Reveal(
              play: play,
              start: 0.2,
              end: 0.58,
              child: const Text(
                'Watch how the week is going. This view is read-only.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: logbookMuted,
                ),
              ),
            ),
            const SizedBox(height: 22),
            // Overview card
            _Reveal(
              play: play,
              start: 0.28,
              end: 0.68,
              child: const _OverviewCard(),
            ),
            const SizedBox(height: 16),
            // Category chips
            _Reveal(
              play: play,
              start: 0.36,
              end: 0.74,
              child: const _CategoryChips(),
            ),
            const Spacer(),
            // Enter
            _Reveal(
              play: play,
              start: 0.44,
              end: 0.82,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onEnter,
                  style: FilledButton.styleFrom(
                    backgroundColor: logbookInk,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Continue as parent',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// Week card
class _OverviewCard extends StatelessWidget {
  const _OverviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1A1A1A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent entries',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: logbookInk,
            ),
          ),
          const SizedBox(height: 14),
          // Real categories
          const _EntryLine(
            icon: Icons.card_giftcard_rounded,
            label: 'Gift',
            kind: 'Income',
            positive: true,
          ),
          const _EntryLine(
            icon: Icons.directions_bus_rounded,
            label: 'Transport',
            kind: 'Expense',
            positive: false,
          ),
          const _EntryLine(
            icon: Icons.school_rounded,
            label: 'School',
            kind: 'Expense',
            positive: false,
          ),
          const _EntryLine(
            icon: Icons.savings_rounded,
            label: 'Allowance',
            kind: 'Income',
            positive: true,
            last: true,
          ),
        ],
      ),
    );
  }
}

// One entry row
class _EntryLine extends StatelessWidget {
  const _EntryLine({
    required this.icon,
    required this.label,
    required this.kind,
    required this.positive,
    this.last = false,
  });

  // Row icon
  final IconData icon;
  // Category
  final String label;
  // Income or expense
  final String kind;
  // Direction
  final bool positive;
  // Trim spacing
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: logbookTrack,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: logbookInk),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: logbookInk,
            ),
          ),
          const Spacer(),
          Text(
            kind,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: positive ? logbookGreen : logbookMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// Category chips
class _CategoryChips extends StatelessWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context) {
    // Real categories
    const List<String> cats = [
      'Allowance',
      'Gift',
      'Transport',
      'School',
      'Hobby',
      'Entertainment',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cats
          .map(
            (c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0x0F1A1A1A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                c,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: logbookMuted,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// Mode tag
class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  // Label
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: logbookInk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: logbookInk,
        ),
      ),
    );
  }
}

// Rise in
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.play,
    required this.start,
    required this.end,
    required this.child,
  });

  // Playhead
  final double play;
  // Window in
  final double start;
  // Window out
  final double end;
  // Content
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Window local
    final double t = ((play - start) / (end - start)).clamp(0.0, 1.0);
    final double rise = const Cubic(0.23, 1, 0.32, 1).transform(t);
    return Opacity(
      opacity: rise,
      child: Transform.translate(
        offset: Offset(0, (1 - rise) * 16),
        child: child,
      ),
    );
  }
}
