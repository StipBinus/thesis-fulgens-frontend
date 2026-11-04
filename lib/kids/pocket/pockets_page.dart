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

/// Lets the child create, edit, and delete money pockets.
class KidsPocketsPage extends StatefulWidget {
  const KidsPocketsPage({super.key});

  @override
  State<KidsPocketsPage> createState() => _KidsPocketsPageState();
}

class _KidsPocketsPageState extends State<KidsPocketsPage> {
  final ChildPocketRepository _repository = ChildPocketRepository();

  List<ChildPocket> _pockets = const [];
  List<ChildGoal> _goals = const [];
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
      // allocated to other pockets and goals.
      final results = await Future.wait<Object>([
        _repository.fetchPockets(),
        ChildGoalRepository().fetchGoals(),
        ChildProfileStore.instance.ensure(),
      ]);

      if (!mounted) return;
      setState(() {
        _pockets = results[0] as List<ChildPocket>;
        _goals = results[1] as List<ChildGoal>;
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
        _error = 'Could not load your pockets. Please try again.';
        _loading = false;
      });
    }
  }

  int _availableFor({int? excludePocketId}) {
    return financeAvailableCash(
      balance: _profile?.userBalance ?? 0,
      pockets: [
        for (final pocket in _pockets)
          if (pocket.pocketId != excludePocketId) pocket.allocatedBalance,
      ],
      goals: _goals.map((goal) => goal.allocatedBalance),
    );
  }

  Future<void> _openEditor({ChildPocket? pocket}) async {
    final profile = _profile;
    if (profile == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x52000000),
      builder:
          (_) => PocketEditorSheet(
            pocket: pocket,
            balance: profile.userBalance,
            available: _availableFor(excludePocketId: pocket?.pocketId),
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
                title: 'Pockets',
                subtitle: 'Keep your money in the right place',
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
                      label: 'Add pocket',
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
    if (_loading && _pockets.isEmpty) {
      return const [
        FinanceCard(
          padding: EdgeInsets.symmetric(vertical: 44),
          child: Center(child: CircularProgressIndicator(color: logbookAccent)),
        ),
      ];
    }

    if (_error != null && _pockets.isEmpty) {
      return [FinanceErrorState(message: _error!, onRetry: _load)];
    }

    if (_pockets.isEmpty) {
      return [
        _CashCard(balance: _availableFor()),
        const SizedBox(height: 16),
        const FinanceEmptyState(
          icon: Icons.account_balance_wallet_rounded,
          title: 'No pockets yet',
          message:
              'Create a pocket for cash, snacks, savings, or anything else.',
        ),
      ];
    }

    return [
      _CashCard(balance: _availableFor()),
      const SizedBox(height: 12),
      for (var i = 0; i < _pockets.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        _PocketCard(
          pocket: _pockets[i],
          onTap: () => _openEditor(pocket: _pockets[i]),
        ),
      ],
    ];
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinancePocketAvatar(image: null, name: 'Cash', size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cash',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: logbookInk,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Money not in a pocket or goal yet',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: logbookMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Available',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: logbookFaint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        financeRupiah(balance),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: logbookInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PocketCard extends StatelessWidget {
  const _PocketCard({required this.pocket, required this.onTap});

  final ChildPocket pocket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = pocket.pocketDesc;

    return FinanceCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinancePocketAvatar(
            image: pocket.pocketImage,
            name: pocket.pocketName,
            size: 50,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pocket.pocketName,
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Allocated',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: logbookFaint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        financeRupiah(pocket.allocatedBalance),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: logbookInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: logbookFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Popup used for both creating and editing a pocket.
class PocketEditorSheet extends StatefulWidget {
  const PocketEditorSheet({
    super.key,
    this.pocket,
    required this.balance,
    required this.available,
  });

  final ChildPocket? pocket;

  /// Child balance, shown for context.
  final int balance;

  /// Money that can still be allocated to this pocket.
  final int available;

  @override
  State<PocketEditorSheet> createState() => _PocketEditorSheetState();
}

class _PocketEditorSheetState extends State<PocketEditorSheet> {
  final ChildPocketRepository _repository = ChildPocketRepository();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _image;
  late final TextEditingController _allocated;

  bool _saving = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.pocket != null;

  @override
  void initState() {
    super.initState();
    final pocket = widget.pocket;
    _name = TextEditingController(text: pocket?.pocketName ?? '');
    _description = TextEditingController(text: pocket?.pocketDesc ?? '');
    _image = TextEditingController(text: pocket?.pocketImage ?? '');
    _allocated = TextEditingController(
      text: _amountText(pocket?.allocatedBalance),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    _allocated.dispose();
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
      setState(() => _error = 'Give your pocket a name first.');
      return;
    }

    final allocated = _amount(_allocated);
    if (allocated > widget.available) {
      setState(
        () =>
            _error =
                'You can only allocate up to ${financeRupiah(widget.available)}. '
                'Lower the amount.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await _repository.updatePocket(
          pocketId: widget.pocket!.pocketId,
          name: name,
          description: _description.text,
          image: _image.text,
          allocatedBalance: allocated,
        );
      } else {
        await _repository.createPocket(
          name: name,
          description: _description.text,
          image: _image.text,
          allocatedBalance: allocated,
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
        _error = 'Could not save your pocket. Please try again.';
      });
    }
  }

  Future<void> _delete() async {
    final pocket = widget.pocket;
    if (pocket == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                title: const Text('Delete pocket?'),
                content: Text(
                  '"${pocket.pocketName}" and the money inside it will be removed.',
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
      await _repository.deletePocket(pocket.pocketId);
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
        _error = 'Could not delete this pocket. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FinanceSheet(
      title: _isEditing ? 'Edit pocket' : 'New pocket',
      subtitle:
          _isEditing
              ? 'Rename it, change the icon, or move the money.'
              : 'What is this pocket for?',
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
              label: 'Pocket name',
              hint: 'e.g. Snacks',
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
              hint: 'What do you use it for?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _image,
            onChanged: (_) => _clearError(),
            decoration: financeInputDecoration(
              label: 'Icon or image (optional)',
              hint: 'e.g. 🎒 or https://…',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _allocated,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => _clearError(),
            decoration: financeInputDecoration(
              label: 'Allocated money',
              hint: '0',
              prefixText: 'Rp ',
            ),
          ),
          FinanceFormError(message: _error),
          const SizedBox(height: 18),
          FinancePrimaryButton(
            label: _isEditing ? 'Save changes' : 'Create pocket',
            onTap: _deleting ? null : _save,
            loading: _saving,
          ),
          if (_isEditing) ...[
            const SizedBox(height: 2),
            FinanceDangerButton(
              label: _deleting ? 'Deleting…' : 'Delete pocket',
              onTap: _deleting ? null : _delete,
            ),
          ],
        ],
      ),
    );
  }
}
