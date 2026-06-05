/// SaViCam T-Mod — Home Screen
///
/// The root screen composing the 3-Mode Swipe UI with the Global SOS Overlay.
///
/// Architecture:
/// - A [Stack] layers the [PageView] (3 modes) underneath the [SosOverlayWidget]
/// - The SOS overlay covers the bottom 50% across ALL modes
/// - Swipe gestures in the top 50% navigate between modes
/// - The [PageView] uses full-screen pages with physics-based scrolling
///
/// Mode order (swipe left/right):
/// 1. Trợ lý an toàn (Green) — default
/// 2. Di chuyển (Blue)
/// 3. Sinh hoạt (Yellow)
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/sos_constants.dart';
import '../../../../core/theme/accessibility_theme.dart';
import '../../../daily_living/pages/daily_living_mode_page.dart';
import '../../../navigation/presentation/pages/navigation_mode_page.dart';
import '../../../sos/presentation/bloc/sos_bloc.dart';
import '../../../sos/presentation/bloc/sos_bloc_event.dart';
import '../../../sos/presentation/bloc/sos_bloc_state.dart';
import 'safety_mode_page.dart';

/// Data class for mode indicator rendering.
class _ModeData {
  final String name;
  final Color color;
  final IconData icon;
  const _ModeData(this.name, this.color, this.icon);
}

/// Home screen that hosts the 3-mode swipe UI and SOS overlay.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  /// Mode data for the page indicator.
  static const _modes = [
    _ModeData('Trợ lý an toàn', SaViColors.safetyGreen, Icons.shield),
    _ModeData('Di chuyển', SaViColors.navigationBlue, Icons.blind),
    _ModeData('Sinh hoạt', SaViColors.dailyLivingYellow, Icons.camera_alt),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ─── Layer 1: 3-Mode PageView (full screen) ───
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            // Allow scrolling even in accessibility mode
            physics: const BouncingScrollPhysics(),
            children: const [
              SafetyModePage(),
              NavigationModePage(),
              DailyLivingModePage(),
            ],
          ),

          // ─── Layer 2: Page indicator dots (top) ───
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: _buildPageIndicator(),
          ),

          // ─── Layer 3: SOS Overlay (bottom 50%) ───
          _buildSosOverlay(context),
        ],
      ),
    );
  }

  /// Page indicator dots showing current mode.
  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_modes.length, (index) {
        final isActive = index == _currentPage;
        final mode = _modes[index];

        return Semantics(
          label: '${mode.name} ${isActive ? "(đang chọn)" : ""}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: isActive ? 32 : 12,
            height: 12,
            decoration: BoxDecoration(
              color: isActive
                  ? mode.color
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: mode.color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  /// Builds the SOS overlay, positioned at the bottom 50%.
  Widget _buildSosOverlay(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sosZoneHeight = screenHeight * SosConstants.zoneHeightFraction;

    return BlocBuilder<SosBloc, SosBlocState>(
      builder: (context, state) {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: sosZoneHeight,
          child: _SosGestureZone(state: state),
        );
      },
    );
  }
}

/// Internal SOS gesture zone that handles the long-press interaction.
class _SosGestureZone extends StatefulWidget {
  final SosBlocState state;

  const _SosGestureZone({required this.state});

  @override
  State<_SosGestureZone> createState() => _SosGestureZoneState();
}

class _SosGestureZoneState extends State<_SosGestureZone>
    with SingleTickerProviderStateMixin {
  DateTime? _holdStartTime;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _SosGestureZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleStateAnimation(widget.state);
  }

  void _handleStateAnimation(SosBlocState state) {
    if (state is SosTriggering) {
      _pulseController.repeat(reverse: true);
    } else if (state is SosIdle || state is SosCancelled) {
      _pulseController.stop();
      _pulseController.reset();
    } else if (state is SosTriggered || state is SosError) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        _holdStartTime = DateTime.now();
        context.read<SosBloc>().add(const SosHoldStarted());
      },
      onLongPressEnd: (_) {
        if (_holdStartTime == null) return;
        final duration = DateTime.now().difference(_holdStartTime!);
        _holdStartTime = null;
        context.read<SosBloc>().add(SosHoldReleased(holdDuration: duration));
      },
      onLongPressCancel: () {
        if (_holdStartTime == null) return;
        final duration = DateTime.now().difference(_holdStartTime!);
        _holdStartTime = null;
        context.read<SosBloc>().add(SosHoldReleased(holdDuration: duration));
      },
      child: Semantics(
        label: 'Vùng S.O.S. Nhấn giữ 3 đến 5 giây để gọi cứu trợ.',
        button: true,
        child: _buildContent(widget.state),
      ),
    );
  }

  Widget _buildContent(SosBlocState state) {
    return switch (state) {
      SosIdle() => _buildIdle(),
      SosHolding(:final progress, :final holdDuration) => _buildHolding(progress, holdDuration),
      SosTriggering() => _buildTriggering(),
      SosTriggered() => _buildTriggered(),
      SosCancelled() => _buildCancelled(),
      SosError(:final message) => _buildError(message),
    };
  }

  Widget _buildIdle() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            SaViColors.sosRed.withValues(alpha: 0.05),
            SaViColors.sosRed.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, color: SaViColors.sosRed.withValues(alpha: 0.4), size: 20),
              const SizedBox(width: 8),
              Text('Nhấn giữ để gọi SOS',
                style: TextStyle(fontSize: 14, color: SaViColors.sosRed.withValues(alpha: 0.4), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHolding(double progress, Duration holdDuration) {
    final hasReachedMin = holdDuration.inSeconds >= 3;
    final progressColor = hasReachedMin ? SaViColors.safetyGreen : SaViColors.sosRedLight;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SaViColors.sosRed.withValues(alpha: 0.2 + progress * 0.4),
            SaViColors.sosRedDark.withValues(alpha: 0.4 + progress * 0.5),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120, height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(value: 1.0, strokeWidth: 8, color: Colors.white.withValues(alpha: 0.2)),
                  CircularProgressIndicator(value: progress, strokeWidth: 8, color: progressColor, strokeCap: StrokeCap.round),
                  Icon(hasReachedMin ? Icons.check_circle : Icons.warning_amber_rounded, size: 48, color: progressColor),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasReachedMin ? 'Thả tay để gửi SOS' : 'Giữ tiếp... ${3 - holdDuration.inSeconds} giây',
              style: SaViTypography.sosText,
            ),
            const SizedBox(height: 8),
            Text(
              '${holdDuration.inSeconds}/${SosConstants.maxHoldDuration.inSeconds} giây',
              style: SaViTypography.statusText.copyWith(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggering() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          color: SaViColors.sosRed.withValues(alpha: _pulseAnimation.value),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 64, height: 64, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 6)),
                SizedBox(height: 24),
                Text('ĐANG GỬI SOS...', style: SaViTypography.sosText),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTriggered() {
    return Container(
      color: SaViColors.sosRedDark.withValues(alpha: 0.9),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.white),
            SizedBox(height: 24),
            Text('SOS ĐÃ GỬI', style: SaViTypography.sosText),
            SizedBox(height: 12),
            Text('Người giám hộ sẽ được thông báo', style: SaViTypography.modeInstruction),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelled() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, SaViColors.sosRed.withValues(alpha: 0.1)],
        ),
      ),
      child: Center(
        child: Text('Đã hủy SOS',
          style: SaViTypography.statusText.copyWith(color: SaViColors.sosRedLight.withValues(alpha: 0.7))),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      color: SaViColors.sosRedDark.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            const Text('LỖI GỬI SOS', style: SaViTypography.sosText),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(message, style: SaViTypography.statusText, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
