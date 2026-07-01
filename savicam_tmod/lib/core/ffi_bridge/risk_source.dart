// risk_source.dart
//
// Abstraction layer cho nguồn dữ liệu risk-level.
// VisionAlertController KHÔNG biết implementation bên dưới là gì.
//
// Implementations:
//   - FfiPollingRiskSource  → production (Timer 33ms → tmod_process_frame)
//   - EventChannelRiskSource → test/debug (Kotlin EventChannel push)
//
// Thêm source mới: implements IRiskSource, đăng ký trong injection_container.dart.
// Không cần đụng vào VisionAlertController hay bất kỳ consumer nào.

/// Contract duy nhất giữa VisionAlertController và nguồn dữ liệu risk.
abstract interface class IRiskSource {
  /// Broadcast stream — nhiều listener safe (UI widget + logger đều có thể subscribe).
  ///
  /// Stream KHÔNG tự đóng trong normal operation.
  /// Khi source chết (native crash, hot reload), stream emit [done] event —
  /// consumer nên log và có thể reconnect hoặc hiển thị warning.
  Stream<RiskEvent> get riskStream;

  /// Kích hoạt source.
  /// - [FfiPollingRiskSource]: bắt đầu Timer.periodic(33ms).
  /// - [EventChannelRiskSource]: no-op (EventChannel tự bắt đầu khi listen).
  void start();

  /// Dừng source.
  /// - [FfiPollingRiskSource]: cancel Timer.
  /// - [EventChannelRiskSource]: no-op.
  void stop();

  /// Giải phóng tài nguyên — gọi khi lifecycle owner bị dispose.
  void dispose();
}

// =============================================================================
// RiskEvent — dữ liệu bất biến mỗi frame
// =============================================================================

/// Snapshot dữ liệu rủi ro từ 1 frame camera.
///
/// Khớp 1:1 với [FrameResult] từ C++ (xem c_structs.dart và ffi_data_contract_v1.md §4).
///
/// Risk scale (từ ffi_exports.h):
///   0 = SAFE      (An Toàn)      — im lặng
///   1 = ATTENTION (Chú Ý)        — đọc tên vật thể
///   2 = WARNING   (Cảnh Báo)     — beep + rung nhịp
///   3 = HIGH      (Nguy Hiểm Cao) — lệnh điều hướng + rung mạnh
///   4 = CRITICAL  (Sinh Tử)      — ghi đè tối cao, ngắt TTS, lệnh gắt
final class RiskEvent {
  /// Mức rủi ro 0–4 (xem bảng trên).
  final int riskLevel;

  /// Time-to-Collision của vật gần nhất (giây).
  /// `999.0` nếu không có vật cản hoặc không tính được.
  final double ttcSeconds;

  /// Khoảng cách vật cản gần nhất (mét).
  /// `99.0` nếu không có vật cản hoặc không tính được.
  final double distanceM;

  /// Class ID của vật cản gần nhất theo dataset 300 class.
  /// `0` = unknown sentinel (xem ClassTaxonomy.of(0)).
  final int classId;

  /// Thời điểm frame được xử lý.
  final DateTime timestamp;

  const RiskEvent({
    required this.riskLevel,
    required this.ttcSeconds,
    required this.distanceM,
    required this.classId,
    required this.timestamp,
  });

  /// Sentinel "an toàn" — dùng khi không có detection hoặc lúc khởi tạo.
  static final safe = RiskEvent(
    riskLevel: 0,
    ttcSeconds: 999.0,
    distanceM: 99.0,
    classId: 0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );

  @override
  String toString() =>
      'RiskEvent(level=$riskLevel, ttc=${ttcSeconds}s, dist=${distanceM}m, class=$classId)';
}
