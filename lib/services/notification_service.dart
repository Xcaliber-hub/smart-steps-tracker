// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../models/reminder.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';

/// Local notifications: milestone alerts and scheduled reminders.
///
/// Scheduling uses inexact alarms (`inexactAllowWhileIdle`) deliberately:
/// reminders do not need to-the-minute precision and inexact alarms are
/// kinder to battery and do not require the `SCHEDULE_EXACT_ALARM` permission.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // Notification channels (Android 8+).
    const reminderChannel = AndroidNotificationChannel(
      AppConstants.channelReminders,
      'Reminders',
      description: 'Motivation, goal and inactivity reminders',
      importance: Importance.defaultImportance,
    );
    const achievementChannel = AndroidNotificationChannel(
      AppConstants.channelAchievements,
      'Achievements',
      description: 'Goal celebrations and unlocked badges',
      importance: Importance.high,
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(reminderChannel);
    await android?.createNotificationChannel(achievementChannel);

    _initialized = true;
  }

  /// Requests the runtime notification permission (Android 13+).
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  AndroidNotificationDetails _details(String channelId,
      {Importance importance = Importance.defaultImportance}) {
    return AndroidNotificationDetails(
      channelId,
      channelId == AppConstants.channelAchievements
          ? 'Achievements'
          : 'Reminders',
      importance: importance,
      priority: importance == Importance.high
          ? Priority.high
          : Priority.defaultPriority,
    );
  }

  /// Immediate notification (milestones, achievements, inactivity).
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String channelId = AppConstants.channelReminders,
    Importance importance = Importance.defaultImportance,
  }) async {
    await init();
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: _details(channelId, importance: importance)),
    );
  }

  /// Schedules a daily notification at [minutesOfDay] (local time).
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int minutesOfDay,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(android: _details(AppConstants.channelReminders)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Re-applies the whole reminder schedule. Idempotent: cancels everything
  /// first, then schedules each enabled reminder.
  Future<void> rescheduleAll({
    required UserProfile profile,
    required List<ReminderItem> reminders,
  }) async {
    await init();
    await cancelAll();
    if (!profile.notificationsEnabled) return;

    for (final reminder in reminders) {
      if (!reminder.enabled) continue;
      // The goal reminder is event-driven (fired from step updates), not
      // time-driven; inactivity is handled by the WorkManager task.
      if (reminder.type == ReminderType.goal ||
          reminder.type == ReminderType.inactivity) {
        continue;
      }
      await scheduleDaily(
        id: 1000 + reminder.id.hashCode % 8000,
        title: reminder.title,
        body: _bodyFor(reminder.type),
        minutesOfDay: reminder.minutesOfDay,
      );
    }
  }

  String _bodyFor(ReminderType type) {
    switch (type) {
      case ReminderType.morning:
        return 'A new day, a new step count. Let\'s make it count.';
      case ReminderType.evening:
        return 'Here is how your day of walking went.';
      case ReminderType.goal:
        return 'You are close to your daily goal. Keep going!';
      case ReminderType.inactivity:
        return 'Time to move — a short walk does wonders.';
      case ReminderType.custom:
        return 'This is your scheduled walking reminder.';
    }
  }
}
