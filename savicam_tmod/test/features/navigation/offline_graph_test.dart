import 'package:flutter_test/flutter_test.dart';
import 'package:savicam_tmod/features/navigation/models/offline_graph.dart';
import 'package:savicam_tmod/features/navigation/offline_graph_engine.dart';
import 'package:savicam_tmod/features/navigation/models/navigation_step.dart';

// Test utils: Mở rộng method của engine để có thể chạy synchronously trong test
extension OfflineGraphEngineTestExtension on OfflineGraphEngine {
  Future<List<NavigationStep>> buildRouteSyncForTest(
      double fromLat, double fromLng, double toLat, double toLng) async {
    // Gọi phương thức async thực sự vì nó dùng Isolate.run, flutter_test hỗ trợ tốt await
    return await buildRoute(fromLat, fromLng, toLat, toLng);
  }
}

void main() {
  group('OfflineGraphEngine Dijkstra', () {
    late OfflineGraphEngine engine;

    setUp(() {
      engine = OfflineGraphEngine();
      
      // Tạo graph mẫu:
      // Node 1 (0,0) --- 10m ---> Node 2 (0, 0.0001) --- 10m ---> Node 3 (0, 0.0002)
      //  |                                                         ^
      //  +--- 30m -------------------------------------------------+
      //
      // Đường đi ngắn nhất 1 -> 3 là qua 2 (20m)
      
      final nodes = [
        const GraphNode(1, 0.0, 0.0),
        const GraphNode(2, 0.0, 0.0001),
        const GraphNode(3, 0.0, 0.0002),
        const GraphNode(4, 1.0, 1.0), // Node rời rạc
      ];
      
      final adjacency = {
        1: [const GraphEdge(1, 2, 10.0, 'Đường A'), const GraphEdge(1, 3, 30.0, 'Đường B')],
        2: [const GraphEdge(2, 1, 10.0, 'Đường A'), const GraphEdge(2, 3, 10.0, 'Đường C')],
        3: [const GraphEdge(3, 1, 30.0, 'Đường B'), const GraphEdge(3, 2, 10.0, 'Đường C')],
        4: <GraphEdge>[],
      };
      
      final graph = OfflineGraph(nodes, adjacency);
      engine.setGraph(graph);
    });

    test('Shortest path is correct (1 -> 3 via 2)', () async {
      final steps = await engine.buildRouteSyncForTest(0.0, 0.0, 0.0, 0.0002);
      
      expect(steps, isNotEmpty);
      // step 1 (bắt đầu), step 2 (tại node 2), step 3 (đến nơi)
      expect(steps.length, 3);
      
      expect(steps[0].instruction, contains('Bắt đầu di chuyển'));
      expect(steps[0].instruction, contains('Đường A')); // Cạnh 1->2
      expect(steps[0].distanceM, 10.0);
      
      expect(steps[1].instruction, contains('Đường C')); // Cạnh 2->3
      expect(steps[1].distanceM, 10.0);
      
      expect(steps[2].instruction, 'Bạn đã đến nơi.');
    });

    test('Disconnected graph returns empty list', () async {
      final steps = await engine.buildRouteSyncForTest(0.0, 0.0, 1.0, 1.0);
      expect(steps, isEmpty);
    });

    test('Origin = Destination returns arrived immediately', () async {
      final steps = await engine.buildRouteSyncForTest(0.0, 0.0, 0.0, 0.0);
      expect(steps.length, 1);
      expect(steps[0].instruction, 'Bạn đã đến nơi.');
    });
  });
}
