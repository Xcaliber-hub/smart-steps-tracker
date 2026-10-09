// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/day_record.dart';
import '../utils/formatters.dart';
import '../utils/stats_calculator.dart';
import '../viewmodels/providers.dart';
import '../widgets/goal_progress_ring.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';

/// Home tab: today's step count, goal ring, quick stats and streak.
class DashboardScreen extends ConsumerStatefulWidget {
  /// Creates the dashboard tab.
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _motivation(double progress) {
    if (progress < 0.25) return 'Every journey begins with a single step.';
    if (progress < 0.5) return 'Nice pace — keep moving.';
    if (progress < 0.75) return 'Over halfway there!';
    if (progress < 1.0) return 'Almost there — one more push!';
    return 'Goal crushed! Take a victory lap.';
  }

  double _progressOf(DayRecord? record, int goal) {
    if (record == null || goal <= 0) return 0.0;
    return record.steps / goal;
  }

  @override
  Widget build(BuildContext context) {
    // Celebrate the moment the goal is first reached each day.
    ref.listen<AsyncValue<DayRecord>>(todayRecordProvider, (previous, next) {
      final goal = ref.read(profileProvider).dailyGoal;
      final prevProgress =
          _progressOf(previous?.valueOrNull, goal);
      final nextProgress = _progressOf(next.valueOrNull, goal);
      if (prevProgress < 1.0 && nextProgress >= 1.0) {
        HapticFeedback.heavyImpact();
        _confetti.play();
      }
    });

    final today = ref.watch(todayRecordProvider);
    final profile = ref.watch(profileProvider);
    final sensor = ref.watch(sensorAvailableProvider);
    final weekStats = ref.watch(statsProvider(StatsPeriod.week));

    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        today.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load today\u2019s data: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (record) {
            final progress = _progressOf(record, profile.dailyGoal);
            final streak = weekStats.valueOrNull?.currentStreak ?? 0;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      _greeting(),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    Formatters.date(DateTime.now()),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Semantics(
                      label:
                          '${Formatters.steps(record.steps)} of ${Formatters.steps(profile.dailyGoal)} steps',
                      child: GoalProgressRing(
                        steps: record.steps,
                        goal: profile.dailyGoal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            progress >= 1.0
                                ? Icons.celebration
                                : Icons.directions_walk,
                            color: colorScheme.primary,
                            semanticLabel: 'Motivation',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _motivation(progress),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (sensor.valueOrNull == false)
                    Card(
                      color: colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sensors_off,
                              color: colorScheme.onErrorContainer,
                              semanticLabel: 'Sensor warning',
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Step sensor unavailable on this device — '
                                'past data is still shown.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onErrorContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (sensor.valueOrNull == false) const SizedBox(height: 16),
                  const SectionHeader(title: 'Today at a glance'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                    children: [
                      StatCard(
                        label: 'Distance',
                        value: Formatters.distance(
                          record.distanceMeters,
                          profile.unitSystem,
                        ),
                        icon: Icons.route,
                      ),
                      StatCard(
                        label: 'Calories',
                        value: Formatters.calories(record.calories),
                        icon: Icons.local_fire_department,
                      ),
                      StatCard(
                        label: 'Active time',
                        value: Formatters.minutes(record.activeMinutes),
                        icon: Icons.timer,
                      ),
                      StatCard(
                        label: 'Current streak',
                        value: '$streak ${streak == 1 ? 'day' : 'days'}',
                        icon: Icons.whatshot,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [
              colorScheme.primary,
              colorScheme.secondary,
              colorScheme.tertiary,
              Colors.amber,
            ],
          ),
        ),
      ],
    );
  }
}
