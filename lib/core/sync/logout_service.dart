import '../../kids/finance/finance_api.dart';
import '../../kids/logbook/logbook_local_store.dart';
import 'sync_engine.dart';

// Order of operations on sign-out: send what is queued, then optionally clear.
class LogoutService {
  LogoutService({
    SyncEngine? engine,
    LogbookLocalStore? store,
    FinanceApi? api,
  }) : _engine = engine ?? SyncEngine(),
       _store = store ?? LogbookLocalStore(),
       _api = api ?? FinanceApi();

  final SyncEngine _engine;
  final LogbookLocalStore _store;
  final FinanceApi _api;

  /// Attempts a final push. Returns true when nothing is left pending.
  Future<bool> flush() async {
    try {
      final report = await _engine.syncNow();
      return report.clean;
    } catch (_) {
      return false;
    }
  }

  /// Clears the child's mirror only when the queue is empty.
  Future<bool> flushAndClear() async {
    String childId;
    try {
      childId = await _api.childId();
    } catch (_) {
      return false;
    }

    final report = await _engine.syncNow(childId: childId);
    if (!report.clean) return false;

    await _store.clearFor(childId);
    return true;
  }
}
