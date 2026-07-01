import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/ffi_bridge/risk_source.dart';
import '../../core/services/audio_haptic_manager.dart';
import '../../core/ffi_bindings/class_taxonomy.dart';

/// Lắng nghe [IRiskSource] và kích hoạt cảnh báo Mức 0–4.
///
/// Controller KHÔNG biết nguồn dữ liệu là FFI polling hay EventChannel —
/// chỉ subscribe [IRiskSource.riskStream]. Swap source bằng DI config.
///
/// Lifecycle (gọi từ EssentialScreen hoặc HeadlessService):
///   startProcessing() → subscribe stream → nhận RiskEvent → TTS + rung + UI
///   stopProcessing()  → cancel subscription → dừng source nếu cần
///
/// Risk scale (khớp ffi_data_contract_v1.md §4):
///   0 = SAFE      (An Toàn)       — im lặng
///   1 = ATTENTION (Chú Ý)         — đọc tên vật thể + khoảng cách
///   2 = WARNING   (Cảnh Báo)      — beep ngắn + rung nhịp đều
///   3 = HIGH      (Nguy Hiểm Cao) — lệnh điều hướng dứt khoát + rung mạnh
///   4 = CRITICAL  (Sinh Tử)       — ghi đè tối cao, ngắt TTS, lệnh gắt
class VisionAlertController {
  final IRiskSource _source;
  final AudioHapticManager _audioHaptic;

  StreamSubscription<RiskEvent>? _subscription;

  // ── State — UI lắng nghe trực tiếp qua ValueListenableBuilder ─────────────

  final ValueNotifier<String> currentStatus   = ValueNotifier<String>('Đang quét...');
  final ValueNotifier<double> lastDistance     = ValueNotifier<double>(0.0);
  final ValueNotifier<int>    currentRiskLevel = ValueNotifier<int>(0);

  VisionAlertController(this._source, this._audioHaptic);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Bắt đầu xử lý — source được kích hoạt, stream được subscribe.
  ///
  /// Idempotent: gọi nhiều lần không tạo duplicate subscription.
  void startProcessing() {
    if (_subscription != null) return;

    // Delegate start() cho source:
    //   FfiPollingRiskSource → khởi Timer.periodic(33ms)
    //   EventChannelRiskSource → no-op
    _source.start();

    _subscription = _source.riskStream.listen(
      _onRiskEvent,
      onError: (Object e, StackTrace st) {
        debugPrint('[VisionAlertController] stream error: $e\n$st');
        // Không rethrow — tiếp tục nhận event nếu stream chưa đóng
      },
      onDone: () {
        debugPrint('[VisionAlertController] stream closed — source dead. '
            'Kiểm tra native side (C++ crash, hot reload?).');
        // Reset UI về trạng thái "không xác định" khi source chết
        currentStatus.value = 'Mất kết nối nguồn';
      },
    );
  }

  /// Dừng xử lý — cancel subscription, dừng source.
  void stopProcessing() {
    _subscription?.cancel();
    _subscription = null;
    _source.stop(); // FfiPollingRiskSource: cancel Timer; EventChannelRiskSource: no-op
  }

  // ── Event handler ──────────────────────────────────────────────────────────

  void _onRiskEvent(RiskEvent event) {
    _updateUiState(event.riskLevel, event.distanceM);

    if (event.riskLevel > 0) {
      _handleRisk(
        riskLevel: event.riskLevel,
        distance: event.distanceM,
        ttc: event.ttcSeconds,
        classId: event.classId,
      );
    }
  }

  // ── UI state ───────────────────────────────────────────────────────────────

  void _updateUiState(int level, double distance) {
    currentRiskLevel.value = level;
    lastDistance.value = distance;
    currentStatus.value = _riskLabel(level);
  }

  static String _riskLabel(int level) => switch (level) {
    0 => 'An toàn',
    1 => 'Chú ý',
    2 => 'Cảnh báo',
    3 => 'Nguy hiểm',
    4 => 'Sinh tử',
    _ => 'Không xác định',
  };

  // ── Alert generation ───────────────────────────────────────────────────────

  /// Tạo thông báo TTS có tên vật thể từ [ClassTaxonomy].
  /// Preemptive: mức cao hơn tự động ngắt mức thấp hơn qua [AudioHapticManager].
  Future<void> _handleRisk({
    required int riskLevel,
    required double distance,
    required double ttc,
    required int classId,
  }) async {
    final label   = ClassTaxonomy.of(classId);
    final objName = label.ttsName;
    final distStr = distance >= 0 && distance < 90
        ? 'cách ${distance.toStringAsFixed(1)} mét'
        : '';

    final String msg = switch (riskLevel) {
      1 => '$objName phía trước${distStr.isNotEmpty ? ', $distStr' : ''}.',
      2 => 'Cảnh báo. $objName gần $distStr.',
      3 => 'Nguy hiểm! $objName rất gần${distStr.isNotEmpty ? ", $distStr" : ""}!',
      4 => 'Nguy hiểm cực độ! $objName! Dừng lại ngay!',
      _ => '',
    };

    if (msg.isEmpty) return;

    await _audioHaptic.fireAlert(msg, riskLevel);
  }
}
