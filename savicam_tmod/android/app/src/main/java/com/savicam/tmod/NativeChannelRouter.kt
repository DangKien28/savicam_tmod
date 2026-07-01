package com.savicam.tmod

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger

/**
 * NativeChannelRouter
 *
 * Điểm trung tâm điều phối mọi MethodChannel call từ Flutter → Native,
 * và quản lý EventChannel đẩy event từ Native → Flutter.
 *
 * Nguyên tắc thiết kế:
 *   - Channel name tuân theo convention: "com.savicam.tmod/<domain>"
 *   - Mỗi domain (bridge, headless, navigation, risk_events, screen_state) có handler riêng.
 *   - Router KHÔNG chứa logic nghiệp vụ; chỉ route + validate.
 *
 * Channel Convention Table:
 *   com.savicam.tmod/bridge        → giao tiếp FFI / C++ layer (MethodChannel)
 *   com.savicam.tmod/headless      → điều khiển HeadlessService  (MethodChannel)
 *   com.savicam.tmod/navigation    → GraphHopper offline routing  (MethodChannel)
 *   com.savicam.tmod/risk_events   → push risk-level events → Flutter (EventChannel)
 *   com.savicam.tmod/screen_state  → push screen on/off events → Flutter (EventChannel)
 */
object NativeChannelRouter {

    private const val TAG = "NativeChannelRouter"

    // ── Channel name constants (dùng chung Kotlin + Dart) ───────────────────
    const val CHANNEL_BRIDGE       = "com.savicam.tmod/bridge"
    const val CHANNEL_HEADLESS     = "com.savicam.tmod/headless"
    const val CHANNEL_NAVIGATION   = "com.savicam.tmod/navigation"
    const val CHANNEL_RISK_EVENTS  = "com.savicam.tmod/risk_events"
    const val CHANNEL_SCREEN_STATE = "com.savicam.tmod/screen_state"

    // ── Method name constants (bridge channel) ──────────────────────────────
    private const val METHOD_PING              = "ping"
    private const val METHOD_GET_VERSION       = "getVersion"
    private const val METHOD_ECHO              = "echo"
    private const val METHOD_SIMULATE_RISK     = "simulateRiskEvent"

    // ── Method name constants (headless channel) ────────────────────────────
    private const val METHOD_START_SERVICE     = "startService"
    private const val METHOD_STOP_SERVICE      = "stopService"
    private const val METHOD_GET_STATUS        = "getStatus"
    private const val METHOD_REQUEST_AUDIO     = "requestAudioFocus"
    private const val METHOD_ABANDON_AUDIO     = "abandonAudioFocus"

    // ── Context — injected từ MainActivity ──────────────────────────────────
    @Volatile
    private var appContext: Context? = null

    // ── TtsAudioFocusManager ────────────────────────────────────────────────
    private var audioFocusManager: TtsAudioFocusManager? = null

    /**
     * Inject application context. Gọi 1 lần từ MainActivity.configureFlutterEngine().
     * Cần cho startForegroundService() và TtsAudioFocusManager.
     */
    fun setContext(context: Context) {
        appContext = context.applicationContext
        audioFocusManager = TtsAudioFocusManager(appContext!!)
        Log.d(TAG, "setContext: applicationContext set")
    }

    // ── EventChannel state — risk_events ────────────────────────────────────
    /**
     * Sink của EventChannel "risk_events".
     * @Volatile đảm bảo visibility khi được ghi từ background thread
     * (ví dụ: JNI callback từ C++ khi Tiến tích hợp AttachCurrentThread).
     *
     * KHÔNG gọi riskEventSink?.success() trực tiếp từ bất kỳ thread nào —
     * luôn dùng [fireRiskEvent] để đảm bảo post về main thread.
     */
    @Volatile
    private var riskEventSink: EventChannel.EventSink? = null

    // ── EventChannel state — screen_state ───────────────────────────────────
    @Volatile
    private var screenStateSink: EventChannel.EventSink? = null

    /**
     * Đăng ký EventChannel "risk_events" với Flutter engine.
     * Gọi 1 lần trong MainActivity.configureFlutterEngine().
     */
    fun setupRiskEventChannel(messenger: BinaryMessenger) {
        EventChannel(messenger, CHANNEL_RISK_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    Log.i(TAG, "risk_events channel: Flutter listening — sink attached")
                    riskEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    Log.i(TAG, "risk_events channel: Flutter stopped listening — sink released")
                    riskEventSink = null
                }
            }
        )
        Log.d(TAG, "setupRiskEventChannel: EventChannel registered → $CHANNEL_RISK_EVENTS")
    }

    /**
     * Đăng ký EventChannel "screen_state" với Flutter engine.
     * Gọi 1 lần trong MainActivity.configureFlutterEngine().
     */
    fun setupScreenStateChannel(messenger: BinaryMessenger) {
        EventChannel(messenger, CHANNEL_SCREEN_STATE).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    Log.i(TAG, "screen_state channel: Flutter listening — sink attached")
                    screenStateSink = events
                }
                override fun onCancel(arguments: Any?) {
                    Log.i(TAG, "screen_state channel: Flutter stopped listening — sink released")
                    screenStateSink = null
                }
            }
        )
        Log.d(TAG, "setupScreenStateChannel: EventChannel registered → $CHANNEL_SCREEN_STATE")
    }

    /**
     * Push 1 risk event xuống Flutter qua EventChannel.
     *
     * Thread-safe: **luôn post về main thread** qua Handler(mainLooper),
     * kể cả khi gọi từ background thread (Timer, JNI callback từ C++, v.v.).
     * Overhead không đáng kể nếu đã ở main thread.
     *
     * Payload Map key khớp 1:1 với EventChannelRiskSource._parseEvent() phía Dart.
     */
    fun fireRiskEvent(
        riskLevel: Int,
        ttcSeconds: Float,
        distanceM: Float,
        classId: Int,
        timestampMs: Long
    ) {
        // Validate trước khi post để tránh crash trên main thread
        if (riskLevel !in 0..4) {
            Log.w(TAG, "fireRiskEvent: riskLevel=$riskLevel ngoài range 0–4, bỏ qua")
            return
        }

        Handler(Looper.getMainLooper()).post {
            val sink = riskEventSink
            if (sink == null) {
                Log.w(TAG, "fireRiskEvent: sink null — Flutter chưa listen hoặc đã cancel")
                return@post
            }
            Log.d(TAG, "fireRiskEvent: level=$riskLevel ttc=$ttcSeconds dist=$distanceM class=$classId")
            sink.success(
                mapOf(
                    "risk_level"            to riskLevel,
                    "ttc_seconds"           to ttcSeconds,
                    "nearest_distance_m"    to distanceM,
                    "nearest_class_id"      to classId,
                    "timestamp_ms"          to timestampMs
                )
            )
        }
    }

    /**
     * Push screen state event xuống Flutter qua EventChannel.
     * Gọi từ [ScreenStateReceiver.onReceive].
     * Thread-safe: post về main thread.
     */
    fun fireScreenStateEvent(isScreenOn: Boolean) {
        Handler(Looper.getMainLooper()).post {
            val sink = screenStateSink
            if (sink == null) {
                Log.w(TAG, "fireScreenStateEvent: sink null — Flutter chưa listen")
                return@post
            }
            Log.i(TAG, "fireScreenStateEvent: isScreenOn=$isScreenOn")
            sink.success(
                mapOf(
                    "is_screen_on" to isScreenOn,
                    "timestamp_ms" to System.currentTimeMillis()
                )
            )
        }
    }

    // ── MethodChannel handlers ──────────────────────────────────────────────

    /**
     * Xử lý tất cả call thuộc channel [CHANNEL_BRIDGE].
     * Gọi từ MainActivity sau khi channel đã được đăng ký.
     */
    fun handleBridgeCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "handleBridgeCall → method='${call.method}' args=${call.arguments}")

        when (call.method) {

            // ── Kiểm thử round-trip cơ bản ──────────────────────────────
            METHOD_PING -> {
                Log.i(TAG, "ping received → replying pong")
                result.success("pong")
            }

            // ── Trả về version string của native layer ───────────────────
            METHOD_GET_VERSION -> {
                val version = "savicam-native/1.0.0 (W1-01)"
                Log.i(TAG, "getVersion → $version")
                result.success(version)
            }

            // ── Echo: phản chiếu nguyên văn bất kỳ String nào từ Dart ───
            METHOD_ECHO -> {
                val payload = call.argument<String>("message")
                if (payload == null) {
                    Log.w(TAG, "echo called without 'message' argument")
                    result.error(
                        "MISSING_ARGUMENT",
                        "Argument 'message' is required for method 'echo'",
                        null
                    )
                    return
                }
                val echoed = "[native-echo] $payload"
                Log.i(TAG, "echo → '$echoed'")
                result.success(echoed)
            }

            // ── Giả lập risk event (DoD test — RiskSimulatorScreen) ──────
            // Dart → MethodChannel → đây → fireRiskEvent → EventChannel → Dart
            METHOD_SIMULATE_RISK -> {
                val riskLevel  = call.argument<Int>("risk_level") ?: 0
                val ttc        = (call.argument<Double>("ttc_seconds") ?: 1.5).toFloat()
                val dist       = (call.argument<Double>("nearest_distance_m") ?: 1.0).toFloat()
                val classId    = call.argument<Int>("nearest_class_id") ?: 1
                val tsMs       = call.argument<Long>("timestamp_ms")
                                  ?: System.currentTimeMillis()

                Log.i(TAG, "simulateRiskEvent: level=$riskLevel ttc=$ttc dist=$dist class=$classId")
                fireRiskEvent(riskLevel, ttc, dist, classId, tsMs)
                result.success(null) // fire-and-forget; Dart không chờ ack
            }

            else -> {
                Log.w(TAG, "Unknown method '${call.method}' on $CHANNEL_BRIDGE")
                result.notImplemented()
            }
        }
    }

    /**
     * Xử lý call thuộc channel [CHANNEL_HEADLESS].
     * Implement đầy đủ: startService, stopService, getStatus, audioFocus.
     */
    fun handleHeadlessCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "handleHeadlessCall → method='${call.method}'")

        val ctx = appContext
        if (ctx == null) {
            Log.e(TAG, "handleHeadlessCall: appContext is null — setContext() chưa được gọi")
            result.error("NO_CONTEXT", "Application context not set", null)
            return
        }

        when (call.method) {

            METHOD_START_SERVICE -> {
                try {
                    val intent = Intent(ctx, HeadlessService::class.java)
                    ContextCompat.startForegroundService(ctx, intent)
                    Log.i(TAG, "startService: HeadlessService started")
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "startService failed: ${e.message}")
                    result.error("START_FAILED", e.message, null)
                }
            }

            METHOD_STOP_SERVICE -> {
                try {
                    val intent = Intent(ctx, HeadlessService::class.java)
                    ctx.stopService(intent)
                    Log.i(TAG, "stopService: HeadlessService stopped")
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "stopService failed: ${e.message}")
                    result.error("STOP_FAILED", e.message, null)
                }
            }

            METHOD_GET_STATUS -> {
                val isRunning = HeadlessService.isRunning.get()
                val uptimeMs = if (isRunning && HeadlessService.startTimeMs > 0) {
                    System.currentTimeMillis() - HeadlessService.startTimeMs
                } else {
                    0L
                }
                val wakeLockHeld = HeadlessService.wakeLockHeld.get()

                val status = mapOf(
                    "isRunning"    to isRunning,
                    "uptimeMs"     to uptimeMs,
                    "wakeLockHeld" to wakeLockHeld
                )
                Log.d(TAG, "getStatus: $status")
                result.success(status)
            }

            METHOD_REQUEST_AUDIO -> {
                val mgr = audioFocusManager
                if (mgr == null) {
                    result.error("NO_AUDIO_MANAGER", "TtsAudioFocusManager not initialized", null)
                    return
                }
                val granted = mgr.requestFocus()
                result.success(granted)
            }

            METHOD_ABANDON_AUDIO -> {
                audioFocusManager?.abandonFocus()
                result.success(true)
            }

            else -> {
                Log.w(TAG, "Unknown method '${call.method}' on $CHANNEL_HEADLESS")
                result.notImplemented()
            }
        }
    }

    /**
     * Xử lý call thuộc channel [CHANNEL_NAVIGATION].
     * Stub sẵn để TASK-W1-03 (GraphHopper) mở rộng.
     */
    fun handleNavigationCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "handleNavigationCall → method='${call.method}'")
        // TODO(W1-03): Implement route calculation, offline tile loading
        result.notImplemented()
    }
}
