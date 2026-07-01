package com.savicam.tmod

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — "Vỏ bọc câm" (thin shell).
 *
 * Nhiệm vụ DUY NHẤT: khởi tạo Flutter engine và đăng ký các channel.
 * Toàn bộ routing + xử lý nghiệp vụ đều nằm trong [NativeChannelRouter].
 *
 * Luồng giao tiếp:
 *   Flutter (Dart) ──MethodChannel──► MainActivity (đăng ký)
 *                                          │
 *                                          ▼
 *                                  NativeChannelRouter (dispatch)
 *                                          │
 *                            ┌─────────────┴──────────────┐
 *                            ▼                            ▼
 *                     handleBridgeCall          handleHeadlessCall …
 *
 *   Native → Flutter push:
 *   NativeChannelRouter.fireRiskEvent()
 *     → EventChannel "risk_events" (đăng ký trong setupRiskEventChannel)
 *       → EventChannelRiskSource.riskStream (Dart)
 *   NativeChannelRouter.fireScreenStateEvent()
 *     → EventChannel "screen_state" (đăng ký trong setupScreenStateChannel)
 *       → HeadlessLifecycleManager (Dart)
 */
class MainActivity : FlutterActivity() {

    private var bridgeChannel: MethodChannel? = null
    private var headlessChannel: MethodChannel? = null
    private var navigationChannel: MethodChannel? = null
    // EventChannel risk_events + screen_state không cần giữ reference — NativeChannelRouter giữ sink

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // ── Inject context cho NativeChannelRouter (cần cho startForegroundService + AudioFocus) ──
        NativeChannelRouter.setContext(this)

        // ── Register: bridge ──────────────────────────────────────────────
        bridgeChannel = MethodChannel(messenger, NativeChannelRouter.CHANNEL_BRIDGE).also {
            it.setMethodCallHandler { call, result ->
                NativeChannelRouter.handleBridgeCall(call, result)
            }
        }

        // ── Register: headless (TASK-W8-NGKIEN-01) ────────────────────────
        headlessChannel = MethodChannel(messenger, NativeChannelRouter.CHANNEL_HEADLESS).also {
            it.setMethodCallHandler { call, result ->
                NativeChannelRouter.handleHeadlessCall(call, result)
            }
        }

        // ── Register: navigation (stub — TASK-W1-03) ──────────────────────
        navigationChannel = MethodChannel(messenger, NativeChannelRouter.CHANNEL_NAVIGATION).also {
            it.setMethodCallHandler { call, result ->
                NativeChannelRouter.handleNavigationCall(call, result)
            }
        }

        // ── Register: risk_events EventChannel (TASK-W6-NGKIEN-01) ───────
        NativeChannelRouter.setupRiskEventChannel(messenger)

        // ── Register: screen_state EventChannel (TASK-W8-NGKIEN-01) ──────
        NativeChannelRouter.setupScreenStateChannel(messenger)
    }

    override fun onDestroy() {
        // Giải phóng handler để tránh memory leak khi Activity bị destroy
        bridgeChannel?.setMethodCallHandler(null)
        headlessChannel?.setMethodCallHandler(null)
        navigationChannel?.setMethodCallHandler(null)
        // EventChannel sink tự release khi Flutter stop listening (onCancel callback)
        super.onDestroy()
    }
}
