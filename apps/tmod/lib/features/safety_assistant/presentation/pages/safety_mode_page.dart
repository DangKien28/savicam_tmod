/// SaViCam T-Mod — Safety Mode Page
///
/// Mode 1: Trợ lý an toàn (Safety Assistant)
/// - Color: Green (Shield Icon)
/// - Interaction: Single tap → read the last safety alert via TTS
///
/// This is the default landing mode when the app starts.
/// It provides real-time obstacle warnings through audio feedback.
///
/// Architecture: Tier 1 — Full Clean Architecture + BLoC
/// (The safety BLoC is not implemented in this phase; using stub data)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/accessibility_theme.dart';

/// Safety Assistant mode page.
///
/// Takes up the full screen. The bottom 50% is overlaid by
/// [SosOverlayWidget] which is positioned in the parent [Stack].
class SafetyModePage extends StatelessWidget {
  const SafetyModePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chế độ Trợ lý an toàn. Chạm một lần để nghe cảnh báo.',
      child: GestureDetector(
        onTap: () => _onSingleTap(context),
        behavior: HitTestBehavior.translucent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                SaViColors.safetyGreenDark,
                SaViColors.safetyGreen,
                SaViColors.safetyGreenLight,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),

                // ─── Mode indicator ───
                _buildModeIndicator(),

                const Spacer(),

                // ─── Central instruction area (in top 50%) ───
                _buildInstructionArea(),

                // Leave space for SOS zone (bottom 50%)
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mode indicator with icon and title.
  Widget _buildModeIndicator() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.shield,
            size: 48,
            color: SaViColors.textOnDark,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Trợ lý an toàn',
          style: SaViTypography.modeTitle,
        ),
      ],
    );
  }

  /// Central area showing the last alert or instructions.
  Widget _buildInstructionArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.touch_app,
              size: 40,
              color: SaViColors.textOnDark,
            ),
            SizedBox(height: 16),
            Text(
              'Chạm để nghe cảnh báo',
              style: SaViTypography.modeInstruction,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Vuốt sang phải để chuyển chế độ',
              style: SaViTypography.statusText,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Handles single tap — reads the last safety alert via TTS.
  void _onSingleTap(BuildContext context) {
    HapticFeedback.mediumImpact();

    // TODO(DEV-01): Wire to NativeBridge.speak() with last alert
    // For MVP stub: announce a static message
    debugPrint('[SafetyMode] Single tap — reading last alert');

    // Show visual feedback for sighted testers
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '🛡️ Không có cảnh báo. Đường đi an toàn.',
          style: TextStyle(fontSize: 18),
        ),
        backgroundColor: SaViColors.safetyGreenDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
