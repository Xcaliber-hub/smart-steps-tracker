// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_screen.dart';
import 'stats_screen.dart';
import 'history_screen.dart';
import 'achievements_screen.dart';
import 'settings_screen.dart';

/// Root shell hosting the five main tabs of the app.
///
/// Uses an [IndexedStack] so each tab keeps its state while navigating, and
/// a floating pill-shaped icon-only navigation bar.
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
    HistoryScreen(),
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
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      tooltip: 'History',
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Material(
          elevation: 6,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(32),
          color: colorScheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < _items.length; i++)
                  _PillNavItem(
                    data: _items[i],
                    selected: _index == i,
                    onTap: () => _onDestinationSelected(i),
                  ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// A single destination in the floating pill nav bar, styled after modern
/// media apps: icon in a tonal circle when selected, small label beneath.
///
/// Labels are shown (unlike the earlier icon-only pass) to match the
/// requested reference design; they also keep the bar accessible.
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
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(10),
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
            const SizedBox(height: 2),
            Text(
              data.tooltip,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
