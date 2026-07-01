import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'core/services/headless_lifecycle_manager.dart';
import 'injection_container.dart';
import 'ui/theme/accessibility_theme.dart';
import 'ui/screens/home_page_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo toàn bộ dependency (DI)
  await initDependencies();

  // Bắt đầu lắng nghe screen state cho Headless Mode (TASK-W8-NGKIEN-01)
  GetIt.instance<HeadlessLifecycleManager>().init();

  runApp(const SaViCamTmodApp());
}

class SaViCamTmodApp extends StatelessWidget {
  const SaViCamTmodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaViCam T-Mod',
      theme: AccessibilityTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const HomePageView(),
    );
  }
}
