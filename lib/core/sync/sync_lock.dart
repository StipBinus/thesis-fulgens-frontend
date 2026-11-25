// One sync job at a time: a pull never overlaps an outbox send.

import 'dart:async';

class SyncLock {
  SyncLock._();

  static Future<void> _tail = Future<void>.value();

  // Runs after every job queued before it, even ones that failed.
  static Future<T> run<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}
