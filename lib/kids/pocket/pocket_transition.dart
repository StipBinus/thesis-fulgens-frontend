import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// How far above the page bottom the disc starts
const double _bloomLift = 72;

// Starting disc radius
const double _bloomStart = 32;

// Pockets route page: the page rides inside a white disc that blooms upward
Page<void> pocketTransitionPage(
  BuildContext context,
  Widget child,
  GoRouterState state,
) {
  final bool reduce =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration:
        reduce
            ? const Duration(milliseconds: 150)
            : const Duration(milliseconds: 1300),
    reverseTransitionDuration:
        reduce
            ? const Duration(milliseconds: 150)
            : const Duration(milliseconds: 500),
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      if (reduce) {
        return FadeTransition(opacity: animation, child: pageChild);
      }
      return _bloom(animation, pageChild);
    },
  );
}

// Page sits still while the disc edge sweeps over it, and recedes on the way out
Widget _bloom(Animation<double> animation, Widget child) {
  final Animation<double> curved = CurvedAnimation(
    parent: animation,
    curve: const Cubic(0.23, 1, 0.32, 1),
    reverseCurve: const _ExitCurve(),
  );

  return AnimatedBuilder(
    animation: animation,
    builder: (context, pageChild) {
      final double b = curved.value.clamp(0.0, 1.0);
      return ClipPath(clipper: _BloomClipper(b), child: pageChild);
    },
    child: child,
  );
}

// Exit: starts already moving, accelerates as it travels down
class _ExitCurve extends Curve {
  const _ExitCurve();

  // Share of the movement done at a constant pace before it accelerates
  static const double _start = 0.01;

  @override
  double transformInternal(double t) {
    final double e = 1 - t;
    return 1 - (_start * e + (1 - _start) * e * e);
  }
}

class _BloomClipper extends CustomClipper<Path> {
  _BloomClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final double half = size.width / 2;
    final double maxRadius =
        math.sqrt(half * half + size.height * size.height) + 2;
    final double radius = _bloomStart + (maxRadius - _bloomStart) * progress;
    return Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(half, size.height - _bloomLift),
          radius: radius,
        ),
      );
  }

  @override
  bool shouldReclip(_BloomClipper oldClipper) =>
      oldClipper.progress != progress;
}
