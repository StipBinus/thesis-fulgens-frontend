import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../home/kids_bottom_nav.dart';
import '../home/listen_sheet.dart';
import '../logbook/entry_form_sheet.dart';
import '../logbook/logbook_models.dart';
import '../logbook/logbook_provider.dart';
import '../logbook/logbook_sheet.dart';
import 'kids_nav_state.dart';

// Permanent kids frame: bar stays put, pages move underneath
class KidsFrame extends ConsumerStatefulWidget {
  const KidsFrame({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<KidsFrame> createState() => _KidsFrameState();
}

class _KidsFrameState extends ConsumerState<KidsFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _quickController;
  bool _quickActionsOpen = false;
  int _homeTab = 0;

  bool get _onPockets => widget.location.startsWith('/kids/pockets');
  int get _selectedTab => _onPockets ? 2 : _homeTab;

  @override
  void initState() {
    super.initState();
    kidsNavHidden.addListener(_syncNavChrome);
    _quickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    kidsNavHidden.removeListener(_syncNavChrome);
    _quickController.dispose();
    super.dispose();
  }

  // Bottom bar slides with the arrange mode
  void _syncNavChrome() {
    if (mounted) setState(() {});
  }

  void _toggleQuickActions() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() => _quickActionsOpen = !_quickActionsOpen);
    if (reduceMotion) {
      _quickController.value = _quickActionsOpen ? 1 : 0;
    } else if (_quickActionsOpen) {
      _quickController.forward(from: 0);
    } else {
      _quickController.reverse();
    }
  }

  void _closeQuickActions() {
    if (!_quickActionsOpen) return;
    setState(() => _quickActionsOpen = false);
    _quickController.reverse();
  }

  void _onSelectTab(int index) {
    _closeQuickActions();
    if (index == 2) {
      if (_onPockets) return;
      context.push('/kids/pockets');
      return;
    }
    setState(() => _homeTab = index);
    if (_onPockets) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final logbook = ref.watch(logbookProvider);
    final popoverWidth = (MediaQuery.sizeOf(context).width * 0.56).clamp(
      200.0,
      260.0,
    );

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_quickActionsOpen,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeQuickActions,
                  child: AnimatedBuilder(
                    animation: _quickController,
                    builder: (context, _) {
                      final t = _quickController.value.clamp(0.0, 1.0);
                      if (t == 0) return const SizedBox.expand();
                      return ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: 4.5 * t,
                            sigmaY: 4.5 * t,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: (safeBottom > 10 ? safeBottom : 10) + 86,
              width: popoverWidth,
              child: IgnorePointer(
                ignoring: !_quickActionsOpen,
                child: KidsQuickActionsPanel(
                  animation: _quickController,
                  entriesToday: logbook.todayEntryCount,
                  onLogbook: () {
                    _closeQuickActions();
                    showLogbookSheet(context);
                  },
                  onNewEntry: () {
                    _closeQuickActions();
                    showEntryFormSheet(context, dateKey: LogbookState.todayKey);
                  },
                  onSpeak: () {
                    _closeQuickActions();
                    showListenSheet(context);
                  },
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: kidsNavHidden.value,
                child: AnimatedSlide(
                  offset:
                      kidsNavHidden.value
                          ? const Offset(0, 1.2)
                          : Offset.zero,
                  duration:
                      (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                          ? Duration.zero
                          : const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: KidsBottomNav(
                        selectedIndex: _selectedTab,
                        onSelectTab: _onSelectTab,
                        quickActionsOpen: _quickActionsOpen,
                        onQuickAction: _toggleQuickActions,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
