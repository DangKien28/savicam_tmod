import 'dart:isolate';
import 'package:collection/collection.dart';
import 'dart:math' as math;

import 'models/navigation_step.dart';
import 'models/offline_graph.dart';

class OfflineGraphEngine {
  OfflineGraph? _graph;

  bool get isReady => _graph != null;

  void setGraph(OfflineGraph graph) {
    _graph = graph;
  }

  Future<List<NavigationStep>> buildRoute(
      double fromLat, double fromLng, double toLat, double toLng) async {
    assert(_graph != null, 'Graph is not ready. Call setGraph() first.');

    final graphData = _graph!.toTransferObject();

    return await Isolate.run(
        () => _dijkstra(graphData, fromLat, fromLng, toLat, toLng));
  }
}

// ----------------------------------------------------------------------------
// Isolate Top-Level Functions
// ----------------------------------------------------------------------------

List<NavigationStep> _dijkstra(GraphTransferObject graphData, double fromLat,
    double fromLng, double toLat, double toLng) {
  
  // 1. Tìm node gần nhất
  final origin = graphData.grid.nearest(fromLat, fromLng);
  final destination = graphData.grid.nearest(toLat, toLng);

  if (origin.id == destination.id) {
    return [const NavigationStep(instruction: 'Bạn đã đến nơi.', distanceM: 0, bearing: 0)];
  }

  // 2. Setup Dijkstra (HeapPriorityQueue cho hiệu năng cao)
  final distances = <int, double>{};
  final previous = <int, _PathData>{};
  
  // Queue chứa _DijkstraNode(id, distance)
  final pq = PriorityQueue<_DijkstraNode>((a, b) => a.dist.compareTo(b.dist));

  distances[origin.id] = 0.0;
  pq.add(_DijkstraNode(origin.id, 0.0));

  bool found = false;

  while (pq.isNotEmpty) {
    final current = pq.removeFirst();

    if (current.id == destination.id) {
      found = true;
      break;
    }

    // Nếu khoảng cách hiện tại lớn hơn khoảng cách đã biết (do có đường ngắn hơn được update trước đó) thì bỏ qua
    final bestDistToCurrent = distances[current.id] ?? double.infinity;
    if (current.dist > bestDistToCurrent) continue;

    final edges = graphData.adjacency[current.id] ?? [];

    for (final edge in edges) {
      final neighborId = edge.to;
      final newDist = current.dist + edge.distM;
      final bestDistToNeighbor = distances[neighborId] ?? double.infinity;

      if (newDist < bestDistToNeighbor) {
        distances[neighborId] = newDist;
        previous[neighborId] = _PathData(current.id, edge.distM, edge.roadName);
        pq.add(_DijkstraNode(neighborId, newDist));
      }
    }
  }

  if (!found) return []; // Không có đường đi

  // 3. Reconstruct Path (từ destination ngược về origin)
  final pathIds = <int>[];
  final edgesPath = <_PathData>[];
  
  int currId = destination.id;
  while (currId != origin.id) {
    pathIds.add(currId);
    final pData = previous[currId]!;
    edgesPath.add(pData);
    currId = pData.prevId;
  }
  pathIds.add(origin.id);
  
  pathIds.reversed.toList();
  final pathEdgesReversed = edgesPath.reversed.toList();

  // 4. Build Navigation Steps
  return _buildSteps(graphData.nodes, pathIds.reversed.toList(), pathEdgesReversed);
}

class _DijkstraNode {
  final int id;
  final double dist;
  _DijkstraNode(this.id, this.dist);
}

class _PathData {
  final int prevId;
  final double distM;
  final String roadName;
  _PathData(this.prevId, this.distM, this.roadName);
}

List<NavigationStep> _buildSteps(List<GraphNode> allNodes, List<int> pathIds, List<_PathData> pathEdges) {
  final steps = <NavigationStep>[];
  final nodeMap = {for (var n in allNodes) n.id: n};

  double currentBearing = 0.0;

  for (int i = 0; i < pathEdges.length; i++) {
    final edge = pathEdges[i];
    final fromNodeId = pathIds[i];
    final toNodeId = pathIds[i + 1];
    
    final fromNode = nodeMap[fromNodeId]!;
    final toNode = nodeMap[toNodeId]!;

    final bearingToNext = _calculateBearing(fromNode.lat, fromNode.lng, toNode.lat, toNode.lng);

    String instruction;
    if (i == 0) {
      instruction = 'Bắt đầu di chuyển. Đi thẳng ${edge.distM.toStringAsFixed(0)} mét'
          '${edge.roadName.isNotEmpty ? ' vào ${edge.roadName}' : ''}.';
    } else {
      final delta = bearingToNext - currentBearing;
      instruction = '${_bearingToInstruction(delta, edge.roadName)}, đi tiếp ${edge.distM.toStringAsFixed(0)} mét.';
    }

    steps.add(NavigationStep(
      instruction: instruction,
      distanceM: edge.distM,
      bearing: bearingToNext,
    ));

    currentBearing = bearingToNext;
  }

  steps.add(const NavigationStep(instruction: 'Bạn đã đến nơi.', distanceM: 0, bearing: 0));
  return steps;
}

String _bearingToInstruction(double delta, String roadName) {
  // delta = bearing_to_next - current_bearing, normalized [-180, 180]
  final d = ((delta + 540) % 360) - 180;
  
  final rn = roadName.isNotEmpty ? ' vào $roadName' : '';
  
  if (d.abs() < 20)             return 'Đi thẳng$rn';
  if (d > 20 && d < 80)         return 'Rẽ nhẹ phải$rn';
  if (d >= 80 && d < 150)       return 'Rẽ phải$rn';
  if (d >= 150)                 return 'Quay đầu';
  if (d < -20 && d > -80)       return 'Rẽ nhẹ trái$rn';
  if (d <= -80 && d > -150)     return 'Rẽ trái$rn';
  return 'Quay đầu';
}

double _calculateBearing(double startLat, double startLng, double destLat, double destLng) {
  final lat1 = startLat * math.pi / 180.0;
  final lat2 = destLat * math.pi / 180.0;
  final dLng = (destLng - startLng) * math.pi / 180.0;

  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final brng = math.atan2(y, x);

  return (brng * 180.0 / math.pi + 360.0) % 360.0;
}
