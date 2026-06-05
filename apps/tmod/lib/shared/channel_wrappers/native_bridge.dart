/// SaViCam T-Mod — Native Bridge (MethodChannel Wrapper)
///
/// Central abstraction layer for all Flutter ↔ Native (Kotlin) communication.
/// Provides a mockable interface for testing without a real Android device.
///
/// Architecture:
/// - Production: calls real MethodChannels registered in Kotlin `channels/`
/// - Testing: uses [MockNativeBridge] with predetermined responses
///
/// See also: `docs/api_contracts/method_channels.md`
/// See also: ARCH-07 (Stub-First Mandate)
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/constants/channel_names.dart';

/// Abstract interface for native platform communication.
/// Implement this to create mock versions for testing.
abstract class NativeBridge {
  // ─── TTS / STT ───

  /// Speaks the given [text] through Android TTS engine.
  /// Uses Vietnamese locale by default.
  Future<void> speak(String text);

  /// Stops any current TTS playback immediately.
  /// Used by Preemptive Interrupt System for Level 1 alerts.
  Future<void> stopSpeaking();

  /// Starts speech recognition and returns the transcribed text.
  Future<String?> startListening();

  /// Stops speech recognition.
  Future<void> stopListening();

  // ─── Foreground Service ───

  /// Starts the SaViCam Foreground Service.
  /// Keeps CV and NLP pipelines alive with screen off.
  Future<bool> startForegroundService();

  /// Stops the Foreground Service.
  Future<bool> stopForegroundService();

  // ─── Headless Mode ───

  /// Toggles headless mode on/off.
  /// Updates `is_headless_active` telemetry to cloud.
  Future<bool> toggleHeadlessMode();

  /// Returns current headless mode state.
  Future<bool> isHeadlessModeActive();

  /// Stream of hardware button events for headless mode toggle.
  Stream<String> get hardwareButtonEvents;

  // ─── Inference ───

  /// Loads a TFLite model from the given [modelPath].
  Future<bool> loadModel(String modelPath);

  /// Runs inference on the current camera frame.
  /// Returns a list of detection results as JSON maps.
  Future<List<Map<String, dynamic>>> runInference();
}

/// Production implementation using real MethodChannels.
class PlatformNativeBridge implements NativeBridge {
  final MethodChannel _ttsSttChannel =
      const MethodChannel(ChannelNames.ttsStt);
  final MethodChannel _serviceChannel =
      const MethodChannel(ChannelNames.service);
  final MethodChannel _headlessChannel =
      const MethodChannel(ChannelNames.headless);
  final MethodChannel _inferenceChannel =
      const MethodChannel(ChannelNames.inference);
  final EventChannel _buttonEventChannel =
      const EventChannel(ChannelNames.hardwareButtonEvents);

  @override
  Future<void> speak(String text) async {
    try {
      await _ttsSttChannel.invokeMethod('speak', {'text': text});
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] TTS speak error: ${e.message}');
    }
  }

  @override
  Future<void> stopSpeaking() async {
    try {
      await _ttsSttChannel.invokeMethod('stopSpeaking');
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] TTS stop error: ${e.message}');
    }
  }

  @override
  Future<String?> startListening() async {
    try {
      final result =
          await _ttsSttChannel.invokeMethod<String>('startListening');
      return result;
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] STT start error: ${e.message}');
      return null;
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _ttsSttChannel.invokeMethod('stopListening');
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] STT stop error: ${e.message}');
    }
  }

  @override
  Future<bool> startForegroundService() async {
    try {
      final result =
          await _serviceChannel.invokeMethod<bool>('startService') ?? false;
      return result;
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] Service start error: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> stopForegroundService() async {
    try {
      final result =
          await _serviceChannel.invokeMethod<bool>('stopService') ?? false;
      return result;
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] Service stop error: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> toggleHeadlessMode() async {
    try {
      final result =
          await _headlessChannel.invokeMethod<bool>('toggleHeadless') ?? false;
      return result;
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] Headless toggle error: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> isHeadlessModeActive() async {
    try {
      final result =
          await _headlessChannel.invokeMethod<bool>('isHeadlessActive') ??
              false;
      return result;
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] Headless query error: ${e.message}');
      return false;
    }
  }

  @override
  Stream<String> get hardwareButtonEvents {
    return _buttonEventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
  }

  @override
  Future<bool> loadModel(String modelPath) async {
    try {
      final result = await _inferenceChannel
              .invokeMethod<bool>('loadModel', {'path': modelPath}) ??
          false;
      return result;
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] Model load error: ${e.message}');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> runInference() async {
    try {
      final result =
          await _inferenceChannel.invokeMethod<List>('runInference');
      if (result == null) return [];
      return result.cast<Map<String, dynamic>>();
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] Inference error: ${e.message}');
      return [];
    }
  }
}

/// Mock implementation for testing and development without a real device.
///
/// Usage in tests:
/// ```dart
/// final bridge = MockNativeBridge();
/// bridge.speakCallback = (text) => print('TTS: $text');
/// ```
class MockNativeBridge implements NativeBridge {
  /// Callback invoked when [speak] is called. Useful for test assertions.
  void Function(String text)? speakCallback;

  /// Controls what [startListening] returns.
  String? nextListeningResult;

  /// Controls what [isHeadlessModeActive] returns.
  bool headlessState = false;

  /// Controls what [runInference] returns.
  List<Map<String, dynamic>> mockDetections = [];

  final StreamController<String> _buttonController =
      StreamController<String>.broadcast();

  @override
  Future<void> speak(String text) async {
    debugPrint('[MockNativeBridge] TTS: $text');
    speakCallback?.call(text);
  }

  @override
  Future<void> stopSpeaking() async {
    debugPrint('[MockNativeBridge] TTS stopped');
  }

  @override
  Future<String?> startListening() async {
    debugPrint('[MockNativeBridge] STT listening...');
    // Simulate a small delay for realistic behavior
    await Future.delayed(const Duration(milliseconds: 500));
    return nextListeningResult ?? 'Đưa tôi về nhà';
  }

  @override
  Future<void> stopListening() async {
    debugPrint('[MockNativeBridge] STT stopped');
  }

  @override
  Future<bool> startForegroundService() async {
    debugPrint('[MockNativeBridge] Foreground service started');
    return true;
  }

  @override
  Future<bool> stopForegroundService() async {
    debugPrint('[MockNativeBridge] Foreground service stopped');
    return true;
  }

  @override
  Future<bool> toggleHeadlessMode() async {
    headlessState = !headlessState;
    debugPrint('[MockNativeBridge] Headless mode: $headlessState');
    return headlessState;
  }

  @override
  Future<bool> isHeadlessModeActive() async => headlessState;

  @override
  Stream<String> get hardwareButtonEvents => _buttonController.stream;

  /// Simulate a hardware button press for testing.
  void simulateButtonPress(String buttonId) {
    _buttonController.add(buttonId);
  }

  @override
  Future<bool> loadModel(String modelPath) async {
    debugPrint('[MockNativeBridge] Model loaded: $modelPath');
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> runInference() async {
    if (mockDetections.isNotEmpty) return mockDetections;
    // Default stub detections per STUB-1 spec
    return [
      {
        'class_id': 0,
        'class_label': 'motorcycle',
        'confidence': 0.92,
        'bbox': {'x': 0.3, 'y': 0.4, 'w': 0.2, 'h': 0.3},
        'estimated_distance_m': 2.5,
        'ttc_level': 2,
      },
    ];
  }

  /// Disposes the button event stream controller.
  void dispose() {
    _buttonController.close();
  }
}
