import 'dart:async';
import 'package:flutter/services.dart';

/// MethodChannelBridge
///
/// Dart-side wrapper cho tất cả lời gọi MethodChannel → Native Android.
/// Đây là lớp DUY NHẤT trong codebase Dart được phép gọi platform channel.
///
/// Channel Convention (khớp 1-1 với NativeChannelRouter.kt):
///   com.savicam.tmod/bridge      → FFI / C++ layer
///   com.savicam.tmod/headless    → HeadlessService (TASK-W1-02)
///   com.savicam.tmod/navigation  → GraphHopper routing (TASK-W1-03)
class MethodChannelBridge {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final MethodChannelBridge _instance = MethodChannelBridge._();
  factory MethodChannelBridge() => _instance;
  MethodChannelBridge._();

  // ── Channel instances ──────────────────────────────────────────────────
  static const String _channelBridge     = 'com.savicam.tmod/bridge';
  static const String _channelHeadless   = 'com.savicam.tmod/headless';
  static const String _channelNavigation = 'com.savicam.tmod/navigation';

  final MethodChannel _bridge     = const MethodChannel(_channelBridge);
  final MethodChannel _headless   = const MethodChannel(_channelHeadless);
  final MethodChannel _navigation = const MethodChannel(_channelNavigation);

  // ── Exposing channels cho các module khác (read-only) ─────────────────
  MethodChannel get bridgeChannel     => _bridge;
  MethodChannel get headlessChannel   => _headless;
  MethodChannel get navigationChannel => _navigation;

  // ==========================================================================
  // Bridge Channel — com.savicam.tmod/bridge
  // ==========================================================================

  /// Gửi lệnh [ping] đến native → kỳ vọng nhận "pong".
  /// Dùng để kiểm thử kết nối channel còn sống.
  Future<String> ping() async {
    try {
      final result = await _bridge.invokeMethod<String>('ping');
      return result ?? '(null response)';
    } on PlatformException catch (e) {
      throw BridgeException('ping', e.code, e.message);
    }
  }

  /// Truy vấn version string của native layer.
  Future<String> getNativeVersion() async {
    try {
      final result = await _bridge.invokeMethod<String>('getVersion');
      return result ?? 'unknown';
    } on PlatformException catch (e) {
      throw BridgeException('getVersion', e.code, e.message);
    }
  }

  /// Gửi [message] lên native → nhận về chuỗi đã được echo-wrap.
  /// Dùng để kiểm thử round-trip có payload.
  Future<String> echo(String message) async {
    try {
      final result = await _bridge.invokeMethod<String>(
        'echo',
        {'message': message},
      );
      return result ?? '(null response)';
    } on PlatformException catch (e) {
      throw BridgeException('echo', e.code, e.message);
    }
  }

  // ==========================================================================
  // Risk Event Simulation — com.savicam.tmod/bridge
  // Chỉ dùng trong RiskSimulatorScreen (DoD test / debug)
  // ==========================================================================

  /// Yêu cầu native phát giả lập risk event qua EventChannel.
  ///
  /// Flow: Dart → MethodChannel "bridge" (method: simulateRiskEvent)
  ///         → NativeChannelRouter.handleBridgeCall
  ///           → NativeChannelRouter.fireRiskEvent [Handler(mainLooper)]
  ///             → EventChannel "risk_events" sink
  ///               → EventChannelRiskSource.riskStream
  ///                 → VisionAlertController → TTS + Rung
  ///
  /// Params mặc định giả lập "vật thể ở 1m, TTC 1.5s" cho mức cảnh báo.
  Future<void> simulateRiskEvent({
    required int riskLevel,
    double ttcSeconds = 1.5,
    double distanceM = 1.0,
    int classId = 1,
  }) async {
    assert(riskLevel >= 0 && riskLevel <= 4,
        'riskLevel phải trong khoảng 0–4, nhận: $riskLevel');
    try {
      await _bridge.invokeMethod<void>('simulateRiskEvent', {
        'risk_level': riskLevel,
        'ttc_seconds': ttcSeconds,
        'nearest_distance_m': distanceM,
        'nearest_class_id': classId,
        'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      throw BridgeException('simulateRiskEvent', e.code, e.message);
    }
  }

  // ==========================================================================
  // Headless Channel — com.savicam.tmod/headless (TASK-W8-NGKIEN-01)
  // ==========================================================================

  /// Khởi động HeadlessService Foreground Service.
  /// Gọi khi screen off hoặc khi user muốn chạy nền thủ công.
  Future<void> startHeadlessService() async {
    try {
      await _headless.invokeMethod<void>('startService');
    } on PlatformException catch (e) {
      throw BridgeException('startService', e.code, e.message);
    }
  }

  /// Dừng HeadlessService.
  /// Gọi khi screen on hoặc khi user tắt chế độ nền.
  Future<void> stopHeadlessService() async {
    try {
      await _headless.invokeMethod<void>('stopService');
    } on PlatformException catch (e) {
      throw BridgeException('stopService', e.code, e.message);
    }
  }

  /// Truy vấn trạng thái HeadlessService.
  /// Returns [HeadlessStatus] chứa isRunning, uptimeMs, wakeLockHeld.
  Future<HeadlessStatus> getHeadlessStatus() async {
    try {
      final result = await _headless.invokeMapMethod<String, dynamic>('getStatus');
      return HeadlessStatus.fromMap(result ?? {});
    } on PlatformException catch (e) {
      throw BridgeException('getStatus', e.code, e.message);
    }
  }

  /// Request AudioFocus TRƯỚC khi TTS phát (bắt buộc cho Xiaomi/Oppo headless).
  /// Returns true nếu được cấp, false nếu bị từ chối.
  Future<bool> requestAudioFocus() async {
    try {
      final result = await _headless.invokeMethod<bool>('requestAudioFocus');
      return result ?? false;
    } on PlatformException catch (e) {
      throw BridgeException('requestAudioFocus', e.code, e.message);
    }
  }

  /// Abandon AudioFocus SAU khi TTS xong.
  Future<void> abandonAudioFocus() async {
    try {
      await _headless.invokeMethod<void>('abandonAudioFocus');
    } on PlatformException catch (e) {
      throw BridgeException('abandonAudioFocus', e.code, e.message);
    }
  }

  // ==========================================================================
  // Navigation Channel — com.savicam.tmod/navigation (stubs — TASK-W1-03)
  // ==========================================================================

  /// TODO(W1-03): Tính tuyến đường GraphHopper offline
  Future<Map<String, dynamic>?> calculateRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    return _navigation.invokeMapMethod<String, dynamic>('calculateRoute', {
      'fromLat': fromLat,
      'fromLng': fromLng,
      'toLat': toLat,
      'toLng': toLng,
    });
  }
}

// =============================================================================
// Exception type riêng — tránh nuốt lỗi platform dưới dạng dynamic
// =============================================================================

class BridgeException implements Exception {
  final String method;
  final String code;
  final String? message;

  const BridgeException(this.method, this.code, this.message);

  @override
  String toString() =>
      'BridgeException[$method]: code=$code, message=$message';
}

// =============================================================================
// HeadlessService status — dữ liệu từ NativeChannelRouter.getStatus()
// =============================================================================

class HeadlessStatus {
  final bool isRunning;
  final int uptimeMs;
  final bool wakeLockHeld;

  const HeadlessStatus({
    this.isRunning = false,
    this.uptimeMs = 0,
    this.wakeLockHeld = false,
  });

  factory HeadlessStatus.fromMap(Map<String, dynamic> m) => HeadlessStatus(
    isRunning: m['isRunning'] as bool? ?? false,
    uptimeMs: (m['uptimeMs'] as num?)?.toInt() ?? 0,
    wakeLockHeld: m['wakeLockHeld'] as bool? ?? false,
  );

  /// Service chạy nhưng WakeLock mất = degraded state
  bool get isDegraded => isRunning && !wakeLockHeld;

  @override
  String toString() =>
      'HeadlessStatus(running=$isRunning, uptime=${uptimeMs}ms, wakeLock=$wakeLockHeld)';
}
