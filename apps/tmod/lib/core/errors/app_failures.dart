/// SaViCam T-Mod — Application Failure Types
///
/// Typed failure classes for functional error handling via `dartz.Either`.
/// Each failure carries a human-readable [message] for logging and a
/// machine-readable type for BLoC state transitions.
library;

import 'package:equatable/equatable.dart';

/// Base class for all application failures.
/// Extends [Equatable] to enable value-based comparison in tests.
abstract class Failure extends Equatable {
  final String message;
  final String? debugInfo;

  const Failure({required this.message, this.debugInfo});

  @override
  List<Object?> get props => [message, debugInfo];
}

/// Failure originating from a MethodChannel call to native code.
class ChannelFailure extends Failure {
  final String channelName;

  const ChannelFailure({
    required super.message,
    required this.channelName,
    super.debugInfo,
  });

  @override
  List<Object?> get props => [message, channelName, debugInfo];
}

/// Failure originating from SQLite database operations.
class DatabaseFailure extends Failure {
  final String? tableName;

  const DatabaseFailure({
    required super.message,
    this.tableName,
    super.debugInfo,
  });

  @override
  List<Object?> get props => [message, tableName, debugInfo];
}

/// Failure originating from GPS/location services.
class LocationFailure extends Failure {
  const LocationFailure({
    required super.message,
    super.debugInfo,
  });
}

/// Failure originating from cloud sync (Supabase).
/// Non-blocking for offline-first architecture.
class CloudSyncFailure extends Failure {
  final int? httpStatusCode;

  const CloudSyncFailure({
    required super.message,
    this.httpStatusCode,
    super.debugInfo,
  });

  @override
  List<Object?> get props => [message, httpStatusCode, debugInfo];
}

/// Failure from the SOS system specifically.
/// Safety-critical: these must be logged even if the UI cannot display them.
class SosFailure extends Failure {
  final bool wasQueuedLocally;

  const SosFailure({
    required super.message,
    this.wasQueuedLocally = false,
    super.debugInfo,
  });

  @override
  List<Object?> get props => [message, wasQueuedLocally, debugInfo];
}
