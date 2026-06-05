/// SaViCam T-Mod — Navigation Mode Page
///
/// Mode 2: Di chuyển (Navigation)
/// Color: Blue (Cane Icon)
/// Interaction: Single tap → activate Microphone for voice commands
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/accessibility_theme.dart';

class NavigationModePage extends StatefulWidget {
  const NavigationModePage({super.key});

  @override
  State<NavigationModePage> createState() => _NavigationModePageState();
}

class _NavigationModePageState extends State<NavigationModePage> {
  bool _isListening = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chế độ Di chuyển. Chạm một lần để ra lệnh bằng giọng nói.',
      child: GestureDetector(
        onTap: () => _onSingleTap(context),
        behavior: HitTestBehavior.translucent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                SaViColors.navigationBlueDark,
                SaViColors.navigationBlue,
                SaViColors.navigationBlueLight,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),
                _buildModeIndicator(),
                const Spacer(),
                _buildInstructionArea(),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeIndicator() {
    return Column(
      children: [
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
          ),
          child: Icon(_isListening ? Icons.mic : Icons.blind, size: 48, color: SaViColors.textOnDark),
        ),
        const SizedBox(height: 16),
        const Text('Di chuyển', style: SaViTypography.modeTitle),
      ],
    );
  }

  Widget _buildInstructionArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(_isListening ? Icons.hearing : Icons.touch_app, size: 40, color: SaViColors.textOnDark),
            const SizedBox(height: 16),
            Text(
              _isListening ? 'Đang nghe... Nói lệnh của bạn' : 'Chạm để ra lệnh giọng nói',
              style: SaViTypography.modeInstruction, textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isListening ? 'Ví dụ: "Đưa tôi về nhà"' : 'Vuốt sang trái hoặc phải để đổi chế độ',
              style: SaViTypography.statusText, textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onSingleTap(BuildContext context) {
    HapticFeedback.mediumImpact();
    setState(() => _isListening = !_isListening);

    if (_isListening) {
      debugPrint('[NavigationMode] Microphone activated');
      // TODO(DEV-01): Wire to NativeBridge.startListening()
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted || !context.mounted) return;
        if (_isListening) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🗺️ Đã nhận: "Đưa tôi về nhà"', style: TextStyle(fontSize: 18)),
              backgroundColor: SaViColors.navigationBlueDark,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }
}
