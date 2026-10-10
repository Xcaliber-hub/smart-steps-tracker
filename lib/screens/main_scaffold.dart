// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_screen.dart';
import 'stats_screen.dart';
import 'achievements_screen.dart';
import 'settings_screen.dart';

/// Root shell hosting the four main tabs of the app.
///
/// Uses an [IndexedStack] so each tab keeps its state while navigating, and
/// a floating glassmorphic pill-shaped navigation dock with icons and labels
/// that hovers over the UI in a [Stack] overlay.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String tooltip;
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    DashboardScreen(),
    StatsScreen(),
    AchievementsScreen(),
    SettingsScreen(),
  ];

  static const List<_NavItemData> _items = [
    _NavItemData(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Home',
      tooltip: 'Dashboard',
    ),
    _NavItemData(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Stats',
      tooltip: 'Stats',
    ),
    _NavItemData(
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
      label: 'Awards',
      tooltip: 'Achievements',
    ),
    _NavItemData(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
      tooltip: 'Settings',
    ),
  ];

  void _onDestinationSelected(int index) {
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Pages fill the whole screen; they scroll *underneath* the dock.
          // Each scrollable adds its own bottom padding so the last item
          // can still be scrolled clear of the dock.
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _index,
              children: _pages,
            ),
          ),
          // Floating navigation dock overlay
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < _items.length; i++)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: _PillNavItem(
                                data: _items[i],
                                selected: _index == i,
                                onTap: () => _onDestinationSelected(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single destination in the floating pill nav bar with icon and text label.
class _PillNavItem extends StatelessWidget {
  const _PillNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: data.tooltip,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: selected
                ? colorScheme.secondaryContainer
                : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? data.selectedIcon : data.icon,
                size: 22,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
