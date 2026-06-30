import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

/// Quản lý TTS + Haptic với quyền tối cao Preemptive.
/// Mức 4 (Sinh Tử) có quyền NGẮT LẬP TỨC mọi luồng phát âm khác.
class AudioHapticManager {
  final FlutterTts _tts = FlutterTts();
  bool _isReady = false;
  bool _isSpeaking = false;
  int _currentPriority = 0; // 0 = idle, 1-4 = mức ưu tiên đang phát

  AudioHapticManager();

  Future<void> init() async {
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.85);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _currentPriority = 0;
    });
    _isReady = true;
  }

  /// Phát cảnh báo với ưu tiên preemptive.
  /// Nếu [priority] cao hơn luồng đang phát → NGẮT luồng cũ ngay lập tức.
  Future<void> speakAlert(String message, {required int priority}) async {
    if (!_isReady) await init();

    // Preemptive: ưu tiên cao hơn → ngắt luồng cũ
    if (_isSpeaking && priority <= _currentPriority) {
      return; // Luồng đang phát có ưu tiên bằng/cao hơn → bỏ qua
    }

    if (_isSpeaking) {
      await _tts.stop(); // NGẮT LẬP TỨC luồng cũ
    }

    _isSpeaking = true;
    _currentPriority = priority;
    await _tts.speak(message);
  }

  /// Kích hoạt rung theo mức rủi ro
  Future<void> triggerHaptic(int riskLevel) async {
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;

    switch (riskLevel) {
      case 1: // Chú ý
        await Vibration.vibrate(duration: 200);
        break;
      case 2: // Cảnh báo
        await Vibration.vibrate(pattern: [0, 400, 200, 400]);
        break;
      case 3: // Nguy hiểm
        await Vibration.vibrate(pattern: [0, 600, 150, 600, 150, 600]);
        break;
      case 4: // SINH TỬ - rung giật cục liên tục
        await Vibration.vibrate(pattern: [0, 1000, 80, 1000, 80, 1000, 80, 1000]);
        break;
    }
  }

  /// Cảnh báo đầy đủ: TTS + Haptic, preemptive
  Future<void> fireAlert(String message, int riskLevel) async {
    // Song song: rung + nói
    await Future.wait([
      triggerHaptic(riskLevel),
      speakAlert(message, priority: riskLevel),
    ]);
  }

  /// Dừng tất cả
  Future<void> stopAll() async {
    await _tts.stop();
    await Vibration.cancel();
    _isSpeaking = false;
    _currentPriority = 0;
  }
}
