/// SaViCam T-Mod — SOS Trigger Constants
///
/// Defines the exact timing and layout constraints for the Global SOS
/// trigger system. These values are safety-critical and must not be
/// modified without team review.
///
/// Design rationale:
/// - Minimum 3 seconds prevents accidental triggers from pocket touches
/// - Maximum 5 seconds prevents confused users from holding indefinitely
/// - 50% bottom zone provides a large, easy-to-find target area
library;

class SosConstants {
  SosConstants._(); // Prevent instantiation

  /// Minimum hold duration to trigger SOS.
  /// User must hold for AT LEAST this long.
  /// Anti-accidental-touch: any release before 3s cancels the SOS.
  static const Duration minHoldDuration = Duration(seconds: 3);

  /// Maximum hold duration — SOS auto-fires at this point.
  /// Prevents user confusion from holding indefinitely.
  static const Duration maxHoldDuration = Duration(seconds: 5);

  /// Fraction of screen height reserved for the SOS touch zone.
  /// Measured from the BOTTOM of the screen upward.
  /// 0.5 = bottom 50% of screen is the SOS zone.
  static const double zoneHeightFraction = 0.5;

  /// Duration of haptic pulse pattern during SOS hold (milliseconds).
  /// Pattern: [wait, vibrate, wait, vibrate, ...]
  static const List<int> holdHapticPattern = [0, 200, 100, 200];

  /// Duration of continuous vibration when SOS is triggered (ms).
  static const int triggeredVibrationDuration = 1000;

  /// Delay before TTS announces "Đang giữ SOS" during hold.
  static const Duration ttsAnnouncementDelay = Duration(seconds: 1);

  /// TTS message when SOS hold begins (after [ttsAnnouncementDelay]).
  static const String holdAnnouncementVi = 'Đang giữ S.O.S. Thả tay để hủy.';

  /// TTS message when SOS is successfully triggered.
  static const String triggeredAnnouncementVi =
      'S.O.S đã được gửi. Người giám hộ sẽ được thông báo.';

  /// TTS message when SOS hold is cancelled (released too early).
  static const String cancelledAnnouncementVi = 'Đã hủy S.O.S.';
}
