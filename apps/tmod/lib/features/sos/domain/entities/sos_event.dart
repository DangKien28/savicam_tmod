/// SaViCam T-Mod — SOS Event Domain Entity
///
/// Represents an SOS emergency event triggered by the visually impaired
/// user. This is the core domain object — free of any framework or
/// serialization dependencies.
///
/// See CONTRACT-03 for the Supabase `sos_events` table schema.
library;

import 'package:equatable/equatable.dart';

/// An SOS emergency event.
///
/// Created when the user successfully holds the SOS zone for 3-5 seconds.
/// Contains GPS coordinates and timestamp for guardian notification.
class SosEvent extends Equatable {
  /// Unique identifier (UUID format when synced to cloud).
  final String id;

  /// GPS latitude at time of trigger.
  final double latitude;

  /// GPS longitude at time of trigger.
  final double longitude;

  /// When the SOS was triggered (device local time).
  final DateTime triggeredAt;

  /// Whether a guardian has acknowledged and resolved the alert.
  final bool resolved;

  /// Device ID that generated this SOS (for multi-device scenarios).
  final String? deviceId;

  const SosEvent({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.triggeredAt,
    this.resolved = false,
    this.deviceId,
  });

  /// Creates a copy with modified fields.
  SosEvent copyWith({
    String? id,
    double? latitude,
    double? longitude,
    DateTime? triggeredAt,
    bool? resolved,
    String? deviceId,
  }) {
    return SosEvent(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      resolved: resolved ?? this.resolved,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        latitude,
        longitude,
        triggeredAt,
        resolved,
        deviceId,
      ];

  @override
  String toString() =>
      'SosEvent(id: $id, lat: $latitude, lng: $longitude, '
      'triggeredAt: $triggeredAt, resolved: $resolved)';
}
