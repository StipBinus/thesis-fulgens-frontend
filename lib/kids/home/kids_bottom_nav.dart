import 'package:flutter/material.dart';

// Shared bar and quick actions for every kids screen

/// Floating bottom navigation, styled after the reference bar.
class KidsBottomNav extends StatelessWidget {
  const KidsBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
    required this.onQuickAction,
    required this.quickActionsOpen,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onQuickAction;
  final bool quickActionsOpen;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final align =
        selectedIndex == 0
            ? const Alignment(-1.0, 0.0)
            : (selectedIndex == 1
                ? const Alignment(0.0, 0.0)
                : const Alignment(1.0, 0.0));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 276,
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(31),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration:
                    reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: align,
                child: FractionallySizedBox(
                  widthFactor: 1 / 3,
                  heightFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEDED),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: selectedIndex == 0,
                    onTap: () => onSelectTab(0),
                  ),
                  _NavItem(
                    icon: Icons.fact_check_rounded,
                    label: 'Tasks',
                    selected: selectedIndex == 1,
                    onTap: () => onSelectTab(1),
                  ),
                  _NavItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Pockets',
                    selected: selectedIndex == 2,
                    onTap: () => onSelectTab(2),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _NavCircleButton(open: quickActionsOpen, onTap: onQuickAction),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const Color active = Color(0xFF2F6BFF);
    const Color ink = Color(0xFF111111);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration:
                    reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: Icon(icon, size: 24, color: selected ? active : ink),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration:
                    reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? active : ink,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  const _NavCircleButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) {
            return RotationTransition(
              turns: Tween<double>(begin: 0.55, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(
            open ? Icons.close_rounded : Icons.add_rounded,
            key: ValueKey<bool>(open),
            size: 25,
            color: const Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}

/// Compact white quick-action card anchored above the pencil button.
class KidsQuickActionsPanel extends StatelessWidget {
  const KidsQuickActionsPanel({
    super.key,
    required this.animation,
    required this.entriesToday,
    required this.onLogbook,
    required this.onNewEntry,
    required this.onSpeak,
  });

  final Animation<double> animation;
  final int entriesToday;
  final VoidCallback onLogbook;
  final VoidCallback onNewEntry;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final panel = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: panel,
      builder: (context, child) {
        final t = panel.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: Transform.scale(
              scale: 0.92 + 0.08 * t,
              alignment: Alignment.bottomRight,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StaggeredReveal(
              animation: animation,
              interval: const Interval(0.18, 0.72, curve: Curves.easeOutCubic),
              child: _QuickActionRow(
                title: 'Logbook',
                subtitle:
                    entriesToday == 0
                        ? 'No entries today'
                        : '$entriesToday ${entriesToday == 1 ? 'entry' : 'entries'} today',
                icon: Icons.menu_book_rounded,
                onTap: onLogbook,
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F1F3)),
            _StaggeredReveal(
              animation: animation,
              interval: const Interval(0.32, 0.88, curve: Curves.easeOutCubic),
              child: _QuickActionRow(
                title: 'New entry',
                subtitle: 'Speak it or type it',
                icon: Icons.edit_note_rounded,
                onTap: onNewEntry,
                secondaryIcon: Icons.mic_rounded,
                onSecondaryTap: onSpeak,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and lifts a child in, timed by an [Interval] of the panel animation.
class _StaggeredReveal extends StatelessWidget {
  const _StaggeredReveal({
    required this.animation,
    required this.interval,
    required this.child,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = CurvedAnimation(
          parent: animation,
          curve: interval,
        ).value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _QuickActionRow extends StatefulWidget {
  const _QuickActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.secondaryIcon,
    this.onSecondaryTap,
    this.secondaryEnabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondaryTap;
  final bool secondaryEnabled;

  @override
  State<_QuickActionRow> createState() => _QuickActionRowState();
}

class _QuickActionRowState extends State<_QuickActionRow> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setDown(true) : null,
      onTapUp: enabled ? (_) => _setDown(false) : null,
      onTapCancel: enabled ? () => _setDown(false) : null,
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color:
                            enabled
                                ? const Color(0xFF111111)
                                : const Color(0xFF9AA0A6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7A7F85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.secondaryIcon != null) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.secondaryEnabled ? widget.onSecondaryTap : null,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7F8F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.secondaryIcon,
                      size: 19,
                      color:
                          widget.secondaryEnabled
                              ? const Color(0xFF111111)
                              : const Color(0xFFB4B9BE),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      _down ? const Color(0xFFE6EAEE) : const Color(0xFFF1F3F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 19,
                  color:
                      enabled
                          ? const Color(0xFF111111)
                          : const Color(0xFF9AA0A6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

