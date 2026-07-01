import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/local_db/entities/local_macro.dart';
import '../../core/local_db/macro_resolver.dart';
import '../../core/local_db/sqlite_helper.dart';
import '../../core/services/audio_haptic_manager.dart';
import '../../core/services/location_service.dart';

import 'graph_extractor.dart';
import 'map_download_service.dart';
import 'models/navigation_exception.dart';
import 'models/navigation_step.dart';
import 'navigation_repository.dart';
import 'offline_graph_engine.dart';

enum NavigationStatus { idle, downloading, graphLoading, routing, active, error }

class NavigationController {
  final NavigationRepository _repo;
  final AudioHapticManager _audioHaptic;
  final MapDownloadService _downloader;
  final GraphExtractor _extractor;
  final OfflineGraphEngine _engine;
  final LocationService _location;
  final MacroResolver _macroResolver;

  final ValueNotifier<NavigationStatus> status = ValueNotifier<NavigationStatus>(NavigationStatus.idle);
  final ValueNotifier<String> currentInstruction = ValueNotifier<String>('Chưa có lộ trình');
  final List<NavigationStep> routeSteps = [];
  int currentStepIndex = 0;

  NavigationController(
    this._repo,
    this._audioHaptic,
    this._downloader,
    this._extractor,
    this._engine,
    this._location, {
    MacroResolver? macroResolver,
  }) : _macroResolver = macroResolver ?? MacroResolver();

  /// Gọi ở app init — KHÔNG gọi trong findPath() để tránh block UX.
  Future<void> initMapInBackground(String regionId) async {
    status.value = NavigationStatus.downloading;
    final downloadOk = await _downloader.downloadIfNeeded(regionId);
    if (!downloadOk) {
      status.value = NavigationStatus.error;
      debugPrint('MapDownloadError: Failed to download $regionId');
      return;
    }

    status.value = NavigationStatus.graphLoading;
    final graph = await _extractor.extract(regionId);
    if (graph == null) {
      status.value = NavigationStatus.error;
      debugPrint('GraphExtractorError: Failed to extract $regionId');
      return;
    }

    _engine.setGraph(graph);
    status.value = NavigationStatus.idle;
  }

  /// Bắt đầu phân tích tìm đường bằng lệnh giọng nói
  Future<void> findPath(String destinationKeyword) async {
    // Phase 2: Check isReady, fail-fast
    if (!_engine.isReady) {
      await _audioHaptic.speakAlert('Bản đồ chưa sẵn sàng. Vui lòng chờ.', priority: 2);
      return;
    }

    status.value = NavigationStatus.routing;
    routeSteps.clear();
    currentStepIndex = 0;
    currentInstruction.value = 'Đang tìm kiếm lộ trình...';

    HapticFeedback.mediumImpact();

    try {
      final pos = await _location.getCurrentPosition();
      if (pos == null) {
        throw NavigationException('no_gps', 'Không lấy được vị trí GPS.');
      }

      final macro = await _resolveMacro(destinationKeyword);
      if (macro == null) {
        throw NavigationException('unknown_destination', 'Không tìm thấy địa điểm $destinationKeyword trong danh bạ.');
      }

      final steps = await _repo.getRoute(
        fromLat: pos.latitude,
        fromLng: pos.longitude,
        toLat: macro.lat,
        toLng: macro.lng,
      );

      if (steps.isEmpty) {
        throw NavigationException('no_route', 'Không tìm thấy đường đi tới điểm này.');
      }

      routeSteps.addAll(steps);
      currentInstruction.value = routeSteps[0].instruction;
      status.value = NavigationStatus.active;

      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.lightImpact();

      await _audioHaptic.speakAlert('Đã tìm thấy lộ trình. ${routeSteps[0].instruction}', priority: 2);
    } on NavigationException catch (e) {
      _handleError(e);
    } catch (e) {
      _handleError(NavigationException('unknown_error', e.toString()));
    } finally {
      if (status.value == NavigationStatus.routing) {
        status.value = NavigationStatus.idle;
      }
    }
  }

  Future<LocalMacro?> _resolveMacro(String keyword) async {
    return _macroResolver.resolveMacro(keyword);
  }

  /// Chuyển tới hướng dẫn tiếp theo
  Future<void> nextStep() async {
    if (routeSteps.isEmpty) return;
    if (currentStepIndex < routeSteps.length - 1) {
      currentStepIndex++;
      currentInstruction.value = routeSteps[currentStepIndex].instruction;
      await _audioHaptic.speakAlert(routeSteps[currentStepIndex].instruction, priority: 2);
    } else {
      await _audioHaptic.speakAlert('Bạn đã đi hết lộ trình.', priority: 2);
    }
  }

  void _handleError(NavigationException e) {
    status.value = NavigationStatus.error;
    currentInstruction.value = 'Lỗi: ${e.code}';
    
    String msg = 'Có lỗi xảy ra.';
    if (e.code == 'no_gps') msg = 'Không tìm thấy vị trí GPS. Vui lòng bật định vị.';
    else if (e.code == 'unknown_destination') msg = e.message ?? 'Điểm đến không hợp lệ.';
    else if (e.code == 'offline_graph_not_ready') msg = 'Bản đồ ngoại tuyến chưa được tải.';
    else if (e.code == 'no_route') msg = e.message ?? 'Không tìm thấy đường đi.';

    _audioHaptic.speakAlert(msg, priority: 3);
  }
}
