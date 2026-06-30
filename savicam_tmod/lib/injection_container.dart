import 'package:get_it/get_it.dart';

import 'core/ffi_bindings/native_library.dart';
import 'core/services/audio_haptic_manager.dart';
import 'core/services/location_service.dart';
import 'core/services/file_storage_service.dart';
import 'core/network/api_client.dart';
import 'core/network/websocket_manager.dart';
import 'features/ai_agent/intent_mapper.dart';
import 'features/navigation/navigation_repository.dart';
import 'features/vision_alerts/vision_alert_controller.dart';
import 'features/sos_module/sos_controller.dart';

import 'features/navigation/navigation_controller.dart';
import 'features/cloud_recognition/cloud_recognition_controller.dart';

final sl = GetIt.instance;

/// Đăng ký tất cả dependency. Gọi 1 lần duy nhất trong main().
Future<void> initDependencies() async {
  // ─── Core Services (Singleton) ───
  sl.registerLazySingleton<NativeLibrary>(() => NativeLibrary());
  sl.registerLazySingleton<AudioHapticManager>(() => AudioHapticManager());
  sl.registerLazySingleton<LocationService>(() => LocationService());
  sl.registerLazySingleton<FileStorageService>(() => FileStorageService());

  // ─── Network ───
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: 'https://api.savicam.vn'), // TODO: config từ env
  );
  sl.registerLazySingleton<WebSocketManager>(() => WebSocketManager());

  // ─── Features ───
  sl.registerLazySingleton<IntentMapper>(() => IntentMapper());
  sl.registerLazySingleton<NavigationRepository>(
    () => NavigationRepository(sl<ApiClient>()),
  );
  sl.registerLazySingleton<NavigationController>(
    () => NavigationController(sl<ApiClient>(), sl<AudioHapticManager>()),
  );
  sl.registerLazySingleton<CloudRecognitionController>(
    () => CloudRecognitionController(sl<ApiClient>(), sl<AudioHapticManager>()),
  );
  sl.registerLazySingleton<VisionAlertController>(
    () => VisionAlertController(sl<NativeLibrary>(), sl<AudioHapticManager>()),
  );
  sl.registerLazySingleton<SosController>(
    () => SosController(sl<ApiClient>(), sl<LocationService>(), sl<AudioHapticManager>()),
  );

  // ─── Init async services ───
  await sl<AudioHapticManager>().init();
  await sl<FileStorageService>().init();
  await sl<IntentMapper>().loadDictionary();
}
