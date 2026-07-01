import 'models/navigation_exception.dart';
import 'models/navigation_step.dart';
import 'offline_graph_engine.dart';

/// Module định tuyến: Hoàn toàn offline qua OfflineGraphEngine
class NavigationRepository {
  final OfflineGraphEngine _engine;

  NavigationRepository(this._engine);

  /// Lấy chỉ dẫn đường đi bằng thuật toán Dijkstra offline
  Future<List<NavigationStep>> getRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    if (!_engine.isReady) {
      throw NavigationException('offline_graph_not_ready', 'Bản đồ ngoại tuyến chưa được tải.');
    }
    return _engine.buildRoute(fromLat, fromLng, toLat, toLng);
  }
}
