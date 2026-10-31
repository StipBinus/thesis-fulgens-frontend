import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:thesis_fulgens_mobile/core/config/api_config.dart';

// Register screen
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  // Field controllers
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final ApiConfig apiConfig = ApiConfig();
  // Step state
  int _step = 0;
  bool _forward = true;
  // Exit gate
  bool _exitOpen = false;
  bool _leaving = false;
  // Password peek
  bool _obscure = true;
  bool _obscureConfirm = true;
  // Busy flag
  bool _busy = false;
  // Error copy
  String? _error;
  // Step entrance
  late final AnimationController _stepAnim;

  @override
  void initState() {
    super.initState();
    // Step setup
    _stepAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 0.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // First cascade
      if (mounted) _stepAnim.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion
    _stepAnim.duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 450);
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    _stepAnim.dispose();
    super.dispose();
  }

  // Step one valid
  bool _validStepOne() {
    final String username = usernameController.text.trim();
    final String email = emailController.text.trim();
    if (username.length < 3) {
      setState(() => _error = 'Username needs at least 3 characters.');
      return false;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return false;
    }
    return true;
  }

  // Go secure step
  void _toStepTwo() {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_validStepOne()) return;
    setState(() {
      _forward = true;
      _step = 1;
    });
    _stepAnim.forward(from: 0.0);
  }

  // Back identity step
  void _toStepOne() {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = false;
      _error = null;
      _step = 0;
    });
    _stepAnim.forward(from: 0.0);
  }

  // Leave with cascade
  Future<void> _leaveBack() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    FocusScope.of(context).unfocus();
    await _stepAnim.reverse();
    if (!mounted) return;
    setState(() => _exitOpen = true);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/parent/login');
    }
  }

  // Create account
  Future<void> _register() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (passwordController.text.isEmpty) {
      setState(() => _error = 'Enter a password.');
      return;
    }
    if (passwordController.text != confirmController.text) {
      // Mismatch keep
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse('${apiConfig.getBackendUrl()}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailController.text.trim(),
          'username': usernameController.text.trim(),
          'password': passwordController.text,
        }),
      );
      if (!mounted) return;
      if (response.statusCode != 200 && response.statusCode != 201) {
        // Server reject
        setState(() {
          _error = 'Registration failed. Try again.';
          _busy = false;
        });
        return;
      }
      if (!mounted) return;
      context.go('/parent/login');
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

  // Step interval
  Animation<double> _stepInterval(double begin, double end) {
    const Cubic ease = Cubic(0.23, 1, 0.32, 1);
    return CurvedAnimation(
      parent: _stepAnim,
      curve: Interval(begin, end, curve: ease),
    );
  }

  // Step side
  Offset _stepBegin() {
    return _forward ? const Offset(0.35, 0.0) : const Offset(-0.35, 0.0);
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
    return PopScope(
      canPop: _exitOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        // System back
        if (_step == 1) {
          _toStepOne();
          return;
        }
        _leaveBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          // Tap out
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            // Centered column
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
                        // Body entrance
                        child: Padding(
                          padding: const EdgeInsets.only(right: 28),
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
                                          // Step back
                                          if (_step == 1) {
                                            _toStepOne();
                                          } else {
                                            _leaveBack();
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
                                  // Step marker
                                  Row(
                                    children: [
                                      Text(
                                        'Step ${_step + 1} of 2',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: muted,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  color: primary,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  color:
                                                      _step == 1
                                                          ? primary
                                                          : sand,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  FadeTransition(
                                    opacity: _stepInterval(0.05, 0.5),
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.0, 0.12),
                                        end: Offset.zero,
                                      ).animate(_stepInterval(0.05, 0.5)),
                                      child: Text(
                                        _step == 0
                                            ? 'Create account'
                                            : 'Secure your account',
                                        style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.3,
                                          color: ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Step body
                                  if (_step == 0)
                                    FadeTransition(
                                      opacity: _stepInterval(0.15, 0.6),
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: _stepBegin(),
                                          end: Offset.zero,
                                        ).animate(_stepInterval(0.15, 0.6)),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            // Field label
                                            const Text(
                                              'Username',
                                              style: label,
                                            ),
                                            const SizedBox(height: 2),
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
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: ink,
                                              ),
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                border: line(sand, 1.0),
                                                enabledBorder: line(sand, 1.0),
                                                focusedBorder: line(
                                                  primary,
                                                  1.6,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    FadeTransition(
                                      opacity: _stepInterval(0.15, 0.6),
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: _stepBegin(),
                                          end: Offset.zero,
                                        ).animate(_stepInterval(0.15, 0.6)),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            // Field label
                                            const Text(
                                              'Password',
                                              style: label,
                                            ),
                                            const SizedBox(height: 2),
                                            TextField(
                                              controller: passwordController,
                                              autofillHints: const [
                                                AutofillHints.newPassword,
                                              ],
                                              autocorrect: false,
                                              enableSuggestions: false,
                                              obscureText: _obscure,
                                              textInputAction:
                                                  TextInputAction.next,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: ink,
                                              ),
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                border: line(sand, 1.0),
                                                enabledBorder: line(sand, 1.0),
                                                focusedBorder: line(
                                                  primary,
                                                  1.6,
                                                ),
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
                                                    color: muted,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  FadeTransition(
                                    opacity: _stepInterval(0.3, 0.75),
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: _stepBegin(),
                                        end: Offset.zero,
                                      ).animate(_stepInterval(0.3, 0.75)),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const SizedBox(height: 14),
                                          // Field label
                                          Text(
                                            _step == 0
                                                ? 'Email'
                                                : 'Confirm password',
                                            style: label,
                                          ),
                                          const SizedBox(height: 2),
                                          if (_step == 0)
                                            TextField(
                                              controller: emailController,
                                              autofillHints: const [
                                                AutofillHints.email,
                                              ],
                                              autocorrect: false,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              textCapitalization:
                                                  TextCapitalization.none,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onSubmitted: (_) => _toStepTwo(),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: ink,
                                              ),
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                border: line(sand, 1.0),
                                                enabledBorder: line(sand, 1.0),
                                                focusedBorder: line(
                                                  primary,
                                                  1.6,
                                                ),
                                              ),
                                            )
                                          else
                                            TextField(
                                              controller: confirmController,
                                              autofillHints: const [
                                                AutofillHints.newPassword,
                                              ],
                                              autocorrect: false,
                                              enableSuggestions: false,
                                              obscureText: _obscureConfirm,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onSubmitted: (_) => _register(),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: ink,
                                              ),
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                border: line(sand, 1.0),
                                                enabledBorder: line(sand, 1.0),
                                                focusedBorder: line(
                                                  primary,
                                                  1.6,
                                                ),
                                                // Peek toggle
                                                suffixIcon: IconButton(
                                                  tooltip:
                                                      _obscureConfirm
                                                          ? 'Show password'
                                                          : 'Hide password',
                                                  onPressed:
                                                      () => setState(
                                                        () =>
                                                            _obscureConfirm =
                                                                !_obscureConfirm,
                                                      ),
                                                  icon: Icon(
                                                    _obscureConfirm
                                                        ? Icons
                                                            .visibility_outlined
                                                        : Icons
                                                            .visibility_off_outlined,
                                                    size: 20,
                                                    color: muted,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
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
                      // Pinned bottom
                      Padding(
                        padding: const EdgeInsets.only(right: 28),
                        child: FadeTransition(
                          opacity: _stepInterval(0.4, 0.9),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.2),
                              end: Offset.zero,
                            ).animate(_stepInterval(0.4, 0.9)),
                            child:
                                _step == 0
                                    ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Google row
                                        Center(
                                          child: Material(
                                            color: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              side: const BorderSide(
                                                color: sand,
                                              ),
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              onTap: _googlePending,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 12,
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
                                                    const Text(
                                                      'Continue with Google',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: ink,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                          onPressed: _toStepTwo,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: primary,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size.fromHeight(
                                              48,
                                            ),
                                            shape: const StadiumBorder(),
                                          ),
                                          child: const Text(
                                            'Continue',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    )
                                    : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        FilledButton(
                                          onPressed: _busy ? null : _register,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: primary,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size.fromHeight(
                                              46,
                                            ),
                                            shape: const StadiumBorder(),
                                          ),
                                          child:
                                              _busy
                                                  ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                  : const Text(
                                                    'Register',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
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
      ),
    );
  }
}
