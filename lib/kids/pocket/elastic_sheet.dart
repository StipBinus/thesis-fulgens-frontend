import 'dart:math' as math;

import 'package:flutter/material.dart';

// Anywhere on the sheet pulls it down; release snaps back with an elastic bounce
class ElasticSheetDrag extends StatefulWidget {
  const ElasticSheetDrag({
    super.key,
    required this.child,
    required this.onDismiss,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final bool enabled;

  @override
  State<ElasticSheetDrag> createState() => _ElasticSheetDragState();
}

class _ElasticSheetDragState extends State<ElasticSheetDrag>
    with SingleTickerProviderStateMixin {
  static const double _dismissFraction = 0.4;
  static const double _dismissVelocity = 1200;
  static const double _flingFloor = 48;

  // Forty percent of the sheet has to leave the screen before it counts
  double get _dismissAt {
    final double height = context.size?.height ?? 0;
    if (height > 0) return height * _dismissFraction;
    final double screen = MediaQuery.maybeOf(context)?.size.height ?? 640;
    return screen * 0.2;
  }

  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _pull(double dy) {
    if (!widget.enabled || dy == 0) return;
    if (_drag.value == 0 && dy < 0) return;
    _drag.value = math.max(0, _drag.value + dy);
  }

  void _settle(double velocity) {
    if (!widget.enabled) return;
    final bool reduce =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bool far = _drag.value > _dismissAt;
    final bool flung =
        velocity > _dismissVelocity && _drag.value > _flingFloor;
    if (far || flung) {
      widget.onDismiss();
      return;
    }
    _drag.animateTo(
      0,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
    );
  }

  // Content at its top hands the overscroll to the sheet instead of dead-stopping
  bool _onScroll(ScrollNotification notification) {
    if (!widget.enabled) return false;
    if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) _pull(-notification.overscroll);
      return false;
    }
    if (notification is ScrollEndNotification && _drag.value > 0) {
      _settle(notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => _pull(details.delta.dy),
      onVerticalDragEnd: (details) => _settle(details.primaryVelocity ?? 0),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: AnimatedBuilder(
          animation: _drag,
          builder:
              (context, child) => Transform.translate(
                offset: Offset(0, _drag.value),
                child: child,
              ),
          child: widget.child,
        ),
      ),
    );
  }
}
