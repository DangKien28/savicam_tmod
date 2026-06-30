import '../../core/network/api_client.dart';

/// Module định tuyến: gọi GraphHopper API hoặc đọc dữ liệu offline
class NavigationRepository {
  final ApiClient _api;

  NavigationRepository(this._api);

  /// Lấy chỉ dẫn đường đi từ API GraphHopper (online)
  Future<List<Map<String, dynamic>>?> getRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final result = await _api.get(
      '/route?point=$fromLat,$fromLng&point=$toLat,$toLng&profile=foot&locale=vi',
    );
    if (result == null) return null;
    // TODO: Parse GraphHopper response → list of instructions
    return [];
  }

  /// Lấy hướng dẫn giọng nói cho bước tiếp theo
  String getNextVoiceInstruction(List<Map<String, dynamic>> routeSteps, int currentStep) {
    if (currentStep >= routeSteps.length) return 'Bạn đã đến nơi.';
    // TODO: Parse instruction text từ routeSteps[currentStep]
    return 'Đi thẳng.';
  }
}
