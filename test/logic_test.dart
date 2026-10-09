// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_steps_tracker/models/day_record.dart';
import 'package:smart_steps_tracker/models/user_profile.dart';
import 'package:smart_steps_tracker/utils/health_calculations.dart';
import 'package:smart_steps_tracker/utils/stats_calculator.dart';

void main() {
  group('HealthCalculations', () {
    test('stride length scales with height and gender', () {
      final male = HealthCalculations.strideLengthMeters(
        heightCm: 180,
        gender: Gender.male,
      );
      final female = HealthCalculations.strideLengthMeters(
        heightCm: 180,
        gender: Gender.female,
      );
      expect(male, closeTo(0.747, 0.001));
      expect(female, closeTo(0.7434, 0.001));
    });

    test('stride falls back when height is unknown', () {
      expect(
        HealthCalculations.strideLengthMeters(heightCm: null, gender: null),
        0.75,
      );
    });

    test('distance is steps times stride', () {
      expect(
        HealthCalculations.distanceMetersForSteps(1000, 0.75),
        750.0,
      );
    });

    test('calories scale with weight', () {
      final light = HealthCalculations.caloriesForSteps(1000, 70);
      final heavy = HealthCalculations.caloriesForSteps(1000, 140);
      expect(light, closeTo(40.0, 0.01));
      expect(heavy, closeTo(80.0, 0.01));
    });

    test('zero steps produce zero metrics', () {
      expect(HealthCalculations.distanceMetersForSteps(0, 0.75), 0);
      expect(HealthCalculations.caloriesForSteps(0, 70), 0);
      expect(HealthCalculations.activeMinutesForSteps(0), 0);
    });
  });

  group('StatsCalculator', () {
    DayRecord day(int year, int month, int day, int steps) =>
        DayRecord(date: DateTime(year, month, day), steps: steps);

    test('current streak tolerates today in progress', () {
      final now = DateTime.now();
      final days = [
        day(now.year, now.month, now.day - 2, 12000),
        day(now.year, now.month, now.day - 1, 11000),
        day(now.year, now.month, now.day, 100), // today, below goal
      ];
      expect(StatsCalculator.currentStreak(days, 10000), 2);
    });

    test('longest streak ignores gaps', () {
      final days = [
        day(2026, 1, 1, 12000),
        day(2026, 1, 2, 12000),
        // Jan 3 missing entirely
        day(2026, 1, 4, 12000),
        day(2026, 1, 5, 12000),
        day(2026, 1, 6, 12000),
      ];
      expect(StatsCalculator.longestStreak(days, 10000), 3);
    });

    test('continuousDays fills missing dates', () {
      final now = DateTime.now();
      final filled = StatsCalculator.continuousDays(
        [day(now.year, now.month, now.day, 500)],
        StatsPeriod.week,
        now,
      );
      expect(filled.length, 7);
      expect(filled.where((d) => d.steps == 0).length, 6);
    });
  });
}
