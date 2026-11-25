// One signal for every committed SQLite write.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalData {
  LocalData._();

  static final LocalData instance = LocalData._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  int _depth = 0;
  bool _dirty = false;

  // A bulk write (backend pull) lands as one signal.
  void begin() => _depth++;

  void end() {
    if (_depth > 0) _depth--;
    if (_depth == 0 && _dirty) {
      _dirty = false;
      revision.value++;
    }
  }

  void bump() {
    if (_depth > 0) {
      _dirty = true;
      return;
    }
    revision.value++;
  }
}

class LocalDataNotifier extends Notifier<int> {
  @override
  int build() {
    final data = LocalData.instance;
    void onChange() => state = data.revision.value;
    data.revision.addListener(onChange);
    ref.onDispose(() => data.revision.removeListener(onChange));
    return data.revision.value;
  }
}

final localDataProvider = NotifierProvider<LocalDataNotifier, int>(
  LocalDataNotifier.new,
);
