import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/network/api_client.dart';
import '../../core/services/audio_haptic_manager.dart';

class CloudRecognitionController {
  final ApiClient _apiClient;
  final AudioHapticManager _audioHaptic;

  final ValueNotifier<bool> isProcessing = ValueNotifier<bool>(false);
  final ValueNotifier<String> lastResult = ValueNotifier<String>('Chưa có kết quả');

  CloudRecognitionController(this._apiClient, this._audioHaptic);

  /// Chụp ảnh và gửi lên Cloud Server (LocateAnything-3B) để nhận dạng
  Future<void> captureAndRecognize() async {
    isProcessing.value = true;
    lastResult.value = 'Đang nhận dạng...';

    // Rung nhẹ xác nhận đã chụp
    HapticFeedback.mediumImpact();

    // Thông báo cho người dùng
    await _audioHaptic.speakAlert('Đang đợi kết quả nhận diện.', priority: 2);

    try {
      // Giả lập gửi ảnh (dạng base64 hoặc dummy payload) lên Cloud AI Server
      final response = await _apiClient.post('/api/v1/recognize', {
        'image_data': 'dummy_base64_string',
        'model': 'LocateAnything-3B'
      });

      if (response == null) {
        _handleNetworkError();
        return;
      }

      // Giả lập kết quả trả về từ Cloud Server
      final detectedObject = response['object'] ?? 'Tờ tiền 500 nghìn đồng';
      final double confidence = (response['confidence'] as num?)?.toDouble() ?? 0.95;
      final int percent = (confidence * 100).toInt();

      final announceMsg = 'Đã nhận diện: $detectedObject với độ tin cậy $percent phần trăm.';
      lastResult.value = announceMsg;

      // Rung phản hồi thành công
      HapticFeedback.lightImpact();
      await _audioHaptic.speakAlert(announceMsg, priority: 2);
    } catch (_) {
      _handleNetworkError();
    } finally {
      isProcessing.value = false;
    }
  }

  void _handleNetworkError() {
    lastResult.value = 'Lỗi kết nối';
    _audioHaptic.speakAlert('Không có kết nối mạng, vui lòng kiểm tra lại.', priority: 3);
  }
}
