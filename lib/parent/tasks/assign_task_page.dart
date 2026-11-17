import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../model/ChildAccount.dart';
import '../home/home_page_provider.dart';
import '../home/selected_child_provider.dart';
import '../ui/parent_ui.dart';

/// Assign a task to a child.
///
/// UI-only for now: there is no task endpoint yet, so submitting validates the
/// form, shows a confirmation and clears it. Wire [AssignTaskDraft] to the
/// backend once `POST /api/tasks` (or similar) exists.
class AssignTaskPage extends ConsumerStatefulWidget {
  const AssignTaskPage({super.key});

  @override
  ConsumerState<AssignTaskPage> createState() => _AssignTaskPageState();
}

class _AssignTaskPageState extends ConsumerState<AssignTaskPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _rewardController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime? _deadline;
  String? _titleError;
  String? _rewardError;
  bool _submitting = false;

  static const List<String> _templates = [
    'Finish homework',
    'Tidy your room',
    'Save 10% of allowance',
    'Read for 20 minutes',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _rewardController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: DateTime(now.year + 2, 12, 31),
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: ParentPalette.accent,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
    );

    if (picked == null || !mounted) return;
    setState(() => _deadline = picked);
  }

  void _applyTemplate(String title) {
    _titleController.text = title;
    setState(() => _titleError = null);
  }

  /// The tasks page is reached with `go`, so there may be nothing to pop.
  void _backToHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/parent/home');
    }
  }

  void _submit(ChildAccount? child) {
    FocusScope.of(context).unfocus();

    final title = _titleController.text.trim();
    final reward = int.tryParse(_rewardController.text.trim()) ?? 0;

    setState(() {
      _titleError = title.isEmpty ? 'Give the task a name.' : null;
      _rewardError = reward <= 0 ? 'Set a reward above 0.' : null;
    });

    if (title.isEmpty || reward <= 0) return;
    if (child == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link a child before assigning a task.')),
      );
      return;
    }

    setState(() => _submitting = true);

    // TODO: replace with the real request once the task endpoint exists.
    final draft = AssignTaskDraft(
      childId: child.childId,
      title: title,
      reward: reward,
      deadline: _deadline,
      note: _noteController.text.trim(),
    );
    debugPrint('Assign task draft: ${draft.toJson()}');

    setState(() {
      _submitting = false;
      _titleController.clear();
      _rewardController.clear();
      _noteController.clear();
      _deadline = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task assigned to ${child.name} (saved locally).'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childAccountsProvider);
    final child = ref.watch(selectedChildProvider);
    final list = children.asData?.value ?? const <ChildAccount>[];
    final selectedIndex = list.indexWhere(
      (item) => item.childId == child?.childId,
    );
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign task',
                            style: parentText(
                              size: 20,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set a chore, a goal and the reward',
                            style: parentText(
                              size: 12.5,
                              weight: FontWeight.w500,
                              color: ParentPalette.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ParentBackButton(onTap: _backToHome),
                  ],
                ),
              ),
            ),

            // Child picker
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                child: ParentCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'For',
                        style: parentText(
                          size: 12,
                          weight: FontWeight.w600,
                          color: ParentPalette.label,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (children.isLoading && !children.hasValue)
                        const SizedBox(
                          height: 36,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: ParentPalette.accent,
                              ),
                            ),
                          ),
                        )
                      else if (children.hasError)
                        Text(
                          '${children.error}',
                          style: parentText(
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: ParentPalette.red,
                          ),
                        )
                      else if (list.isEmpty)
                        Text(
                          'No children linked yet. Add one from the home page.',
                          style: parentText(
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: ParentPalette.label,
                          ),
                        )
                      else
                        ParentUnderlineTabs(
                          labels: [for (final item in list) item.name],
                          index: selectedIndex < 0 ? 0 : selectedIndex,
                          onChanged:
                              (index) => ref
                                  .read(selectedChildIdProvider.notifier)
                                  .select(list[index].childId),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Form
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                child: ParentCard(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task',
                        style: parentText(
                          size: 15,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.sentences,
                        style: parentText(size: 14, weight: FontWeight.w500),
                        onChanged: (_) {
                          if (_titleError == null) return;
                          setState(() => _titleError = null);
                        },
                        decoration: parentInputDecoration(
                          hint: 'What should they do?',
                          error: _titleError,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final template in _templates)
                            _TemplateChip(
                              label: template,
                              onTap: () => _applyTemplate(template),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _rewardController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: parentText(size: 14, weight: FontWeight.w500),
                        onChanged: (_) {
                          if (_rewardError == null) return;
                          setState(() => _rewardError = null);
                        },
                        decoration: parentInputDecoration(
                          hint: 'Reward amount',
                          label: 'Reward',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(
                              left: 14,
                              right: 8,
                            ),
                            child: Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Color(0xFFD98324),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                          error: _rewardError,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DeadlineRow(
                        deadline: _deadline,
                        onTap: _pickDeadline,
                        onClear:
                            _deadline == null
                                ? null
                                : () => setState(() => _deadline = null),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        style: parentText(size: 14, weight: FontWeight.w500),
                        decoration: parentInputDecoration(
                          hint: 'Anything they should know? (optional)',
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
                    ParentPrimaryButton(
                      label: 'Assign task',
                      loading: _submitting,
                      onPressed: () => _submit(child),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nothing is sent to the server yet — this form is a '
                      'preview of the assign-task flow.',
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
      bottomNavigationBar: ParentBottomNav(
        index: 1,
        onSelect: (index) {
          if (index == 0) context.go('/parent/home');
        },
        onFabPressed: () => context.go('/child-register'),
        fabTooltip: 'Add child',
      ),
    );
  }
}

/// Deadline picker row: flat card with a calendar icon and a clear action.
class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({
    required this.deadline,
    required this.onTap,
    this.onClear,
  });

  final DateTime? deadline;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      color: ParentPalette.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.event_rounded,
            size: 18,
            color: ParentPalette.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deadline',
                  style: parentText(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: ParentPalette.label,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deadline == null
                      ? 'Pick a date'
                      : '${deadline!.day}/${deadline!.month}/${deadline!.year}',
                  style: parentText(
                    size: 14,
                    weight: FontWeight.w600,
                    color:
                        deadline == null
                            ? ParentPalette.faint
                            : ParentPalette.ink,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Clear deadline',
              onPressed: onClear,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: ParentPalette.faint,
              ),
            ),
        ],
      ),
    );
  }
}

/// Suggestion pill under the task field.
class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: ParentPalette.raised,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: parentText(
                size: 12,
                weight: FontWeight.w600,
                color: ParentPalette.label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Payload this screen would send once the backend supports tasks.
class AssignTaskDraft {
  const AssignTaskDraft({
    required this.childId,
    required this.title,
    required this.reward,
    this.deadline,
    this.note = '',
  });

  final String childId;
  final String title;
  final int reward;
  final DateTime? deadline;
  final String note;

  Map<String, dynamic> toJson() {
    return {
      'childId': childId,
      'title': title,
      'reward': reward,
      'deadline': deadline?.toIso8601String().split('T').first,
      'note': note,
    };
  }
}
