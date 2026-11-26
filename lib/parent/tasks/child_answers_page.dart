import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../model/ChildAccount.dart';
import '../home/home_models.dart';
import '../home/home_page_provider.dart';
import '../home/selected_child_provider.dart';
import '../ui/parent_ui.dart';

/// The selected child's daily task answers, split by status.
///
/// - Waiting: answered, needs the parent's approval (Approve button).
/// - Completed: approved; the child got the coins.
/// - Pending: not answered yet.
class ChildAnswersPage extends ConsumerStatefulWidget {
  const ChildAnswersPage({super.key});

  @override
  ConsumerState<ChildAnswersPage> createState() => _ChildAnswersPageState();
}

class _ChildAnswersPageState extends ConsumerState<ChildAnswersPage> {
  static const List<String> _statuses = [
    ChildTaskAnswer.waiting,
    ChildTaskAnswer.completed,
    ChildTaskAnswer.pending,
  ];
  static const Map<String, String> _labels = {
    ChildTaskAnswer.waiting: 'Waiting',
    ChildTaskAnswer.completed: 'Completed',
    ChildTaskAnswer.pending: 'Pending',
  };

  int _tab = 0;
  final Set<int> _approving = {};

  Future<void> _approve(ChildAccount child, ChildTaskAnswer task) async {
    setState(() => _approving.add(task.taskId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(homeApiProvider).approveTask(task.taskId);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Approved · ${child.name} gets +${task.reward} coins'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      // Reload either way: a 409 means it was already approved elsewhere.
      ref.invalidate(childTaskAnswersProvider(child.childId));
      // Coins changed, so the home tiles should refetch the child.
      ref.invalidate(childAccountsProvider);
      if (mounted) setState(() => _approving.remove(task.taskId));
    }
  }

  void _backToHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/parent/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childAccountsProvider);
    final child = ref.watch(selectedChildProvider);
    final list = children.asData?.value ?? const <ChildAccount>[];
    final selectedIndex = list.indexWhere(
      (item) => item.childId == child?.childId,
    );
    final answers =
        child == null ? null : ref.watch(childTaskAnswersProvider(child.childId));
    final all = answers?.asData?.value ?? const <ChildTaskAnswer>[];
    final counts = {
      for (final s in _statuses) s: all.where((t) => t.status == s).length,
    };
    final status = _statuses[_tab];
    final shown = all.where((t) => t.status == status).toList();
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: ParentPalette.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: ParentPalette.accent,
          onRefresh: () async {
            if (child == null) return;
            ref.invalidate(childTaskAnswersProvider(child.childId));
            await ref.read(childTaskAnswersProvider(child.childId).future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                              'Answers',
                              style: parentText(
                                size: 20,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Read your child's daily answers and approve them",
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
                    child:
                        children.hasError
                            ? Text(
                              '${children.error}',
                              style: parentText(
                                size: 12.5,
                                weight: FontWeight.w500,
                                color: ParentPalette.red,
                              ),
                            )
                            : list.isEmpty
                            ? Text(
                              children.isLoading
                                  ? 'Loading children…'
                                  : 'No children linked yet. Add one from the home page.',
                              style: parentText(
                                size: 12.5,
                                weight: FontWeight.w500,
                                color: ParentPalette.label,
                              ),
                            )
                            : ParentUnderlineTabs(
                              labels: [for (final item in list) item.name],
                              index: selectedIndex < 0 ? 0 : selectedIndex,
                              onChanged:
                                  (index) => ref
                                      .read(selectedChildIdProvider.notifier)
                                      .select(list[index].childId),
                            ),
                  ),
                ),
              ),

              // Status tabs
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
                  child: ParentUnderlineTabs(
                    labels: [
                      for (final s in _statuses)
                        answers?.hasValue == true
                            ? '${_labels[s]} (${counts[s]})'
                            : _labels[s]!,
                    ],
                    index: _tab,
                    onChanged: (index) => setState(() => _tab = index),
                  ),
                ),
              ),

              if (child != null && answers != null)
                if (answers.isLoading && !answers.hasValue)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: ParentPalette.accent,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (answers.hasError && !answers.hasValue)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                      child: _Message(
                        icon: Icons.cloud_off_rounded,
                        text: '${answers.error}',
                        onRetry:
                            () => ref.invalidate(
                              childTaskAnswersProvider(child.childId),
                            ),
                      ),
                    ),
                  )
                else if (shown.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                      child: _Message(
                        icon: Icons.inbox_rounded,
                        text: _emptyText(status, child.name),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                    sliver: SliverList.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder:
                          (context, i) => _AnswerCard(
                            task: shown[i],
                            approving: _approving.contains(shown[i].taskId),
                            onApprove:
                                shown[i].status == ChildTaskAnswer.waiting
                                    ? () => _approve(child, shown[i])
                                    : null,
                          ),
                    ),
                  ),

              SliverToBoxAdapter(child: SizedBox(height: 24 + bottomInset)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ParentBottomNav(
        index: 2,
        onSelect: (index) {
          if (index == 0) context.go('/parent/home');
          if (index == 1) context.go('/parent/tasks');
        },
        onFabPressed: () => context.go('/child-register'),
        fabTooltip: 'Add child',
      ),
    );
  }

  static String _emptyText(String status, String name) {
    switch (status) {
      case ChildTaskAnswer.waiting:
        return 'Nothing to approve. New answers from $name show up here.';
      case ChildTaskAnswer.completed:
        return 'No approved answers yet.';
      default:
        return '$name has no unanswered tasks.';
    }
  }
}

/// One task: date, question, the child's answer and its status.
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.task,
    required this.approving,
    this.onApprove,
  });

  final ChildTaskAnswer task;
  final bool approving;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final answer = task.answer;

    return ParentCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_typeLabel(task.questionType)} · ${_dateLabel(task.taskDate)}',
                  style: parentText(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: ParentPalette.label,
                  ),
                ),
              ),
              _StatusChip(status: task.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.question,
            style: parentText(size: 14.5, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            decoration: BoxDecoration(
              color: ParentPalette.canvas,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ANSWER',
                  style: parentText(
                    size: 9.5,
                    weight: FontWeight.w700,
                    color: ParentPalette.faint,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  answer == null || answer.isEmpty ? 'Not answered yet' : answer,
                  style: parentText(
                    size: 13,
                    weight: FontWeight.w500,
                    color:
                        answer == null
                            ? ParentPalette.faint
                            : ParentPalette.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: Color(0xFFD98324),
              ),
              const SizedBox(width: 4),
              Text(
                '${task.reward} coins',
                style: parentText(
                  size: 12,
                  weight: FontWeight.w600,
                  color: ParentPalette.label,
                ),
              ),
              const Spacer(),
              if (task.submittedAt != null)
                Text(
                  'Sent ${_timeLabel(task.submittedAt!)}',
                  style: parentText(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: ParentPalette.faint,
                  ),
                ),
            ],
          ),
          if (onApprove != null) ...[
            const SizedBox(height: 14),
            ParentPrimaryButton(
              label: 'Approve',
              height: 46,
              loading: approving,
              onPressed: onApprove,
            ),
          ],
        ],
      ),
    );
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'MULTIPLE_CHOICE':
        return 'Quiz';
      case 'REFLECTION':
        return 'Reflection';
      default:
        return type;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      ChildTaskAnswer.waiting => (
        'Waiting',
        const Color(0xFFB07A12),
        const Color(0xFFFFF1D6),
      ),
      ChildTaskAnswer.completed => (
        'Completed',
        ParentPalette.green,
        const Color(0xFFE3F3E8),
      ),
      _ => ('Pending', ParentPalette.label, ParentPalette.line),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: parentText(size: 11, weight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      child: Row(
        children: [
          Icon(icon, size: 20, color: ParentPalette.faint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: parentText(
                size: 12.5,
                weight: FontWeight.w500,
                color: ParentPalette.label,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: parentText(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: ParentPalette.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dateLabel(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String _timeLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.day} ${_months[time.month - 1]}, $hour:$minute';
}
