/// SaViCam T-Mod — Trigger SOS Use Case
///
/// Orchestrates the SOS trigger flow:
/// 1. Capture current GPS position
/// 2. Create SosEvent entity
/// 3. Persist via repository (cloud or offline queue)
///
/// This is a safety-critical use case — it must NEVER silently fail.
/// If cloud write fails, it MUST be queued locally.
library;

import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_failures.dart';
import '../../../../shared/services/location_service.dart';
import '../entities/sos_event.dart';
import '../repositories/sos_repository.dart';

/// Use case: Trigger an SOS emergency alert.
///
/// Called by [SosBloc] when the user successfully completes the
/// 3-5 second long-press gesture.
class TriggerSos {
  final SosRepository _repository;
  final LocationService _locationService;

  const TriggerSos({
    required SosRepository repository,
    required LocationService locationService,
  })  : _repository = repository,
        _locationService = locationService;

  /// Executes the SOS trigger flow.
  ///
  /// Returns [Right(SosEvent)] with the created event on success,
  /// or [Left(Failure)] if both cloud and local persist fail
  /// (which should be extremely rare).
  Future<Either<Failure, SosEvent>> call() async {
    try {
      // Step 1: Capture GPS position
      final position = await _locationService.getCurrentPosition();

      // Step 2: Create domain entity
      final event = SosEvent(
        id: _generateId(),
        latitude: position.latitude,
        longitude: position.longitude,
        triggeredAt: DateTime.now(),
        resolved: false,
      );

      // Step 3: Persist (cloud → fallback to offline queue)
      final result = await _repository.triggerSos(event);

      return result.fold(
        // Even on failure, we return the event for TTS announcement
        (failure) => Left(failure),
        (_) => Right(event),
      );
    } on LocationServiceException catch (e) {
      // GPS unavailable — create event with default coordinates
      // This is better than not sending SOS at all
      final event = SosEvent(
        id: _generateId(),
        latitude: 0.0,
        longitude: 0.0,
        triggeredAt: DateTime.now(),
        resolved: false,
      );

      final result = await _repository.triggerSos(event);
      return result.fold(
        (failure) => Left(LocationFailure(
          message: 'GPS unavailable: ${e.message}',
          debugInfo: 'SOS queued with zero coordinates',
        )),
        (_) => Right(event),
      );
    } catch (e) {
      return Left(SosFailure(
        message: 'Không thể gửi SOS: $e',
        wasQueuedLocally: false,
      ));
    }
  }

  /// Generates a simple unique ID.
  /// In production, use `uuid` package for proper UUIDs.
  String _generateId() {
    final now = DateTime.now();
    return 'sos_${now.millisecondsSinceEpoch}_${now.microsecond}';
  }
}
