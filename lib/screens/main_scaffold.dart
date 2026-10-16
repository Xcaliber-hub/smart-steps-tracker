// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_screen.dart';
import 'stats_screen.dart';
import 'achievements_screen.dart';
import 'groups_screen.dart';
import 'settings_screen.dart';
import '../widgets/beam_border.dart';

/// Root shell hosting the five main tabs of the app.
///
/// Keeps each tab mounted while animating between them, and uses a floating
/// glassmorphic pill-shaped navigation dock with icons and labels.
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
    GroupsScreen(),
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
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'Groups',
      tooltip: 'Friends and groups',
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
          // Pages fill the whole screen and stay mounted to preserve their
          // state; inactive pages fade and slide out of view.
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: _index != i,
                      child: ExcludeSemantics(
                        excluding: _index != i,
                        child: AnimatedOpacity(
                          opacity: _index == i ? 1 : 0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          child: AnimatedSlide(
                            offset: _index == i
                                ? Offset.zero
                                : const Offset(0.025, 0),
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOutCubic,
                            child: _pages[i],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
                child: BeamBorder(
                  borderRadius: 36,
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
                                  compact: MediaQuery.sizeOf(context).width < 400,
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
    required this.compact,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final bool compact;
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
            horizontal: selected ? (compact ? 8 : 14) : (compact ? 6 : 12),
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
