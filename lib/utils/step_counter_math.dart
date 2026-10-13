// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

/// Result of reconciling one cumulative hardware step-counter reading.
class StepCounterCalculation {
  const StepCounterCalculation({required this.baseline, required this.steps});

  /// Cumulative sensor value to persist as the current day's baseline.
  final int baseline;

  /// Daily steps represented by this sensor reading.
  final int steps;
}

/// Converts the monotonic Android step counter into a local-calendar-day total.
class StepCounterMath {
  StepCounterMath._();

  static StepCounterCalculation calculate({
    required int cumulative,
    required int? storedBaseline,
    required String? baselineDay,
    required int? lastSensorValue,
    required String todayKey,
  }) {
    final rebooted = lastSensorValue != null && cumulative < lastSensorValue;
    final dayChanged = storedBaseline == null || baselineDay != todayKey;

    // On a day change, the previous day's last observed counter is the
    // midnight boundary approximation. Subtracting it retains steps counted
    // after midnight but before the first reading received for the new day.
    // After a device reboot the counter restarts at zero, so zero is the new
    // baseline and post-reboot steps are retained.
    final baseline = rebooted
        ? 0
        : dayChanged
            ? (lastSensorValue ?? cumulative)
            : storedBaseline;
    final steps = (cumulative - baseline).clamp(0, 200000).toInt();

    return StepCounterCalculation(baseline: baseline, steps: steps);
  }
}
