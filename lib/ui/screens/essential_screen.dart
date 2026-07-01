import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import '../../features/vision_alerts/vision_alert_controller.dart';
import '../../core/services/audio_haptic_manager.dart';
import '../widgets/sos_button.dart';

class EssentialScreen extends StatefulWidget {
  const EssentialScreen({super.key});

  @override
  State<EssentialScreen> createState() => _EssentialScreenState();
}

class _EssentialScreenState extends State<EssentialScreen> {
  final _visionController = GetIt.instance<VisionAlertController>();
  final _audioHaptic = GetIt.instance<AudioHapticManager>();

  @override
  void initState() {
    super.initState();
    // Khởi chạy vòng lặp xử lý frame ngầm khi vào màn hình
    _visionController.startProcessing();
  }

  @override
  void dispose() {
    _visionController.stopProcessing();
    super.dispose();
  }

  /// Phát âm thanh trạng thái hiện tại khi chạm vào màn hình
  Future<void> _speakStatus() async {
    HapticFeedback.mediumImpact();
    final status = _visionController.currentStatus.value;
    final distance = _visionController.lastDistance.value;
    final riskLevel = _visionController.currentRiskLevel.value;

    String announceMsg = "Trạng thái hiện tại: $status.";
    if (riskLevel > 0) {
      announceMsg += " Vật cản gần nhất cách ${distance.toStringAsFixed(1)} mét.";
    }
    announceMsg += " Thiết bị pin 80 phần trăm.";

    await _audioHaptic.speakAlert(announceMsg, priority: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Khu vực chạm lớn toàn màn hình để đọc trạng thái
            Expanded(
              child: Semantics(
                label: "Vùng chạm đọc trạng thái. Chạm hai lần để nghe báo cáo an toàn và mức pin.",
                button: true,
                child: GestureDetector(
                  onTap: _speakStatus,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: Center(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _visionController.currentStatus,
                        builder: (context, status, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable: _visionController.currentRiskLevel,
                            builder: (context, level, _) {
                              Color textColor = const Color(0xFFFFFF00); // Lemon Yellow
                              if (level >= 3) {
                                textColor = Colors.redAccent;
                              }
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    level >= 3 ? Icons.warning_amber_rounded : Icons.shield_outlined,
                                    size: 100,
                                    color: textColor,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "CHẠM ĐỂ NGHE BÁO CÁO",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "PIN 80%",
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Nút SOS tràn viền ở cuối trang
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SosButton(),
            ),
          ],
        ),
      ),
    );
  }
}
