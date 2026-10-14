// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_steps_tracker/models/day_record.dart';
import 'package:smart_steps_tracker/models/user_profile.dart';
import 'package:smart_steps_tracker/utils/health_calculations.dart';
import 'package:smart_steps_tracker/utils/step_counter_math.dart';
import 'package:smart_steps_tracker/utils/stats_calculator.dart';

void main() {
  group('UserProfile', () {
    test('persists a name and reads legacy data without one', () {
      const profile = UserProfile(
        name: 'Aditya',
        dailyGoal: 12000,
        amoledBlack: true,
        dynamicColor: true,
        accentColor: 0xFF6750A4,
        fontScale: 1.15,
        showNavigationLabels: false,
      );
      final restored = UserProfile.fromJson(profile.toJson());
      expect(restored.name, 'Aditya');
      expect(restored.dailyGoal, 12000);
      expect(restored.amoledBlack, isTrue);
      expect(restored.dynamicColor, isTrue);
      expect(restored.accentColor, 0xFF6750A4);
      expect(restored.fontScale, 1.15);
      expect(restored.showNavigationLabels, isFalse);

      final legacy = UserProfile.fromJson({'dailyGoal': 7000});
      expect(legacy.name, '');
      expect(legacy.dailyGoal, 7000);
      expect(legacy.amoledBlack, isFalse);
      expect(legacy.fontScale, 1.0);
      expect(legacy.showNavigationLabels, isTrue);
    });
  });

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
      expect(HealthCalculations.distanceMetersForSteps(1000, 0.75), 750.0);
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

  group('StepCounterMath', () {
    test('uses the prior reading as the day boundary', () {
      final result = StepCounterMath.calculate(
        cumulative: 90140,
        storedBaseline: 80000,
        baselineDay: '2026-10-12',
        lastSensorValue: 90123,
        todayKey: '2026-10-13',
      );
      expect(result.baseline, 90123);
      expect(result.steps, 17);
    });

    test('starts fresh installs from the first observed reading', () {
      final result = StepCounterMath.calculate(
        cumulative: 1234,
        storedBaseline: null,
        baselineDay: null,
        lastSensorValue: null,
        todayKey: '2026-10-13',
      );
      expect(result.baseline, 1234);
      expect(result.steps, 0);
    });

    test('counts steps after the sensor counter resets on reboot', () {
      final result = StepCounterMath.calculate(
        cumulative: 55,
        storedBaseline: 80000,
        baselineDay: '2026-10-13',
        lastSensorValue: 90000,
        todayKey: '2026-10-13',
        sinceLastReading: const Duration(minutes: 30),
      );
      expect(result.accepted, isTrue);
      expect(result.baseline, 0);
      expect(result.steps, 55);
    });

    test('keeps earlier steps from today when the device reboots', () {
      final result = StepCounterMath.calculate(
        cumulative: 55,
        storedBaseline: 87000,
        baselineDay: '2026-10-13',
        lastSensorValue: 90000,
        todayKey: '2026-10-13',
        previousSteps: 3000,
        sinceLastReading: const Duration(minutes: 30),
      );
      expect(result.accepted, isTrue);
      expect(result.baseline, -3000);
      expect(result.steps, 3055);

      // The next reading continues from the carried baseline.
      final next = StepCounterMath.calculate(
        cumulative: 80,
        storedBaseline: result.baseline,
        baselineDay: '2026-10-13',
        lastSensorValue: 55,
        todayKey: '2026-10-13',
        previousSteps: result.steps,
        sinceLastReading: const Duration(seconds: 20),
      );
      expect(next.steps, 3080);
    });

    test('ignores a stale reading instead of treating it as a reboot', () {
      // Regression: a cached reading that is slightly older than the live one
      // used to reset the baseline to zero, so today's steps became the whole
      // "steps since boot" counter (57k steps after walking under 3k).
      final result = StepCounterMath.calculate(
        cumulative: 57300,
        storedBaseline: 54450,
        baselineDay: '2026-10-14',
        lastSensorValue: 57351,
        todayKey: '2026-10-14',
        previousSteps: 2901,
        sinceLastReading: const Duration(seconds: 3),
      );
      expect(result.accepted, isFalse);
      expect(result.steps, 2901);
      expect(result.baseline, 54450);
    });

    test('ignores a stale reading even when the last one is minutes old', () {
      final result = StepCounterMath.calculate(
        cumulative: 57000,
        storedBaseline: 54450,
        baselineDay: '2026-10-14',
        lastSensorValue: 57351,
        todayKey: '2026-10-14',
        previousSteps: 2901,
        sinceLastReading: const Duration(minutes: 15),
      );
      expect(result.accepted, isFalse);
    });

    test('a reboot on a new day starts from the post-boot steps', () {
      final result = StepCounterMath.calculate(
        cumulative: 55,
        storedBaseline: 80000,
        baselineDay: '2026-10-12',
        lastSensorValue: 90000,
        todayKey: '2026-10-13',
        previousSteps: 0,
        sinceLastReading: const Duration(hours: 6),
      );
      expect(result.accepted, isTrue);
      expect(result.baseline, 0);
      expect(result.steps, 55);
    });

    test('never exceeds the daily sanity clamp', () {
      final result = StepCounterMath.calculate(
        cumulative: 900000,
        storedBaseline: 0,
        baselineDay: '2026-10-13',
        lastSensorValue: 899990,
        todayKey: '2026-10-13',
      );
      expect(result.steps, 200000);
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
