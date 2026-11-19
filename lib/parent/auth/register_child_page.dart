import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:thesis_fulgens_mobile/core/auth/session_manager.dart';
import '../tasks/child_task_models.dart';
import '../ui/parent_ui.dart';

class RegisterChildPage extends StatefulWidget {
  const RegisterChildPage({super.key});

  @override
  State<RegisterChildPage> createState() => _RegisterChildPage();
}

class RegisterChildHandler {
  Map<String, String> validate({
    required String name,
    required String username,
    required String password,
    required DateTime? birthDate,
    required String grade,
    required String prompt,
  }) {
    Map<String, String> errResult = {};

    if (name.trim().isEmpty) {
      errResult['name'] = 'Name is required';
    }

    if (username.trim().isEmpty) {
      errResult['username'] = 'Username is required';
    }

    if (password.trim().isEmpty) {
      errResult['password'] = 'Password is required';
    }

    if (birthDate == null) {
      errResult['birthDate'] = 'Birth Date is required';
    }

    if (grade.trim().isEmpty) {
      errResult['grade'] = 'Grade is required';
    }

    if (prompt.trim().isEmpty) {
      errResult['prompt'] = 'Tell us what the questions should focus on';
    }

    return errResult;
  }
}

class _RegisterChildPage extends State<RegisterChildPage> {
  final sessionManager = SessionManager.instance;

  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final gradeController = TextEditingController();
  final promptController = TextEditingController();

  DateTime? birthDate;

  Map<String, String> errors = {};

  bool submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    gradeController.dispose();
    promptController.dispose();
    super.dispose();
  }

  /// Validates the form and hands the filled-in details to the next step,
  /// where the parent previews and approves the daily questions.
  ///
  /// The child is not created here: the register endpoint runs only after the
  /// questions are approved.
  Future<void> _continue() async {
    if (submitting) return;

    final handler = RegisterChildHandler();

    final validationErrors = handler.validate(
      name: nameController.text,
      username: usernameController.text,
      password: passwordController.text,
      birthDate: birthDate,
      grade: gradeController.text,
      prompt: promptController.text,
    );

    if (validationErrors.isNotEmpty) {
      setState(() => errors = validationErrors);
      return;
    }

    setState(() {
      submitting = true;
      errors.remove('session');
    });

    // Read (and refresh when needed) the token right before moving on,
    // so a token that expired while the form was being filled is still valid.
    final authToken = await sessionManager.getValidToken();
    final parentUserId =
        authToken == null ? null : sessionManager.getUserId(authToken);

    if (!mounted) return;

    if (authToken == null || parentUserId == null) {
      setState(() {
        submitting = false;
        errors['session'] = 'Session expired. Please log in again.';
      });
      return;
    }

    setState(() => submitting = false);

    context.push(
      '/parent/set-child-task',
      extra: ChildDraft(
        name: nameController.text.trim(),
        username: usernameController.text.trim(),
        password: passwordController.text,
        birthDate: birthDate!,
        grade: gradeController.text.trim(),
        parentId: parentUserId,
        prompt: promptController.text.trim(),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(2015),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(
                context,
              ).colorScheme.copyWith(primary: ParentPalette.accent),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      birthDate = selectedDate;
      errors.remove('birthDate');
    });
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: ParentPalette.canvas,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                child: Row(
                  children: [
                    ParentBackButton(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/parent/home');
                        }
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add child',
                            style: parentText(
                              size: 20,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Set the details, then approve their daily questions',
                            style: parentText(
                              size: 12.5,
                              weight: FontWeight.w500,
                              color: ParentPalette.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                child: ParentCard(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        style: parentText(size: 14.5, weight: FontWeight.w500),
                        decoration: parentInputDecoration(
                          hint: "Child's full name",
                          label: 'Name',
                          error: errors['name'],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: usernameController,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        style: parentText(size: 14.5, weight: FontWeight.w500),
                        decoration: parentInputDecoration(
                          hint: 'Pick a username',
                          label: 'Username',
                          error: errors['username'],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        style: parentText(size: 14.5, weight: FontWeight.w500),
                        decoration: parentInputDecoration(
                          hint: 'Set a password',
                          label: 'Password',
                          error: errors['password'],
                          suffixIcon: IconButton(
                            tooltip:
                                _obscure ? 'Show password' : 'Hide password',
                            onPressed:
                                () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: ParentPalette.label,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: gradeController,
                        textInputAction: TextInputAction.done,
                        style: parentText(size: 14.5, weight: FontWeight.w500),
                        decoration: parentInputDecoration(
                          hint: 'e.g. 5',
                          label: 'Grade',
                          error: errors['grade'],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _BirthDateRow(
                        birthDate: birthDate,
                        onTap: _pickBirthDate,
                        error: errors['birthDate'],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Daily questions',
                        style: parentText(size: 14, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Questions are generated from this prompt. '
                        'You can review them before the account is created.',
                        style: parentText(
                          size: 11.5,
                          weight: FontWeight.w500,
                          color: ParentPalette.label,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: promptController,
                        maxLength: ChildDraft.maxPromptLength,
                        minLines: 3,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: parentText(size: 14.5, weight: FontWeight.w500),
                        decoration: parentInputDecoration(
                          hint: 'e.g. Ask about saving part of their allowance',
                          label: 'Prompt',
                          error: errors['prompt'],
                        ).copyWith(
                          counterStyle: parentText(
                            size: 11,
                            weight: FontWeight.w500,
                            color: ParentPalette.faint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 20, 22, 24 + bottomInset),
                child: Column(
                  children: [
                    if (errors['session'] != null &&
                        errors['session']!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          errors['session']!,
                          style: parentText(
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: ParentPalette.red,
                          ),
                        ),
                      ),
                    ParentPrimaryButton(
                      label: 'Continue',
                      loading: submitting,
                      onPressed: _continue,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Next you will preview the daily questions and approve '
                      'them. The account is created after you approve.',
                      textAlign: TextAlign.center,
                      style: parentText(
                        size: 11.5,
                        weight: FontWeight.w500,
                        color: ParentPalette.faint,
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
}

/// Birth date picker row, same shape as the deadline row on Assign task.
class _BirthDateRow extends StatelessWidget {
  const _BirthDateRow({
    required this.birthDate,
    required this.onTap,
    this.error,
  });

  final DateTime? birthDate;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParentCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: onTap,
          child: Row(
            children: [
              const Icon(
                Icons.cake_rounded,
                size: 18,
                color: ParentPalette.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Birth date',
                      style: parentText(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: ParentPalette.label,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      birthDate == null
                          ? 'Pick a date'
                          : birthDate!.toIso8601String().split('T').first,
                      style: parentText(
                        size: 14,
                        weight: FontWeight.w600,
                        color:
                            birthDate == null
                                ? ParentPalette.faint
                                : ParentPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: ParentPalette.faint,
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              error!,
              style: parentText(
                size: 11.5,
                weight: FontWeight.w500,
                color: ParentPalette.red,
              ),
            ),
          ),
      ],
    );
  }
}
