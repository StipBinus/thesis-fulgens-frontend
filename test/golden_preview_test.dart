import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_fulgens_mobile/kids/home/home_page.dart';
import 'package:thesis_fulgens_mobile/parent/auth/login_page.dart';
import 'package:thesis_fulgens_mobile/parent/auth/register_page.dart';

// Golden registry
const _pages = <String, Widget>{
  'login': LoginPage(),
  'register': RegisterPage(),
  'home': HomePageFin(),
};

// Golden sizes
const _fullSizes = <Size>[Size(320, 568), Size(390, 844), Size(1440, 900)];
const _wideOnly = <Size>[Size(1440, 900)];

// Size picker
List<Size> _sizesFor(String name) {
  if (name == 'login' || name == 'register') return _wideOnly;
  return _fullSizes;
}

void main() {
  for (final entry in _pages.entries) {
    for (final size in _sizesFor(entry.key)) {
      final w = size.width.toInt();
      final h = size.height.toInt();
      testWidgets('golden ${entry.key} ${w}x$h', (tester) async {
        // Surface size
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Pump page
        await tester.pumpWidget(MaterialApp(home: entry.value));
        await tester.pumpAndSettle();

        // Golden snapshot
        await expectLater(
          find.byWidget(entry.value),
          matchesGoldenFile('goldens/${entry.key}-${w}x$h.png'),
        );
      });
    }
  }
}
