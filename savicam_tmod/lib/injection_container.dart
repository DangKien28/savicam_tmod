import 'package:get_it/get_it.dart';

import 'core/ffi_bindings/native_library.dart';
import 'core/ffi_bridge/method_channel_bridge.dart';
import 'core/ffi_bridge/risk_source.dart';
import 'core/ffi_bridge/ffi_polling_risk_source.dart';
import 'core/ffi_bridge/event_channel_risk_source.dart';
import 'core/services/audio_haptic_manager.dart';
import 'core/services/headless_lifecycle_manager.dart';
import 'core/services/location_service.dart';
import 'core/services/file_storage_service.dart';
import 'core/network/api_client.dart';
import 'core/network/websocket_manager.dart';
import 'features/ai_agent/intent_mapper.dart';
import 'features/navigation/navigation_repository.dart';
import 'features/vision_alerts/vision_alert_controller.dart';
import 'features/telemetry/location_tracking_repository.dart';
import 'features/telemetry/watch_live_location_usecase.dart';
import 'features/sos_module/sos_controller.dart';

import 'features/navigation/navigation_controller.dart';
import 'features/navigation/navigation_repository.dart';
import 'features/navigation/map_download_service.dart';
import 'features/navigation/graph_extractor.dart';
import 'features/navigation/offline_graph_engine.dart';
import 'features/cloud_recognition/cloud_recognition_controller.dart';

final sl = GetIt.instance;

/// Đăng ký tất cả dependency. Gọi 1 lần duy nhất trong main().
Future<void> initDependencies() async {
  // ─── Core Services (Singleton) ───
  sl.registerLazySingleton<MethodChannelBridge>(() => MethodChannelBridge());
  sl.registerLazySingleton<NativeLibrary>(() => NativeLibrary());
  sl.registerLazySingleton<AudioHapticManager>(() => AudioHapticManager());
  sl.registerLazySingleton<LocationService>(() => LocationService());
  sl.registerLazySingleton<FileStorageService>(() => FileStorageService());
  sl.registerLazySingleton<WebSocketManager>(() => WebSocketManager());

  // ─── Headless Mode (TASK-W8-NGKIEN-01) ───
  sl.registerLazySingleton<HeadlessLifecycleManager>(
    () => HeadlessLifecycleManager(
      sl<MethodChannelBridge>(),
      sl<WatchLiveLocationUsecase>(),
    ),
  );

  // ─── Risk Source (TASK-W6-NGKIEN-01) ───
  sl.registerLazySingleton<IRiskSource>(
    () => FfiPollingRiskSource(sl<NativeLibrary>()),
  );
  sl.registerFactory<EventChannelRiskSource>(() => EventChannelRiskSource());

  // ─── Network ───
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: 'https://api.savicam.vn'),
  );
  sl.registerLazySingleton<WebSocketManager>(() => WebSocketManager());

  // ─── Features ───
  sl.registerLazySingleton<IntentMapper>(() => IntentMapper());
  
  // Navigation (TASK-W6-NGKIEN-02)
  sl.registerLazySingleton<MapDownloadService>(
    () => MapDownloadService(sl<FileStorageService>()),
  );
  sl.registerLazySingleton<GraphExtractor>(
    () => GraphExtractor(sl<FileStorageService>()),
  );
  sl.registerLazySingleton<OfflineGraphEngine>(() => OfflineGraphEngine());
  sl.registerLazySingleton<NavigationRepository>(
    () => NavigationRepository(sl<OfflineGraphEngine>()),
  );
  sl.registerLazySingleton<NavigationController>(
    () => NavigationController(
      sl<NavigationRepository>(),
      sl<AudioHapticManager>(),
      sl<MapDownloadService>(),
      sl<GraphExtractor>(),
      sl<OfflineGraphEngine>(),
      sl<LocationService>(),
    ),
  );

  sl.registerLazySingleton<CloudRecognitionController>(
    () => CloudRecognitionController(sl<ApiClient>(), sl<AudioHapticManager>()),
  );

  sl.registerLazySingleton<VisionAlertController>(
    () => VisionAlertController(sl<IRiskSource>(), sl<AudioHapticManager>()),
  );

  sl.registerLazySingleton<SosController>(
    () => SosController(
      sl<ApiClient>(),
      sl<LocationService>(),
      sl<AudioHapticManager>(),
    ),
  );

  // ─── Telemetry / Relap (TASK-W8-NGKIEN-01) ───
  sl.registerLazySingleton<LocationTrackingRepository>(
    () => LocationTrackingRepository(
      sl<WebSocketManager>(),
      sl<LocationService>(),
      sl<VisionAlertController>(),
    ),
  );

  sl.registerLazySingleton<WatchLiveLocationUsecase>(
    () => WatchLiveLocationUsecase(sl<LocationTrackingRepository>()),
  );

  // ─── Init async services ───
  await sl<AudioHapticManager>().init();
  await sl<FileStorageService>().init();
  await sl<IntentMapper>().loadDictionary();

  // Khởi động background map download (Phase 1)
  sl<NavigationController>().initMapInBackground('danang').ignore();
}
