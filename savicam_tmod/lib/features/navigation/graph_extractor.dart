import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';

import '../../core/services/file_storage_service.dart';
import 'models/offline_graph.dart';

class GraphExtractor {
  final FileStorageService _storage;

  GraphExtractor(this._storage);

  /// Giải nén và parse JSON trong một isolate khác để không block UI.
  Future<OfflineGraph?> extract(String regionId) async {
    final bytes = await _storage.readFile('offline_maps/$regionId.zip');
    if (bytes == null) return null;

    try {
      return await Isolate.run(() => _extractAndParse(bytes));
    } catch (e) {
      debugPrint('GraphExtractorError: $e');
      return null;
    }
  }
}

/// Top-level function chạy trong Isolate
OfflineGraph _extractAndParse(List<int> zipBytes) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  
  // 1. Tìm graph.json
  final graphFile = archive.findFile('graph.json');
  if (graphFile == null) {
    throw Exception('graph.json not found in ZIP');
  }
  
  // 2. Decode content (byte -> string -> json)
  final graphBytes = graphFile.content as List<int>;
  final jsonString = utf8.decode(graphBytes);
  final json = jsonDecode(jsonString) as Map<String, dynamic>;
  
  // 3. Xây dựng OfflineGraph (bao gồm build SpatialGrid)
  return OfflineGraph.fromJson(json);
}
