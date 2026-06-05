/// SaViCam T-Mod — Flush Offline Queue Use Case
///
/// Syncs all locally-queued SOS events and telemetry to the cloud
/// when connectivity is restored. Called automatically by the
/// connectivity listener or manually via settings.
///
/// See ARCH-04: All safety-critical functions operate fully offline;
/// cloud sync is best-effort and never blocks the user.
library;

import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_failures.dart';
import '../repositories/sos_repository.dart';

/// Use case: Flush the offline queue to the cloud.
///
/// Returns the number of events successfully synced.
class FlushOfflineQueue {
  final SosRepository _repository;

  const FlushOfflineQueue({required SosRepository repository})
      : _repository = repository;

  /// Attempts to sync all queued events.
  ///
  /// Returns [Right(int)] with count of synced events,
  /// or [Left(Failure)] if the flush operation itself fails.
  /// Individual event sync failures are handled internally
  /// by the repository (retry logic).
  Future<Either<Failure, int>> call() async {
    return _repository.flushOfflineQueue();
  }
}
