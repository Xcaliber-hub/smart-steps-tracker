package com.smartsteps.smart_steps_tracker

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRACKING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            getSharedPreferences(FLUTTER_PREFS, MODE_PRIVATE)
                                .edit()
                                .putBoolean(PREF_TRACKING_ENABLED, true)
                                .apply()
                            val intent = Intent(this, AndroidStepTrackingService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("step_service_start_failed", error.message, null)
                        }
                    }

                    "stop" -> {
                        getSharedPreferences(FLUTTER_PREFS, MODE_PRIVATE)
                            .edit()
                            .putBoolean(PREF_TRACKING_ENABLED, false)
                            .apply()
                        stopService(Intent(this, AndroidStepTrackingService::class.java))
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val TRACKING_CHANNEL = "com.smartsteps/step_tracking"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val PREF_TRACKING_ENABLED = "flutter.step_tracking_enabled"
    }
}
