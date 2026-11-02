import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:thesis_fulgens_mobile/parent/landing/landing_page.dart';

void main() {
  testWidgets('Parent login navigates and children stays on landing', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LandingPage()),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Login destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Log in as a parent'), findsOneWidget);
    await tester.tap(find.text('Children'));
    await tester.pumpAndSettle();
    expect(find.textContaining('coming soon'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
    await tester.tap(find.text('Back to parents'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log in as a parent'));
    await tester.tap(find.text('Log in as a parent'));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    testWidgets('Landing fits $size with enlarged text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
          home: const LandingPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Log in as a parent'));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Children'));
      await tester.tap(find.text('Children'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
