/// SaViCam T-Mod — TTS Channel Wrapper
///
/// Provides a dedicated wrapper interface for Text-to-Speech (TTS) operations.
/// Delegates to the shared [NativeBridge] for platform communication.
///
/// See also: `shared/channel_wrappers/native_bridge.dart`
library;

import 'native_bridge.dart';

/// Controller specifically for Text-to-Speech functions.
class TtsChannel {
  final NativeBridge _bridge;

  const TtsChannel({required NativeBridge bridge}) : _bridge = bridge;

  /// Speaks the given [text] through the platform TTS engine.
  Future<void> speak(String text) async {
    await _bridge.speak(text);
  }

  /// Stops any current speech playback.
  Future<void> stopSpeaking() async {
    await _bridge.stopSpeaking();
  }
}
