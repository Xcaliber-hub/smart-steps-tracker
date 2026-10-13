package com.smartsteps.smart_steps_tracker

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log

/** Restarts tracking after reboot when the user previously enabled it. */
class StepTrackingBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return

        val preferences = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        if (!preferences.getBoolean(PREF_TRACKING_ENABLED, false)) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            Log.i(TAG, "Not restoring step tracking: activity-recognition permission is not granted")
            return
        }

        try {
            val serviceIntent = Intent(context, AndroidStepTrackingService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (error: IllegalStateException) {
            // Android may defer a foreground-service launch during boot on
            // some OS/device combinations. WorkManager still reconciles the
            // last durable reading when its next eligible task runs.
            Log.w(TAG, "Android deferred step-service restoration after boot", error)
        } catch (error: SecurityException) {
            Log.w(TAG, "Android denied step-service restoration after boot", error)
        }
    }

    companion object {
        private const val TAG = "StrideStepBootReceiver"
        private const val PREF_TRACKING_ENABLED = "flutter.step_tracking_enabled"
    }
}
