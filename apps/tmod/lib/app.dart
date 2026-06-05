/// SaViCam T-Mod — App Configuration
///
/// MaterialApp setup with accessibility theme, BLoC providers,
/// and TTS locale configuration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/accessibility_theme.dart';
import 'features/safety_assistant/presentation/pages/home_screen.dart';
import 'features/sos/data/datasources/sqlite_queue_source.dart';
import 'features/sos/data/datasources/supabase_sos_source.dart';
import 'features/sos/data/repositories/sos_repository_impl.dart';
import 'features/sos/domain/usecases/flush_offline_queue.dart';
import 'features/sos/domain/usecases/trigger_sos.dart';
import 'features/sos/presentation/bloc/sos_bloc.dart';
import 'shared/database/sqlite_helper.dart';
import 'shared/services/location_service.dart';

/// Root widget for the SaViCam T-Mod application.
class SaViCamApp extends StatelessWidget {
  const SaViCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ─── Dependency Wiring (MVP — manual DI) ───
    // TODO(DEV-01): Migrate to get_it service locator in core/di/
    final dbHelper = SqliteHelper.instance;
    final locationService = MockLocationService();
    final localSource = SqliteQueueSource(dbHelper: dbHelper);
    final cloudSource = const StubSupabaseSosSource();
    final sosRepository = SosRepositoryImpl(
      cloudSource: cloudSource,
      localSource: localSource,
    );
    final triggerSos = TriggerSos(
      repository: sosRepository,
      locationService: locationService,
    );
    final flushQueue = FlushOfflineQueue(repository: sosRepository);

    return MultiBlocProvider(
      providers: [
        BlocProvider<SosBloc>(
          create: (_) => SosBloc(
            triggerSos: triggerSos,
            flushOfflineQueue: flushQueue,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'SaViCam T-Mod',
        debugShowCheckedModeBanner: false,

        // Accessibility-first dark theme
        theme: SaViTheme.darkTheme,
        darkTheme: SaViTheme.darkTheme,
        themeMode: ThemeMode.dark,

        // Home screen with 3-mode swipe UI + SOS overlay
        home: const HomeScreen(),

        // Global accessibility settings
        builder: (context, child) {
          // Ensure text is never scaled below 1.0x for accessibility
          final mediaQuery = MediaQuery.of(context);
          final currentScale = mediaQuery.textScaler.scale(14) / 14;
          final clampedScale = currentScale.clamp(1.0, 2.0);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(clampedScale),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
