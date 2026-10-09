// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import '../utils/constants.dart';

/// Lightweight key-value persistence: user profile plus step-sensor bookkeeping.
///
/// Heavier time-series data lives in [DatabaseService]; this service keeps
/// small, frequently-read values (profile, sensor baselines, per-day flags).
class SettingsService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    final p = _prefs;
    if (p != null) return p;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  // --- Profile ------------------------------------------------------------

  Future<UserProfile> loadProfile() async {
    final prefs = await _instance;
    final raw = prefs.getString(AppConstants.prefsProfile);
    if (raw == null) return const UserProfile();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await _instance;
    await prefs.setString(
      AppConstants.prefsProfile,
      jsonEncode(profile.toJson()),
    );
  }

  // --- Sensor bookkeeping ---------------------------------------------------
  //
  // The pedometer plugin reports steps counted since device boot. We store a
  // per-day baseline and derive today's steps as (current - baseline).

  /// Cumulative sensor value at the start of the current day.
  Future<int?> getSensorBaseline() async =>
      (await _instance).getInt(AppConstants.prefsSensorBaseline);

  Future<void> setSensorBaseline(int value) async =>
      (await _instance).setInt(AppConstants.prefsSensorBaseline, value);

  /// Last cumulative sensor value seen (used to detect reboots).
  Future<int?> getLastSensorValue() async =>
      (await _instance).getInt(AppConstants.prefsLastSensorValue);

  Future<void> setLastSensorValue(int value) async =>
      (await _instance).setInt(AppConstants.prefsLastSensorValue, value);

  /// `yyyy-MM-dd` of the day the baseline belongs to.
  Future<String?> getBaselineDay() async =>
      (await _instance).getString(AppConstants.prefsLastSyncDay);

  Future<void> setBaselineDay(String dateKey) async =>
      (await _instance).setString(AppConstants.prefsLastSyncDay, dateKey);

  // --- Per-day notification flags --------------------------------------------

  Future<String?> getGoalNotifiedDay() async =>
      (await _instance).getString(AppConstants.prefsGoalNotifiedDay);

  Future<void> setGoalNotifiedDay(String dateKey) async =>
      (await _instance).setString(AppConstants.prefsGoalNotifiedDay, dateKey);

  Future<String?> getHalfwayNotifiedDay() async =>
      (await _instance).getString(AppConstants.prefsHalfwayNotifiedDay);

  Future<void> setHalfwayNotifiedDay(String dateKey) async => (await _instance)
      .setString(AppConstants.prefsHalfwayNotifiedDay, dateKey);

  // --- Onboarding ---------------------------------------------------------------

  Future<bool> isOnboardingDone() async =>
      (await _instance).getBool(AppConstants.prefsOnboardingDone) ?? false;

  Future<void> setOnboardingDone() async =>
      (await _instance).setBool(AppConstants.prefsOnboardingDone, true);

  /// Raw preferences handle for the WorkManager background isolate, where
  /// the cached [_prefs] instance may not be initialized.
  Future<SharedPreferences> prefsForBackground() => _instance;
}
