// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../models/day_record.dart';
import '../utils/constants.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';

/// Entry point for WorkManager background tasks.
///
/// Must be top-level (and kept via the pragma) so the background isolate
/// can find it. WorkManager persists registered periodic tasks across
/// reboots, which is what restores our background behavior after a restart.
///
/// Two periodic tasks are registered in `main()`:
/// - [AppConstants.wmTaskSyncSteps] (every 15 min): day-rollover handling,
///   reminder re-scheduling, achievement bookkeeping.
/// - [AppConstants.wmTaskCheckReminders] (hourly): inactivity detection.
///
/// Note: the background isolate cannot read the live step-counter stream;
/// step reconciliation happens on the next sensor event in the main isolate
/// (see [StepTrackerService] docs). These tasks therefore focus on
/// maintenance that does not need live sensor data.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final db = DatabaseService();
    final settings = SettingsService();
    try {
      switch (taskName) {
        case AppConstants.wmTaskSyncSteps:
          await _doMaintenance(db, settings);
        case AppConstants.wmTaskCheckReminders:
          await _checkInactivity(db, settings);
      }
      return true;
    } catch (_) {
      return false;
    }
    // NOTE: deliberately no db.close() here. Closing the database in the
    // background isolate has been observed to invalidate the main
    // isolate's handle (native database ids are shared), surfacing as
    // `DatabaseException(database_closed)` in the app. The isolate is
    // torn down right after the task, so nothing leaks in practice, and
    // DatabaseService reopens transparently if a handle ever goes stale.
  });
}

/// Ensures today's row exists (covers day rollover while the app was dead)
/// and re-applies the reminder schedule idempotently.
Future<void> _doMaintenance(
  DatabaseService db,
  SettingsService settings,
) async {
  final now = DateTime.now();
  final todayKey = DayRecord.dateKeyFor(now);
  final existing = await db.getDay(todayKey);
  if (existing == null) {
    await db.upsertDay(DayRecord(date: now));
  }

  final notifications = NotificationService();
  await notifications.init();
  final profile = await settings.loadProfile();
  final reminders = await db.getReminders();
  await notifications.rescheduleAll(profile: profile, reminders: reminders);
}

/// Fires an inactivity nudge when no steps were recorded for a while during
/// waking hours. Uses a lightweight steps-snapshot in preferences because
/// the background isolate has no live sensor access.
Future<void> _checkInactivity(
  DatabaseService db,
  SettingsService settings,
) async {
  final profile = await settings.loadProfile();
  if (!profile.notificationsEnabled || !profile.inactivityAlert) return;

  final now = DateTime.now();
  if (now.hour < AppConstants.awakeFromHour ||
      now.hour >= AppConstants.awakeToHour) {
    return;
  }

  final prefs = await settings.prefsForBackground();
  final today = await db.getDay(DayRecord.dateKeyFor(now));
  final steps = today?.steps ?? 0;
  final lastSteps = prefs.getInt(AppConstants.prefsLastActivitySteps) ?? steps;
  final lastCheckMs = prefs.getInt(AppConstants.prefsLastActivityCheck) ?? 0;
  final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);

  await prefs.setInt(AppConstants.prefsLastActivitySteps, steps);
  await prefs.setInt(
    AppConstants.prefsLastActivityCheck,
    now.millisecondsSinceEpoch,
  );

  // Two consecutive hourly checks with (almost) no new steps → nudge.
  if (now.difference(lastCheck).inMinutes >= 90 && steps - lastSteps < 100) {
    final notifications = NotificationService();
    await notifications.init();
    await notifications.showNow(
      id: AppConstants.idInactivity,
      title: 'Time to move',
      body: 'You have been still for a while. A short walk does wonders.',
    );
  }
}
