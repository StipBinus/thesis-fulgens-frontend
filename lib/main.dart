import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'kids/logbook/logbook_provider.dart';

// Main entry
void main() {
  runApp(const ProviderScope(child: FulgensApp()));
}

// App root
class FulgensApp extends ConsumerStatefulWidget {
  const FulgensApp({super.key});

  @override
  ConsumerState<FulgensApp> createState() => _FulgensAppState();
}

class _FulgensAppState extends ConsumerState<FulgensApp> {
  Timer? _berryTicker;

  @override
  void initState() {
    super.initState();
    _berryTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!appRouter.state.uri.path.startsWith('/kids')) return;
      ref.read(logbookProvider.notifier).addBerries(1);
    });
  }

  @override
  void dispose() {
    _berryTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fulgens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
