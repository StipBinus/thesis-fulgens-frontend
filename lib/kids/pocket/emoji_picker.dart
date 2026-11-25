import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../finance/finance_widgets.dart';
import '../logbook/logbook_tokens.dart';

/// Pocket/goal icon picker wrapped around the name field.
/// Stores `icon:<key>` in [controller]; empty = auto from the name.
class PocketIconPicker extends StatefulWidget {
  const PocketIconPicker({
    super.key,
    required this.controller,
    required this.name,
    required this.fieldBuilder,
    this.goal = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final TextEditingController name;

  /// Builds the name field; [leading] is the icon when the layout puts it there.
  final Widget Function(Widget? leading) fieldBuilder;
  final bool goal;
  final ValueChanged<String>? onChanged;

  @override
  State<PocketIconPicker> createState() => _PocketIconPickerState();
}

class _PocketIconPickerState extends State<PocketIconPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  String get _value => widget.controller.text.trim();

  void _pick(String value) {
    HapticFeedback.selectionClick();
    widget.controller.text = value;
    widget.onChanged?.call(value);
    setState(() {});
  }

  void _toggle() {
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    setState(() => _open = !_open);
    if (reduce) {
      _reveal.value = _open ? 1 : 0;
    } else if (_open) {
      _reveal.forward(from: 0);
    } else {
      _reveal.animateBack(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.name,
      builder:
          (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.fieldBuilder(_avatar(36, onTap: _toggle)),
              _gridReveal(),
            ],
          ),
    );
  }

  // Tinted circle: picked icon, else auto from the name
  Widget _avatar(double size, {VoidCallback? onTap, bool editBadge = true}) {
    final look = pocketLookFor(_value);
    final name = widget.name.text;
    final tint = look?.tint ?? financePocketTint(name);
    final icon =
        look?.icon ??
        (widget.goal ? Icons.flag_rounded : financePocketIcon(name));
    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder:
            (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(anim),
                child: child,
              ),
            ),
        child: Icon(
          icon,
          key: ValueKey('$icon$tint'),
          size: size * 0.5,
          color: tint,
        ),
      ),
    );
    if (onTap == null) return circle;
    return Semantics(
      button: true,
      label: 'Change icon',
      child: _Pressable(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            circle,
            if (editBadge)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  decoration: BoxDecoration(
                    color: logbookInk,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: size * 0.22,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Inline grid: tap the icon, grid opens under the name
  Widget _gridReveal() {
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    return ClipRect(
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, child) {
          final double raw = reduce ? (_open ? 1 : 0) : _reveal.value;
          final double t = Curves.easeOutCubic.transform(raw);
          final double fade = ((t - 0.2) / 0.8).clamp(0.0, 1.0);
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(
              opacity: fade,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - t)),
                child: Transform.scale(
                  scale: 0.98 + 0.02 * t,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: _grid(columns: 6),
        ),
      ),
    );
  }

  Widget _grid({required int columns}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final size = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _autoTile(size),
            for (final look in kPocketLooks) _lookTile(look, size),
          ],
        );
      },
    );
  }

  // Auto: follow the name
  Widget _autoTile(double size) {
    final on = _value.isEmpty || pocketLookFor(_value) == null;
    return _ringTile(
      size: size,
      selected: on,
      tint: logbookLabel,
      onTap: () => _pick(''),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size * 0.42,
        color: logbookLabel,
      ),
    );
  }

  Widget _lookTile(PocketIconLook look, double size) {
    final on = _value == look.value;
    return _ringTile(
      size: size,
      selected: on,
      tint: look.tint,
      label: look.label,
      onTap: () => _pick(look.value),
      child: Icon(look.icon, size: size * 0.48, color: look.tint),
    );
  }

  Widget _ringTile({
    required double size,
    required bool selected,
    required Color tint,
    required VoidCallback onTap,
    required Widget child,
    String? label,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: label ?? 'Auto',
      child: _Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: selected ? 0.2 : 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? tint : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Press feedback: quick scale-down
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
