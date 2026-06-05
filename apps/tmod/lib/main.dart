/// SaViCam T-Mod — Application Entry Point
///
/// Initializes core services before launching the Flutter app:
/// 1. Flutter engine bindings
/// 2. SQLite database (schema creation / migration)
/// 3. SaViCam app with BLoC providers
///
/// See architecture_lock.md ARCH-06 for SQLite initialization requirements.
/// See architecture_lock.md ARCH-09 for BLoC provider registration.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'shared/database/sqlite_helper.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for accessibility
  // (consistent touch zone positions for visually impaired users)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style for immersive experience
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF121212),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize SQLite database (creates tables on first launch)
  await SqliteHelper.instance.database;

  // Launch the app
  runApp(const SaViCamApp());
}
