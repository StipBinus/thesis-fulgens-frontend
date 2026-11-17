import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../finance/finance_models.dart';
import '../finance/finance_repository.dart';
import '../finance/money_manager.dart';
import 'logbook_provider.dart';
import 'logbook_repository.dart';

/// Money shown inside the logbook.
///
/// Previously the logbook kept its own wallet in SharedPreferences, seeded with
/// a fixed Rp 1.150.000 that had no relation to the real balance. Now:
///
/// - [balance] is the child's `userBalance`, read from the profile that
///   [ChildProfileStore] caches in SharedPreferences (`child_profile_v1`), so
///   the logbook always shows the same number as the home page.
/// - [pockets] come from `GET /api/pocket/child/{childId}` through
///   `ChildPocketRepository.fetchPockets()`, which is the same data the
///   Pockets page shows (name, image, allocatedBalance).
class LogbookMoney {
  const LogbookMoney({
    required this.balance,
    required this.pockets,
    this.goals = 0,
  });

  // Rebuilt from the logbook entries; the profile balance is no longer used.
  final int balance;
  final List<ChildPocket> pockets;

  /// Money already set aside for goals.
  final int goals;

  ChildPocket? pocketById(String? pocketId) {
    if (pocketId == null) return null;
    for (final pocket in pockets) {
      if (pocket.pocketId == pocketId) return pocket;
    }
    return null;
  }
}

final logbookMoneyProvider = FutureProvider<LogbookMoney>((ref) async {
  final logbook = ref.watch(logbookProvider);
  var balance = moneyBalance(logbook.days.values);
  try {
    balance = await ref.watch(logbookRepositoryProvider).readBalance();
  } catch (_) {
    // Keep the entry sum when the balance row is unavailable.
  }
  var pockets = const <ChildPocket>[];
  var goals = 0;

  // Pockets now live in SQLite, so the entry form works offline too.
  try {
    pockets = await ref.watch(pocketRepositoryProvider).fetchPockets();
  } catch (_) {
    pockets = const <ChildPocket>[];
  }

  // Goals are optional too: a failed read just means cash shows more.
  try {
    final loaded = await ref.watch(goalRepositoryProvider).fetchGoals();
    for (final goal in loaded) {
      goals += goal.allocatedBalance;
    }
  } catch (_) {
    goals = 0;
  }

  return LogbookMoney(balance: balance, pockets: pockets, goals: goals);
});
