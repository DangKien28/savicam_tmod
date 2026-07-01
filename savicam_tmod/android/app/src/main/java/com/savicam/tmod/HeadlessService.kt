package com.savicam.tmod

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.atomic.AtomicBoolean

/**
 * HeadlessService — Foreground Service giữ process sống khi app chạy ngầm.
 *
 * Kiến trúc:
 *   - WakeLock (PARTIAL_WAKE_LOCK): giữ CPU active khi screen off
 *   - Watchdog Timer: heartbeat mỗi 5 phút, update notification
 *   - ScreenStateReceiver: đăng ký động (ACTION_SCREEN_OFF/ON)
 *   - WorkManager fallback: tự restart nếu bị OEM kill
 *   - START_STICKY: OS tự restart service nếu bị kill do áp lực bộ nhớ
 *
 * KHÔNG chứa logic CV/AI. Tất cả logic nằm ở Dart + C++ qua FFI.
 */
class HeadlessService : Service() {

    companion object {
        private const val TAG = "HeadlessService"
        const val CHANNEL_ID = "savicam_headless_channel"
        private const val NOTIFICATION_ID = 9999
        private const val WATCHDOG_INTERVAL_MS = 5 * 60 * 1000L // 5 phút
        private const val WAKELOCK_TAG = "SaViCam::HeadlessWakeLock"
        const val WORK_NAME_RESTART = "savicam_headless_restart"

        /** Thread-safe state flag — query từ NativeChannelRouter */
        val isRunning = AtomicBoolean(false)

        /** Thời điểm service start (epochMs) — tính uptime */
        @Volatile
        var startTimeMs: Long = 0L
            private set

        /** Trạng thái WakeLock — report qua getStatus() */
        val wakeLockHeld = AtomicBoolean(false)

        /**
         * Schedule WorkManager restart khi service bị kill.
         * Dùng setExpedited() để chạy ASAP. Nếu quota bị cạn (user force-stop liên tục),
         * WorkManager tự fallback sang regular work — log cảnh báo Degraded state.
         */
        fun scheduleWorkManagerRestart(context: Context) {
            try {
                val request = OneTimeWorkRequestBuilder<HeadlessRestartWorker>()
                    .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                    .build()

                WorkManager.getInstance(context).enqueueUniqueWork(
                    WORK_NAME_RESTART,
                    ExistingWorkPolicy.REPLACE,
                    request
                )
                Log.i(TAG, "WorkManager restart scheduled (expedited)")
            } catch (e: Exception) {
                Log.e(TAG, "WorkManager schedule failed: ${e.message}")
            }
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private val watchdogHandler = Handler(Looper.getMainLooper())
    private var screenStateReceiver: ScreenStateReceiver? = null

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "onCreate")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand — flags=$flags startId=$startId")

        // 1. Start foreground ngay lập tức (Android 12+ yêu cầu <5s)
        startForeground(NOTIFICATION_ID, buildNotification("Đang khởi động..."))

        // 2. Acquire WakeLock
        acquireWakeLock()

        // 3. Đăng ký ScreenStateReceiver động
        registerScreenReceiver()

        // 4. Start watchdog heartbeat
        watchdogHandler.removeCallbacksAndMessages(null)
        watchdogHandler.postDelayed(watchdogRunnable, WATCHDOG_INTERVAL_MS)

        // 5. Update state
        isRunning.set(true)
        startTimeMs = System.currentTimeMillis()

        Log.i(TAG, "Service started — WakeLock=${wakeLockHeld.get()}")

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.i(TAG, "onDestroy")

        // 1. Cancel watchdog
        watchdogHandler.removeCallbacksAndMessages(null)

        // 2. Unregister receiver
        unregisterScreenReceiver()

        // 3. Release WakeLock
        releaseWakeLock()

        // 4. Update state
        isRunning.set(false)
        startTimeMs = 0L

        super.onDestroy()
    }

    /**
     * Khi user swipe-kill app từ Recents.
     * Schedule WorkManager restart làm fallback — không dùng AlarmManager (bị throttle API 31+).
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.w(TAG, "onTaskRemoved — scheduling WorkManager restart")
        scheduleWorkManagerRestart(this)
        super.onTaskRemoved(rootIntent)
    }

    // ── WakeLock ─────────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        if (wakeLock != null && wakeLock!!.isHeld) return

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG).apply {
            setReferenceCounted(false)
            acquire() // Không timeout — giữ cho đến khi service destroy
        }
        wakeLockHeld.set(true)
        Log.i(TAG, "WakeLock acquired")
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.i(TAG, "WakeLock released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "WakeLock release error: ${e.message}")
        } finally {
            wakeLock = null
            wakeLockHeld.set(false)
        }
    }

    // ── ScreenStateReceiver (đăng ký động — bắt buộc cho ACTION_SCREEN_OFF) ─

    private fun registerScreenReceiver() {
        if (screenStateReceiver != null) return

        screenStateReceiver = ScreenStateReceiver()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenStateReceiver, filter)
        }
        Log.i(TAG, "ScreenStateReceiver registered dynamically")
    }

    private fun unregisterScreenReceiver() {
        screenStateReceiver?.let {
            try {
                unregisterReceiver(it)
                Log.i(TAG, "ScreenStateReceiver unregistered")
            } catch (e: Exception) {
                Log.w(TAG, "ScreenStateReceiver unregister error: ${e.message}")
            }
        }
        screenStateReceiver = null
    }

    // ── Watchdog Timer ───────────────────────────────────────────────────────

    private val watchdogRunnable = object : Runnable {
        override fun run() {
            val uptimeMin = (System.currentTimeMillis() - startTimeMs) / 60_000
            val wlHeld = wakeLock?.isHeld == true
            wakeLockHeld.set(wlHeld)

            Log.i(TAG, "Watchdog heartbeat — uptime=${uptimeMin}min WakeLock=$wlHeld")

            // Re-acquire WakeLock nếu bị mất (OEM kill)
            if (!wlHeld) {
                Log.w(TAG, "WakeLock lost! Re-acquiring...")
                acquireWakeLock()
            }

            // Update notification với uptime
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, buildNotification("Hoạt động ${uptimeMin} phút"))

            // Schedule next heartbeat
            watchdogHandler.postDelayed(this, WATCHDOG_INTERVAL_MS)
        }
    }

    // ── Notification ─────────────────────────────────────────────────────────

    private fun buildNotification(contentText: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SaViCam T-Mod")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SaViCam Trợ lý nền",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Giữ ứng dụng SaViCam hoạt động khi màn hình tắt"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }
}

/**
 * Worker khởi động lại HeadlessService khi bị system/OEM kill.
 * OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST = nếu hết quota expedited,
 * chạy dạng regular work (có thể delay 10-15 phút) — degraded nhưng vẫn sống.
 */
class HeadlessRestartWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    override fun doWork(): Result {
        Log.i("HeadlessRestartWorker", "Attempting to restart HeadlessService...")

        return try {
            val intent = Intent(applicationContext, HeadlessService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(intent)
            } else {
                applicationContext.startService(intent)
            }
            Log.i("HeadlessRestartWorker", "HeadlessService restart intent sent")
            Result.success()
        } catch (e: Exception) {
            Log.e("HeadlessRestartWorker", "Restart failed: ${e.message}")
            // Degraded state — Relap should be notified via next telemetry cycle
            Result.failure()
        }
    }
}
