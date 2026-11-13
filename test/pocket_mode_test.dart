import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_fulgens_mobile/kids/pocket/pocket_mode.dart';

void main() {
  late ValueNotifier<bool> nav;
  late PocketModeController mode;

  setUp(() {
    nav = ValueNotifier<bool>(false);
    mode = PocketModeController(nav: nav);
  });

  tearDown(() {
    mode.dispose();
    nav.dispose();
  });

  test('nav mirrors the mode through every transition', () {
    expect(nav.value, false);

    mode.expand(true);
    expect(nav.value, true);

    mode.arrange(true);
    expect(nav.value, true);

    mode.transfer(true);
    expect(nav.value, true);

    mode.reset();
    expect(nav.value, false);

    mode.arrange(true);
    mode.reset();
    mode.reset();
    expect(nav.value, false);
  });

  test('stress: 2000 random transitions never leave the nav behind', () {
    final random = Random(7);

    for (var i = 0; i < 2000; i++) {
      switch (random.nextInt(5)) {
        case 0:
          mode.expand(true);
        case 1:
          mode.arrange(true);
        case 2:
          mode.transfer(true);
        case 3:
          mode.reset();
        case 4:
          mode.sync();
      }
      expect(
        nav.value,
        mode.active,
        reason: 'step $i ended in ${mode.mode}',
      );
    }

    mode.reset();
    expect(nav.value, false);
  });

  test('leaving any single mode puts the nav back', () {
    final List<void Function(bool)> enters = <void Function(bool)>[
      mode.expand,
      mode.arrange,
      mode.transfer,
    ];

    for (final enter in enters) {
      enter(true);
      expect(nav.value, true);
      mode.reset();
      expect(nav.value, false);
    }
  });
}
