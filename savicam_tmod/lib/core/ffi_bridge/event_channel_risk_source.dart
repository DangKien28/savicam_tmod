// event_channel_risk_source.dart
//
// Test/Debug implementation của IRiskSource.
// Nhận RiskEvent từ Kotlin qua EventChannel "com.savicam.tmod/risk_events".
//
// CHỈ dùng trong RiskSimulatorScreen (DoD test) — KHÔNG phải production path.
// Production dùng FfiPollingRiskSource.
//
// Trigger flow (test):
//   RiskSimulatorScreen → MethodChannelBridge.simulateRiskEvent()
//     → NativeChannelRouter.handleBridgeCall (case "simulateRiskEvent")
//       → NativeChannelRouter.fireRiskEvent() [Handler(mainLooper).post]
//         → EventChannel.EventSink.success(Map)
//           → EventChannelRiskSource.riskStream
//             → VisionAlertController._onRiskEvent()
//               → TTS + Rung + UI

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'risk_source.dart';

/// EventChannel implementation của [IRiskSource] — dành cho test/debug.
///
/// [start] và [stop] là no-op vì [EventChannel.receiveBroadcastStream]
/// tự quản lý lifecycle khi có/không có listener.
///
/// Stream behavior:
/// - Hot stream: emit ngay khi Kotlin push event.
/// - Nếu native side crash hoặc hot-reload, stream emit [done] → consumer được log.
/// - `.handleError()` bắt lỗi trung gian mà không close stream.
/// - `.asBroadcastStream()` cho phép nhiều widget subscribe cùng lúc.
class EventChannelRiskSource implements IRiskSource {
  static const _channelName = 'com.savicam.tmod/risk_events';
  static const _channel = EventChannel(_channelName);

  // Lazy-initialized broadcast stream — tạo 1 lần, chia sẻ nhiều listener
  late final Stream<RiskEvent> _stream = _channel
      .receiveBroadcastStream()
      .cast<Map<Object?, Object?>>()
      .map(_parseEvent)
      .handleError((Object e, StackTrace st) {
        // Log lỗi nhưng không rethrow — stream tiếp tục cho đến khi native đóng
        debugPrint('[EventChannelRiskSource] stream error: $e\n$st');
      })
      .asBroadcastStream(
        onListen: (_) => debugPrint(
            '[EventChannelRiskSource] listener attached → channel: $_channelName'),
        onCancel: (_) => debugPrint(
            '[EventChannelRiskSource] last listener detached'),
      );

  @override
  Stream<RiskEvent> get riskStream => _stream;

  /// no-op — EventChannel tự bắt đầu khi có listener subscribe.
  @override
  void start() {}

  /// no-op — EventChannel tự dừng khi không còn listener.
  @override
  void stop() {}

  /// Cleanup — EventChannelRiskSource không giữ tài nguyên cần release thủ công.
  @override
  void dispose() {
    debugPrint('[EventChannelRiskSource] disposed');
  }

  // ── Parsing ────────────────────────────────────────────────────────────────

  /// Parse Map từ Kotlin thành [RiskEvent].
  ///
  /// Dùng null-coalescing cho mọi field — nếu Kotlin gửi thiếu key,
  /// Dart dùng giá trị "an toàn" thay vì throw Exception.
  RiskEvent _parseEvent(Map<Object?, Object?> raw) {
    try {
      return RiskEvent(
        riskLevel: (raw['risk_level'] as int?) ?? 0,
        ttcSeconds: _toDouble(raw['ttc_seconds']) ?? 999.0,
        distanceM: _toDouble(raw['nearest_distance_m']) ?? 99.0,
        classId: (raw['nearest_class_id'] as int?) ?? 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (raw['timestamp_ms'] as int?) ?? 0,
        ),
      );
    } catch (e) {
      debugPrint('[EventChannelRiskSource] parse error: $e | raw=$raw');
      return RiskEvent.safe; // fallback an toàn
    }
  }

  /// Kotlin có thể gửi num (int hoặc double) → normalize về double.
  double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }
}
