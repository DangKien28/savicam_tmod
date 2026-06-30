import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import '../../features/cloud_recognition/cloud_recognition_controller.dart';
import '../../core/services/audio_haptic_manager.dart';

class RecognitionScreen extends StatefulWidget {
  const RecognitionScreen({super.key});

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends State<RecognitionScreen> {
  final _recController = GetIt.instance<CloudRecognitionController>();
  final _audioHaptic = GetIt.instance<AudioHapticManager>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Khu vực hiển thị kết quả cuối cùng
            Expanded(
              flex: 2,
              child: ValueListenableBuilder<String>(
                valueListenable: _recController.lastResult,
                builder: (context, result, _) {
                  return Semantics(
                    label: "Kết quả nhận diện: $result. Chạm một lần để nghe lại.",
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _audioHaptic.speakAlert(result, priority: 1);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text(
                          result.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFFF00),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Khu vực chạm đúp lớn để chụp hình
            Expanded(
              flex: 3,
              child: ValueListenableBuilder<bool>(
                valueListenable: _recController.isProcessing,
                builder: (context, processing, _) {
                  return Semantics(
                    label: processing
                        ? "Đang gửi ảnh lên máy chủ đám mây. Vui lòng giữ chắc máy."
                        : "Nút chụp ảnh nhận dạng. Chạm hai lần vào khu vực này để chụp ảnh nhận dạng đồ vật.",
                    button: true,
                    child: GestureDetector(
                      onDoubleTap: () {
                        if (!processing) {
                          _recController.captureAndRecognize();
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: processing ? const Color(0xFFFFFF00) : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFFFF00), width: 4),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              processing ? Icons.cloud_sync_outlined : Icons.camera_alt_outlined,
                              size: 120,
                              color: processing ? Colors.black : const Color(0xFFFFFF00),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              processing ? "ĐANG XỬ LÝ..." : "CHẠM 2 LẦN ĐỂ CHỤP",
                              style: TextStyle(
                                color: processing ? Colors.black : const Color(0xFFFFFF00),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
