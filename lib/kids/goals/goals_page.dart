import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile/child_profile.dart';
import '../../core/profile/child_profile_store.dart';
import '../finance/finance_api.dart';
import '../finance/finance_models.dart';
import '../finance/finance_repository.dart';
import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';

/// Lets the child create, edit, and delete saving goals.
class KidsGoalsPage extends StatefulWidget {
  const KidsGoalsPage({super.key});

  @override
  State<KidsGoalsPage> createState() => _KidsGoalsPageState();
}

class _KidsGoalsPageState extends State<KidsGoalsPage> {
  final ChildGoalRepository _repository = ChildGoalRepository();

  List<ChildGoal> _goals = const [];
  List<ChildPocket> _pockets = const [];
  ChildProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Both lists are needed to know how much of the balance is already
      // allocated to other goals and pockets.
      final results = await Future.wait<Object>([
        _repository.fetchGoals(),
        ChildPocketRepository().fetchPockets(),
        ChildProfileStore.instance.ensure(),
      ]);

      if (!mounted) return;
      setState(() {
        _goals = results[0] as List<ChildGoal>;
        _pockets = results[1] as List<ChildPocket>;
        _profile = results[2] as ChildProfile;
        _loading = false;
      });
    } on FinanceApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your goals. Please try again.';
        _loading = false;
      });
    }
  }

  int _allocatedElsewhere({int? excludeGoalId}) {
    var total = 0;

    for (final goal in _goals) {
      if (goal.goalId == excludeGoalId) continue;
      total += goal.allocatedBalance;
    }
    for (final pocket in _pockets) {
      total += pocket.allocatedBalance;
    }

    return total;
  }

  int _availableFor({int? excludeGoalId}) {
    final balance = _profile?.userBalance ?? 0;
    final remaining =
        balance - _allocatedElsewhere(excludeGoalId: excludeGoalId);
    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _openEditor({ChildGoal? goal}) async {
    final profile = _profile;
    if (profile == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x52000000),
      builder:
          (_) => GoalEditorSheet(
            goal: goal,
            balance: profile.userBalance,
            available: _availableFor(excludeGoalId: goal?.goalId),
          ),
    );

    if (changed == true) await _load();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/kids/home');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: FinanceHeader(
                title: 'Goals',
                subtitle: 'Save up for something you want',
                onBack: _goBack,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: logbookAccent,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottomInset),
                  children: [
                    FinanceAddButton(
                      label: 'Add goal',
                      onTap: () => _openEditor(),
                    ),
                    const SizedBox(height: 16),
                    ..._content(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content() {
    if (_loading && _goals.isEmpty) {
      return const [
        FinanceCard(
          padding: EdgeInsets.symmetric(vertical: 44),
          child: Center(child: CircularProgressIndicator(color: logbookAccent)),
        ),
      ];
    }

    if (_error != null && _goals.isEmpty) {
      return [FinanceErrorState(message: _error!, onRetry: _load)];
    }

    if (_goals.isEmpty) {
      return const [
        FinanceEmptyState(
          icon: Icons.flag_rounded,
          title: 'No goals yet',
          message:
              'Create your first saving goal, then put money aside for it.',
        ),
      ];
    }

    return [
      for (var i = 0; i < _goals.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        _GoalCard(goal: _goals[i], onTap: () => _openEditor(goal: _goals[i])),
      ],
    ];
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final ChildGoal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = goal.goalsDesc;

    return FinanceCard(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: logbookAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  size: 22,
                  color: logbookAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.goalsName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: logbookInk,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: logbookMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: logbookFaint,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${financeRupiah(goal.allocatedBalance)} saved',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: logbookInk,
                  ),
                ),
              ),
              Text(
                financePercent(goal.progress),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: logbookAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FinanceProgressBar(value: goal.progress),
          const SizedBox(height: 8),
          Text(
            'Target ${financeRupiah(goal.goalPrice)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: logbookFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Popup used for both creating and editing a goal.
class GoalEditorSheet extends StatefulWidget {
  const GoalEditorSheet({
    super.key,
    this.goal,
    required this.balance,
    required this.available,
  });

  final ChildGoal? goal;

  /// Child balance, shown for context.
  final int balance;

  /// Money that can still be allocated to this goal.
  final int available;

  @override
  State<GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<GoalEditorSheet> {
  final ChildGoalRepository _repository = ChildGoalRepository();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _saved;
  late final TextEditingController _target;

  bool _saving = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _name = TextEditingController(text: goal?.goalsName ?? '');
    _description = TextEditingController(text: goal?.goalsDesc ?? '');
    _saved = TextEditingController(text: _amountText(goal?.allocatedBalance));
    _target = TextEditingController(text: _amountText(goal?.goalPrice));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _saved.dispose();
    _target.dispose();
    super.dispose();
  }

  String _amountText(int? value) {
    if (value == null || value <= 0) return '';
    return '$value';
  }

  int _amount(TextEditingController controller) {
    final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _save() async {
    final name = _name.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Give your goal a name first.');
      return;
    }

    final target = _amount(_target);
    if (target <= 0) {
      setState(() => _error = 'Set a target bigger than Rp 0.');
      return;
    }

    final allocated = _amount(_saved);
    if (allocated > widget.available) {
      setState(
        () =>
            _error =
                'You can only allocate up to ${financeRupiah(widget.available)}. '
                'Lower the saved amount.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await _repository.updateGoal(
          goalId: widget.goal!.goalId,
          name: name,
          description: _description.text,
          allocatedBalance: allocated,
          goalPrice: target,
        );
      } else {
        await _repository.createGoal(
          name: name,
          description: _description.text,
          allocatedBalance: allocated,
          goalPrice: target,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FinanceApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save your goal. Please try again.';
      });
    }
  }

  Future<void> _delete() async {
    final goal = widget.goal;
    if (goal == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                title: const Text('Delete goal?'),
                content: Text(
                  '"${goal.goalsName}" and the money saved for it will be removed.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: TextButton.styleFrom(foregroundColor: logbookRed),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await _repository.deleteGoal(goal.goalId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FinanceApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Could not delete this goal. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FinanceSheet(
      title: _isEditing ? 'Edit goal' : 'New goal',
      subtitle:
          _isEditing
              ? 'Adjust the target, savings, or details.'
              : 'What are you saving for?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinanceAllocationInfo(
            balance: widget.balance,
            available: widget.available,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(),
            decoration: financeInputDecoration(
              label: 'Goal name',
              hint: 'e.g. New bicycle',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: financeInputDecoration(
              label: 'Description (optional)',
              hint: 'Why do you want it?',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _clearError(),
                  decoration: financeInputDecoration(
                    label: 'Target',
                    hint: '0',
                    prefixText: 'Rp ',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _saved,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _clearError(),
                  decoration: financeInputDecoration(
                    label: 'Saved',
                    hint: '0',
                    prefixText: 'Rp ',
                  ),
                ),
              ),
            ],
          ),
          FinanceFormError(message: _error),
          const SizedBox(height: 18),
          FinancePrimaryButton(
            label: _isEditing ? 'Save changes' : 'Create goal',
            onTap: _deleting ? null : _save,
            loading: _saving,
          ),
          if (_isEditing) ...[
            const SizedBox(height: 2),
            FinanceDangerButton(
              label: _deleting ? 'Deleting…' : 'Delete goal',
              onTap: _deleting ? null : _delete,
            ),
          ],
        ],
      ),
    );
  }
}
