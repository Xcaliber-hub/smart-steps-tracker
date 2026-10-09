// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'day_record.dart';

/// Aggregated statistics for a time period (week, month, year, or all time).
class PeriodStats {
  final int totalSteps;
  final double totalDistanceMeters;
  final double totalCalories;
  final int totalActiveMinutes;
  final double averageSteps;
  final DayRecord? bestDay;
  final int daysTracked;
  final double goalCompletionRate;
  final int longestStreak;
  final int currentStreak;
  final double consistencyScore;
  final int lifetimeSteps;

  const PeriodStats({
    required this.totalSteps,
    required this.totalDistanceMeters,
    required this.totalCalories,
    required this.totalActiveMinutes,
    required this.averageSteps,
    required this.bestDay,
    required this.daysTracked,
    required this.goalCompletionRate,
    required this.longestStreak,
    required this.currentStreak,
    required this.consistencyScore,
    required this.lifetimeSteps,
  });

  factory PeriodStats.empty() => const PeriodStats(
        totalSteps: 0,
        totalDistanceMeters: 0,
        totalCalories: 0,
        totalActiveMinutes: 0,
        averageSteps: 0,
        bestDay: null,
        daysTracked: 0,
        goalCompletionRate: 0,
        longestStreak: 0,
        currentStreak: 0,
        consistencyScore: 0,
        lifetimeSteps: 0,
      );
}
