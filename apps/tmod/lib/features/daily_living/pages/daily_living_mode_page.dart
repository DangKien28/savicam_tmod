/// SaViCam T-Mod — Daily Living Mode Page
///
/// Mode 3: Sinh hoạt (Daily Living)
/// Color: Yellow (Camera Icon)
/// Interaction: Double tap → trigger OCR photo capture
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/accessibility_theme.dart';

class DailyLivingModePage extends StatefulWidget {
  const DailyLivingModePage({super.key});

  @override
  State<DailyLivingModePage> createState() => _DailyLivingModePageState();
}

class _DailyLivingModePageState extends State<DailyLivingModePage> {
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chế độ Sinh hoạt. Chạm hai lần để chụp ảnh và đọc chữ.',
      child: GestureDetector(
        onDoubleTap: () => _onDoubleTap(context),
        behavior: HitTestBehavior.translucent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                SaViColors.dailyLivingYellowDark,
                SaViColors.dailyLivingYellow,
                SaViColors.dailyLivingYellowLight,
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
            color: Colors.black.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.2), width: 2),
          ),
          child: Icon(
            _isCapturing ? Icons.camera : Icons.camera_alt,
            size: 48,
            color: SaViColors.textOnLight,
          ),
        ),
        const SizedBox(height: 16),
        Text('Sinh hoạt', style: SaViTypography.modeTitle.copyWith(color: SaViColors.textOnLight)),
      ],
    );
  }

  Widget _buildInstructionArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(
              _isCapturing ? Icons.hourglass_top : Icons.touch_app,
              size: 40,
              color: SaViColors.textOnLight,
            ),
            const SizedBox(height: 16),
            Text(
              _isCapturing ? 'Đang xử lý ảnh...' : 'Chạm 2 lần để đọc chữ',
              style: SaViTypography.modeInstruction.copyWith(color: SaViColors.textOnLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isCapturing ? 'Vui lòng giữ yên điện thoại' : 'Vuốt sang trái để đổi chế độ',
              style: SaViTypography.statusText.copyWith(color: SaViColors.textOnLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onDoubleTap(BuildContext context) {
    if (_isCapturing) return;

    HapticFeedback.heavyImpact();
    setState(() => _isCapturing = true);
    debugPrint('[DailyLiving] Double tap — OCR capture triggered');

    // TODO(DEV-01): Wire to camera capture + OCR inference
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || !context.mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '📷 "Thuốc Paracetamol 500mg — Uống 2 viên sau bữa ăn"',
            style: TextStyle(fontSize: 18),
          ),
          backgroundColor: SaViColors.dailyLivingYellowDark,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }
}
