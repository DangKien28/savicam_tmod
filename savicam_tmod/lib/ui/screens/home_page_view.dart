import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'essential_screen.dart';
import 'navigation_screen.dart';
import 'recognition_screen.dart';
import '../../core/services/audio_haptic_manager.dart';

class HomePageView extends StatefulWidget {
  const HomePageView({super.key});

  @override
  State<HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends State<HomePageView> {
  final PageController _pageController = PageController();
  final _audioHaptic = GetIt.instance<AudioHapticManager>();

  final List<Widget> _pages = const [
    EssentialScreen(),
    NavigationScreen(),
    RecognitionScreen(),
  ];

  final List<String> _pageNames = const [
    "Chế độ Sinh Hoạt. Phát hiện vật cản ngoại tuyến.",
    "Chế độ Di Chuyển. Tìm đường đi trực tuyến.",
    "Chế độ Nhận Diện. Nhận dạng vật phẩm qua máy chủ đám mây."
  ];

  @override
  void initState() {
    super.initState();
    // Chào mừng và đọc hướng dẫn ban đầu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioHaptic.speakAlert(
        "Chào mừng bạn đến với SaViCam T-Mod. "
        "Vuốt sang trái hoặc phải để chuyển đổi giữa ba chế độ: Sinh hoạt, Di chuyển, và Nhận diện.",
        priority: 1,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // Rung phản hồi khi vuốt qua trang mới
    HapticFeedback.mediumImpact();

    // Phát âm thanh tên trang mới qua TTS - Mức ưu tiên 1 (bình thường)
    _audioHaptic.speakAlert(_pageNames[index], priority: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: _pages.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          return Semantics(
            label: "Màn hình số ${index + 1} trên 3. ${_pageNames[index]}",
            child: _pages[index],
          );
        },
      ),
    );
  }
}
