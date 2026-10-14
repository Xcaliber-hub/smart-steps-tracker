// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

/// Result of reconciling one cumulative hardware step-counter reading.
class StepCounterCalculation {
  const StepCounterCalculation({
    required this.baseline,
    required this.steps,
    this.accepted = true,
  });

  /// Cumulative sensor value to persist as the current day's baseline.
  final int baseline;

  /// Daily steps represented by this sensor reading.
  final int steps;

  /// `false` when the reading was rejected as stale or out of order. Callers
  /// must then leave all stored state untouched.
  final bool accepted;
}

/// Converts the monotonic Android step counter into a local-calendar-day total.
class StepCounterMath {
  StepCounterMath._();

  /// Generous upper bound on sustained cadence (sprinting is about 4 steps/s).
  static const int maxStepsPerSecond = 5;

  /// Extra allowance for sensor batching and timing jitter.
  static const int rebootSlackSteps = 100;

  static const int _maxDailySteps = 200000;

  /// Whether [cumulative] could be the counter value of a device that
  /// rebooted somewhere inside [sinceLastReading].
  ///
  /// The counter restarts at zero on boot, so right after a real reboot it can
  /// only hold the steps walked since boot, which is small compared with the
  /// time that passed since our previous reading. A stale reading from the
  /// same boot still holds the whole "steps since boot" total and fails this
  /// test.
  static bool _plausibleSinceBoot(int cumulative, Duration? sinceLastReading) {
    final elapsed = sinceLastReading;
    final seconds =
        (elapsed == null || elapsed.isNegative) ? 0 : elapsed.inSeconds;
    return cumulative <= seconds * maxStepsPerSecond + rebootSlackSteps;
  }

  /// Reconciles one cumulative reading with the stored day baseline.
  ///
  /// [previousSteps] is the step total already recorded for today and
  /// [sinceLastReading] is the time between the previous recorded reading and
  /// this one. Both are only needed to tell a real reboot from a stale reading
  /// when the counter appears to go backwards.
  static StepCounterCalculation calculate({
    required int cumulative,
    required int? storedBaseline,
    required String? baselineDay,
    required int? lastSensorValue,
    required String todayKey,
    int previousSteps = 0,
    Duration? sinceLastReading,
  }) {
    final stored = storedBaseline;
    final last = lastSensorValue;
    final sameDay = stored != null && baselineDay == todayKey;

    if (last != null && cumulative < last) {
      // Within one boot the counter never decreases, so this is either a real
      // reboot or an old reading arriving late (for example a cached copy
      // replayed after a newer live reading). Treating the latter as a reboot
      // would zero the baseline and make "steps today" equal "steps since
      // boot", so only accept a drop that is physically consistent with a
      // reboot and ignore everything else.
      if (!_plausibleSinceBoot(cumulative, sinceLastReading)) {
        return StepCounterCalculation(
          baseline: stored ?? cumulative,
          steps: sameDay ? previousSteps : 0,
          accepted: false,
        );
      }
      // The counter restarted at zero, so every step it holds is new. Carry
      // today's earlier total forward by using a negative baseline.
      final carried = sameDay ? previousSteps : 0;
      return StepCounterCalculation(
        baseline: -carried,
        steps: (cumulative + carried).clamp(0, _maxDailySteps).toInt(),
      );
    }

    if (stored != null && sameDay) {
      return StepCounterCalculation(
        baseline: stored,
        steps: (cumulative - stored).clamp(0, _maxDailySteps).toInt(),
      );
    }

    // First reading of a new day. The previous day's last observed counter is
    // the midnight boundary approximation; subtracting it retains steps
    // counted after midnight but before the first reading for the new day.
    final baseline = last ?? cumulative;
    return StepCounterCalculation(
      baseline: baseline,
      steps: (cumulative - baseline).clamp(0, _maxDailySteps).toInt(),
    );
  }
}
