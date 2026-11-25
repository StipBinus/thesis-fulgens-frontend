// One drain for the whole app: debounced, single flight, retried until clean.

import 'dart:async';

import 'sync_engine.dart';
import 'sync_lock.dart';

class SyncScheduler {
  SyncScheduler._();

  static final SyncScheduler instance = SyncScheduler._();

  static const Duration _debounce = Duration(milliseconds: 250);
  static const Duration _retry = Duration(seconds: 30);
  static const Duration _timeout = Duration(seconds: 15);

  Timer? _wake;
  Future<void>? _inFlight;
  bool _again = false;

  // A write asked for a drain; bursts collapse into one run.
  Future<void> request() {
    if (_inFlight != null) {
      _again = true;
      return _inFlight!;
    }
    _wake?.cancel();
    _wake = Timer(_debounce, () => unawaited(_run()));
    return Future<void>.value();
  }

  Future<void> _run() async {
    _wake = null;
    final pending = _inFlight;
    if (pending != null) {
      _again = true;
      return pending;
    }

    final future = _drain();
    _inFlight = future;
    try {
      await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<void> _drain() async {
    SyncReport report;
    try {
      report = await SyncLock.run(
        () => SyncEngine().syncNow().timeout(_timeout),
      );
    } catch (_) {
      _scheduleRetry();
      return;
    }

    if (_again) {
      _again = false;
      unawaited(request());
      return;
    }
    if (report.pending > 0) {
      if (report.sent > 0) {
        unawaited(request());
      } else {
        _scheduleRetry();
      }
    }
  }

  void _scheduleRetry() {
    _wake?.cancel();
    _wake = Timer(_retry, () => unawaited(_run()));
  }
}
