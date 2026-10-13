// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// Step-sensor listener with an Android foreground-service companion.
///
/// The hardware counter reports steps since device boot. The native Android
/// service keeps a sensor listener active while Flutter's activity/process is
/// backgrounded and checkpoints its latest value in shared preferences. This
/// stream remains active for immediate UI updates when Flutter is running.
class StepTrackerService {
  static const MethodChannel _trackingChannel = MethodChannel(
    'com.smartsteps/step_tracking',
  );

  final StreamController<int> _cumulativeController =
      StreamController<int>.broadcast();
  final StreamController<bool> _sensorStateController =
      StreamController<bool>.broadcast();

  StreamSubscription<StepCount>? _subscription;
  bool _started = false;
  bool _sensorOk = false;

  /// Raw cumulative "steps since boot" values from the hardware sensor.
  Stream<int> get cumulativeSteps => _cumulativeController.stream;

  /// Emits `true` once the first sensor reading arrives, `false` on failure.
  Stream<bool> get sensorAvailable => _sensorStateController.stream;

  bool get sensorOk => _sensorOk;

  /// Requests activity-recognition permission (Android 10+).
  Future<PermissionStatus> ensurePermission() async {
    var status = await Permission.activityRecognition.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.activityRecognition.request();
    }
    return status;
  }

  /// Starts the Android service and in-process stream. Safe to call repeatedly;
  /// a failure in one tracking route does not prevent attempting the other.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _trackingChannel.invokeMethod<void>('start');
      } catch (error) {
        // Keep the pedometer stream available even if Android denies service
        // startup or this build does not expose the native channel.
        debugPrint('Could not start native step-tracking service: $error');
      }
    }

    try {
      _subscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _sensorOk = true;
          _sensorStateController.add(true);
          _cumulativeController.add(event.steps);
        },
        onError: (_) {
          _sensorOk = false;
          _sensorStateController.add(false);
        },
        cancelOnError: false,
      );
    } catch (error) {
      _sensorOk = false;
      _sensorStateController.add(false);
      debugPrint('Could not listen to the step sensor: $error');
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _trackingChannel.invokeMethod<void>('stop');
      } catch (error) {
        debugPrint('Could not stop native step-tracking service: $error');
      }
    }
    _started = false;
  }

  void dispose() {
    _cumulativeController.close();
    _sensorStateController.close();
  }
}
