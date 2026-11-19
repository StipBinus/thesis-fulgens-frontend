import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_manager.dart';
import '../home/home_page_provider.dart';
import '../ui/parent_ui.dart';
import 'child_task_api.dart';
import 'child_task_models.dart';

/// Second step of adding a child: preview the daily questions generated from
/// the parent's prompt, let the parent edit or regenerate them, and only create
/// the child account once the parent approves.
///
/// Reached from the Add child form with a [ChildDraft] as `extra`.
class SetChildTaskPage extends ConsumerStatefulWidget {
  const SetChildTaskPage({super.key, required this.draft});

  final ChildDraft draft;

  @override
  ConsumerState<SetChildTaskPage> createState() => _SetChildTaskPageState();
}

class _SetChildTaskPageState extends ConsumerState<SetChildTaskPage> {
  static const int _maxQuestionLength = 240;

  final ChildTaskApi _api = ChildTaskApi();
  final TextEditingController _promptController = TextEditingController();

  final List<_QuestionDraft> _questions = [];

  bool _loading = true;
  bool _creating = false;
  String? _loadError;
  String? _createError;

  @override
  void initState() {
    super.initState();
    _promptController.text = widget.draft.prompt;
    // The first preview uses the prompt typed on the Add child page.
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _promptController.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/child-register');
    }
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _loadError = 'Write what the daily questions should focus on.');
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
      _createError = null;
    });

    final token = await SessionManager.instance.getValidToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _loadError = 'Your session has expired. Please sign in again.';
      });
      return;
    }

    try {
      final preview = await _api.preview(prompt: prompt, token: token);
      if (!mounted) return;

      _replaceQuestions(preview.dailyTasks);
      setState(() => _loading = false);
    } on ChildTaskApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not reach the server. Check your connection.';
      });
    }
  }

  void _replaceQuestions(List<PreviewQuestion> questions) {
    final old = List<_QuestionDraft>.of(_questions);

    _questions
      ..clear()
      ..addAll(questions.map(_QuestionDraft.new));

    // Dispose after the frame so the removed TextFields are gone before their
    // controllers are torn down.
    _disposeAfterFrame(old);
  }

  void _removeQuestion(int index) {
    final removed = _questions.removeAt(index);
    setState(() {});
    _disposeAfterFrame([removed]);
  }

  void _disposeAfterFrame(List<_QuestionDraft> drafts) {
    if (drafts.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final draft in drafts) {
        draft.dispose();
      }
    });
  }

  Future<void> _approve() async {
    if (_creating) return;
    FocusScope.of(context).unfocus();

    final prompt = _promptController.text.trim();
    final accepted = [
      for (final question in _questions)
        if (question.text.text.trim().isNotEmpty) question.text.text.trim(),
    ];

    if (prompt.isEmpty) {
      setState(
        () => _createError = 'Write what the daily questions should focus on.',
      );
      return;
    }

    if (accepted.isEmpty) {
      setState(() => _createError = 'Keep at least one question.');
      return;
    }

    setState(() {
      _creating = true;
      _createError = null;
    });

    final token = await SessionManager.instance.getValidToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() {
        _creating = false;
        _createError = 'Your session has expired. Please sign in again.';
      });
      return;
    }

    try {
      await _api.registerChild(
        draft: widget.draft,
        composedPrompt: composeChildPrompt(prompt, accepted),
        token: token,
      );

      if (!mounted) return;

      // The new child has to show up on the home page right away.
      ref.invalidate(childAccountsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.draft.name} is ready to sign in.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/parent/home');
    } on ChildTaskApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _createError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _createError = 'Could not reach the server. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final bool showQuestions = _questions.isNotEmpty;

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
                    ParentBackButton(onTap: _goBack),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily questions',
                            style: parentText(
                              size: 20,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Approve what ${widget.draft.name} will be asked',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                child: _childSummary(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                child: _promptCard(),
              ),
            ),
            SliverToBoxAdapter(
              child: ParentSectionHeader(
                title:
                    showQuestions
                        ? 'Questions (${_questions.length})'
                        : 'Questions',
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              ),
            ),
            ..._questionSlivers(),
            if (showQuestions && _loadError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                    _loadError!,
                    style: parentText(
                      size: 12,
                      weight: FontWeight.w500,
                      color: ParentPalette.red,
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 22, 22, 24 + bottomInset),
                child: Column(
                  children: [
                    if (_createError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _createError!,
                          textAlign: TextAlign.center,
                          style: parentText(
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: ParentPalette.red,
                          ),
                        ),
                      ),
                    ParentPrimaryButton(
                      label: 'Approve & create child',
                      loading: _creating,
                      onPressed: showQuestions ? _approve : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The account is created only after you approve. '
                      'Questions are examples generated from your prompt.',
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

  /// Compact reminder of who is being created, so the approval step is clear.
  Widget _childSummary() {
    return ParentCard(
      color: ParentPalette.raised,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ParentPalette.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Text(
              _initial(widget.draft.name),
              style: parentText(
                size: 16,
                weight: FontWeight.w700,
                color: ParentPalette.accentDeep,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.draft.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: parentText(size: 15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${widget.draft.username} · not created yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: parentText(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: ParentPalette.label,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _promptCard() {
    return ParentCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What should the questions teach?',
            style: parentText(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Daily questions are generated from this prompt. '
            'Edit it, then generate again.',
            style: parentText(
              size: 12,
              weight: FontWeight.w500,
              color: ParentPalette.label,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _promptController,
            maxLength: ChildDraft.maxPromptLength,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: parentText(size: 14, weight: FontWeight.w500),
            decoration:
                parentInputDecoration(
                  hint: 'e.g. Ask about saving part of their allowance',
                ).copyWith(
                  counterStyle: parentText(
                    size: 11,
                    weight: FontWeight.w500,
                    color: ParentPalette.faint,
                  ),
                ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loading ? null : _generate,
              style: TextButton.styleFrom(
                foregroundColor: ParentPalette.accent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _loading ? 'Generating…' : 'Generate again',
                style: parentText(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color:
                      _loading ? ParentPalette.faint : ParentPalette.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _questionSlivers() {
    if (_loading && _questions.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _statusCard(
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: ParentPalette.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Writing questions from your prompt…',
                    style: parentText(
                      size: 12.5,
                      weight: FontWeight.w500,
                      color: ParentPalette.label,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_questions.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _statusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loadError ?? 'No questions yet. Generate a preview first.',
                  style: parentText(
                    size: 12.5,
                    weight: FontWeight.w500,
                    color:
                        _loadError == null
                            ? ParentPalette.label
                            : ParentPalette.red,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _generate,
                  style: TextButton.styleFrom(
                    foregroundColor: ParentPalette.accent,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Try again',
                    style: parentText(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: ParentPalette.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      for (var index = 0; index < _questions.length; index++)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: _questionCard(index),
          ),
        ),
    ];
  }

  Widget _statusCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      child: ParentCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: child,
      ),
    );
  }

  Widget _questionCard(int index) {
    final draft = _questions[index];

    return ParentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _numberBadge(index + 1),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  draft.typeLabel.toUpperCase(),
                  style: parentText(
                    size: 10.5,
                    weight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: ParentPalette.accentDeep,
                  ),
                ),
              ),
              _RewardPill(reward: draft.reward),
              const SizedBox(width: 2),
              IconButton(
                onPressed: () => _removeQuestion(index),
                tooltip: 'Remove question',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: ParentPalette.faint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: draft.text,
            minLines: 2,
            maxLines: null,
            maxLength: _maxQuestionLength,
            textCapitalization: TextCapitalization.sentences,
            style: parentText(size: 13.5, weight: FontWeight.w500, height: 1.45),
            decoration: parentInputDecoration(
              hint: 'Question text',
            ).copyWith(counterText: ''),
          ),
          if (draft.options.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in draft.options) _OptionChip(label: option),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _numberBadge(int number) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ParentPalette.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: parentText(
          size: 11.5,
          weight: FontWeight.w700,
          color: ParentPalette.accentDeep,
        ),
      ),
    );
  }
}

/// Editable copy of one previewed question.
class _QuestionDraft {
  _QuestionDraft(PreviewQuestion question)
    : questionType = question.questionType,
      options = question.options,
      reward = question.reward,
      text = TextEditingController(text: question.question);

  final String questionType;
  final List<String> options;
  final int reward;
  final TextEditingController text;

  String get typeLabel {
    switch (questionType.trim().toUpperCase()) {
      case 'MULTIPLE_CHOICE':
        return 'Multiple choice';
      case 'REFLECTION':
        return 'Reflection';
      default:
        return 'Question';
    }
  }

  void dispose() => text.dispose();
}

/// Small read-only reward badge.
///
/// Rewards are decided by the backend when the daily task is generated, so the
/// preview value is shown but not editable here.
class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.reward});

  final int reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ParentPalette.card,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFD98324)),
          const SizedBox(width: 3),
          Text(
            '$reward',
            style: parentText(size: 11.5, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ParentPalette.card,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: parentText(
          size: 11.5,
          weight: FontWeight.w500,
          color: ParentPalette.label,
        ),
      ),
    );
  }
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}
