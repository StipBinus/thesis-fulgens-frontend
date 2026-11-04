import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/session_manager.dart';
import 'core/profile/child_profile_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

// Main entry
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore the session and cached profile before the first frame. The tokens
  // live in SessionManager; the profile stays in SharedPreferences.
  await SessionManager.instance.restore();
  await SessionManager.instance.clearLegacyStorage();
  await ChildProfileStore.instance.restore();

  runApp(const ProviderScope(child: FulgensApp()));

  unawaited(ChildProfileStore.instance.refreshIfSignedIn());
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
