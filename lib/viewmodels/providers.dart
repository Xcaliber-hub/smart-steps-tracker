// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

// ignore_for_file: avoid_public_notifier_properties

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement.dart';
import '../models/day_record.dart';
import '../models/period_stats.dart';
import '../models/reminder.dart';
import '../models/user_profile.dart';
import '../repositories/settings_repository.dart';
import '../repositories/step_repository.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/step_tracker_service.dart';
import '../utils/stats_calculator.dart';

// --- Services ---------------------------------------------------------------

final databaseServiceProvider =
    Provider<DatabaseService>((ref) => DatabaseService());

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final backupServiceProvider =
    Provider<BackupService>((ref) => BackupService());

final stepTrackerServiceProvider =
    Provider<StepTrackerService>((ref) => StepTrackerService());

// --- Repositories -------------------------------------------------------------

final stepRepositoryProvider = Provider<StepRepository>(
  (ref) => StepRepository(
    db: ref.watch(databaseServiceProvider),
    settings: ref.watch(settingsServiceProvider),
    tracker: ref.watch(stepTrackerServiceProvider),
    notifications: ref.watch(notificationServiceProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(settingsServiceProvider)),
);

// --- Profile ------------------------------------------------------------------

/// Holds the user profile; every mutation persists to SharedPreferences.
class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier(this._repo) : super(const UserProfile()) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    state = await _repo.loadProfile();
  }

  Future<void> update(UserProfile profile) async {
    state = profile;
    await _repo.saveProfile(profile);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile>(
  (ref) => ProfileNotifier(ref.watch(settingsRepositoryProvider)),
);

// --- Live step data -------------------------------------------------------------

/// Today's record, updated on every sensor event.
final todayRecordProvider = StreamProvider<DayRecord>((ref) {
  return ref.watch(stepRepositoryProvider).todayStream;
});

/// Whether the step-counter sensor is currently delivering data.
final sensorAvailableProvider = StreamProvider<bool>((ref) {
  return ref.watch(stepTrackerServiceProvider).sensorAvailable;
});

// --- History & statistics -------------------------------------------------------

final allDaysProvider = FutureProvider<List<DayRecord>>((ref) {
  return ref.watch(stepRepositoryProvider).getAllDays();
});

final statsProvider =
    FutureProvider.family<PeriodStats, StatsPeriod>((ref, period) {
  return ref.watch(stepRepositoryProvider).computeStats(period);
});

final achievementsProvider = FutureProvider<List<Achievement>>((ref) {
  return ref.watch(databaseServiceProvider).achievementsWithState();
});

// --- Reminders --------------------------------------------------------------------

class RemindersNotifier extends StateNotifier<List<ReminderItem>> {
  RemindersNotifier(this._ref) : super(const []) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    state = await _ref.read(databaseServiceProvider).getReminders();
  }

  Future<void> _persistAndReschedule() async {
    final db = _ref.read(databaseServiceProvider);
    for (final r in state) {
      await db.upsertReminder(r);
    }
    await _ref.read(notificationServiceProvider).rescheduleAll(
          profile: _ref.read(profileProvider),
          reminders: state,
        );
  }

  Future<void> toggle(String id, bool enabled) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(enabled: enabled) else r,
    ];
    await _persistAndReschedule();
  }

  Future<void> add(ReminderItem reminder) async {
    state = [...state, reminder];
    await _persistAndReschedule();
  }

  Future<void> remove(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _ref.read(databaseServiceProvider).deleteReminder(id);
    await _ref.read(notificationServiceProvider).rescheduleAll(
          profile: _ref.read(profileProvider),
          reminders: state,
        );
  }

  Future<void> updateTime(String id, int minutesOfDay) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(minutesOfDay: minutesOfDay) else r,
    ];
    await _persistAndReschedule();
  }
}

final remindersProvider =
    StateNotifierProvider<RemindersNotifier, List<ReminderItem>>(
  (ref) => RemindersNotifier(ref),
);

// --- Onboarding ---------------------------------------------------------------------

final onboardingDoneProvider = FutureProvider<bool>((ref) {
  return ref.watch(settingsRepositoryProvider).isOnboardingDone();
});
