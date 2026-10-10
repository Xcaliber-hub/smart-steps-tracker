// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

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
/// a floating pill-shaped icon-only navigation bar. (History lives at the
/// bottom of the dashboard, reachable by scrolling.)
class MainScaffold extends ConsumerStatefulWidget {
  /// Creates the app shell.
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.tooltip,
  });

  final IconData icon;
  final IconData selectedIcon;
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
      tooltip: 'Dashboard',
    ),
    _NavItemData(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      tooltip: 'Stats',
    ),
    _NavItemData(
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
      tooltip: 'Achievements',
    ),
    _NavItemData(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
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
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: _pages,
        ),
      ),
      // Center expands to fill the nav slot (pushing the page body to
      // zero height), so a centered Row is used: the pill hugs its content.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                elevation: 6,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(999),
                color: colorScheme.surfaceContainer,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _items.length; i++)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// A single destination in the floating pill nav bar.
///
/// Icon-only by design; the tooltip is exposed as the semantic label so
/// screen readers still announce each destination.
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
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? colorScheme.secondaryContainer
                : Colors.transparent,
          ),
          child: Icon(
            selected ? data.selectedIcon : data.icon,
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
