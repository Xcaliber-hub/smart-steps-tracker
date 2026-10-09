// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

/// App-wide constants: keys, task names, channels, defaults.
class AppConstants {
  AppConstants._();

  // --- Preferences keys -------------------------------------------------
  static const String prefsProfile = 'user_profile_v1';
  static const String prefsSensorBaseline = 'sensor_baseline';
  static const String prefsLastSensorValue = 'last_sensor_value';
  static const String prefsLastSyncDay = 'last_sync_day';
  static const String prefsOnboardingDone = 'onboarding_done';
  static const String prefsGoalNotifiedDay = 'goal_notified_day';
  static const String prefsHalfwayNotifiedDay = 'halfway_notified_day';
  static const String prefsLastActivitySteps = 'last_activity_steps';
  static const String prefsLastActivityCheck = 'last_activity_check_ms';

  // --- Database ---------------------------------------------------------
  static const String dbName = 'smart_steps.db';
  static const int dbVersion = 1;

  // --- WorkManager ------------------------------------------------------
  static const String wmTaskSyncSteps = 'syncSteps';
  static const String wmTaskCheckReminders = 'checkReminders';
  static const String wmUniqueSync = 'steps-sync';
  static const String wmUniqueReminders = 'reminder-check';

  // --- Notifications ----------------------------------------------------
  static const String channelReminders = 'reminders';
  static const String channelAchievements = 'achievements';
  static const int idMorning = 100;
  static const int idGoalReached = 101;
  static const int idHalfway = 102;
  static const int idInactivity = 103;
  static const int idEvening = 104;

  // --- Defaults ---------------------------------------------------------
  static const int defaultDailyGoal = 10000;

  /// Earliest hour considered "awake" for inactivity checks.
  static const int awakeFromHour = 7;

  /// Latest hour considered "awake" for inactivity checks.
  static const int awakeToHour = 22;
}
