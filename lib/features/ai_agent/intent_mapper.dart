import 'dart:convert';
import 'package:flutter/services.dart';

/// Rule-based NLP: Sửa lỗi chính tả (Levenshtein) + Ánh xạ intent
class IntentMapper {
  Map<String, String> _corrections = {};

  Future<void> loadDictionary() async {
    try {
      final raw = await rootBundle.loadString('assets/dict/fasttext_vi_core.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      _corrections = Map<String, String>.from(data['corrections'] ?? {});
    } catch (_) {
      _corrections = {};
    }
  }

  /// Sửa lỗi chính tả bằng Levenshtein distance
  String correctSpelling(String input) {
    final words = input.toLowerCase().split(' ');
    return words.map((w) {
      if (_corrections.containsKey(w)) return _corrections[w]!;
      String best = w;
      int bestDist = 3; // Ngưỡng tối đa
      for (final entry in _corrections.entries) {
        final d = _levenshtein(w, entry.key);
        if (d < bestDist) {
          bestDist = d;
          best = entry.value;
        }
      }
      return best;
    }).join(' ');
  }

  /// Ánh xạ câu nói đã sửa lỗi → action intent
  String mapToAction(String corrected) {
    final s = corrected.toLowerCase();
    if (s.contains('cứu') || s.contains('khẩn cấp')) return 'SOS';
    if (s.contains('đi') || s.contains('rẽ') || s.contains('chỉ đường')) return 'NAVIGATE';
    if (s.contains('dừng') || s.contains('tắt')) return 'STOP';
    return 'UNKNOWN';
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final v = List.generate(b.length + 1, (i) => i);
    for (int i = 0; i < a.length; i++) {
      var prev = v[0];
      v[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        final tmp = v[j + 1];
        v[j + 1] = [v[j] + 1, v[j + 1] + 1, prev + cost].reduce((a, b) => a < b ? a : b);
        prev = tmp;
      }
    }
    return v[b.length];
  }
}
