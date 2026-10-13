package com.smartsteps.smart_steps_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Keeps the hardware step-counter listener registered independently of the
 * Flutter activity. Android can restart this sticky foreground service after
 * reclaiming the app process; each reading is checkpointed for Dart/WorkManager.
 */
class AndroidStepTrackingService : Service(), SensorEventListener {
    private var sensorManager: SensorManager? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        try {
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (error: Exception) {
            Log.e(TAG, "Could not start step-tracking foreground service", error)
            stopSelf()
            return
        }

        val manager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null) {
            Log.w(TAG, "This device does not expose TYPE_STEP_COUNTER")
            removeForegroundNotification()
            stopSelf()
            return
        }

        sensorManager = manager
        try {
            if (!manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)) {
                Log.w(TAG, "Could not register the step-counter listener")
                removeForegroundNotification()
                stopSelf()
            }
        } catch (error: SecurityException) {
            Log.w(TAG, "Activity-recognition permission is required for step tracking", error)
            removeForegroundNotification()
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER || event.values.isEmpty()) return
        val cumulative = event.values[0].toInt()
        getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt(PREF_LATEST, cumulative)
            .putLong(PREF_LATEST_AT, System.currentTimeMillis())
            .apply()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        sensorManager = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun removeForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Step tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps daily step tracking active in the background"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }),
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentTitle("Stride is tracking steps")
            .setContentText("Step counting continues in the background.")
            .setContentIntent(openApp)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .build()
    }

    companion object {
        private const val TAG = "StrideStepService"
        private const val NOTIFICATION_ID = 4101
        private const val CHANNEL_ID = "step_tracking_service"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val PREF_LATEST = "flutter.native_sensor_latest"
        private const val PREF_LATEST_AT = "flutter.native_sensor_updated_at_ms"
    }
}
