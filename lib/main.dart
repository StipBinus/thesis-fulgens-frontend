import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

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
