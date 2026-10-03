import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thesis_fulgens_mobile/app/presentation/auth_service/auth_service.dart';
import 'package:thesis_fulgens_mobile/pages/register_page.dart';

import '../../app/presentation/home/home_page.dart';
import '../../app/presentation/landing/landing_page.dart';
import '../../app/presentation/preview/fulgens_preview_page.dart';
import '../../game/presentation/game_page.dart';
import '../../pages/login_page.dart';

/// Central routing for the app.
/// - Input is NOT a route, it's a draggable overlay (bottom sheet) on top of Home.
/// - This keeps the "back" behavior clean: closing the sheet != navigating back.

final authService = AuthService();

final appRouter = GoRouter(
  initialLocation: '/',

  //Pake kalo udah login full selsai
  // redirect: (context, state) async {
  //   final isLoggedIn = await authService.hasValidToken();

  //   print('isLoggedIn: $isLoggedIn');

  //   final isLoginPage = state.matchedLocation == '/login';

  //   if (!isLoggedIn && !isLoginPage) {
  //     return '/login';
  //   }

  //   if (isLoggedIn && isLoginPage) {
  //     return '/';
  //   }

  //   return null;
  // },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder:
          (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const LoginPage(),
            transitionDuration: const Duration(milliseconds: 650),
            reverseTransitionDuration: const Duration(milliseconds: 450),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              const Cubic ease = Cubic(0.23, 1, 0.32, 1);
              final CurvedAnimation curve = CurvedAnimation(
                parent: animation,
                curve: ease,
              );
              // Slide rise
              return SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).animate(curve),
                child: FadeTransition(opacity: curve, child: child),
              );
            },
          ),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/',
      name: 'landing',
      builder:
          (context, state) => LandingPage(
            showDetail: state.uri.queryParameters['detail'] == '1',
          ),
    ),
    GoRoute(
      path: '/home',
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
