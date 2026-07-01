import 'package:flutter_test/flutter_test.dart';
import 'package:savicam_tmod/features/navigation/models/offline_graph.dart';
import 'dart:math' as math;

void main() {
  group('SpatialGrid nearestNode Tests', () {
    test('Finds exact match', () {
      final nodes = [
        const GraphNode(1, 16.0, 108.0),
        const GraphNode(2, 16.001, 108.001),
        const GraphNode(3, 16.002, 108.002),
      ];
      final graph = OfflineGraph(nodes, {});
      
      final nearest = graph.nearestNode(16.001, 108.001);
      expect(nearest.id, 2);
    });

    test('Finds nearest in empty space', () {
      final nodes = [
        const GraphNode(1, 10.0, 10.0), // xa
        const GraphNode(2, 10.0, 10.0001), // gần
        const GraphNode(3, 10.1, 10.1), // xa tít
      ];
      final graph = OfflineGraph(nodes, {});
      
      // Tìm điểm gần 2 nhất
      final nearest = graph.nearestNode(10.0, 10.00008);
      expect(nearest.id, 2);
    });

    test('Handles boundaries correctly (negative coordinates)', () {
      final nodes = [
        const GraphNode(1, -10.0, -10.0),
        const GraphNode(2, -10.001, -10.001),
      ];
      final graph = OfflineGraph(nodes, {});
      
      final nearest = graph.nearestNode(-10.0009, -10.0009);
      expect(nearest.id, 2);
    });

    test('Throws if graph is empty', () {
      final graph = OfflineGraph([], {});
      expect(() => graph.nearestNode(0.0, 0.0), throwsStateError);
    });
  });
}
