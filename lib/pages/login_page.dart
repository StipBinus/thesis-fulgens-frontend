import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:thesis_fulgens_mobile/core/config/api_config.dart';
import '../app//presentation/auth_service/auth_service.dart';

// Login screen
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion
    _enter.duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 800);
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
    // Ink tokens
    const Color ink = Color(0xFF1A1A1A);
    const Color muted = Color(0xFF6F695F);
    const Color sand = Color(0xFFE8E2D9);
    final Color primary = Theme.of(context).colorScheme.primary;
    // Small label
    const TextStyle label = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: muted,
    );
    // Line field
    InputBorder line(Color side, double weight) => UnderlineInputBorder(
      borderSide: BorderSide(color: side, width: weight),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Centered column
        child: GestureDetector(
          // Tap out
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
                                ScrollViewKeyboardDismissBehavior.onDrag,
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
                                          context.go('/?detail=1');
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
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Field label
                                const Text('Username', style: label),
                                const SizedBox(height: 2),
                                TextField(
                                  controller: usernameController,
                                  autofillHints: const [
                                    AutofillHints.username,
                                  ],
                                  autocorrect: false,
                                  textCapitalization:
                                      TextCapitalization.none,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: ink,
                                  ),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    border: line(sand, 1.0),
                                    enabledBorder: line(sand, 1.0),
                                    focusedBorder: line(primary, 1.6),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Field label
                                const Text('Password', style: label),
                                const SizedBox(height: 2),
                                TextField(
                                  controller: passwordController,
                                  autofillHints: const [
                                    AutofillHints.password,
                                  ],
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _login(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: ink,
                                  ),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    border: line(sand, 1.0),
                                    enabledBorder: line(sand, 1.0),
                                    focusedBorder: line(primary, 1.6),
                                    // Peek toggle
                                    suffixIcon: IconButton(
                                      tooltip:
                                          _obscure
                                              ? 'Show password'
                                              : 'Hide password',
                                      onPressed:
                                          () => setState(
                                            () => _obscure = !_obscure,
                                          ),
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
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
                            const SizedBox(height: 20),
                            // Google row
                            Center(
                              child: Material(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: sand),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _googlePending,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SvgPicture.asset(
                                          'assets/app/google_g.svg',
                                          width: 20,
                                          height: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _busy ? null : _login,
                              style: FilledButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(46),
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
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                            // Account link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: muted,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Navigate to register
                                    if (!context.mounted) {
                                      return;
                                    }

                                    context.go('/register');
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    'Register',
                                    style: TextStyle(fontSize: 13),
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
      ),
    );
  }
}
