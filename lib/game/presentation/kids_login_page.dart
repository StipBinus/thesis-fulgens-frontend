import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:thesis_fulgens_mobile/core/config/api_config.dart';

import '../../app/presentation/auth_service/auth_service.dart';

// Kids login
class KidsLoginPage extends StatefulWidget {
  const KidsLoginPage({super.key});

  @override
  State<KidsLoginPage> createState() => _KidsLoginPageState();
}

class _KidsLoginPageState extends State<KidsLoginPage>
    with SingleTickerProviderStateMixin {
  // Field controllers
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();
  final ApiConfig apiConfig = ApiConfig();
  // Password peek
  bool _obscure = true;
  // Busy flag
  bool _busy = false;
  // Error copy
  String? _error;
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

  // Google pending
  void _googlePending() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google sign-in is not enabled yet. Use your account.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Brand tokens
    final Color primary = Theme.of(context).colorScheme.primary;
    const Color ink = Color(0xFF1A1A1A);
    const Color muted = Color(0xFF6F695F);
    const Color sand = Color(0xFFE8E2D9);
    const Color fieldBg = Color(0xFFF9F7F3);
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          // Tap out
          onTap: () => FocusScope.of(context).unfocus(),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _rise,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: AutofillGroup(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),
                        // Back edge
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                              tooltip: 'Back',
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                // Back slide
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/kids-start');
                                }
                              },
                              // Back icon
                              icon: SvgPicture.string(
                                '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#1A1A1A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><path d="m12 19-7-7 7-7"/></svg>',
                                width: 22,
                                height: 22,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Welcome mascot
                        Center(
                          child: SizedBox(
                            width: width * 0.42,
                            child: Image.asset(
                              'assets/game/mascotIllustrations/fulgensWelcomeMascot.png',
                              fit: BoxFit.contain,
                              semanticLabel: 'Fulgens welcome mascot',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome back!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to keep saving.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.5,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Field label
                        const Text(
                          'Username',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: usernameController,
                          autofillHints: const [AutofillHints.username],
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(fontSize: 15, color: ink),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: fieldBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: sand),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: sand),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: primary, width: 1.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Field label
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: passwordController,
                          autofillHints: const [AutofillHints.password],
                          autocorrect: false,
                          enableSuggestions: false,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          style: const TextStyle(fontSize: 15, color: ink),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: fieldBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: sand),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: sand),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: primary, width: 1.6),
                            ),
                            // Peek toggle
                            suffixIcon: SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                tooltip:
                                    _obscure ? 'Show password' : 'Hide password',
                                padding: EdgeInsets.zero,
                                onPressed:
                                    () => setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: muted,
                                ),
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
                              color: Color(0xFFB3261E),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _login,
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: primary.withValues(
                              alpha: 0.6,
                            ),
                            minimumSize: const Size.fromHeight(50),
                            shape: const StadiumBorder(),
                          ),
                          child:
                              _busy
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text(
                                    'Sign in',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                        ),
                        const SizedBox(height: 14),
                        // Divider row
                        Row(
                          children: [
                            const Expanded(
                              child: ColoredBox(
                                color: sand,
                                child: SizedBox(height: 1),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: ColoredBox(
                                color: sand,
                                child: SizedBox(height: 1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Google match
                        OutlinedButton(
                          onPressed: _googlePending,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ink,
                            minimumSize: const Size.fromHeight(50),
                            shape: const StadiumBorder(),
                            side: const BorderSide(color: sand),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/app/google_g.svg',
                                width: 18,
                                height: 18,
                                excludeFromSemantics: true,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
