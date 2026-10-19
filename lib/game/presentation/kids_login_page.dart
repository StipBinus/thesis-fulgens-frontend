import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:thesis_fulgens_mobile/core/config/api_config.dart';

import '../../app/presentation/auth_service/auth_service.dart';

// Login phases
enum _LoginPhase { form, loggingIn, savings, settingUp, ready }

// Kids login
class KidsLoginPage extends StatefulWidget {
  const KidsLoginPage({super.key});

  @override
  State<KidsLoginPage> createState() => _KidsLoginPageState();
}

class _KidsLoginPageState extends State<KidsLoginPage>
    with TickerProviderStateMixin {
  // Field controllers
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();
  final ApiConfig apiConfig = ApiConfig();
  // Password focus
  final passwordFocus = FocusNode();
  // Password peek
  bool _obscure = true;
  // Busy flag
  bool _busy = false;
  // Error copy
  String? _error;
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
  // Step index
  int _step = 0;
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
      duration: const Duration(milliseconds: 600),
    );
    const Cubic ease = Cubic(0.23, 1, 0.32, 1);
    final CurvedAnimation curve = CurvedAnimation(parent: _enter, curve: ease);
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _rise = Tween<Offset>(
      begin: const Offset(0.0, 0.03),
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion
    _enter.duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 600);
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
    passwordFocus.dispose();
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse(
          '${apiConfig.getKeycloakUrl()}/realms/fulgens/protocol/openid-connect/token',
        ),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': 'fulgens-mobile',
          'username': usernameController.text,
          'password': passwordController.text,
          'grant_type': 'password',
        },
      );

      if (response.statusCode != 200) {
        // Bad credentials
        if (!mounted) return;
        setState(() {
          _error = 'Username or password did not match. Try again.';
          _busy = false;
        });
        return;
      }

      final responseData = jsonDecode(response.body);
      final accessToken = responseData['access_token'];

      await authService.saveToken(accessToken);

      final role = authService.getUserRole(accessToken);

      if (!mounted) return;

      if (role == 'PARENT' || role == 'USER') {
        // Setup run
        _beginSetup();
        return;
      }

      // Unknown role
      setState(() {
        _error = 'This account has no app access. Contact support.';
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
      _phase = _LoginPhase.loggingIn;
    });
    _setup.forward();
    // Ring spin
    if (!MediaQuery.disableAnimationsOf(context)) {
      _spin.repeat();
    }
    _fakeLoad?.cancel();
    // Fake load
    _fakeLoad = Timer(const Duration(milliseconds: 900), _beginSavings);
  }

  // Savings start
  void _beginSavings() {
    if (!mounted) return;
    setState(() {
      _phase = _LoginPhase.savings;
    });
    _fakeLoad?.cancel();
    // Savings load
    _fakeLoad = Timer(const Duration(milliseconds: 900), _beginWorld);
  }

  // World start
  void _beginWorld() {
    if (!mounted) return;
    setState(() {
      _phase = _LoginPhase.settingUp;
    });
    _fakeLoad?.cancel();
    // World load
    _fakeLoad = Timer(const Duration(milliseconds: 1000), _finishSetup);
  }

  // Setup done
  void _finishSetup() {
    if (!mounted) return;
    _spin.stop();
    setState(() {
      _phase = _LoginPhase.ready;
    });
  }

  // Step forward
  void _advance() {
    if (_step == 1) {
      _login();
      return;
    }
    if (usernameController.text.trim().isEmpty) {
      setState(() {
        _error = 'Enter your username to continue.';
      });
      return;
    }
    setState(() {
      _error = null;
      _step = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) passwordFocus.requestFocus();
    });
  }

  // Step back
  void _back() {
    if (_phase != _LoginPhase.form) return;
    if (_step == 0) return;
    setState(() {
      _error = null;
      _step = 0;
    });
  }

  // Close edge
  void _close() {
    if (_phase != _LoginPhase.form) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/kids-start');
    }
  }

  // Setup view
  Widget _buildSetup() {
    // Setup tokens
    const Color ink = Color(0xFF1A1A1A);
    const Color muted = Color(0xFF6F695F);
    const Color greyed = Color(0xFF9A948A);
    const Color green = Color(0xFF34C759);
    final Color primary = Theme.of(context).colorScheme.primary;
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
        painter: _DashRingPainter(primary),
        size: const Size.square(26),
      ),
    );
    // Check mark
    final Widget check = Container(
      key: const ValueKey('check'),
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: green, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Signed in row
        FadeTransition(
          opacity: _rowFade,
          child: SlideTransition(
            position: _rowRise,
            child: AnimatedSwitcher(
              duration:
                  reduce ? Duration.zero : const Duration(milliseconds: 260),
              transitionBuilder:
                  (child, anim) => FadeTransition(opacity: anim, child: child),
              child:
                  _phase == _LoginPhase.loggingIn
                      ? Row(
                        key: const ValueKey('pending'),
                        children: [
                          // Pending mark
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Center(
                              child: SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Logging you in',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: greyed,
                              ),
                            ),
                          ),
                        ],
                      )
                      : Row(
                        key: const ValueKey('done'),
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 20,
                            color: greyed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Signed in as ${usernameController.text.trim()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: greyed,
                              ),
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Savings row
        TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 0.0,
            end: _phase == _LoginPhase.loggingIn ? 0.0 : 1.0,
          ),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder:
              (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 16),
                  child: child,
                ),
              ),
          child: Row(
            children: [
              // Savings mark
              SizedBox(
                width: 20,
                height: 20,
                child: AnimatedSwitcher(
                  duration:
                      reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                  transitionBuilder:
                      (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                  child:
                      _phase == _LoginPhase.savings
                          ? SizedBox(
                            key: const ValueKey('busy'),
                            child: Center(
                              child: SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primary,
                                ),
                              ),
                            ),
                          )
                          : const Icon(
                            Icons.cloud_outlined,
                            key: ValueKey('done'),
                            size: 20,
                            color: greyed,
                          ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Setting up your savings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: greyed,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Active block
        TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 0.0,
            end:
                (_phase == _LoginPhase.loggingIn ||
                        _phase == _LoginPhase.savings)
                    ? 0.0
                    : 1.0,
          ),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder:
              (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 16),
                  child: child,
                ),
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status mark
              SizedBox(
                width: 26,
                height: 26,
                child: AnimatedSwitcher(
                  duration:
                      reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder:
                      (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                  child: ready ? check : ring,
                ),
              ),
              const SizedBox(height: 14),
              // Status copy
              AnimatedSwitcher(
                duration:
                    reduce ? Duration.zero : const Duration(milliseconds: 260),
                transitionBuilder:
                    (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                child: Column(
                  key: ValueKey(_phase),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready ? 'Your world is ready!' : 'Setting up your world',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ready
                          ? "Let's begin."
                          : 'Hold tight — your panda is getting everything ready.',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Brand tokens
    final Color primary = Theme.of(context).colorScheme.primary;
    const Color ink = Color(0xFF1A1A1A);
    const Color muted = Color(0xFF6F695F);
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    // Aurora block
    final auroraH = height * 0.54;
    // Pill action
    Widget arrow(VoidCallback onTap) {
      return Material(
        color: primary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy ? null : onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child:
                  _busy
                      ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
            ),
          ),
        ),
      );
    }

    // Field shell
    Widget fieldBox(Widget child) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(29),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 6, 14, 6),
        child: child,
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      canPop: _step == 0,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          // Tap out
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              // Aurora wash
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: auroraH,
                child: ClipRect(
                  child: Stack(
                    children: [
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                        child: Stack(
                          children: [
                            // Blob sky
                            Positioned(
                              left: -width * 0.34,
                              top: -width * 0.30,
                              child: Container(
                                width: width * 0.68,
                                height: width * 0.68,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD2E3FC,
                                  ).withValues(alpha: 0.38),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            // Blob blue
                            Positioned(
                              left: -width * 0.20,
                              top: auroraH * 0.14,
                              child: Container(
                                width: width * 0.42,
                                height: width * 0.42,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4285F4,
                                  ).withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            // Blob ember
                            Positioned(
                              right: -width * 0.22,
                              top: auroraH * 0.10,
                              child: Container(
                                width: width * 0.46,
                                height: width * 0.34,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEA4335,
                                  ).withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Fade out
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white,
                              ],
                              stops: const [0.0, 0.42, 0.92],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Setup layer
              if (_phase != _LoginPhase.form)
                Positioned.fill(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                      // Rest offset
                      child: Transform.translate(
                        offset: const Offset(0, 40),
                        child: _buildSetup(),
                      ),
                    ),
                  ),
                ),
              // Foreground
              SafeArea(
                bottom: false,
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _rise,
                    child: Column(
                      children: [
                        // Top edge
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Eyebrow
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    "Let's get you back in",
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.1,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Close edge
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: IconButton(
                                  tooltip: 'Close',
                                  padding: EdgeInsets.zero,
                                  onPressed: _close,
                                  icon: const Icon(
                                    Icons.close,
                                    size: 21,
                                    color: ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Form body
                        Expanded(
                          child: IgnorePointer(
                            ignoring: _phase != _LoginPhase.form,
                            child: FadeTransition(
                              opacity: _formFade,
                              child: SlideTransition(
                                position: _formExit,
                                child: SingleChildScrollView(
                                  reverse: true,
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: EdgeInsets.fromLTRB(
                                    28,
                                    0,
                                    28,
                                    MediaQuery.viewInsetsOf(context).bottom > 0
                                        ? 28
                                        : 88,
                                  ),
                                  child: AutofillGroup(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 700,
                                      ),
                                      // Outgoing reads its curve reversed, so easeIn here = the exit mirrors the entrance
                                      switchInCurve: const Interval(
                                        0.15,
                                        1.0,
                                        curve: Curves.easeOutCubic,
                                      ),
                                      switchOutCurve: const Interval(
                                        0.62,
                                        1.0,
                                        curve: Curves.easeInCubic,
                                      ),
                                      // Fade through
                                      transitionBuilder:
                                          (child, animation) => FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              // Short rise, so the step reads as advancing rather than dissolving
                                              position: Tween<Offset>(
                                                begin: const Offset(0, 0.04),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          ),
                                      child:
                                          _step == 0
                                              ? Column(
                                                key: const ValueKey(0),
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  // Sign in mark
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Icon(
                                                      Icons.key_rounded,
                                                      size: 26,
                                                      color: primary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 14),
                                                  Text(
                                                    'Sign in',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 34,
                                                      height: 1.1,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: -1.0,
                                                      color: ink,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  const Text(
                                                    'Pick up right where you left off.',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      height: 1.5,
                                                      color: muted,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 22),
                                                  fieldBox(
                                                    TextField(
                                                      controller:
                                                          usernameController,
                                                      autofillHints: const [
                                                        AutofillHints.username,
                                                      ],
                                                      autocorrect: false,
                                                      textCapitalization:
                                                          TextCapitalization
                                                              .none,
                                                      textInputAction:
                                                          TextInputAction.next,
                                                      onSubmitted:
                                                          (_) => _advance(),
                                                      style: const TextStyle(
                                                        fontSize: 15.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: ink,
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText:
                                                            'Enter your username',
                                                        hintStyle:
                                                            const TextStyle(
                                                              fontSize: 15.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Color(
                                                                0xFF9C9589,
                                                              ),
                                                            ),
                                                        border:
                                                            InputBorder.none,
                                                        contentPadding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 14,
                                                            ),
                                                        suffixIcon: arrow(
                                                          _advance,
                                                        ),
                                                        suffixIconConstraints:
                                                            const BoxConstraints(
                                                              minWidth: 0,
                                                              minHeight: 0,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Error slot
                                                  if (_error != null) ...[
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      _error!,
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        height: 1.4,
                                                        color: Color(
                                                          0xFFB3261E,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 32),
                                                  // Next step
                                                  const _StepRow(
                                                    icon: Icons.lock_rounded,
                                                    label: 'Password',
                                                  ),
                                                ],
                                              )
                                              : Column(
                                                key: const ValueKey(1),
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  // Completed step
                                                  _StepRow(
                                                    icon: Icons.check_rounded,
                                                    label:
                                                        usernameController.text
                                                            .trim(),
                                                    onTap: _back,
                                                  ),
                                                  const SizedBox(height: 20),
                                                  // Password mark
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Icon(
                                                      Icons.lock_rounded,
                                                      size: 26,
                                                      color: primary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 14),
                                                  Text(
                                                    'Enter your password',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 34,
                                                      height: 1.1,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: -1.0,
                                                      color: ink,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  const Text(
                                                    'Almost there.',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      height: 1.5,
                                                      color: muted,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 22),
                                                  fieldBox(
                                                    TextField(
                                                      controller:
                                                          passwordController,
                                                      focusNode: passwordFocus,
                                                      autofillHints: const [
                                                        AutofillHints.password,
                                                      ],
                                                      autocorrect: false,
                                                      enableSuggestions: false,
                                                      obscureText: _obscure,
                                                      textInputAction:
                                                          TextInputAction.done,
                                                      onSubmitted:
                                                          (_) => _advance(),
                                                      style: const TextStyle(
                                                        fontSize: 15.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: ink,
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText:
                                                            'Enter your password',
                                                        hintStyle:
                                                            const TextStyle(
                                                              fontSize: 15.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Color(
                                                                0xFF9C9589,
                                                              ),
                                                            ),
                                                        border:
                                                            InputBorder.none,
                                                        contentPadding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 14,
                                                            ),
                                                        suffixIcon: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            // Peek toggle
                                                            IconButton(
                                                              tooltip:
                                                                  _obscure
                                                                      ? 'Show password'
                                                                      : 'Hide password',
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              constraints:
                                                                  const BoxConstraints(
                                                                    minWidth:
                                                                        40,
                                                                    minHeight:
                                                                        40,
                                                                  ),
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
                                                                color: muted,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            arrow(_advance),
                                                          ],
                                                        ),
                                                        suffixIconConstraints:
                                                            const BoxConstraints(
                                                              minWidth: 0,
                                                              minHeight: 0,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Error slot
                                                  if (_error != null) ...[
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      _error!,
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        height: 1.4,
                                                        color: Color(
                                                          0xFFB3261E,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                    ),
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}

// Step row
class _StepRow extends StatelessWidget {
  const _StepRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6F695F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6F695F),
              ),
            ),
          ),
        ],
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
