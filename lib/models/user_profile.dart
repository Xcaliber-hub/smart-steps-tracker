// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';

/// Biological sex used only to refine stride-length estimation.
enum Gender { male, female, other }

/// Unit system for displaying distance/weight.
enum UnitSystem { metric, imperial }

/// User-configurable profile and preferences, persisted in SharedPreferences.
class UserProfile {
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final Gender? gender;

  /// Daily step goal. Defaults to 10 000.
  final int dailyGoal;

  final UnitSystem unitSystem;
  final ThemeMode themeMode;

  // Notification toggles.
  final bool notificationsEnabled;
  final bool morningMotivation;
  final bool goalReachedAlert;
  final bool halfwayReminder;
  final bool inactivityAlert;
  final bool eveningSummary;

  /// Minutes since midnight for the morning motivation notification.
  final int morningReminderMinutes;

  /// Minutes since midnight for the evening summary notification.
  final int eveningSummaryMinutes;

  const UserProfile({
    this.age,
    this.heightCm,
    this.weightKg,
    this.gender,
    this.dailyGoal = 10000,
    this.unitSystem = UnitSystem.metric,
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.morningMotivation = true,
    this.goalReachedAlert = true,
    this.halfwayReminder = true,
    this.inactivityAlert = true,
    this.eveningSummary = true,
    this.morningReminderMinutes = 8 * 60,
    this.eveningSummaryMinutes = 21 * 60,
  });

  UserProfile copyWith({
    int? age,
    double? heightCm,
    double? weightKg,
    Gender? gender,
    int? dailyGoal,
    UnitSystem? unitSystem,
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? morningMotivation,
    bool? goalReachedAlert,
    bool? halfwayReminder,
    bool? inactivityAlert,
    bool? eveningSummary,
    int? morningReminderMinutes,
    int? eveningSummaryMinutes,
  }) {
    return UserProfile(
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      gender: gender ?? this.gender,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      unitSystem: unitSystem ?? this.unitSystem,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      morningMotivation: morningMotivation ?? this.morningMotivation,
      goalReachedAlert: goalReachedAlert ?? this.goalReachedAlert,
      halfwayReminder: halfwayReminder ?? this.halfwayReminder,
      inactivityAlert: inactivityAlert ?? this.inactivityAlert,
      eveningSummary: eveningSummary ?? this.eveningSummary,
      morningReminderMinutes:
          morningReminderMinutes ?? this.morningReminderMinutes,
      eveningSummaryMinutes:
          eveningSummaryMinutes ?? this.eveningSummaryMinutes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'age': age,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'gender': gender?.name,
      'dailyGoal': dailyGoal,
      'unitSystem': unitSystem.name,
      'themeMode': themeMode.name,
      'notificationsEnabled': notificationsEnabled,
      'morningMotivation': morningMotivation,
      'goalReachedAlert': goalReachedAlert,
      'halfwayReminder': halfwayReminder,
      'inactivityAlert': inactivityAlert,
      'eveningSummary': eveningSummary,
      'morningReminderMinutes': morningReminderMinutes,
      'eveningSummaryMinutes': eveningSummaryMinutes,
    };
  }

  factory UserProfile.fromJson(Map<String, Object?> json) {
    Gender? gender;
    final g = json['gender'] as String?;
    if (g != null) {
      gender = Gender.values.firstWhere(
        (e) => e.name == g,
        orElse: () => Gender.other,
      );
    }
    ThemeMode themeMode = ThemeMode.system;
    final t = json['themeMode'] as String?;
    if (t != null) {
      themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == t,
        orElse: () => ThemeMode.system,
      );
    }
    UnitSystem unitSystem = UnitSystem.metric;
    final u = json['unitSystem'] as String?;
    if (u != null) {
      unitSystem = UnitSystem.values.firstWhere(
        (e) => e.name == u,
        orElse: () => UnitSystem.metric,
      );
    }
    return UserProfile(
      age: (json['age'] as num?)?.toInt(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      gender: gender,
      dailyGoal: (json['dailyGoal'] as num?)?.toInt() ?? 10000,
      unitSystem: unitSystem,
      themeMode: themeMode,
      notificationsEnabled: (json['notificationsEnabled'] as bool?) ?? true,
      morningMotivation: (json['morningMotivation'] as bool?) ?? true,
      goalReachedAlert: (json['goalReachedAlert'] as bool?) ?? true,
      halfwayReminder: (json['halfwayReminder'] as bool?) ?? true,
      inactivityAlert: (json['inactivityAlert'] as bool?) ?? true,
      eveningSummary: (json['eveningSummary'] as bool?) ?? true,
      morningReminderMinutes:
          (json['morningReminderMinutes'] as num?)?.toInt() ?? 8 * 60,
      eveningSummaryMinutes:
          (json['eveningSummaryMinutes'] as num?)?.toInt() ?? 21 * 60,
    );
  }
}
