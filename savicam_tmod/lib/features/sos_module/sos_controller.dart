import 'dart:convert';
import '../../core/local_db/sqlite_helper.dart';
import '../../core/local_db/entities/offline_queue_item.dart';
import '../../core/network/api_client.dart';
import '../../core/services/audio_haptic_manager.dart';
import '../../core/services/location_service.dart';

/// Module SOS: Báo động đỏ khẩn cấp, cloud-first / offline-fallback
class SosController {
  final ApiClient _api;
  final LocationService _location;
  final AudioHapticManager _audioHaptic;

  SosController(this._api, this._location, this._audioHaptic);

  /// Kích hoạt SOS - Mức cảnh báo tối đa (4 - Sinh tử)
  Future<void> triggerSos({required String reason}) async {
    // 1. Phát cảnh báo ngay lập tức (preemptive mức 4)
    await _audioHaptic.fireAlert('Đã kích hoạt báo động đỏ SOS!', 4);

    // 2. Lấy vị trí GPS
    final pos = await _location.getCurrentPosition();

    final payload = {
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': pos?.latitude ?? 0.0,
      'longitude': pos?.longitude ?? 0.0,
      'reason': reason,
      'status': 'SOS_RED_ALERT',
    };

    // 3. Cloud-first: gửi lên server
    final result = await _api.post('/api/v1/sos', payload);

    // 4. Offline-fallback: nếu thất bại → lưu vào hàng đợi
    if (result == null) {
      await SqliteHelper.instance.enqueue(OfflineQueueItem(
        endpoint: '/api/v1/sos',
        payloadJson: json.encode(payload),
        createdAt: DateTime.now().toIso8601String(),
      ));
    }
  }
}
