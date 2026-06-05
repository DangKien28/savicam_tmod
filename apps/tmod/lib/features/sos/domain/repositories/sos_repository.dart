/// SaViCam T-Mod — SOS Repository Interface (Domain Layer)
///
/// Defines the contract for SOS data operations. The domain layer
/// depends only on this interface — never on concrete implementations.
///
/// Implementations:
/// - [SosRepositoryImpl] in `data/repositories/` (production)
/// - Mock repository for unit tests
library;

import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_failures.dart';
import '../entities/sos_event.dart';

/// Repository contract for SOS event operations.
abstract class SosRepository {
  /// Triggers an SOS event.
  ///
  /// Attempts to write to Supabase `sos_events` table.
  /// If offline (ConnectivityResult.none), falls back to local
  /// SQLite `offline_queue` table.
  ///
  /// Returns [Right(void)] on success or [Left(Failure)] on error.
  /// Even on cloud failure, the event should be queued locally.
  Future<Either<Failure, void>> triggerSos(SosEvent event);

  /// Returns all SOS events currently queued locally (not yet synced).
  Future<Either<Failure, List<SosEvent>>> getOfflineQueue();

  /// Attempts to sync all queued offline events to the cloud.
  ///
  /// Returns the number of events successfully synced.
  /// Events that fail to sync remain in the queue for retry.
  Future<Either<Failure, int>> flushOfflineQueue();

  /// Returns the most recent SOS event (for status display).
  Future<Either<Failure, SosEvent?>> getLastSosEvent();
}
