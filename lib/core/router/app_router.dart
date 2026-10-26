import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thesis_fulgens_mobile/app/presentation/auth_service/auth_service.dart';
import 'package:thesis_fulgens_mobile/pages/register_page.dart';

import '../../app/presentation/home/home_page.dart';
import '../../app/presentation/landing/landing_page.dart';
import '../../app/presentation/select/select_page.dart';
import '../../game/presentation/game_page.dart';
import '../../game/presentation/kids_auth_portal_page.dart';
import '../../game/presentation/kids_login_page.dart';
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
      // Reduced motion
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        return FadeTransition(opacity: animation, child: pageChild);
      }
      const Cubic ease = Cubic(0.23, 1, 0.32, 1);
      final CurvedAnimation curve = CurvedAnimation(
        parent: animation,
        curve: ease,
      );
      // Slide rise
      final SlideTransition slide = SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(curve),
        child: pageChild,
      );
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

// Bloom page
Page<void> _bloomPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 640),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      // Reduced motion
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        return FadeTransition(opacity: animation, child: pageChild);
      }
      // Dissolve in
      final CurvedAnimation enter = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      );
      return FadeTransition(opacity: enter, child: pageChild);
    },
  );
}

// Recede page
Page<void> _recedePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 650),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      // Reduced motion
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        return FadeTransition(opacity: animation, child: pageChild);
      }
      // Veil cover
      final CurvedAnimation veil = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.40, curve: Curves.easeInOut),
      );
      // Rise enter
      final CurvedAnimation enter = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.38, 1.0, curve: Cubic(0.23, 1, 0.32, 1)),
      );
      final CurvedAnimation push = CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Cubic(0.32, 0.72, 0, 1),
      );
      return Stack(
        children: [
          // Backdrop base
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: veil,
                child: const ColoredBox(color: Color(0xFFF9F7F3)),
              ),
            ),
          ),
          // Press back
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 0.96).animate(push),
            alignment: Alignment.topCenter,
            child: FadeTransition(
              opacity: enter,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.03),
                  end: Offset.zero,
                ).animate(enter),
                child: pageChild,
              ),
            ),
          ),
        ],
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/select',

  //Pake kalo udah login full selsai
  routes: [
    GoRoute(
      path: '/select',
      name: 'select',
      pageBuilder: (context, state) => _fadePage(const SelectPage(), state),
    ),
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
      pageBuilder:
          (context, state) => _bloomPage(
            // Dev back-to-loading
            PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                context.go('/kids-login?loading=1');
              },
              child: const HomePageFin(),
            ),
            state,
          ),
    ),
    GoRoute(
      path: '/kids',
      name: 'kids',
      pageBuilder:
          (context, state) => _fadePage(const KidsLandingPage(), state),
    ),
    GoRoute(
      path: '/kids-start',
      name: 'kids-start',
      pageBuilder:
          (context, state) => _recedePage(const KidsAuthPortalPage(), state),
    ),
    GoRoute(
      path: '/kids-login',
      name: 'kids-login',
      pageBuilder:
          (context, state) => _fadePage(
            KidsLoginPage(
              // Dev loading entry
              autoStart: state.uri.queryParameters['loading'] == '1',
            ),
            state,
          ),
    ),
    GoRoute(
      path: '/game',
      name: 'game',
      builder: (context, state) => const GamePage(),
    ),
  ],
);
