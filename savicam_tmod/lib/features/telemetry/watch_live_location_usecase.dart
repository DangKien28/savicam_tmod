import 'dart:async';
import 'package:flutter/foundation.dart';
import 'location_tracking_repository.dart';

/// Usecase xử lý logic đồng bộ live location & telemetry tới Relap
class WatchLiveLocationUsecase {
  final LocationTrackingRepository _repository;
  Timer? _telemetryTimer;

  WatchLiveLocationUsecase(this._repository);

  /// Bắt đầu gửi telemetry định kỳ (mặc định 10s/lần)
  void startTracking({Duration interval = const Duration(seconds: 10)}) {
    if (_telemetryTimer != null && _telemetryTimer!.isActive) {
      return;
    }

    debugPrint('[WatchLiveLocationUsecase] Bắt đầu đồng bộ Telemetry tới Relap...');
    _telemetryTimer = Timer.periodic(interval, (_) async {
      try {
        await _repository.pushTelemetry();
      } catch (e) {
        debugPrint('[WatchLiveLocationUsecase] Lỗi đồng bộ Telemetry: $e');
      }
    });
  }

  /// Dừng việc đồng bộ
  void stopTracking() {
    if (_telemetryTimer?.isActive ?? false) {
      _telemetryTimer?.cancel();
      _telemetryTimer = null;
      debugPrint('[WatchLiveLocationUsecase] Đã dừng đồng bộ Telemetry tới Relap.');
    }
  }
}
