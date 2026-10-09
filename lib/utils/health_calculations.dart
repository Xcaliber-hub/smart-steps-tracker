// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import '../models/user_profile.dart';

/// Pure functions that turn raw step counts into human-meaningful metrics.
///
/// All formulas are documented approximations, not medical measurements.
/// They err on the conservative side and are clearly labeled "estimated"
/// wherever shown in the UI.
class HealthCalculations {
  HealthCalculations._();

  /// Estimated stride length in meters.
  ///
  /// Uses the common anthropometric approximation:
  /// stride ≈ height × 0.415 (male) or × 0.413 (female/other).
  /// Falls back to a 0.75 m average stride when height is unknown.
  static double strideLengthMeters({
    required double? heightCm,
    required Gender? gender,
  }) {
    if (heightCm == null || heightCm <= 0) return 0.75;
    final factor = gender == Gender.male ? 0.415 : 0.413;
    return heightCm / 100 * factor;
  }

  /// Distance in meters for [steps] at the given stride length.
  static double distanceMetersForSteps(int steps, double strideLengthM) {
    if (steps <= 0) return 0;
    return steps * strideLengthM;
  }

  /// Estimated kilocalories burned while walking [steps] steps.
  ///
  /// Approximation: ~0.04 kcal per step for a 70 kg adult, scaled linearly
  /// with body weight. Defaults to 70 kg when weight is unknown.
  static double caloriesForSteps(int steps, double? weightKg) {
    if (steps <= 0) return 0;
    final weight = (weightKg != null && weightKg > 0) ? weightKg : 70.0;
    return steps * 0.04 * (weight / 70.0);
  }

  /// Estimated active walking minutes.
  ///
  /// Assumes an average cadence of ~100 steps per minute for purposeful
  /// walking. Casual ambling will read slightly high; running reads low.
  static int activeMinutesForSteps(int steps) {
    if (steps <= 0) return 0;
    return (steps / 100).round();
  }

  /// Convenience: build all derived metrics for a step count at once.
  static ({
    double distanceMeters,
    double calories,
    int activeMinutes,
  }) metricsForSteps({
    required int steps,
    required UserProfile profile,
  }) {
    final stride = strideLengthMeters(
      heightCm: profile.heightCm,
      gender: profile.gender,
    );
    return (
      distanceMeters: distanceMetersForSteps(steps, stride),
      calories: caloriesForSteps(steps, profile.weightKg),
      activeMinutes: activeMinutesForSteps(steps),
    );
  }
}
