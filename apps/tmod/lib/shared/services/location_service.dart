/// SaViCam T-Mod — Location Service
///
/// GPS wrapper that streams coordinates for SOS and telemetry features.
/// Provides a simple interface over the platform's location services.
///
/// In production, this will use `geolocator` or direct MethodChannel
/// to Android LocationManager. For MVP, provides mock locations.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Represents a geographic coordinate with accuracy metadata.
class GeoPosition {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  const GeoPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  /// Da Nang default position for stub/testing.
  factory GeoPosition.daNangDefault() => GeoPosition(
        latitude: 16.0544,
        longitude: 108.2022,
        accuracy: 10.0,
        timestamp: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() =>
      'GeoPosition($latitude, $longitude, accuracy: ${accuracy}m)';
}

/// Abstract interface for location services.
/// Enables mock injection for testing.
abstract class LocationService {
  /// Gets the current GPS position.
  /// Throws [LocationServiceException] if unavailable.
  Future<GeoPosition> getCurrentPosition();

  /// Streams position updates at the specified [interval].
  Stream<GeoPosition> getPositionStream({
    Duration interval = const Duration(seconds: 5),
  });

  /// Checks if location permission is granted.
  Future<bool> hasPermission();

  /// Requests location permission from the user.
  Future<bool> requestPermission();

  /// Disposes resources.
  void dispose();
}

/// Mock implementation for development and testing.
///
/// Returns positions around Da Nang with slight random drift
/// to simulate movement.
class MockLocationService implements LocationService {
  StreamController<GeoPosition>? _positionController;
  Timer? _timer;

  // Base position (Da Nang city center)
  double _lat = 16.0544;
  double _lng = 108.2022;

  @override
  Future<GeoPosition> getCurrentPosition() async {
    debugPrint('[MockLocation] getCurrentPosition: $_lat, $_lng');
    return GeoPosition(
      latitude: _lat,
      longitude: _lng,
      accuracy: 10.0,
      timestamp: DateTime.now(),
    );
  }

  @override
  Stream<GeoPosition> getPositionStream({
    Duration interval = const Duration(seconds: 5),
  }) {
    _positionController?.close();
    _positionController = StreamController<GeoPosition>.broadcast();

    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      // Simulate slight movement (walking speed ~1.4 m/s)
      _lat += 0.00001 * (DateTime.now().millisecond % 3 - 1);
      _lng += 0.00001 * (DateTime.now().millisecond % 3 - 1);

      final position = GeoPosition(
        latitude: _lat,
        longitude: _lng,
        accuracy: 10.0,
        timestamp: DateTime.now(),
      );

      _positionController?.add(position);
    });

    return _positionController!.stream;
  }

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  void dispose() {
    _timer?.cancel();
    _positionController?.close();
  }
}

/// Exception thrown when location services are unavailable.
class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}
