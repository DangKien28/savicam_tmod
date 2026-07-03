import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/headless_lifecycle_manager.dart';
import 'injection_container.dart';
import 'ui/theme/accessibility_theme.dart';
import 'ui/screens/home_page_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tải các biến môi trường từ file .env
  await dotenv.load(fileName: ".env");

  // Khởi tạo kết nối Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

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