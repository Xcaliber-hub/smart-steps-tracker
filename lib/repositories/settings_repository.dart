// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import '../models/user_profile.dart';
import '../services/settings_service.dart';

/// Thin persistence boundary for the user profile and preferences.
class SettingsRepository {
  SettingsRepository(this._settings);

  final SettingsService _settings;

  Future<UserProfile> loadProfile() => _settings.loadProfile();

  Future<void> saveProfile(UserProfile profile) =>
      _settings.saveProfile(profile);

  Future<bool> isOnboardingDone() => _settings.isOnboardingDone();

  Future<void> setOnboardingDone() => _settings.setOnboardingDone();
}
