// Background sync while the app is open: reconnect, resume, every 5 minutes.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'backend_pull.dart';
import 'sync_engine.dart';
import 'sync_lock.dart';
import 'sync_scheduler.dart';

class SyncTriggers {
  SyncTriggers._();

  static final SyncTriggers instance = SyncTriggers._();

  static const Duration _interval = Duration(minutes: 5);
  static const Duration _minPullGap = Duration(minutes: 1);

  StreamSubscription<List<ConnectivityResult>>? _net;
  Timer? _tick;
  bool _online = true;
  DateTime? _lastPull;
  Future<void>? _inFlight;

  // Called once from main after runApp.
  void start() {
    _net ??= Connectivity().onConnectivityChanged.listen(_onNet);
    _startTimer();
  }

  // App back in front: push, then pull.
  void onResumed() {
    _startTimer();
    unawaited(syncNow());
  }

  // App in background: no timer.
  void onPaused() {
    _tick?.cancel();
    _tick = null;
  }

  // Push the outbox, then pull; the pull keeps unsent edits on top.
  Future<void> syncNow({bool force = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _run(force: force);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<void> _run({required bool force}) async {
    if (!_online) return;
    // Wait for the send to finish so the pull sees it on the server.
    try {
      await SyncLock.run(
        () => SyncEngine().syncNow().timeout(const Duration(seconds: 15)),
      );
    } catch (_) {
      // Offline: the scheduler keeps retrying.
      unawaited(SyncScheduler.instance.request());
    }

    final last = _lastPull;
    if (!force && last != null && DateTime.now().difference(last) < _minPullGap) {
      return;
    }
    _lastPull = DateTime.now();
    try {
      await BackendPull().run(force: true);
    } catch (_) {
      // Offline or signed out: local copy stays.
    }
  }

  void _onNet(List<ConnectivityResult> results) {
    final wasOnline = _online;
    _online = results.any((r) => r != ConnectivityResult.none);
    if (_online && !wasOnline) unawaited(syncNow(force: true));
  }

  void _startTimer() {
    _tick?.cancel();
    _tick = Timer.periodic(_interval, (_) => unawaited(syncNow()));
  }
}
