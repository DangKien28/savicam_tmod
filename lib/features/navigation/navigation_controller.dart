import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/network/api_client.dart';
import '../../core/services/audio_haptic_manager.dart';

class NavigationController {
  final ApiClient _apiClient;
  final AudioHapticManager _audioHaptic;

  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String> currentInstruction = ValueNotifier<String>('Chưa có lộ trình');
  final List<String> routeSteps = [];
  int currentStepIndex = 0;

  NavigationController(this._apiClient, this._audioHaptic);

  /// Bắt đầu phân tích tìm đường bằng lệnh giọng nói
  Future<void> findPath(String destinationKeyword) async {
    isLoading.value = true;
    routeSteps.clear();
    currentStepIndex = 0;
    currentInstruction.value = 'Đang tìm kiếm lộ trình...';

    // Rung nhẹ khi bắt đầu tìm
    HapticFeedback.mediumImpact();

    try {
      // Gọi API định tuyến (giả lập hoặc gọi thật qua ApiClient)
      final response = await _apiClient.post('/api/v1/routing', {
        'destination': destinationKeyword,
        'current_lat': 21.0285,
        'current_lng': 105.8542
      });

      if (response == null) {
        // Fallback offline / Lỗi mạng
        _handleNetworkError();
        return;
      }

      // Giả lập đọc JSON thành công và bóc tách lộ trình
      routeSteps.addAll([
        'Bắt đầu di chuyển. Đi thẳng 100 mét hướng Nguyễn Trãi.',
        'Rẽ phải vào đường Lê Lợi, đi tiếp 200 mét.',
        'Bạn đã đến điểm hẹn.'
      ]);

      currentInstruction.value = routeSteps[0];
      
      // Rung phản hồi khi tìm thấy đường
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.lightImpact();

      await _audioHaptic.speakAlert('Đã tìm thấy lộ trình. ${routeSteps[0]}', priority: 2);
    } catch (_) {
      _handleNetworkError();
    } finally {
      isLoading.value = false;
    }
  }

  /// Chuyển tới hướng dẫn tiếp theo
  Future<void> nextStep() async {
    if (routeSteps.isEmpty) return;
    if (currentStepIndex < routeSteps.length - 1) {
      currentStepIndex++;
      currentInstruction.value = routeSteps[currentStepIndex];
      await _audioHaptic.speakAlert(routeSteps[currentStepIndex], priority: 2);
    } else {
      await _audioHaptic.speakAlert('Bạn đã đi hết lộ trình.', priority: 2);
    }
  }

  void _handleNetworkError() {
    currentInstruction.value = 'Lỗi kết nối';
    _audioHaptic.speakAlert('Không có kết nối mạng, vui lòng kiểm tra lại.', priority: 3);
  }
}
