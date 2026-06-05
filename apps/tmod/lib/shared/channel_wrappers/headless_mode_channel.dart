/// SaViCam T-Mod — Headless Mode Channel Wrapper
///
/// Dart-side implementation for headless mode toggling.
/// Listens to hardware volume/power buttons via [EventChannel] and
/// translates button events into headless mode toggle commands.
///
/// Architecture:
/// - Kotlin side: `HeadlessModeManager.kt` intercepts volume button presses
/// - Flutter side: this class listens to the event stream and updates state
///
/// Headless Mode: CV + NLP pipelines continue running with screen off.
/// The user toggles this via a specific volume button pattern.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'native_bridge.dart';

/// Button event identifiers from Kotlin [HeadlessModeManager].
class HardwareButtonEvent {
  HardwareButtonEvent._();

  /// Volume-up button pressed
  static const String volumeUp = 'VOLUME_UP';

  /// Volume-down button pressed
  static const String volumeDown = 'VOLUME_DOWN';

  /// Power button pressed (short press)
  static const String powerShort = 'POWER_SHORT';

  /// Special combo: both volume buttons pressed simultaneously
  /// This is the default trigger for headless mode toggle.
  static const String volumeCombo = 'VOLUME_COMBO';
}

/// Manages headless mode state and listens for hardware button triggers.
///
/// Usage:
/// ```dart
/// final headless = HeadlessModeController(bridge: nativeBridge);
/// headless.isActive.listen((active) => print('Headless: $active'));
/// headless.startListening();
/// ```
class HeadlessModeController {
  final NativeBridge _bridge;

  StreamSubscription<String>? _buttonSubscription;
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();

  bool _isActive = false;

  HeadlessModeController({required NativeBridge bridge}) : _bridge = bridge;

  /// Stream of headless mode state changes.
  Stream<bool> get isActive => _stateController.stream;

  /// Current headless mode state (synchronous).
  bool get currentState => _isActive;

  /// Starts listening for hardware button events.
  /// Call this when the app starts or resumes.
  void startListening() {
    _buttonSubscription?.cancel();
    _buttonSubscription = _bridge.hardwareButtonEvents.listen(
      _handleButtonEvent,
      onError: (error) {
        debugPrint('[HeadlessMode] Button event stream error: $error');
      },
    );

    // Sync initial state from native side
    _syncState();
  }

  /// Stops listening for hardware button events.
  /// Call this when the app is disposed.
  void stopListening() {
    _buttonSubscription?.cancel();
    _buttonSubscription = null;
  }

  /// Handles a hardware button event from the native side.
  Future<void> _handleButtonEvent(String event) async {
    debugPrint('[HeadlessMode] Button event: $event');

    // Toggle headless mode on volume combo (both volume buttons)
    if (event == HardwareButtonEvent.volumeCombo) {
      await toggle();
    }
  }

  /// Manually toggle headless mode.
  Future<bool> toggle() async {
    try {
      _isActive = await _bridge.toggleHeadlessMode();
      _stateController.add(_isActive);
      debugPrint('[HeadlessMode] Toggled to: $_isActive');
      return _isActive;
    } catch (e) {
      debugPrint('[HeadlessMode] Toggle error: $e');
      return _isActive;
    }
  }

  /// Syncs the current state from the native side.
  Future<void> _syncState() async {
    try {
      _isActive = await _bridge.isHeadlessModeActive();
      _stateController.add(_isActive);
    } catch (e) {
      debugPrint('[HeadlessMode] State sync error: $e');
    }
  }

  /// Disposes all resources.
  void dispose() {
    stopListening();
    _stateController.close();
  }
}
