import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ffi_bridge/method_channel_bridge.dart';
import '../../features/telemetry/watch_live_location_usecase.dart';

/// HeadlessLifecycleManager
///
/// Orchestrator trung tâm cho Headless Mode. Lắng nghe screen state từ
/// native [ScreenStateReceiver] qua EventChannel, tự động:
///   - screen_off → startHeadlessService + set isHeadless = true
///   - screen_on  → stopHeadlessService  + set isHeadless = false
///
/// KHÔNG dùng [AppLifecycleState.paused] vì paused fire khi:
///   - Nhận cuộc gọi
///   - Vuốt notification panel
///   - Chuyển app
/// → Gây start/stop liên tục. Thay vào đó dùng BroadcastReceiver
/// (ACTION_SCREEN_OFF/ON) — chỉ fire khi screen thật sự tắt/bật.
///
/// Usage:
/// ```dart
/// final manager = HeadlessLifecycleManager(bridge);
/// manager.init(); // Bắt đầu lắng nghe
/// // ...
/// manager.dispose(); // Dừng lắng nghe
/// ```
class HeadlessLifecycleManager {
  final MethodChannelBridge _bridge;
  final WatchLiveLocationUsecase _watchLiveLocationUsecase;

  /// EventChannel nhận screen state từ native ScreenStateReceiver.
  /// Channel name phải khớp với NativeChannelRouter.CHANNEL_SCREEN_STATE.
  static const String _screenStateChannel = 'com.savicam.tmod/screen_state';

  final EventChannel _eventChannel = const EventChannel(_screenStateChannel);
  StreamSubscription<dynamic>? _subscription;

  /// Trạng thái Headless hiện tại — UI widgets lắng nghe để skip rendering.
  final ValueNotifier<bool> isHeadless = ValueNotifier<bool>(false);

  /// Trạng thái chi tiết từ native service.
  final ValueNotifier<HeadlessStatus> serviceStatus =
      ValueNotifier<HeadlessStatus>(const HeadlessStatus());

  HeadlessLifecycleManager(this._bridge, this._watchLiveLocationUsecase);

  /// Bắt đầu lắng nghe screen state từ native.
  /// Gọi 1 lần sau DI init.
  void init() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      _onScreenStateEvent,
      onError: (Object e) {
        debugPrint('[HeadlessLifecycleManager] EventChannel error: $e');
      },
      onDone: () {
        debugPrint('[HeadlessLifecycleManager] EventChannel closed');
      },
    );
    debugPrint('[HeadlessLifecycleManager] Listening on $_screenStateChannel');
  }

  /// Xử lý event từ native ScreenStateReceiver.
  void _onScreenStateEvent(dynamic event) {
    if (event is! Map) {
      debugPrint('[HeadlessLifecycleManager] Invalid event type: ${event.runtimeType}');
      return;
    }

    final isScreenOn = event['is_screen_on'] as bool? ?? true;
    debugPrint('[HeadlessLifecycleManager] Screen ${isScreenOn ? "ON" : "OFF"}');

    if (isScreenOn) {
      _onScreenOn();
    } else {
      _onScreenOff();
    }
  }

  /// Screen tắt → khởi động Foreground Service.
  Future<void> _onScreenOff() async {
    if (isHeadless.value) return; // Đã chạy headless

    try {
      await _bridge.startHeadlessService();
      isHeadless.value = true;
      debugPrint('[HeadlessLifecycleManager] Headless Mode ACTIVATED');

      // Bắt đầu gửi telemetry
      _watchLiveLocationUsecase.startTracking();

      // Cập nhật trạng thái chi tiết
      await _refreshStatus();
    } catch (e) {
      debugPrint('[HeadlessLifecycleManager] startHeadlessService failed: $e');
    }
  }

  /// Screen bật → dừng Foreground Service.
  Future<void> _onScreenOn() async {
    if (!isHeadless.value) return; // Không đang headless

    try {
      await _bridge.stopHeadlessService();
      isHeadless.value = false;
      serviceStatus.value = const HeadlessStatus();
      debugPrint('[HeadlessLifecycleManager] Headless Mode DEACTIVATED');
      
      // Dừng telemetry
      _watchLiveLocationUsecase.stopTracking();
    } catch (e) {
      debugPrint('[HeadlessLifecycleManager] stopHeadlessService failed: $e');
    }
  }

  /// Truy vấn trạng thái chi tiết từ native.
  Future<void> _refreshStatus() async {
    try {
      final status = await _bridge.getHeadlessStatus();
      serviceStatus.value = status;

      if (status.isDegraded) {
        debugPrint('[HeadlessLifecycleManager] WARNING: Service is DEGRADED '
            '(running=${status.isRunning}, wakeLock=${status.wakeLockHeld})');
      }
    } catch (e) {
      debugPrint('[HeadlessLifecycleManager] getStatus failed: $e');
    }
  }

  /// Bắt đầu headless mode thủ công (không phụ thuộc screen state).
  Future<void> forceStart() async {
    await _onScreenOff();
  }

  /// Dừng headless mode thủ công.
  Future<void> forceStop() async {
    await _onScreenOn();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    isHeadless.dispose();
    serviceStatus.dispose();
  }
}
