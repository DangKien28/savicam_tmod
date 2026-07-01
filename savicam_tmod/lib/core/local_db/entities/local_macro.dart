/// Entity: bản sao cục bộ của location_macros (Supabase).
/// lat & lng là field riêng biệt (Float) — nhất quán với schema NCKH doc.
class LocalMacro {
  final int? id;
  final String keyword;
  final String actionType; // "navigate" | "locate" | ...
  final double lat;
  final double lng;

  const LocalMacro({
    this.id,
    required this.keyword,
    required this.actionType,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'keyword': keyword,
    'actionType': actionType,
    'lat': lat,
    'lng': lng,
  };

  factory LocalMacro.fromMap(Map<String, dynamic> m) => LocalMacro(
    id: m['id'] as int?,
    keyword: m['keyword'] as String? ?? '',
    actionType: m['actionType'] as String? ?? 'navigate',
    lat: (m['lat'] as num?)?.toDouble() ?? 0.0,
    lng: (m['lng'] as num?)?.toDouble() ?? 0.0,
  );
}
