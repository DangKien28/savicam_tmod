import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Dịch vụ lấy vị trí GPS cho SOS & Navigation
class LocationService {
  StreamSubscription<Position>? _positionStream;
  Position? lastKnownPosition;

  /// Kiểm tra và yêu cầu quyền vị trí
  Future<bool> ensurePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  /// Lấy vị trí hiện tại 1 lần
  Future<Position?> getCurrentPosition() async {
    if (!await ensurePermissions()) return null;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    lastKnownPosition = pos;
    return pos;
  }

  /// Bắt đầu stream vị trí liên tục (cho SOS tracking)
  void startTracking(void Function(Position) onPosition) {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Cập nhật mỗi 5 mét
      ),
    ).listen((pos) {
      lastKnownPosition = pos;
      onPosition(pos);
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}
