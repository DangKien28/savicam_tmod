// ffi_polling_risk_source.dart
//
// Production implementation của IRiskSource.
// Sử dụng Timer.periodic(33ms) để poll tmod_process_frame() qua Dart FFI.
//
// Khi Huỳnh Minh Tiến hoàn thiện C++ core (yolov8n_engine + ttc_calculator),
// class này TỰ NHIÊN nhận được kết quả thật mà KHÔNG cần thay đổi kiến trúc.
// Chỉ cần thay nullptr bằng camera frame thực (xem TODO bên dưới).

import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../ffi_bindings/c_structs.dart';
import '../ffi_bindings/native_library.dart';
import 'risk_source.dart';

/// FFI polling implementation của [IRiskSource].
///
/// Vòng lặp 33ms (~30 FPS) gọi [NativeLibrary.processFrame] và emit [RiskEvent]
/// vào broadcast stream. [VisionAlertController] subscribe stream này mà không
/// biết chi tiết về FFI hay Timer.
///
/// Thread safety: Timer callback chạy trên Dart main isolate — an toàn cho
/// ValueNotifier và setState(). Nếu chuyển sang Isolate riêng, cần SendPort.
class FfiPollingRiskSource implements IRiskSource {
  final NativeLibrary _native;
  final StreamController<RiskEvent> _ctrl;

  Timer? _timer;

  FfiPollingRiskSource(this._native)
      : _ctrl = StreamController<RiskEvent>.broadcast();

  @override
  Stream<RiskEvent> get riskStream => _ctrl.stream;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void start() {
    if (_timer != null) return; // idempotent — gọi nhiều lần không sao
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => _poll());
    debugPrint('[FfiPollingRiskSource] started @ 33ms interval');
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('[FfiPollingRiskSource] stopped');
  }

  @override
  void dispose() {
    stop();
    _ctrl.close();
    debugPrint('[FfiPollingRiskSource] disposed');
  }

  // ── Polling logic ──────────────────────────────────────────────────────────

  void _poll() {
    if (_ctrl.isClosed) return;

    final resultPtr = calloc<FrameResult>();
    try {
      // TODO(integration — Nguyễn Trung Kiên): Thay [nullptr] bằng camera frame thực
      // khi tích hợp CameraController (xem camera isolate design §8 của contract).
      //
      // C++ stub HIỆN TẠI không dereference rgba_data → an toàn truyền nullptr.
      // Khi Tiến bổ sung implementation thật, PHẢI check null trước dereference:
      //   if (!rgba_data || !result) { LOGE(...); return 0; }
      // Nếu bỏ sót → crash native im lặng mà không có stack trace Dart.
      final status = _native.processFrame(nullptr, 0, 0, resultPtr);

      // status != 1 → C++ báo lỗi (chưa init hoặc null pointer) → skip frame
      // finally vẫn chạy → không leak
      if (status != 1) return;

      final r = resultPtr.ref;

      _ctrl.add(RiskEvent(
        riskLevel: r.riskLevel,
        ttcSeconds: r.ttcSeconds,
        distanceM: r.nearestDistanceM,
        classId: r.nearestClassId,
        timestamp: DateTime.now(),
      ));
    } catch (e, st) {
      // Lỗi FFI hiếm gặp (ví dụ native .so crash) — log không crash Dart app
      debugPrint('[FfiPollingRiskSource] poll error: $e\n$st');
    } finally {
      // Chạy kể cả khi return sớm (status != 1) — đảm bảo không memory leak
      calloc.free(resultPtr);
    }
  }
}
