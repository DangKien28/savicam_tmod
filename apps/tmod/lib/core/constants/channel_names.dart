/// SaViCam T-Mod — MethodChannel Name Constants
///
/// Centralizes all MethodChannel identifiers used for Flutter ↔ Native
/// communication. These names MUST match the Kotlin-side channel
/// registrations in `apps/tmod/android/.../channels/`.
///
/// See also: `docs/api_contracts/method_channels.md`
library;

class ChannelNames {
  ChannelNames._(); // Prevent instantiation

  /// Flutter ↔ TFLite inference bridge (YOLOv8n, MiniLM)
  /// Kotlin side: `InferenceChannel.kt`
  static const String inference = 'com.savicam.tmod/inference';

  /// Flutter ↔ IoU object tracker
  /// Kotlin side: `TrackingChannel.kt`
  static const String tracking = 'com.savicam.tmod/tracking';

  /// Flutter ↔ Android TTS/STT engine
  /// Kotlin side: `TtsSttChannel.kt`
  static const String ttsStt = 'com.savicam.tmod/tts_stt';

  /// Flutter ↔ Foreground Service lifecycle
  /// Kotlin side: `ServiceChannel.kt`
  static const String service = 'com.savicam.tmod/service';

  /// Flutter ↔ Headless Mode Manager
  /// Kotlin side: `HeadlessModeManager.kt`
  static const String headless = 'com.savicam.tmod/headless';

  /// EventChannel for hardware button events (volume/power)
  /// Used to toggle headless mode from physical buttons
  static const String hardwareButtonEvents =
      'com.savicam.tmod/hardware_button_events';
}
