import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import '../../features/navigation/navigation_controller.dart';
import '../../core/services/audio_haptic_manager.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _navController = GetIt.instance<NavigationController>();
  final _audioHaptic = GetIt.instance<AudioHapticManager>();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
  }

  void _onSpeakStart() {
    HapticFeedback.heavyImpact();
    setState(() => _isListening = true);
    _audioHaptic.speakAlert("Đang lắng nghe.", priority: 1);
  }

  void _onSpeakEnd() {
    HapticFeedback.mediumImpact();
    setState(() => _isListening = false);
    // Gọi tìm đường giả lập tới "Nguyễn Trãi" khi nhả tay
    _navController.findPath("Nguyễn Trãi");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Thông tin chỉ đường hiện tại
            Expanded(
              flex: 2,
              child: ValueListenableBuilder<String>(
                valueListenable: _navController.currentInstruction,
                builder: (context, instruction, _) {
                  return Semantics(
                    label: "Chỉ dẫn hiện tại: $instruction. Chạm hai lần để nghe lại.",
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _audioHaptic.speakAlert(instruction, priority: 1);
                      },
                      onDoubleTap: () {
                        HapticFeedback.mediumImpact();
                        _navController.nextStep();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text(
                          instruction.toUpperCase(),
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
            // Nút "Nhấn giữ để nói" lớn chiếm nửa dưới màn hình
            Expanded(
              flex: 3,
              child: Semantics(
                label: _isListening
                    ? "Đang ghi âm giọng nói. Thả ra để tìm đường."
                    : "Nút nhấn giữ để tìm đường. Nhấn và giữ để nói tên điểm đến.",
                button: true,
                child: GestureDetector(
                  onLongPressStart: (_) => _onSpeakStart(),
                  onLongPressEnd: (_) => _onSpeakEnd(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isListening ? const Color(0xFFFFFF00) : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFFFF00), width: 4),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none_outlined,
                          size: 120,
                          color: _isListening ? Colors.black : const Color(0xFFFFFF00),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _isListening ? "THẢ ĐỂ TÌM ĐƯỜNG" : "GIỮ ĐỂ NÓI ĐIỂM ĐẾN",
                          style: TextStyle(
                            color: _isListening ? Colors.black : const Color(0xFFFFFF00),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
