import 'entities/local_macro.dart';
import 'sqlite_helper.dart';

/// Kết quả phân giải keyword → tọa độ GPS.
class ResolvedCoordinate {
  final double lat;
  final double lng;
  final String matchedKeyword;
  final bool isFuzzyMatch;

  const ResolvedCoordinate({
    required this.lat,
    required this.lng,
    required this.matchedKeyword,
    this.isFuzzyMatch = false,
  });

  @override
  String toString() =>
      'ResolvedCoordinate(lat: $lat, lng: $lng, keyword: "$matchedKeyword", fuzzy: $isFuzzyMatch)';
}

/// Tầng 3 — Logic Rule-based Mapping:
/// Nhận keyword (entity đã bóc tách từ Tầng 2 NLP) → tra bảng Local_Macros
/// → trả về tọa độ GPS cho GraphHopper / OfflineGraphEngine.
///
/// Chiến lược tìm kiếm:
///   1. Exact match (case-insensitive, trimmed)
///   2. Substring containment (VD: "đi nhà" match "nhà")
///   3. Fuzzy match bằng Levenshtein distance (ngưỡng ≤ 2)
class MacroResolver {
  final SqliteHelper _db;

  /// Ngưỡng Levenshtein distance tối đa cho fuzzy match.
  final int fuzzyThreshold;

  MacroResolver({
    SqliteHelper? db,
    this.fuzzyThreshold = 2,
  }) : _db = db ?? SqliteHelper.instance;

  /// Phân giải keyword → tọa độ GPS.
  ///
  /// Trả về [ResolvedCoordinate] nếu tìm thấy, `null` nếu không match.
  ///
  /// ```dart
  /// final resolver = MacroResolver();
  /// final coord = await resolver.resolveKeywordToCoordinate('nhà');
  /// if (coord != null) {
  ///   print('Điều hướng tới: ${coord.lat}, ${coord.lng}');
  /// }
  /// ```
  Future<ResolvedCoordinate?> resolveKeywordToCoordinate(String keyword) async {
    if (keyword.trim().isEmpty) return null;

    final macros = await _db.getMacros();
    if (macros.isEmpty) return null;

    final normalizedInput = _normalize(keyword);

    // --- Pass 1: Exact match (case-insensitive, trimmed) ---
    for (final m in macros) {
      if (_normalize(m.keyword) == normalizedInput) {
        return _toResult(m, isFuzzy: false);
      }
    }

    // --- Pass 2: Substring containment ---
    // VD: user nói "đi đến nhà", entity = "đi đến nhà", macro keyword = "nhà"
    // Ưu tiên macro có keyword dài nhất match (tránh "a" match mọi thứ).
    LocalMacro? bestSubstring;
    int bestSubstringLen = 0;
    for (final m in macros) {
      final normalizedMacro = _normalize(m.keyword);
      if (normalizedMacro.length > 1 &&
          normalizedInput.contains(normalizedMacro) &&
          normalizedMacro.length > bestSubstringLen) {
        bestSubstring = m;
        bestSubstringLen = normalizedMacro.length;
      }
    }
    // Cũng check chiều ngược: keyword ngắn hơn macro (VD: "nhà" match "nhà tôi")
    if (bestSubstring == null) {
      for (final m in macros) {
        final normalizedMacro = _normalize(m.keyword);
        if (normalizedInput.length > 1 &&
            normalizedMacro.contains(normalizedInput) &&
            normalizedInput.length > bestSubstringLen) {
          bestSubstring = m;
          bestSubstringLen = normalizedInput.length;
        }
      }
    }
    if (bestSubstring != null) {
      return _toResult(bestSubstring, isFuzzy: false);
    }

    // --- Pass 3: Fuzzy match (Levenshtein ≤ threshold) ---
    int bestDist = fuzzyThreshold + 1;
    LocalMacro? bestFuzzy;
    for (final m in macros) {
      final d = levenshtein(_normalize(m.keyword), normalizedInput);
      if (d <= fuzzyThreshold && d < bestDist) {
        bestDist = d;
        bestFuzzy = m;
      }
    }
    if (bestFuzzy != null) {
      return _toResult(bestFuzzy, isFuzzy: true);
    }

    return null;
  }

  /// Phân giải keyword và trả về [LocalMacro] đầy đủ (cho trường hợp cần
  /// actionType hoặc metadata khác ngoài tọa độ).
  Future<LocalMacro?> resolveMacro(String keyword) async {
    if (keyword.trim().isEmpty) return null;

    final macros = await _db.getMacros();
    if (macros.isEmpty) return null;

    final normalizedInput = _normalize(keyword);

    // Exact → Fuzzy pipeline (giống resolveKeywordToCoordinate)
    for (final m in macros) {
      if (_normalize(m.keyword) == normalizedInput) return m;
    }

    int bestDist = fuzzyThreshold + 1;
    LocalMacro? bestFuzzy;
    for (final m in macros) {
      final d = levenshtein(_normalize(m.keyword), normalizedInput);
      if (d <= fuzzyThreshold && d < bestDist) {
        bestDist = d;
        bestFuzzy = m;
      }
    }
    return bestFuzzy;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _normalize(String s) => s.toLowerCase().trim();

  ResolvedCoordinate _toResult(LocalMacro m, {required bool isFuzzy}) =>
      ResolvedCoordinate(
        lat: m.lat,
        lng: m.lng,
        matchedKeyword: m.keyword,
        isFuzzyMatch: isFuzzy,
      );

  /// Levenshtein distance — O(mn) classic DP.
  /// Public for reuse in IntentMapper nếu cần.
  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final v = List<int>.generate(b.length + 1, (i) => i);
    for (int i = 0; i < a.length; i++) {
      var prev = v[0];
      v[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        final tmp = v[j + 1];
        v[j + 1] = _min3(v[j] + 1, v[j + 1] + 1, prev + cost);
        prev = tmp;
      }
    }
    return v[b.length];
  }

  static int _min3(int a, int b, int c) {
    if (a <= b && a <= c) return a;
    return b <= c ? b : c;
  }
}
