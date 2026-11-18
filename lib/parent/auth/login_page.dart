import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';
import 'dart:math' as math;
import '../../core/auth/session_manager.dart';
import '../ui/parent_ui.dart';

// Login phases
enum _LoginPhase { form, settingUp, ready }

// Login screen
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // Field controllers
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final sessionManager = SessionManager.instance;
  // Password peek
  bool _obscure = true;
  // Busy flag
  bool _busy = false;
  // Error copy
  String? _error;
  // Role destination
  String _nextRoute = '/parent/home';
  // Setup phase
  _LoginPhase _phase = _LoginPhase.form;
  // Setup driver
  late final AnimationController _setup;
  // Ring driver
  late final AnimationController _spin;
  // Fake load
  Timer? _fakeLoad;
  // Form exit fade
  late final Animation<double> _formFade;
  // Form exit drift
  late final Animation<Offset> _formExit;
  // Row entrance fade
  late final Animation<double> _rowFade;
  // Row entrance rise
  late final Animation<Offset> _rowRise;
  // Block entrance fade
  late final Animation<double> _blockFade;
  // Block entrance rise
  late final Animation<Offset> _blockRise;
  // Entrance driver
  late final AnimationController _enter;
  // Entrance fade
  late final Animation<double> _fade;
  // Entrance rise
  late final Animation<Offset> _rise;

  @override
  void initState() {
    super.initState();
    // Entrance setup
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    const Cubic ease = Cubic(0.23, 1, 0.32, 1);
    final CurvedAnimation curve = CurvedAnimation(parent: _enter, curve: ease);
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _rise = Tween<Offset>(
      begin: const Offset(0.0, 0.04),
      end: Offset.zero,
    ).animate(curve);
    _enter.forward();
    // Setup driver
    _setup = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    // Ring driver
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Form exit fade
    _formFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _setup,
        curve: const Interval(0.0, 0.55, curve: ease),
      ),
    );
    // Form exit drift
    _formExit = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -0.05),
    ).animate(
      CurvedAnimation(
        parent: _setup,
        curve: const Interval(0.0, 0.9, curve: ease),
      ),
    );
    // Row entrance fade
    _rowFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _setup,
        curve: const Interval(0.3, 0.75, curve: ease),
      ),
    );
    // Row entrance rise
    _rowRise = Tween<Offset>(
      begin: const Offset(0.0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _setup,
        curve: const Interval(0.3, 0.75, curve: ease),
      ),
    );
    // Block entrance fade
    _blockFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _setup,
        curve: const Interval(0.42, 1.0, curve: ease),
      ),
    );
    // Block entrance rise
    _blockRise = Tween<Offset>(
      begin: const Offset(0.0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _setup,
        curve: const Interval(0.42, 1.0, curve: ease),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion
    _enter.duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 800);
    // Setup duration
    _setup.duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 620);
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    _fakeLoad?.cancel();
    _setup.dispose();
    _spin.dispose();
    _enter.dispose();
    super.dispose();
  }

  // Sign in
  Future<void> _login() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    // Required fields
    final username = usernameController.text.trim();
    final password = passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Enter your username and password.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final accessToken = await sessionManager.signIn(
        username: username,
        password: password,
      );

      final role = sessionManager.getUserRole(accessToken);

      if (!mounted) return;

      if (role == 'PARENT' || role == 'USER') {
        // Role handoff
        _nextRoute = role == 'PARENT' ? '/parent/home' : '/kids/home';
        // Setup run
        //TODO: Ini nanti buat page untuk create user
        //context.go('/child-register');
        context.go(_nextRoute);
        return;
      }

      // Unknown role
      await sessionManager.clear();
      if (!mounted) return;
      setState(() {
        _error = 'This account has no app access. Contact support.';
        _busy = false;
      });
    } on SessionException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    } catch (_) {
      // Network failure
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server. Check your connection.';
        _busy = false;
      });
    }
  }

  // Setup start
  void _beginSetup() {
    setState(() {
      _phase = _LoginPhase.settingUp;
    });
    _setup.forward();
    // Ring spin
    if (!MediaQuery.disableAnimationsOf(context)) {
      _spin.repeat();
    }
    _fakeLoad?.cancel();
    // Fake load
    _fakeLoad = Timer(const Duration(milliseconds: 2200), _finishSetup);
  }

  // Setup done
  void _finishSetup() {
    if (!mounted) return;
    _spin.stop();
    setState(() {
      _phase = _LoginPhase.ready;
    });
    // Parent home handoff
    final reduce = MediaQuery.disableAnimationsOf(context);
    Timer(reduce ? Duration.zero : const Duration(milliseconds: 900), () {
      if (mounted) context.pushReplacement(_nextRoute);
    });
  }

  // Google pending
  void _googlePending() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google sign-in is not enabled yet. Use your account.'),
      ),
    );
  }

  // Setup view
  Widget _buildSetup() {
    final bool ready = _phase == _LoginPhase.ready;
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    // Ring mark
    final Widget ring = AnimatedBuilder(
      key: const ValueKey('ring'),
      animation: _spin,
      builder:
          (context, child) =>
              Transform.rotate(angle: _spin.value * 2 * math.pi, child: child),
      child: CustomPaint(
        painter: _DashRingPainter(ParentPalette.accent),
        size: const Size.square(22),
      ),
    );
    // Check mark
    final Widget check = Container(
      key: const ValueKey('check'),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ParentPalette.green,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
    );
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 64, right: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Signed in row
            FadeTransition(
              opacity: _rowFade,
              child: SlideTransition(
                position: _rowRise,
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: ParentPalette.faint,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Signed in as ${usernameController.text.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: parentText(
                          size: 15,
                          weight: FontWeight.w500,
                          color: ParentPalette.faint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Active block
            FadeTransition(
              opacity: _blockFade,
              child: SlideTransition(
                position: _blockRise,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status mark
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: AnimatedSwitcher(
                        duration:
                            reduce
                                ? Duration.zero
                                : const Duration(milliseconds: 320),
                        switchInCurve: Curves.linear,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder:
                            (child, anim) => FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.6, end: 1)
                                    .animate(
                                      anim.drive(
                                        CurveTween(
                                          curve: Curves.easeOutBack,
                                        ),
                                      ),
                                    ),
                                child: child,
                              ),
                            ),
                        child: ready ? check : ring,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status copy
                    Expanded(
                      child: AnimatedSwitcher(
                        duration:
                            reduce
                                ? Duration.zero
                                : const Duration(milliseconds: 260),
                        transitionBuilder:
                            (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                        child: Column(
                          key: ValueKey(_phase),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ready
                                  ? 'Your world is ready!'
                                  : 'Setting up your world',
                              style: parentText(
                                size: 20,
                                weight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ready
                                  ? 'Time to explore.'
                                  : 'Hold tight — your panda is getting everything ready.',
                              style: parentText(
                                size: 14,
                                weight: FontWeight.w500,
                                height: 1.4,
                                color: ParentPalette.label,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentPalette.canvas,
      body: SafeArea(
        // Centered column
        child: GestureDetector(
          // Tap out
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Stack(
                children: [
                  // Form layer
                  IgnorePointer(
                    ignoring: _phase != _LoginPhase.form,
                    child: FadeTransition(
                      opacity: _formFade,
                      child: SlideTransition(
                        position: _formExit,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top breath
                              const SizedBox(height: 12),
                              Expanded(
                                flex: 2,
                                // Body entrance
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 28),
                                  child: FadeTransition(
                                    opacity: _fade,
                                    child: SlideTransition(
                                      position: _rise,
                                      child: SingleChildScrollView(
                                        keyboardDismissBehavior:
                                            ScrollViewKeyboardDismissBehavior
                                                .onDrag,
                                        child: AutofillGroup(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const SizedBox(height: 8),
                                              // Back edge
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Transform.translate(
                                                  offset: const Offset(-12, 0),
                                                  child: IconButton(
                                                    tooltip: 'Back',
                                                    onPressed: () {
                                                      // Back slide
                                                      if (context.canPop()) {
                                                        context.pop();
                                                      } else {
                                                        context.go(
                                                          '/parent?detail=1',
                                                        );
                                                      }
                                                    },
                                                    // Back icon
                                                    icon: SvgPicture.string(
                                                      '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#1A1A1A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><path d="m12 19-7-7 7-7"/></svg>',
                                                      width: 22,
                                                      height: 22,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Welcome back',
                                                style: parentText(
                                                  size: 24,
                                                  weight: FontWeight.w700,
                                                  letterSpacing: -0.4,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Sign in to keep an eye on '
                                                'their progress.',
                                                style: parentText(
                                                  size: 13,
                                                  weight: FontWeight.w500,
                                                  color: ParentPalette.label,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              // Field label
                                              Text(
                                                'Username',
                                                style: parentText(
                                                  size: 12.5,
                                                  weight: FontWeight.w600,
                                                  color: ParentPalette.label,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              TextField(
                                                controller: usernameController,
                                                autofillHints: const [
                                                  AutofillHints.username,
                                                ],
                                                autocorrect: false,
                                                textCapitalization:
                                                    TextCapitalization.none,
                                                textInputAction:
                                                    TextInputAction.next,
                                                style: parentText(
                                                  size: 14.5,
                                                  weight: FontWeight.w500,
                                                ),
                                                decoration:
                                                    parentInputDecoration(
                                                      hint:
                                                          'Your username',
                                                    ),
                                              ),
                                              const SizedBox(height: 16),
                                              // Field label
                                              Text(
                                                'Password',
                                                style: parentText(
                                                  size: 12.5,
                                                  weight: FontWeight.w600,
                                                  color: ParentPalette.label,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              TextField(
                                                controller: passwordController,
                                                autofillHints: const [
                                                  AutofillHints.password,
                                                ],
                                                autocorrect: false,
                                                enableSuggestions: false,
                                                obscureText: _obscure,
                                                textInputAction:
                                                    TextInputAction.done,
                                                onSubmitted: (_) => _login(),
                                                style: parentText(
                                                  size: 14.5,
                                                  weight: FontWeight.w500,
                                                ),
                                                decoration:
                                                    parentInputDecoration(
                                                      hint:
                                                          'Your password',
                                                      // Peek toggle
                                                      suffixIcon: IconButton(
                                                        tooltip:
                                                            _obscure
                                                                ? 'Show password'
                                                                : 'Hide password',
                                                        onPressed:
                                                            () => setState(
                                                              () =>
                                                                  _obscure =
                                                                      !_obscure,
                                                            ),
                                                        icon: Icon(
                                                          _obscure
                                                              ? Icons
                                                                  .visibility_outlined
                                                              : Icons
                                                                  .visibility_off_outlined,
                                                          size: 20,
                                                          color:
                                                              ParentPalette
                                                                  .label,
                                                        ),
                                                      ),
                                                    ),
                                              ),
                                              // Error slot
                                              if (_error != null) ...[
                                                const SizedBox(height: 12),
                                                Text(
                                                  _error!,
                                                  style: parentText(
                                                    size: 12.5,
                                                    weight: FontWeight.w500,
                                                    color: ParentPalette.red,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 20),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Pinned bottom
                              Padding(
                                padding: const EdgeInsets.only(right: 28),
                                child: FadeTransition(
                                  opacity: _fade,
                                  child: SlideTransition(
                                    position: _rise,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        ParentPrimaryButton(
                                          label: 'Login',
                                          loading: _busy,
                                          onPressed: _login,
                                        ),
                                        const SizedBox(height: 18),
                                        // Divider row
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: ColoredBox(
                                                color: ParentPalette.line,
                                                child: SizedBox(height: 1),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                              child: Text(
                                                'or',
                                                style: parentText(
                                                  size: 12,
                                                  weight: FontWeight.w500,
                                                  color: ParentPalette.faint,
                                                ),
                                              ),
                                            ),
                                            const Expanded(
                                              child: ColoredBox(
                                                color: ParentPalette.line,
                                                child: SizedBox(height: 1),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        // Google row
                                        Center(
                                          child: Material(
                                            color: ParentPalette.raised,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              side: const BorderSide(
                                                color: ParentPalette.line,
                                              ),
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              onTap: _googlePending,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 13,
                                                    ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    SvgPicture.asset(
                                                      'assets/app/google_g.svg',
                                                      width: 20,
                                                      height: 20,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      'Continue with Google',
                                                      style: parentText(
                                                        size: 14,
                                                        weight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Account link
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Don't have an account? ",
                                              style: parentText(
                                                size: 13,
                                                weight: FontWeight.w500,
                                                color: ParentPalette.label,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                // Navigate to register
                                                if (!context.mounted) {
                                                  return;
                                                }

                                                context.go('/parent/register');
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    ParentPalette.accent,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                              ),
                                              child: Text(
                                                'Register',
                                                style: parentText(
                                                  size: 13,
                                                  weight: FontWeight.w700,
                                                  color: ParentPalette.accent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                      ],
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
                  // Setup layer
                  if (_phase != _LoginPhase.form)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: _buildSetup(),
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

// Dash ring
class _DashRingPainter extends CustomPainter {
  _DashRingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 - 1.2;
    const int dashes = 9;
    for (int i = 0; i < dashes; i++) {
      final double start = (i / dashes) * 2 * math.pi;
      final double sweep = (2 * math.pi / dashes) * 0.45;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
