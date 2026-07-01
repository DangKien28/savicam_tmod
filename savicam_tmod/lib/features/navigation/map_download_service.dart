import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import '../../core/services/file_storage_service.dart';
import 'models/map_manifest.dart';
import 'models/navigation_exception.dart';

class MapDownloadService {
  final FileStorageService _storage;
  
  // URL giả định trên R2
  static const String baseUrl = 'https://r2.savicam.vn/map';

  final ValueNotifier<double> downloadProgress = ValueNotifier(0.0);
  final ValueNotifier<bool> isDownloading = ValueNotifier(false);

  MapDownloadService(this._storage);

  /// Trả về true nếu tải (hoặc đã có) thành công, false nếu lỗi.
  Future<bool> downloadIfNeeded(String regionId) async {
    isDownloading.value = true;
    downloadProgress.value = 0.0;

    try {
      // 1. Check local manifest nếu có
      MapManifest? localManifest;
      final localManifestBytes = await _storage.readFile('offline_maps/${regionId}_manifest.json');
      if (localManifestBytes != null) {
        localManifest = MapManifest.fromJson(jsonDecode(utf8.decode(localManifestBytes)));
      }

      // 2. Fetch remote manifest
      final remoteManifestRes = await http.get(Uri.parse('$baseUrl/${regionId}_manifest.json'));
      if (remoteManifestRes.statusCode != 200) {
        // Không tải được manifest, nếu đã có local thì dùng tạm local, nếu không thì fail.
        return localManifest != null;
      }
      
      final remoteManifest = MapManifest.fromJson(jsonDecode(remoteManifestRes.body));

      // 3. Compare version
      if (localManifest != null && localManifest.version >= remoteManifest.version) {
        final zipExists = await _storage.fileExists('offline_maps/$regionId.zip');
        if (zipExists) {
          isDownloading.value = false;
          return true; // Đã có phiên bản mới nhất
        }
      }

      // 4. Stream download ZIP
      final zipUrl = '$baseUrl/$regionId.zip';
      final request = http.Request('GET', Uri.parse(zipUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw NavigationException('download_failed', 'HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 1;
      int bytesReceived = 0;
      final List<int> zipBytes = [];

      await for (final chunk in response.stream) {
        zipBytes.addAll(chunk);
        bytesReceived += chunk.length;
        downloadProgress.value = bytesReceived / contentLength;
      }

      // 5. Verify SHA-256
      final hash = sha256.convert(zipBytes).toString();
      if (hash != remoteManifest.sha256) {
        throw NavigationException('integrity_failed', 'SHA-256 mismatch');
      }

      // 6. Save files
      await _storage.saveFile('offline_maps/$regionId.zip', zipBytes);
      await _storage.saveFile('offline_maps/${regionId}_manifest.json', remoteManifestRes.bodyBytes);

      return true;
    } catch (e) {
      debugPrint('MapDownloadError: $e');
      return false;
    } finally {
      isDownloading.value = false;
    }
  }
}
