import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thesis_fulgens_mobile/parent/auth/register_child_page.dart';

import '../../kids/auth/kids_auth_portal_page.dart';
import '../../kids/auth/kids_login_page.dart';
import '../../kids/goals/goals_page.dart';
import '../../kids/home/home_page.dart';
import '../../kids/landing/kids_landing_page.dart';
import '../../kids/pocket/pocket_transition.dart';
import '../../kids/pocket/pockets_page.dart';
import '../../kids/shell/kids_frame.dart';
import '../../parent/auth/login_page.dart';
import '../../parent/auth/register_page.dart';
import '../../parent/home/parent_home_page.dart';
import '../../parent/landing/landing_page.dart';
import '../../select/select_page.dart';

/// Central routing for the app.
/// - Input is NOT a route, it's a draggable overlay (bottom sheet) on top of Home.
/// - This keeps the "back" behavior clean: closing the sheet != navigating back.

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

  // Select branches into parent and kids; each side keeps its own pages.
  routes: [
    GoRoute(
      path: '/select',
      name: 'select',
      pageBuilder: (context, state) => _fadePage(const SelectPage(), state),
    ),
    // Parent
    GoRoute(
      path: '/parent',
      name: 'parent',
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
      path: '/parent/login',
      name: 'parent-login',
      pageBuilder: (context, state) => _slideUpPage(const LoginPage(), state),
    ),
    GoRoute(
      path: '/parent/register',
      name: 'parent-register',
      pageBuilder: (context, state) => _fadePage(const RegisterPage(), state),
    ),
    GoRoute(
      path: '/parent/home',
      name: 'parent-home',
      pageBuilder:
          (context, state) => _bloomPage(const ParentHomePage(), state),
    ),
    // Kids
    GoRoute(
      path: '/kids',
      name: 'kids',
      pageBuilder:
          (context, state) => _fadePage(const KidsLandingPage(), state),
    ),
    GoRoute(
      path: '/kids/start',
      name: 'kids-start',
      pageBuilder:
          (context, state) => _recedePage(const KidsAuthPortalPage(), state),
    ),
    GoRoute(
      path: '/kids/login',
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
    ShellRoute(
      pageBuilder:
          (context, state, child) => _bloomPage(
            KidsFrame(location: state.uri.path, child: child),
            state,
          ),
      routes: [
        GoRoute(
          path: '/kids/home',
          name: 'kids-home',
          pageBuilder:
              (context, state) => NoTransitionPage<void>(
                // Dev back-to-loading
                child: PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) {
                    if (didPop) return;
                    context.go('/kids/login?loading=1');
                  },
                  child: const HomePageFin(),
                ),
              ),
        ),
        GoRoute(
          path: '/kids/pockets',
          name: 'kids-pockets',
          pageBuilder:
              (context, state) =>
                  pocketTransitionPage(context, const KidsPocketsPage(), state),
        ),
      ],
    ),
    GoRoute(
      path: '/kids/goals',
      name: 'kids-goals',
      pageBuilder:
          (context, state) => _slideUpPage(const KidsGoalsPage(), state),
    ),
    GoRoute(
      path: '/child-register',
      name: 'child-register',
      builder: (context, state) => const RegisterChildPage(),
    ),
  ],
);
