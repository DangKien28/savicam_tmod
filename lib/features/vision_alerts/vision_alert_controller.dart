import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../../core/ffi_bindings/c_structs.dart';
import '../../core/ffi_bindings/native_library.dart';
import '../../core/services/audio_haptic_manager.dart';

/// Lắng nghe kết quả FFI từ C++ pipeline và kích hoạt cảnh báo Mức 1-4.
/// Chạy trong Isolate/Timer loop khi ở Headless Mode.
class VisionAlertController {
  final NativeLibrary _native;
  final AudioHapticManager _audioHaptic;
  Timer? _frameLoop;

  // Trạng thái được bóc tách ra để UI lắng nghe trực tiếp
  final ValueNotifier<String> currentStatus = ValueNotifier<String>('Đang quét...');
  final ValueNotifier<double> lastDistance = ValueNotifier<double>(0.0);
  final ValueNotifier<int> currentRiskLevel = ValueNotifier<int>(0);

  VisionAlertController(this._native, this._audioHaptic);

  /// Bắt đầu vòng lặp xử lý frame (gọi từ Headless Mode)
  void startProcessing() {
    _frameLoop = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _processOneFrame();
    });
  }

  void stopProcessing() {
    _frameLoop?.cancel();
    _frameLoop = null;
  }

  void _processOneFrame() {
    final resultPtr = calloc<FrameResult>();

    try {
      // Gọi C++ pipeline qua FFI
      // TODO: Thay dummyFrame bằng camera frame thực tế
      final status = _native.processFrame(nullptr, 0, 0, resultPtr);
      if (status != 1) return;

      final result = resultPtr.ref;
      
      // Cập nhật trạng thái cho UI thông báo
      _updateStatus(result.riskLevel, result.nearestDistanceM);

      if (result.riskLevel > 0) {
        _handleRisk(result.riskLevel, result.nearestDistanceM, result.ttcSeconds);
      }
    } finally {
      calloc.free(resultPtr);
    }
  }

  void _updateStatus(int level, double distance) {
    currentRiskLevel.value = level;
    lastDistance.value = distance;
    switch (level) {
      case 0:
        currentStatus.value = 'An toàn';
        break;
      case 1:
        currentStatus.value = 'Chú ý';
        break;
      case 2:
        currentStatus.value = 'Cảnh báo';
        break;
      case 3:
        currentStatus.value = 'Nguy hiểm';
        break;
      case 4:
        currentStatus.value = 'Sinh tử';
        break;
      default:
        currentStatus.value = 'Chưa xác định';
    }
  }

  /// Xử lý cảnh báo theo mức rủi ro - Preemptive
  Future<void> _handleRisk(int level, double distance, double ttc) async {
    String msg;
    switch (level) {
      case 1:
        msg = 'Có vật cản cách ${distance.toStringAsFixed(1)} mét.';
        break;
      case 2:
        msg = 'Cảnh báo. Vật cản ở gần, khoảng cách ${distance.toStringAsFixed(1)} mét.';
        break;
      case 3:
        msg = 'Nguy hiểm! Vật cản rất gần, ${distance.toStringAsFixed(1)} mét!';
        break;
      case 4:
        msg = 'Nguy hiểm cực độ! Dừng lại ngay!';
        break;
      default:
        return;
    }

    // fireAlert tự xử lý preemptive (mức cao hơn ngắt mức thấp hơn)
    await _audioHaptic.fireAlert(msg, level);
  }
}
