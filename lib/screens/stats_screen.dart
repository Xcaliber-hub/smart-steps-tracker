// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/formatters.dart';
import '../utils/stats_calculator.dart';
import '../viewmodels/providers.dart';
import '../widgets/heatmap_calendar.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/steps_bar_chart.dart';
import '../widgets/steps_line_chart.dart';

/// Statistics tab: period selector, summary cards and trend charts.
class StatsScreen extends ConsumerStatefulWidget {
  /// Creates the stats tab.
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsPeriod _period = StatsPeriod.week;

  String _periodLabel(StatsPeriod period) {
    switch (period) {
      case StatsPeriod.week:
        return 'Week';
      case StatsPeriod.month:
        return 'Month';
      case StatsPeriod.year:
        return 'Year';
      case StatsPeriod.all:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider(_period));
    final allDays = ref.watch(allDaysProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Semantics(
              label: 'Statistics period',
              child: SegmentedButton<StatsPeriod>(
                segments: StatsPeriod.values
                    .map(
                      (p) => ButtonSegment<StatsPeriod>(
                        value: p,
                        label: Text(_periodLabel(p)),
                      ),
                    )
                    .toList(),
                selected: {_period},
                onSelectionChanged: (selected) =>
                    setState(() => _period = selected.first),
              ),
            ),
          ),
          const SizedBox(height: 16),
          stats.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load statistics: $error',
                textAlign: TextAlign.center,
              ),
            ),
            data: (s) {
              final best = s.bestDay;
              final cards = <StatCard>[
                StatCard(
                  label: 'Total steps',
                  value: Formatters.steps(s.totalSteps),
                  icon: Icons.directions_walk,
                ),
                StatCard(
                  label: 'Average / day',
                  value: Formatters.steps(s.averageSteps.round()),
                  icon: Icons.speed,
                ),
                if (best != null)
                  StatCard(
                    label: 'Best day · ${Formatters.shortDate(best.date)}',
                    value: Formatters.steps(best.steps),
                    icon: Icons.emoji_events,
                  ),
                StatCard(
                  label: 'Goal completion',
                  value: Formatters.percent(s.goalCompletionRate),
                  icon: Icons.task_alt,
                ),
                StatCard(
                  label: 'Consistency',
                  value: Formatters.percent(s.consistencyScore),
                  icon: Icons.balance,
                ),
                StatCard(
                  label: 'Longest streak',
                  value:
                      '${s.longestStreak} ${s.longestStreak == 1 ? 'day' : 'days'}',
                  icon: Icons.trending_up,
                ),
                StatCard(
                  label: 'Current streak',
                  value:
                      '${s.currentStreak} ${s.currentStreak == 1 ? 'day' : 'days'}',
                  icon: Icons.whatshot,
                ),
                StatCard(
                  label: 'Lifetime steps',
                  value: Formatters.steps(s.lifetimeSteps),
                  icon: Icons.all_inclusive,
                ),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                    children: cards,
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Trends'),
                  allDays.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load history: $error',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    data: (days) {
                      final profile = ref.watch(profileProvider);
                      final now = DateTime.now();
                      Widget chart;
                      String title;
                      switch (_period) {
                        case StatsPeriod.week:
                          title = 'This week';
                          chart = StepsBarChart(
                            days: StatsCalculator.continuousDays(
                              days,
                              StatsPeriod.week,
                              now,
                            ),
                            goal: profile.dailyGoal,
                          );
                        case StatsPeriod.month:
                          title = 'This month';
                          chart = StepsLineChart(
                            days: StatsCalculator.continuousDays(
                              days,
                              StatsPeriod.month,
                              now,
                            ),
                            goal: profile.dailyGoal,
                          );
                        case StatsPeriod.year:
                          title = 'This year';
                          chart = StepsLineChart(
                            days: StatsCalculator.continuousDays(
                              days,
                              StatsPeriod.year,
                              now,
                            ),
                            goal: profile.dailyGoal,
                          );
                        case StatsPeriod.all:
                          title = 'Activity heatmap';
                          chart = HeatmapCalendar(
                            days: days,
                            goal: profile.dailyGoal,
                          );
                      }
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SectionHeader(title: title),
                              chart,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
