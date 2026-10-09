// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:async';

import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// Foreground step-sensor listener.
///
/// ## How step counting works
/// The `pedometer` plugin exposes the Android hardware `TYPE_STEP_COUNTER`
/// sensor, which reports a monotonically increasing count of steps since the
/// last device boot. This service forwards those raw cumulative values; the
/// [StepRepository] turns them into per-day totals using a stored baseline.
///
/// ## Background behavior (read this)
/// - While the app process is alive (foreground or backgrounded), sensor
///   events keep arriving and are persisted on every event.
/// - If Android kills the app, no Dart code runs until the user reopens it
///   or a WorkManager task fires. On the next event we reconcile the delta,
///   so the daily total self-heals as long as the device did not reboot.
/// - A device reboot resets the hardware counter to zero; we detect the
///   counter moving backwards and re-baseline (steps taken before the
///   reboot are kept, steps between kill and reboot may be undercounted).
/// - Truly continuous 24/7 capture requires a foreground service with an
///   ongoing notification (e.g. via `flutter_foreground_task`). That is the
///   recommended next step if exact background fidelity matters more than
///   the extra battery/notification cost; the repository layer is already
///   structured so the data path would not change.
class StepTrackerService {
  final StreamController<int> _cumulativeController =
      StreamController<int>.broadcast();
  final StreamController<bool> _sensorStateController =
      StreamController<bool>.broadcast();

  StreamSubscription<StepCount>? _subscription;
  bool _started = false;
  bool _sensorOk = false;

  /// Raw cumulative "steps since boot" values from the hardware sensor.
  Stream<int> get cumulativeSteps => _cumulativeController.stream;

  /// Emits `true` once the first sensor reading arrives, `false` when the
  /// sensor reports an error (e.g. no step-counter hardware).
  Stream<bool> get sensorAvailable => _sensorStateController.stream;

  bool get sensorOk => _sensorOk;

  /// Requests activity-recognition permission (Android 10+). Returns the
  /// resulting status; tracking is degraded to manual-only when denied.
  Future<PermissionStatus> ensurePermission() async {
    var status = await Permission.activityRecognition.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.activityRecognition.request();
    }
    return status;
  }

  /// Starts listening to the step-counter sensor. Safe to call repeatedly.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _subscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _sensorOk = true;
          _sensorStateController.add(true);
          _cumulativeController.add(event.steps);
        },
        onError: (_) {
          // No step-counter sensor (or sensor failure): the app keeps
          // working, the dashboard shows an explanatory empty state and
          // previously recorded data remains visible.
          _sensorOk = false;
          _sensorStateController.add(false);
        },
        cancelOnError: false,
      );
    } catch (_) {
      _sensorOk = false;
      _sensorStateController.add(false);
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  void dispose() {
    _cumulativeController.close();
    _sensorStateController.close();
  }
}
