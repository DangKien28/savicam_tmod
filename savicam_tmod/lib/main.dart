import 'package:flutter/material.dart';
import 'injection_container.dart';
import 'ui/theme/accessibility_theme.dart';
import 'ui/screens/home_page_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo toàn bộ dependency (DI)
  await initDependencies();

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
