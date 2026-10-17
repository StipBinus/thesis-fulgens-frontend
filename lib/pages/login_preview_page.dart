import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:thesis_fulgens_mobile/core/config/api_config.dart';

import '../app/presentation/auth_service/auth_service.dart';

// Unified login preview
class LoginPreviewPage extends StatefulWidget {
  const LoginPreviewPage({super.key});

  @override
  State<LoginPreviewPage> createState() => _LoginPreviewPageState();
}

class _LoginPreviewPageState extends State<LoginPreviewPage>
    with SingleTickerProviderStateMixin {
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion
    _enter.duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 600);
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    passwordFocus.dispose();
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

      if (role == 'PARENT') {
        context.go('/parent');
        return;
      }

      if (role == 'USER') {
        context.go('/');
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
    if (_step == 0) return;
    setState(() {
      _error = null;
      _step = 0;
    });
  }

  // Close edge
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/kids-start');
    }
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
        color: ink,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy ? null : onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: _busy
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
                          child: SingleChildScrollView(
                            reverse: true,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                            child: AutofillGroup(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 700),
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
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
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
                                              alignment: Alignment.centerLeft,
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
                                                fontWeight: FontWeight.w700,
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
                                                controller: usernameController,
                                                autofillHints: const [
                                                  AutofillHints.username,
                                                ],
                                                autocorrect: false,
                                                textCapitalization:
                                                    TextCapitalization.none,
                                                textInputAction:
                                                    TextInputAction.next,
                                                onSubmitted: (_) => _advance(),
                                                style: const TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: ink,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Enter your username',
                                                  hintStyle: const TextStyle(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF9C9589),
                                                  ),
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 14,
                                                      ),
                                                  suffixIcon: arrow(_advance),
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
                                                  color: Color(0xFFB3261E),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 22),
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
                                              label: usernameController.text
                                                  .trim(),
                                              onTap: _back,
                                            ),
                                            const SizedBox(height: 20),
                                            // Password mark
                                            Align(
                                              alignment: Alignment.centerLeft,
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
                                                fontWeight: FontWeight.w700,
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
                                                controller: passwordController,
                                                focusNode: passwordFocus,
                                                autofillHints: const [
                                                  AutofillHints.password,
                                                ],
                                                autocorrect: false,
                                                enableSuggestions: false,
                                                obscureText: _obscure,
                                                textInputAction:
                                                    TextInputAction.done,
                                                onSubmitted: (_) => _advance(),
                                                style: const TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: ink,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Enter your password',
                                                  hintStyle: const TextStyle(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF9C9589),
                                                  ),
                                                  border: InputBorder.none,
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
                                                        tooltip: _obscure
                                                            ? 'Show password'
                                                            : 'Hide password',
                                                        padding: EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(
                                                              minWidth: 40,
                                                              minHeight: 40,
                                                            ),
                                                        onPressed: () =>
                                                            setState(
                                                              () => _obscure =
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
                                                      const SizedBox(width: 4),
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
                                                  color: Color(0xFFB3261E),
                                                ),
                                              ),
                                            ],
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
            ],
          ),
        ),
      ),
    );
  }
}

// Step row
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.label,
    this.onTap,
  });

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
