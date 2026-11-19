import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:thesis_fulgens_mobile/core/config/api_config.dart';

import '../ui/parent_ui.dart';

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
        backgroundColor: ParentPalette.canvas,
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
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                        style: parentText(
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: ParentPalette.label,
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
                                                  color: ParentPalette.accent,
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
                                                          ? ParentPalette.accent
                                                          : ParentPalette.line,
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
                                  const SizedBox(height: 14),
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
                                        style: parentText(
                                          size: 24,
                                          weight: FontWeight.w700,
                                          letterSpacing: -0.4,
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
                                                    hint: 'Pick a username',
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
                                                AutofillHints.newPassword,
                                              ],
                                              autocorrect: false,
                                              enableSuggestions: false,
                                              obscureText: _obscure,
                                              textInputAction:
                                                  TextInputAction.next,
                                              style: parentText(
                                                size: 14.5,
                                                weight: FontWeight.w500,
                                              ),
                                              decoration:
                                                  parentInputDecoration(
                                                    hint: 'Your password',
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
                                                            ParentPalette.label,
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
                                          const SizedBox(height: 16),
                                          // Field label
                                          Text(
                                            _step == 0
                                                ? 'Email'
                                                : 'Confirm password',
                                            style: parentText(
                                              size: 12.5,
                                              weight: FontWeight.w600,
                                              color: ParentPalette.label,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
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
                                              style: parentText(
                                                size: 14.5,
                                                weight: FontWeight.w500,
                                              ),
                                              decoration:
                                                  parentInputDecoration(
                                                    hint: 'you@email.com',
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
                                              style: parentText(
                                                size: 14.5,
                                                weight: FontWeight.w500,
                                              ),
                                              decoration:
                                                  parentInputDecoration(
                                                    hint: 'Repeat password',
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
                                                        color:
                                                            ParentPalette.label,
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
                                        const SizedBox(height: 12),
                                        ParentPrimaryButton(
                                          label: 'Continue',
                                          onPressed: _toStepTwo,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    )
                                    : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        ParentPrimaryButton(
                                          label: 'Register',
                                          loading: _busy,
                                          onPressed: _register,
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
