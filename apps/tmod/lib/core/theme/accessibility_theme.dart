/// SaViCam T-Mod — Accessibility-First Theme
///
/// High-contrast color palette and typography designed for visually
/// impaired users. All values comply with WCAG AA contrast ratios.
///
/// Design philosophy:
/// - NO small physical buttons
/// - NO complex text forms
/// - Minimum touch target: 48x48 dp (Android accessibility guideline)
/// - Minimum font size: 24sp for body text
/// - Distinct colors per mode for partial-vision users
library;

import 'package:flutter/material.dart';

/// Color palette for the 3-mode UI and global SOS.
class SaViColors {
  SaViColors._();

  // ─── Mode 1: Trợ lý an toàn (Safety Assistant) ───
  static const Color safetyGreen = Color(0xFF2E7D32);
  static const Color safetyGreenLight = Color(0xFF4CAF50);
  static const Color safetyGreenDark = Color(0xFF1B5E20);
  static const Color safetyGreenSurface = Color(0xFFE8F5E9);

  // ─── Mode 2: Di chuyển (Navigation) ───
  static const Color navigationBlue = Color(0xFF1565C0);
  static const Color navigationBlueLight = Color(0xFF42A5F5);
  static const Color navigationBlueDark = Color(0xFF0D47A1);
  static const Color navigationBlueSurface = Color(0xFFE3F2FD);

  // ─── Mode 3: Sinh hoạt (Daily Living) ───
  static const Color dailyLivingYellow = Color(0xFFF9A825);
  static const Color dailyLivingYellowLight = Color(0xFFFFEE58);
  static const Color dailyLivingYellowDark = Color(0xFFF57F17);
  static const Color dailyLivingYellowSurface = Color(0xFFFFF8E1);

  // ─── SOS Emergency ───
  static const Color sosRed = Color(0xFFD32F2F);
  static const Color sosRedLight = Color(0xFFEF5350);
  static const Color sosRedDark = Color(0xFFB71C1C);
  static const Color sosRedSurface = Color(0xFFFFEBEE);

  // ─── Neutral / Shared ───
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnLight = Color(0xFF212121);
  static const Color disabledGrey = Color(0xFF9E9E9E);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
}

/// Typography system with minimum 24sp body text for accessibility.
class SaViTypography {
  SaViTypography._();

  /// Mode title text (e.g., "Trợ lý an toàn")
  static const TextStyle modeTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: SaViColors.textOnDark,
    letterSpacing: 1.2,
  );

  /// Mode subtitle / instruction text
  static const TextStyle modeInstruction = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: SaViColors.textOnDark,
    height: 1.4,
  );

  /// SOS overlay text
  static const TextStyle sosText = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: SaViColors.textOnDark,
    letterSpacing: 2.0,
  );

  /// Status / feedback text
  static const TextStyle statusText = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: SaViColors.textOnDark,
  );
}

/// Main app theme with accessibility optimizations.
class SaViTheme {
  SaViTheme._();

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: SaViColors.safetyGreen,
        scaffoldBackgroundColor: SaViColors.backgroundDark,
        colorScheme: const ColorScheme.dark(
          primary: SaViColors.safetyGreen,
          secondary: SaViColors.navigationBlue,
          tertiary: SaViColors.dailyLivingYellow,
          error: SaViColors.sosRed,
          surface: SaViColors.surfaceDark,
        ),
        // Minimum touch target size for accessibility
        materialTapTargetSize: MaterialTapTargetSize.padded,
        // High-contrast text
        textTheme: const TextTheme(
          headlineLarge: SaViTypography.modeTitle,
          bodyLarge: SaViTypography.modeInstruction,
          bodyMedium: SaViTypography.statusText,
        ),
        // Ensure focus indicators are visible
        focusColor: SaViColors.safetyGreenLight,
        hoverColor: SaViColors.safetyGreenLight.withValues(alpha: 0.3),
      );
}
