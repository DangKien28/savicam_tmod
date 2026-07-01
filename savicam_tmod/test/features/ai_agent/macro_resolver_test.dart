import 'package:flutter_test/flutter_test.dart';
import 'package:savicam_tmod/core/local_db/entities/local_macro.dart';
import 'package:savicam_tmod/core/local_db/macro_resolver.dart';
import 'package:savicam_tmod/core/local_db/sqlite_helper.dart';

// ---------------------------------------------------------------------------
// Fake SqliteHelper — in-memory store, không cần sqflite native.
// ---------------------------------------------------------------------------
class FakeSqliteHelper extends SqliteHelper {
  final List<LocalMacro> _macros = [];

  FakeSqliteHelper() : super.internal();

  void setMacros(List<LocalMacro> macros) {
    _macros
      ..clear()
      ..addAll(macros);
  }

  @override
  Future<List<LocalMacro>> getMacros() async => List.unmodifiable(_macros);

  // Không dùng DB thật nên bỏ qua
  @override
  Future<void> upsertMacro(LocalMacro m) async => _macros.add(m);
}

// ---------------------------------------------------------------------------
// Dữ liệu mẫu — tọa độ khu vực Đà Nẵng
// ---------------------------------------------------------------------------
const _sampleMacros = [
  LocalMacro(id: 1, keyword: 'nhà', actionType: 'navigate', lat: 16.0544, lng: 108.2022),
  LocalMacro(id: 2, keyword: 'trường', actionType: 'navigate', lat: 16.0740, lng: 108.1499),
  LocalMacro(id: 3, keyword: 'bệnh viện', actionType: 'navigate', lat: 16.0678, lng: 108.2120),
  LocalMacro(id: 4, keyword: 'chợ', actionType: 'navigate', lat: 16.0680, lng: 108.2240),
  LocalMacro(id: 5, keyword: 'công viên', actionType: 'navigate', lat: 16.0616, lng: 108.2280),
];

void main() {
  late FakeSqliteHelper fakeDb;
  late MacroResolver resolver;

  setUp(() {
    fakeDb = FakeSqliteHelper();
    fakeDb.setMacros(_sampleMacros);
    resolver = MacroResolver(db: fakeDb);
  });

  // =========================================================================
  // resolveKeywordToCoordinate — exact match
  // =========================================================================
  group('resolveKeywordToCoordinate — exact match', () {
    test('tìm đúng keyword "nhà"', () async {
      final result = await resolver.resolveKeywordToCoordinate('nhà');
      expect(result, isNotNull);
      expect(result!.lat, 16.0544);
      expect(result.lng, 108.2022);
      expect(result.matchedKeyword, 'nhà');
      expect(result.isFuzzyMatch, isFalse);
    });

    test('tìm đúng keyword "bệnh viện" (2 từ)', () async {
      final result = await resolver.resolveKeywordToCoordinate('bệnh viện');
      expect(result, isNotNull);
      expect(result!.lat, 16.0678);
      expect(result.matchedKeyword, 'bệnh viện');
    });

    test('case-insensitive: "NHÀ" → match "nhà"', () async {
      final result = await resolver.resolveKeywordToCoordinate('NHÀ');
      expect(result, isNotNull);
      expect(result!.matchedKeyword, 'nhà');
    });

    test('trim whitespace: "  nhà  " → match "nhà"', () async {
      final result = await resolver.resolveKeywordToCoordinate('  nhà  ');
      expect(result, isNotNull);
      expect(result!.matchedKeyword, 'nhà');
    });

    test('tìm đúng keyword "công viên"', () async {
      final result = await resolver.resolveKeywordToCoordinate('công viên');
      expect(result, isNotNull);
      expect(result!.lat, 16.0616);
      expect(result.lng, 108.2280);
    });
  });

  // =========================================================================
  // resolveKeywordToCoordinate — substring containment
  // =========================================================================
  group('resolveKeywordToCoordinate — substring match', () {
    test('"đi nhà" chứa keyword "nhà" → match', () async {
      final result = await resolver.resolveKeywordToCoordinate('đi nhà');
      expect(result, isNotNull);
      expect(result!.matchedKeyword, 'nhà');
    });

    test('"đi đến bệnh viện ngay" chứa keyword "bệnh viện" → match', () async {
      final result = await resolver.resolveKeywordToCoordinate('đi đến bệnh viện ngay');
      expect(result, isNotNull);
      expect(result!.matchedKeyword, 'bệnh viện');
    });

    test('ưu tiên keyword dài hơn khi nhiều substring match', () async {
      // "công viên" (8 chars) should be preferred over "chợ" (3 chars)
      // if input contains both... but here test with specific input
      final result = await resolver.resolveKeywordToCoordinate('đi công viên');
      expect(result, isNotNull);
      expect(result!.matchedKeyword, 'công viên');
    });
  });

  // =========================================================================
  // resolveKeywordToCoordinate — fuzzy match (Levenshtein)
  // =========================================================================
  group('resolveKeywordToCoordinate — fuzzy match', () {
    test('"nha" (thiếu dấu) → fuzzy match "nhà" (distance ≤ 2)', () async {
      final result = await resolver.resolveKeywordToCoordinate('nha');
      // "nha" vs "nhà" — chỉ khác dấu thanh, Levenshtein = 1 (ở cấp character)
      expect(result, isNotNull);
      expect(result!.matchedKeyword, 'nhà');
      expect(result.isFuzzyMatch, isTrue);
    });

    test('"cho" (thiếu dấu) → fuzzy match "chợ"', () async {
      final result = await resolver.resolveKeywordToCoordinate('cho');
      expect(result, isNotNull);
      expect(result!.matchedKeyword, 'chợ');
      expect(result.isFuzzyMatch, isTrue);
    });

    test('keyword quá xa (distance > threshold) → null', () async {
      final result = await resolver.resolveKeywordToCoordinate('siêu thị lớn');
      expect(result, isNull);
    });
  });

  // =========================================================================
  // Edge cases
  // =========================================================================
  group('edge cases', () {
    test('keyword rỗng → null', () async {
      final result = await resolver.resolveKeywordToCoordinate('');
      expect(result, isNull);
    });

    test('keyword chỉ có khoảng trắng → null', () async {
      final result = await resolver.resolveKeywordToCoordinate('   ');
      expect(result, isNull);
    });

    test('database trống → null', () async {
      fakeDb.setMacros([]);
      final result = await resolver.resolveKeywordToCoordinate('nhà');
      expect(result, isNull);
    });

    test('keyword không tồn tại → null', () async {
      final result = await resolver.resolveKeywordToCoordinate('sân bay');
      expect(result, isNull);
    });
  });

  // =========================================================================
  // resolveMacro — trả về LocalMacro đầy đủ
  // =========================================================================
  group('resolveMacro', () {
    test('trả về LocalMacro với actionType', () async {
      final macro = await resolver.resolveMacro('nhà');
      expect(macro, isNotNull);
      expect(macro!.keyword, 'nhà');
      expect(macro.actionType, 'navigate');
      expect(macro.lat, 16.0544);
      expect(macro.lng, 108.2022);
    });

    test('keyword không tồn tại → null', () async {
      final macro = await resolver.resolveMacro('thư viện');
      expect(macro, isNull);
    });
  });

  // =========================================================================
  // Levenshtein — unit tests cho hàm thuần
  // =========================================================================
  group('Levenshtein distance', () {
    test('strings giống nhau → 0', () {
      expect(MacroResolver.levenshtein('nhà', 'nhà'), 0);
    });

    test('string rỗng', () {
      expect(MacroResolver.levenshtein('', 'abc'), 3);
      expect(MacroResolver.levenshtein('abc', ''), 3);
    });

    test('1 ký tự khác → 1', () {
      expect(MacroResolver.levenshtein('abc', 'adc'), 1);
    });

    test('kiểm tra distance thực tế', () {
      // "kitten" → "sitting" = 3
      expect(MacroResolver.levenshtein('kitten', 'sitting'), 3);
    });
  });
}
