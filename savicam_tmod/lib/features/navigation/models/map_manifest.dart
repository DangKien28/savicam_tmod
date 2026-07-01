/// Manifest mô tả metadata của file ZIP "Sổ tay lộ trình".
/// Parse từ manifest.json bên trong file .zip.
class MapManifest {
  final int version;
  final String region;

  /// Bounding box [minLat, minLng, maxLat, maxLng]
  final List<double> bbox;

  /// SHA-256 hex của file graph.json (để verify integrity sau giải nén)
  final String sha256;

  final DateTime generatedAt;

  const MapManifest({
    required this.version,
    required this.region,
    required this.bbox,
    required this.sha256,
    required this.generatedAt,
  });

  factory MapManifest.fromJson(Map<String, dynamic> json) => MapManifest(
    version: (json['version'] as num).toInt(),
    region: json['region'] as String,
    bbox: (json['bbox'] as List<dynamic>)
        .map((e) => (e as num).toDouble())
        .toList(),
    sha256: json['sha256'] as String? ?? '',
    generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'region': region,
    'bbox': bbox,
    'sha256': sha256,
    'generated_at': generatedAt.toIso8601String(),
  };
}
