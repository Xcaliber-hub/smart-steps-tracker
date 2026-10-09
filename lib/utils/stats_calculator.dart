// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import '../models/day_record.dart';
import '../models/period_stats.dart';

/// Time ranges for the statistics screen.
enum StatsPeriod { week, month, year, all }

/// Pure functions that compute streaks and aggregates from day records.
///
/// A "streak day" is a day on which the daily step goal was met or exceeded.
/// The current streak tolerates today still being in progress: if today is
/// below the goal, counting starts from yesterday.
class StatsCalculator {
  StatsCalculator._();

  /// Number of days in [period] ending today (inclusive).
  static int periodLength(StatsPeriod period) {
    switch (period) {
      case StatsPeriod.week:
        return 7;
      case StatsPeriod.month:
        return 30;
      case StatsPeriod.year:
        return 365;
      case StatsPeriod.all:
        return 3650; // effectively unbounded
    }
  }

  /// Records within [period] ending today, ascending by date. Missing days
  /// are filled with empty records so charts and streaks stay continuous.
  static List<DayRecord> continuousDays(
    List<DayRecord> all,
    StatsPeriod period,
    DateTime now,
  ) {
    final byKey = {for (final d in all) d.dateKey: d};
    final length = periodLength(period);
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(length, (i) {
      final date = today.subtract(Duration(days: length - 1 - i));
      return byKey[DayRecord.dateKeyFor(date)] ?? DayRecord(date: date);
    });
  }

  /// Consecutive goal-met days ending today (or yesterday if today is still
  /// below the goal).
  static int currentStreak(List<DayRecord> all, int goal) {
    if (goal <= 0) return 0;
    final byKey = {for (final d in all) d.dateKey: d};
    var date = DateTime.now();
    // Allow today to be in progress.
    final todaySteps = byKey[DayRecord.dateKeyFor(date)]?.steps ?? 0;
    if (todaySteps < goal) {
      date = date.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (true) {
      final steps = byKey[DayRecord.dateKeyFor(date)]?.steps ?? 0;
      if (steps >= goal) {
        streak++;
        date = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// Longest run of consecutive goal-met days in the whole history.
  /// Missing days (no recorded row) break the run, as they should.
  static int longestStreak(List<DayRecord> all, int goal) {
    if (goal <= 0 || all.isEmpty) return 0;
    final sorted = [...all]..sort((a, b) => a.date.compareTo(b.date));
    var best = 0;
    var run = 0;
    DateTime? prevDate;
    for (final day in sorted) {
      final dateOnly =
          DateTime(day.date.year, day.date.month, day.date.day);
      final consecutive =
          prevDate != null && dateOnly.difference(prevDate).inDays == 1;
      if (day.steps >= goal) {
        run = (run > 0 && consecutive) ? run + 1 : 1;
      } else {
        run = 0;
      }
      if (run > best) best = run;
      prevDate = dateOnly;
    }
    return best;
  }

  /// Aggregates for the days of [period].
  static PeriodStats compute({
    required List<DayRecord> all,
    required StatsPeriod period,
    required int goal,
    required DateTime now,
  }) {
    final days = continuousDays(all, period, now);
    if (days.isEmpty) return PeriodStats.empty();

    var totalSteps = 0;
    var totalDistance = 0.0;
    var totalCalories = 0.0;
    var totalActive = 0;
    var tracked = 0;
    var goalDays = 0;
    DayRecord? best;

    for (final d in days) {
      totalSteps += d.steps;
      totalDistance += d.distanceMeters;
      totalCalories += d.calories;
      totalActive += d.activeMinutes;
      if (d.steps > 0) tracked++;
      if (goal > 0 && d.steps >= goal) goalDays++;
      if (best == null || d.steps > best.steps) best = d;
    }

    final lifetime = all.fold<int>(0, (sum, d) => sum + d.steps);
    return PeriodStats(
      totalSteps: totalSteps,
      totalDistanceMeters: totalDistance,
      totalCalories: totalCalories,
      totalActiveMinutes: totalActive,
      averageSteps: days.isEmpty ? 0 : totalSteps / days.length,
      bestDay: best != null && best.steps > 0 ? best : null,
      daysTracked: tracked,
      goalCompletionRate: days.isEmpty ? 0 : goalDays / days.length,
      longestStreak: longestStreak(all, goal),
      currentStreak: currentStreak(all, goal),
      consistencyScore: days.isEmpty ? 0 : tracked / days.length,
      lifetimeSteps: lifetime,
    );
  }
}
