import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/ffi_bridge/event_channel_risk_source.dart';
import '../../core/ffi_bridge/method_channel_bridge.dart';
import '../../core/ffi_bridge/risk_source.dart';
import '../../core/services/audio_haptic_manager.dart';
import '../../../features/vision_alerts/vision_alert_controller.dart';

/// RiskSimulatorScreen — DoD Test Screen cho TASK-W6-NGKIEN-01
///
/// Mục đích: giả lập risk event từ native → kiểm tra toàn bộ pipeline
///   MethodChannel → Kotlin EventChannel → Dart Stream → VisionAlertController
///   → TTS + Rung + UI update
///
/// Đặt tại lib/ui/screens/debug/ vì đây là UI screen, không phải core infrastructure.
///
/// Cách mở:
///   Navigator.push(context, MaterialPageRoute(builder: (_) => const RiskSimulatorScreen()));
///
/// Screen tự quản lý VisionAlertController riêng với EventChannelRiskSource —
/// KHÔNG dùng production controller (sl<VisionAlertController>()) để tránh conflict.
class RiskSimulatorScreen extends StatefulWidget {
  const RiskSimulatorScreen({super.key});

  @override
  State<RiskSimulatorScreen> createState() => _RiskSimulatorScreenState();
}

class _RiskSimulatorScreenState extends State<RiskSimulatorScreen> {
  final _bridge = MethodChannelBridge();

  // Controller riêng với EventChannelRiskSource — không ảnh hưởng production
  late final EventChannelRiskSource _eventSource;
  late final VisionAlertController _simulatorController;

  StreamSubscription<RiskEvent>? _logSubscription;
  final List<_LogEntry> _log = [];
  bool _streamConnected = false;
  bool _isFiring = false;

  @override
  void initState() {
    super.initState();

    _eventSource = GetIt.instance<EventChannelRiskSource>();
    _simulatorController = VisionAlertController(
      _eventSource,
      GetIt.instance<AudioHapticManager>(),
    );

    _simulatorController.startProcessing();

    // Subscribe stream riêng để log real-time (controller xử lý TTS/rung)
    _logSubscription = _eventSource.riskStream.listen(
      _onEvent,
      onError: (e) => _setStreamStatus(false),
      onDone: ()  => _setStreamStatus(false),
    );

    // Một frame sau khi listen thành công → đánh dấu connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _streamConnected = true);
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _simulatorController.stopProcessing();
    _eventSource.dispose();
    super.dispose();
  }

  void _setStreamStatus(bool connected) {
    if (mounted) setState(() => _streamConnected = connected);
  }

  void _onEvent(RiskEvent event) {
    if (!mounted) return;
    setState(() {
      _streamConnected = true;
      _log.insert(0, _LogEntry(event: event));
      if (_log.length > 50) _log.removeLast(); // giới hạn log buffer
    });
  }

  // ── Fire event ─────────────────────────────────────────────────────────────

  Future<void> _fireLevel(int level) async {
    if (_isFiring) return;
    setState(() => _isFiring = true);

    // TTC và distance giả lập theo risk matrix (ffi_data_contract_v1.md §4)
    final (double ttc, double dist) = switch (level) {
      4 => (0.8, 0.5),
      3 => (1.5, 1.2),
      2 => (3.0, 2.5),
      1 => (6.0, 4.0),
      _ => (999.0, 99.0), // SAFE
    };

    try {
      await _bridge.simulateRiskEvent(
        riskLevel: level,
        ttcSeconds: ttc,
        distanceM: dist,
        classId: level > 0 ? 1 : 0, // classId=1 (xe máy) cho test
      );
    } on BridgeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi bridge: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFiring = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D27),
        elevation: 0,
        title: const Text(
          'TASK-W6 · Risk Simulator',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFB0B8D0),
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _StreamBadge(connected: _streamConnected),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ValueNotifier display ─────────────────────────────────────
            _ControllerStatusCard(controller: _simulatorController),
            const SizedBox(height: 16),

            // ── Risk level buttons ────────────────────────────────────────
            const Text(
              'GIẢI LẬP MỨC RỦI RO',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(5, (i) {
              final level = 4 - i; // hiển thị từ 4 xuống 0
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RiskButton(
                  level: level,
                  enabled: !_isFiring,
                  onPressed: () => _fireLevel(level),
                ),
              );
            }),
            const SizedBox(height: 16),

            // ── Event log ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'EVENT LOG',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                if (_log.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _log.clear()),
                    child: const Text(
                      'Xóa',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _log.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có event.\nNhấn nút để giả lập.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF4B5563), fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _log.length,
                      itemBuilder: (_, i) => _LogCard(entry: _log[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Internal widgets
// =============================================================================

/// Badge trạng thái EventChannel stream
class _StreamBadge extends StatelessWidget {
  final bool connected;
  const _StreamBadge({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: connected
            ? const Color(0xFF14532D).withValues(alpha: 0.8)
            : const Color(0xFF3B1515).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: connected ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card hiển thị trạng thái ValueNotifier từ controller
class _ControllerStatusCard extends StatelessWidget {
  final VisionAlertController controller;
  const _ControllerStatusCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2D3148), width: 1),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: controller.currentRiskLevel,
        builder: (_, level, __) {
          final color = _riskColor(level);
          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: controller.currentStatus,
                      builder: (_, status, __) => Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    ValueListenableBuilder<double>(
                      valueListenable: controller.lastDistance,
                      builder: (_, dist, __) => Text(
                        dist > 0 && dist < 90
                            ? 'Khoảng cách: ${dist.toStringAsFixed(1)} m'
                            : 'Không có vật cản',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Color _riskColor(int level) => switch (level) {
    0 => const Color(0xFF22C55E),   // green — SAFE
    1 => const Color(0xFF84CC16),   // lime — ATTENTION
    2 => const Color(0xFFF59E0B),   // amber — WARNING
    3 => const Color(0xFFF97316),   // orange — HIGH
    4 => const Color(0xFFEF4444),   // red — CRITICAL
    _ => const Color(0xFF6B7280),
  };
}

/// Nút bấm giả lập 1 mức rủi ro
class _RiskButton extends StatelessWidget {
  final int level;
  final bool enabled;
  final VoidCallback onPressed;

  const _RiskButton({
    required this.level,
    required this.enabled,
    required this.onPressed,
  });

  static const _labels = {
    0: ('Mức 0 — An Toàn (SAFE)', Color(0xFF22C55E)),
    1: ('Mức 1 — Chú Ý (ATTENTION)', Color(0xFF84CC16)),
    2: ('Mức 2 — Cảnh Báo (WARNING)', Color(0xFFF59E0B)),
    3: ('Mức 3 — Nguy Hiểm (HIGH)', Color(0xFFF97316)),
    4: ('Mức 4 — Sinh Tử (CRITICAL)', Color(0xFFEF4444)),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labels[level]!;
    return Semantics(
      label: 'Giả lập $label',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: enabled
                  ? color.withValues(alpha: 0.08)
                  : const Color(0xFF1A1D27),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: enabled
                    ? color.withValues(alpha: 0.5)
                    : const Color(0xFF2D3148),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? color.withValues(alpha: 0.2) : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      '$level',
                      style: TextStyle(
                        color: enabled ? color : const Color(0xFF4B5563),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: enabled ? color : const Color(0xFF4B5563),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.play_arrow_rounded,
                  color: enabled ? color.withValues(alpha: 0.7) : const Color(0xFF374151),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 1 dòng trong log
class _LogEntry {
  final RiskEvent event;
  final DateTime receivedAt;
  _LogEntry({required this.event}) : receivedAt = DateTime.now();
}

class _LogCard extends StatelessWidget {
  final _LogEntry entry;
  const _LogCard({required this.entry});

  static const _colors = {
    0: Color(0xFF22C55E),
    1: Color(0xFF84CC16),
    2: Color(0xFFF59E0B),
    3: Color(0xFFF97316),
    4: Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final e = entry.event;
    final color = _colors[e.riskLevel] ?? const Color(0xFF6B7280);
    final ts = entry.receivedAt;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}.${(ts.millisecond ~/ 10).toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                '${e.riskLevel}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TTC: ${e.ttcSeconds >= 900 ? "∞" : "${e.ttcSeconds.toStringAsFixed(1)}s"}  '
                  '·  Dist: ${e.distanceM >= 90 ? "∞" : "${e.distanceM.toStringAsFixed(1)}m"}  '
                  '·  Class: ${e.classId}',
                  style: const TextStyle(
                    color: Color(0xFFB0B8D0),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
