// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/achievement.dart';
import '../models/day_record.dart';
import '../models/period_stats.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/step_tracker_service.dart';
import '../utils/constants.dart';
import '../utils/health_calculations.dart';
import '../utils/stats_calculator.dart';

/// Orchestrates step counting: turns raw sensor values into persisted
/// [DayRecord]s, emits live updates, fires milestone notifications and
/// evaluates achievements.
///
/// Sensor math: the hardware counter reports steps since boot. We keep a
/// per-day `baseline`; today's steps = `current - baseline`. A backwards
/// jump means the device rebooted, so we re-baseline. A baseline from a
/// previous calendar day means a new day started.
class StepRepository {
  StepRepository({
    required this.db,
    required this.settings,
    required this.tracker,
    required this.notifications,
  });

  final DatabaseService db;
  final SettingsService settings;
  final StepTrackerService tracker;
  final NotificationService notifications;

  final StreamController<DayRecord> _todayController =
      StreamController<DayRecord>.broadcast();

  DayRecord _today = DayRecord(date: DateTime.now());

  /// Live updates of today's record. Every new subscriber immediately
  /// receives the current value, then live updates.
  ///
  /// (A plain broadcast controller was not enough here: [initialize] runs
  /// before any widget subscribes, so the initial [add] was silently
  /// dropped and the dashboard spun forever whenever the sensor had not
  /// emitted yet.)
  Stream<DayRecord> get todayStream async* {
    yield _today;
    yield* _todayController.stream;
  }

  DayRecord get today => _today;

  /// Loads today's record and subscribes to the sensor. Call once at startup.
  Future<void> initialize() async {
    final now = DateTime.now();
    _today = await db.getDay(DayRecord.dateKeyFor(now)) ??
        DayRecord(date: now);
    if (!_todayController.isClosed) _todayController.add(_today);

    tracker.cumulativeSteps.listen(_onSensorEvent);
    // Evaluate achievements once at startup (catches unlocks earned while
    // the app was dead).
    await evaluateAchievements(notify: false);
  }

  /// Forces a reload of today's record from the database (e.g. after an
  /// import or manual correction).
  Future<void> refreshToday() async {
    final now = DateTime.now();
    _today =
        await db.getDay(DayRecord.dateKeyFor(now)) ?? DayRecord(date: now);
    if (!_todayController.isClosed) _todayController.add(_today);
  }

  Future<void> _onSensorEvent(int cumulative) async {
    final now = DateTime.now();
    final todayKey = DayRecord.dateKeyFor(now);

    var baseline = await settings.getSensorBaseline();
    final baselineDay = await settings.getBaselineDay();
    final last = await settings.getLastSensorValue();

    final rebooted = last != null && cumulative < last;
    final newDay = baseline == null || baselineDay != todayKey;
    if (rebooted || newDay) {
      baseline = cumulative;
      await settings.setSensorBaseline(cumulative);
      await settings.setBaselineDay(todayKey);
    }
    await settings.setLastSensorValue(cumulative);

    // Sanity clamp: no human walks 200k steps in a day.
    // (baseline is always set above: fresh installs and reboots re-baseline.)
    final steps = (cumulative - baseline).clamp(0, 200000);

    final profile = await settings.loadProfile();
    final m = HealthCalculations.metricsForSteps(steps: steps, profile: profile);

    _today = DayRecord(
      date: now,
      steps: steps,
      distanceMeters: m.distanceMeters,
      calories: m.calories,
      activeMinutes: m.activeMinutes,
      // The pedometer plugin exposes no floor data; stays 0. Documented
      // in the README as a hardware-dependent limitation.
      floors: 0,
    );
    await db.upsertDay(_today);
    if (!_todayController.isClosed) _todayController.add(_today);

    await _checkMilestones(steps, profile, todayKey);
  }

  Future<void> _checkMilestones(
    int steps,
    UserProfile profile,
    String todayKey,
  ) async {
    if (!profile.notificationsEnabled) {
      await evaluateAchievements(notify: false);
      return;
    }
    final goal = profile.dailyGoal;

    if (profile.halfwayReminder && goal > 0 && steps >= goal / 2) {
      final done = await settings.getHalfwayNotifiedDay();
      if (done != todayKey) {
        await settings.setHalfwayNotifiedDay(todayKey);
        await notifications.showNow(
          id: AppConstants.idHalfway,
          title: 'Halfway there!',
          body:
              'You have reached 50% of your ${goal.toString()} step goal. Keep walking!',
        );
      }
    }

    if (profile.goalReachedAlert && goal > 0 && steps >= goal) {
      final done = await settings.getGoalNotifiedDay();
      if (done != todayKey) {
        await settings.setGoalNotifiedDay(todayKey);
        await notifications.showNow(
          id: AppConstants.idGoalReached,
          title: 'Goal reached! 🎉',
          body: 'Amazing — you hit your $goal step goal today.',
          channelId: AppConstants.channelAchievements,
          importance: Importance.high,
        );
      }
    }

    await evaluateAchievements();
  }

  /// Checks the badge catalog against current totals. Returns badges newly
  /// unlocked by this call.
  Future<List<Achievement>> evaluateAchievements({bool notify = true}) async {
    final unlocked = <Achievement>[];
    final already = await db.unlockedAchievements();
    final profile = await settings.loadProfile();
    final days = await db.getAllDays();
    final lifetime = days.fold<int>(0, (sum, d) => sum + d.steps);
    final streak = StatsCalculator.currentStreak(days, profile.dailyGoal);
    final now = DateTime.now();

    bool meets(Achievement a) {
      switch (a.metric) {
        case AchievementMetric.singleDaySteps:
          return _today.steps >= a.targetValue;
        case AchievementMetric.streakDays:
          return streak >= a.targetValue;
        case AchievementMetric.singleDayDistanceMeters:
          return _today.distanceMeters >= a.targetValue;
        case AchievementMetric.lifetimeSteps:
          return lifetime >= a.targetValue;
      }
    }

    for (final a in AchievementCatalog.all) {
      if (already.containsKey(a.id)) continue;
      if (meets(a)) {
        await db.markAchievementUnlocked(a.id, now);
        unlocked.add(a.copyWith(unlockedAt: now));
        if (notify && profile.notificationsEnabled) {
          await notifications.showNow(
            id: 2000 + (a.id.hashCode % 7000).abs(),
            title: 'Achievement unlocked: ${a.title}',
            body: a.description,
            channelId: AppConstants.channelAchievements,
            importance: Importance.high,
          );
        }
      }
    }
    return unlocked;
  }

  Future<List<DayRecord>> getAllDays() => db.getAllDays();

  Future<List<DayRecord>> getRange(DateTime from, DateTime to) =>
      db.getDaysInRange(from, to);

  Future<PeriodStats> computeStats(StatsPeriod period) async {
    final days = await db.getAllDays();
    final goal = (await settings.loadProfile()).dailyGoal;
    return StatsCalculator.compute(
      all: days,
      period: period,
      goal: goal,
      now: DateTime.now(),
    );
  }

  void dispose() {
    _todayController.close();
  }
}
