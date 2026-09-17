import 'package:go_router/go_router.dart';

import '../../app/presentation/home/home_page.dart';
import '../../app/presentation/preview/fulgens_preview_page.dart';
import '../../game/presentation/game_page.dart';

// App router
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/game',
      name: 'game',
      builder: (context, state) => const GamePage(),
    ),
    GoRoute(
      path: '/preview-fulgens',
      name: 'preview-fulgens',
      builder: (context, state) => const FulgensPreviewPage(),
    ),
  ],
);
