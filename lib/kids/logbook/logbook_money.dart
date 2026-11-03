import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile/child_profile.dart';
import '../../core/profile/child_profile_store.dart';
import '../finance/finance_models.dart';
import '../finance/finance_repository.dart';

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
  const LogbookMoney({required this.balance, required this.pockets});

  /// `userBalance` from the cached profile. Null when no profile is cached yet
  /// (for example a parent session, which cannot read a child profile).
  final int? balance;
  final List<ChildPocket> pockets;

  ChildPocket? pocketById(int? pocketId) {
    if (pocketId == null) return null;
    for (final pocket in pockets) {
      if (pocket.pocketId == pocketId) return pocket;
    }
    return null;
  }
}

final logbookMoneyProvider = FutureProvider<LogbookMoney>((ref) async {
  // Both lookups are best-effort: a missing cache or an offline device should
  // not break the logbook, it should just show Rp 0 / no pockets.
  int? balance;
  var pockets = const <ChildPocket>[];

  try {
    // Cached copy first so the logbook opens instantly after login.
    final ChildProfile? cached = ChildProfileStore.instance.profile;
    final profile = cached ?? await ChildProfileStore.instance.ensure();
    balance = profile.userBalance;
  } catch (_) {
    balance = null;
  }

  // Pocket data is optional for the logbook: if the request fails (offline)
  // the entry form simply shows no pockets instead of breaking the sheet.
  try {
    pockets = await ChildPocketRepository().fetchPockets();
  } catch (_) {
    pockets = const <ChildPocket>[];
  }

  return LogbookMoney(balance: balance, pockets: pockets);
});
