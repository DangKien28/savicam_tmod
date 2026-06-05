/// SaViCam T-Mod — SOS Event Data Model
///
/// Serialization layer for [SosEvent] domain entity.
/// Handles conversion between domain entities, JSON (Supabase),
/// and SQLite maps.
///
/// See CONTRACT-03 for the `sos_events` table schema.
library;

import '../../domain/entities/sos_event.dart';

/// Data model with serialization support for [SosEvent].
class SosEventModel extends SosEvent {
  const SosEventModel({
    required super.id,
    required super.latitude,
    required super.longitude,
    required super.triggeredAt,
    super.resolved,
    super.deviceId,
  });

  /// Creates a model from a domain entity.
  factory SosEventModel.fromEntity(SosEvent entity) {
    return SosEventModel(
      id: entity.id,
      latitude: entity.latitude,
      longitude: entity.longitude,
      triggeredAt: entity.triggeredAt,
      resolved: entity.resolved,
      deviceId: entity.deviceId,
    );
  }

  /// Creates a model from Supabase JSON response.
  ///
  /// Expected format (from CONTRACT-03):
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "device_id": "uuid",
  ///   "lat": 16.0544,
  ///   "lng": 108.2022,
  ///   "triggered_at": "2025-01-01T10:05:00Z",
  ///   "resolved": false
  /// }
  /// ```
  factory SosEventModel.fromJson(Map<String, dynamic> json) {
    return SosEventModel(
      id: json['id'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      triggeredAt: DateTime.parse(json['triggered_at'] as String),
      resolved: json['resolved'] as bool? ?? false,
      deviceId: json['device_id'] as String?,
    );
  }

  /// Converts to JSON for Supabase INSERT.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': latitude,
      'lng': longitude,
      'triggered_at': triggeredAt.toIso8601String(),
      'resolved': resolved,
      if (deviceId != null) 'device_id': deviceId,
    };
  }

  /// Creates a model from SQLite row map.
  factory SosEventModel.fromSqliteMap(Map<String, dynamic> map) {
    return SosEventModel(
      id: map['id'] as String? ?? '',
      latitude: (map['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['lng'] as num?)?.toDouble() ?? 0.0,
      triggeredAt: map['triggered_at'] != null
          ? DateTime.parse(map['triggered_at'] as String)
          : DateTime.now(),
      resolved: (map['resolved'] as int?) == 1,
      deviceId: map['device_id'] as String?,
    );
  }

  /// Converts to SQLite-compatible map for INSERT.
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'lat': latitude,
      'lng': longitude,
      'triggered_at': triggeredAt.toIso8601String(),
      'resolved': resolved ? 1 : 0,
      'device_id': deviceId,
    };
  }

  /// Converts back to a pure domain entity.
  SosEvent toEntity() {
    return SosEvent(
      id: id,
      latitude: latitude,
      longitude: longitude,
      triggeredAt: triggeredAt,
      resolved: resolved,
      deviceId: deviceId,
    );
  }
}
