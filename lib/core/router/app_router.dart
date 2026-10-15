import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thesis_fulgens_mobile/app/presentation/auth_service/auth_service.dart';
import 'package:thesis_fulgens_mobile/pages/register_page.dart';

import '../../app/presentation/home/home_page.dart';
import '../../app/presentation/landing/landing_page.dart';
import '../../app/presentation/preview/fulgens_preview_page.dart';
import '../../game/presentation/game_page.dart';
import '../../game/presentation/kids_auth_portal_page.dart';
import '../../game/presentation/kids_landing_page.dart';
import '../../pages/login_page.dart';

/// Central routing for the app.
/// - Input is NOT a route, it's a draggable overlay (bottom sheet) on top of Home.
/// - This keeps the "back" behavior clean: closing the sheet != navigating back.

final authService = AuthService();

// Slide up page
Page<void> _slideUpPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 650),
    reverseTransitionDuration: const Duration(milliseconds: 625),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      const Cubic ease = Cubic(0.23, 1, 0.32, 1);
      final CurvedAnimation curve = CurvedAnimation(
        parent: animation,
        curve: ease,
      );
      // Slide rise
      final SlideTransition slide = SlideTransition(
        position:
            Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(curve),
        child: pageChild,
      );
      // Fade only in
      if (animation.status == AnimationStatus.reverse) {
        return slide;
      }
      return FadeTransition(opacity: curve, child: slide);
    },
  );
}

// Fade page
Page<void> _fadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      return FadeTransition(opacity: animation, child: pageChild);
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',

  //Pake kalo udah login full selsai
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) => _slideUpPage(const LoginPage(), state),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      pageBuilder: (context, state) => _fadePage(const RegisterPage(), state),
    ),
    GoRoute(
      path: '/',
      name: 'landing',
      pageBuilder:
          (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: LandingPage(
              showDetail: state.uri.queryParameters['detail'] == '1',
            ),
            // Instant in
            transitionDuration: Duration.zero,
            // Fade out
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/kids',
      name: 'kids',
      pageBuilder: (context, state) => _fadePage(const KidsLandingPage(), state),
    ),
    GoRoute(
      path: '/kids-start',
      name: 'kids-start',
      pageBuilder:
          (context, state) => _fadePage(const KidsAuthPortalPage(), state),
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
