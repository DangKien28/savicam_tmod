import 'dart:math' as math;

class GraphNode {
  final int id;
  final double lat;
  final double lng;

  const GraphNode(this.id, this.lat, this.lng);

  factory GraphNode.fromJson(Map<String, dynamic> json) => GraphNode(
    json['id'] as int,
    (json['lat'] as num).toDouble(),
    (json['lng'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'id': id, 'lat': lat, 'lng': lng};
}

class GraphEdge {
  final int from;
  final int to;
  final double distM;
  final String roadName;

  const GraphEdge(this.from, this.to, this.distM, this.roadName);

  factory GraphEdge.fromJson(Map<String, dynamic> json) => GraphEdge(
    json['from'] as int,
    json['to'] as int,
    (json['dist_m'] as num).toDouble(),
    json['road_name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'dist_m': distM,
    'road_name': roadName,
  };
}

/// Dữ liệu truyền qua Isolate boundary.
/// Chỉ chứa primitives (List, Map, int, double, String).
class GraphTransferObject {
  final List<GraphNode> nodes;
  final Map<int, List<GraphEdge>> adjacency;
  final _SpatialGrid grid;

  const GraphTransferObject(this.nodes, this.adjacency, this.grid);
}

class OfflineGraph {
  final List<GraphNode> nodes;
  final Map<int, List<GraphEdge>> adjacency;
  late final _SpatialGrid _grid;

  OfflineGraph(this.nodes, this.adjacency) {
    _grid = _SpatialGrid(nodes);
  }

  factory OfflineGraph.fromJson(Map<String, dynamic> json) {
    final nodesList = (json['nodes'] as List<dynamic>)
        .map((e) => GraphNode.fromJson(e as Map<String, dynamic>))
        .toList();

    final edgesList = (json['edges'] as List<dynamic>)
        .map((e) => GraphEdge.fromJson(e as Map<String, dynamic>));

    final adjacencyMap = <int, List<GraphEdge>>{};
    for (final node in nodesList) {
      adjacencyMap[node.id] = [];
    }

    for (final edge in edgesList) {
      adjacencyMap[edge.from]?.add(edge);
      // Đồ thị vô hướng (người đi bộ)
      adjacencyMap[edge.to]?.add(
        GraphEdge(edge.to, edge.from, edge.distM, edge.roadName),
      );
    }

    return OfflineGraph(nodesList, adjacencyMap);
  }

  GraphNode nearestNode(double lat, double lng) => _grid.nearest(lat, lng);

  GraphTransferObject toTransferObject() =>
      GraphTransferObject(nodes, adjacency, _grid);
}

/// Spatial Grid Index chia Bounding Box thành các ô vuông nhỏ.
/// Giúp lookup `nearestNode()` đạt O(1) trung bình thay vì O(N).
class _SpatialGrid {
  static const double cellSizeDeg = 0.001; // ~100m tại xích đạo

  double minLat = 0.0;
  double minLng = 0.0;
  int cols = 0;
  final Map<int, List<GraphNode>> _cells = {};
  final List<GraphNode> _allNodes;

  _SpatialGrid(this._allNodes) {
    if (_allNodes.isEmpty) return;

    double tempMaxLat = -90.0;
    double tempMaxLng = -180.0;
    double tempMinLat = 90.0;
    double tempMinLng = 180.0;

    for (final n in _allNodes) {
      if (n.lat < tempMinLat) tempMinLat = n.lat;
      if (n.lat > tempMaxLat) tempMaxLat = n.lat;
      if (n.lng < tempMinLng) tempMinLng = n.lng;
      if (n.lng > tempMaxLng) tempMaxLng = n.lng;
    }

    minLat = tempMinLat;
    minLng = tempMinLng;
    cols = ((tempMaxLng - tempMinLng) / cellSizeDeg).ceil() + 1;

    for (final n in _allNodes) {
      final cellId = _getCellId(n.lat, n.lng);
      _cells.putIfAbsent(cellId, () => []).add(n);
    }
  }

  int _getCellId(double lat, double lng) {
    final row = ((lat - minLat) / cellSizeDeg).floor();
    final col = ((lng - minLng) / cellSizeDeg).floor();
    return row * cols + col;
  }

  GraphNode nearest(double lat, double lng) {
    if (_allNodes.isEmpty) throw StateError('Empty graph');

    final targetRow = ((lat - minLat) / cellSizeDeg).floor();
    final targetCol = ((lng - minLng) / cellSizeDeg).floor();

    GraphNode? bestNode;
    double bestDist = double.infinity;

    // Tìm trong ô hiện tại và 8 ô xung quanh (3x3)
    for (int r = targetRow - 1; r <= targetRow + 1; r++) {
      for (int c = targetCol - 1; c <= targetCol + 1; c++) {
        final cellId = r * cols + c;
        final nodesInCell = _cells[cellId];
        if (nodesInCell != null) {
          for (final n in nodesInCell) {
            final d = _haversine(lat, lng, n.lat, n.lng);
            if (d < bestDist) {
              bestDist = d;
              bestNode = n;
            }
          }
        }
      }
    }

    // Nếu grid thưa quá không có ai trong 3x3 (hiếm), fallback brute-force
    if (bestNode == null) {
      for (final n in _allNodes) {
        final d = _haversine(lat, lng, n.lat, n.lng);
        if (d < bestDist) {
          bestDist = d;
          bestNode = n;
        }
      }
    }

    return bestNode!;
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Bán kính TĐ (m)
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
