import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/session_manager.dart';
import 'core/profile/child_profile_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/sync/backend_pull.dart';
import 'core/sync/sync_scheduler.dart';
import 'core/sync/sync_triggers.dart';

// Main entry
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore the session and cached profile before the first frame. The tokens
  // live in SessionManager; the profile stays in SharedPreferences.
  await SessionManager.instance.restore();
  await SessionManager.instance.clearLegacyStorage();
  await ChildProfileStore.instance.restore();

  runApp(const ProviderScope(child: FulgensApp()));

  // Single bootstrap: backend copy, then the pending outbox on top.
  unawaited(BackendPull().run().whenComplete(SyncScheduler.instance.request));
  SyncTriggers.instance.start();
}

// App root
class FulgensApp extends ConsumerStatefulWidget {
  const FulgensApp({super.key});

  @override
  ConsumerState<FulgensApp> createState() => _FulgensAppState();
}

class _FulgensAppState extends ConsumerState<FulgensApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SyncTriggers.instance.onResumed();
    } else if (state == AppLifecycleState.paused) {
      SyncTriggers.instance.onPaused();
    }
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
