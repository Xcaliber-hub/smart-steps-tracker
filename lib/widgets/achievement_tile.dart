// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';

import '../models/achievement.dart';

/// Card showing one achievement badge and how close it is to unlocking.
///
/// Centered vertical layout: badge icon on top, title and description
/// beneath it, progress bar at the bottom. Unlocked badges render in
/// full color with an "Unlocked" chip; locked badges are dimmed with a
/// lock overlay. [progress] is a 0..1 fraction shown on the progress
/// bar.
class AchievementTile extends StatelessWidget {
  /// Creates a tile for [achievement] with completion [progress].
  const AchievementTile({
    super.key,
    required this.achievement,
    required this.progress,
  });

  /// The badge being displayed.
  final Achievement achievement;

  /// Completion fraction, 0..1 (clamped by the caller).
  final double progress;

  static IconData _iconFor(AchievementMetric metric) {
    switch (metric) {
      case AchievementMetric.singleDaySteps:
        return Icons.directions_walk;
      case AchievementMetric.streakDays:
        return Icons.local_fire_department;
      case AchievementMetric.singleDayDistanceMeters:
        return Icons.route;
      case AchievementMetric.lifetimeSteps:
        return Icons.military_tech;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final unlocked = achievement.unlocked;

    final content = Opacity(
      opacity: unlocked ? 1.0 : 0.55,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: unlocked
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconFor(achievement.metric),
                size: 30,
                color: unlocked
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (unlocked) ...[
              const SizedBox(height: 6),
              Chip(
                label: const Text('Unlocked'),
                visualDensity: VisualDensity.compact,
                backgroundColor: colorScheme.tertiaryContainer,
                labelStyle: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
          ],
        ),
      ),
    );

    return Semantics(
      label:
          '${unlocked ? 'Unlocked' : 'Locked'} achievement: ${achievement.title}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            content,
            if (!unlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.lock,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
