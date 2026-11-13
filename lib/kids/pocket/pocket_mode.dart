import 'package:flutter/foundation.dart';

import '../shell/kids_nav_state.dart';

// Every full-screen mode the savings page can be in
enum PocketPageMode { none, expand, arrange, transfer, edit }

// Single owner of the mode; the bottom nav mirrors it and can never drift
class PocketModeController extends ChangeNotifier {
  PocketModeController({ValueNotifier<bool>? nav}) : nav = nav ?? kidsNavHidden;

  final ValueNotifier<bool> nav;

  PocketPageMode _mode = PocketPageMode.none;

  PocketPageMode get mode => _mode;

  bool get active => _mode != PocketPageMode.none;
  bool get expands => _mode == PocketPageMode.expand;
  bool get arranges => _mode == PocketPageMode.arrange;
  bool get transfers => _mode == PocketPageMode.transfer;

  void expand(bool on) => on ? _set(PocketPageMode.expand) : reset();

  void arrange(bool on) => on ? _set(PocketPageMode.arrange) : reset();

  void edit(bool on) => on ? _set(PocketPageMode.edit) : reset();

  void transfer(bool on) => on ? _set(PocketPageMode.transfer) : reset();

  // Always puts the nav back, safe to call twice
  void reset() {
    final bool changed = _mode != PocketPageMode.none;
    _mode = PocketPageMode.none;
    sync();
    if (changed) notifyListeners();
  }

  // Force the nav to match the current mode
  void sync() => nav.value = _mode != PocketPageMode.none;

  void _set(PocketPageMode mode) {
    if (_mode == mode) {
      sync();
      return;
    }
    _mode = mode;
    sync();
    notifyListeners();
  }
}
