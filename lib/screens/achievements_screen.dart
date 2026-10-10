// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement.dart';
import '../utils/stats_calculator.dart';
import '../viewmodels/providers.dart';
import '../widgets/achievement_tile.dart';

/// Achievements tab: unlockable milestones with live progress.
class AchievementsScreen extends ConsumerWidget {
  /// Creates the achievements tab.
  const AchievementsScreen({super.key});

  double _progressFor(
    Achievement achievement, {
    required int todaySteps,
    required double todayDistanceMeters,
    required int currentStreak,
    required int lifetimeSteps,
  }) {
    double raw;
    switch (achievement.metric) {
      case AchievementMetric.singleDaySteps:
        raw = todaySteps / achievement.targetValue;
      case AchievementMetric.streakDays:
        raw = currentStreak / achievement.targetValue;
      case AchievementMetric.singleDayDistanceMeters:
        raw = todayDistanceMeters / achievement.targetValue;
      case AchievementMetric.lifetimeSteps:
        raw = lifetimeSteps / achievement.targetValue;
    }
    return raw.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    final today = ref.watch(todayRecordProvider);
    final all = ref.watch(allDaysProvider);
    final stats = ref.watch(statsProvider(StatsPeriod.all));

    return achievements.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load achievements: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (list) {
        final unlockedCount = list.where((a) => a.unlocked).length;
        final todayRecord = today.valueOrNull;
        final lifetime = stats.valueOrNull?.lifetimeSteps ?? 0;
        final goal = ref.watch(profileProvider).dailyGoal;
        final streak = all.valueOrNull != null
            ? StatsCalculator.currentStreak(all.valueOrNull!, goal)
            : 0;

        final colorScheme = Theme.of(context).colorScheme;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 40,
                        color: colorScheme.onPrimaryContainer,
                        semanticLabel: 'Trophy',
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$unlockedCount of ${list.length} unlocked',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                            Text(
                              'Keep walking to unlock them all.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final achievement = list[index];
                  return AchievementTile(
                    achievement: achievement,
                    progress: _progressFor(
                      achievement,
                      todaySteps: todayRecord?.steps ?? 0,
                      todayDistanceMeters:
                          todayRecord?.distanceMeters ?? 0,
                      currentStreak: streak,
                      lifetimeSteps: lifetime,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
