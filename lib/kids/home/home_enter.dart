import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Rise entrance length for Pocket → Home
const Duration _riseDuration = Duration(milliseconds: 460);

// Home route page: plays the rise entrance
Page<void> homeEnterPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _riseDuration,
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return FadeTransition(opacity: animation, child: pageChild);
      }
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) => homeEnterVisual(animation.value, child!),
        child: pageChild,
      );
    },
  );
}

// Draws the rise entrance at the given progress
Widget homeEnterVisual(double progress, Widget child) {
  final double t = progress.clamp(0.0, 1.0);
  if (t >= 1) return child;
  // Scale up: fade + 0.94 → 1
  final double e = const Cubic(0.23, 1, 0.32, 1).transform(t);
  return Opacity(
    opacity: Curves.easeOut.transform(t),
    child: Transform.scale(scale: 0.94 + 0.06 * e, child: child),
  );
}
