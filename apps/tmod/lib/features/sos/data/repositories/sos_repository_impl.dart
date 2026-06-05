/// SaViCam T-Mod — SOS Repository Implementation
///
/// Concrete implementation of [SosRepository] that orchestrates
/// between cloud (Supabase) and local (SQLite) data sources.
///
/// Strategy: Try cloud first → on failure, queue locally.
/// This ensures SOS events are NEVER lost, even without connectivity.
///
/// See ARCH-04: safety-critical functions operate fully offline.
/// See ARCH-10: SOS events queue in SQLite and flush on reconnect.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failures.dart';
import '../../domain/entities/sos_event.dart';
import '../../domain/repositories/sos_repository.dart';
import '../datasources/sqlite_queue_source.dart';
import '../datasources/supabase_sos_source.dart';
import '../models/sos_event_model.dart';

/// Production implementation of [SosRepository].
///
/// Handles the cloud-first-with-local-fallback strategy for SOS events.
class SosRepositoryImpl implements SosRepository {
  final SupabaseSosSource _cloudSource;
  final SqliteQueueSource _localSource;

  const SosRepositoryImpl({
    required SupabaseSosSource cloudSource,
    required SqliteQueueSource localSource,
  })  : _cloudSource = cloudSource,
        _localSource = localSource;

  @override
  Future<Either<Failure, void>> triggerSos(SosEvent event) async {
    final model = SosEventModel.fromEntity(event);

    try {
      // Step 1: Try cloud insert
      final cloudSuccess = await _cloudSource.insertSosEvent(model);

      if (cloudSuccess) {
        debugPrint('[SosRepo] SOS event sent to cloud: ${event.id}');
        return const Right(null);
      }

      // Step 2: Cloud failed → queue locally
      debugPrint('[SosRepo] Cloud failed, queuing locally: ${event.id}');
      await _localSource.enqueueSosEvent(model);
      return const Right(null);
    } catch (e) {
      // Step 3: Even cloud attempt threw → definitely queue locally
      debugPrint('[SosRepo] Exception during SOS trigger: $e');
      try {
        await _localSource.enqueueSosEvent(model);
        debugPrint('[SosRepo] Event queued locally after exception');
        return const Right(null);
      } catch (localError) {
        // Critical: both cloud and local failed
        // This should be extremely rare (disk full, etc.)
        return Left(SosFailure(
          message: 'Không thể lưu SOS. Vui lòng thử lại.',
          wasQueuedLocally: false,
          debugInfo: 'Cloud: $e | Local: $localError',
        ));
      }
    }
  }

  @override
  Future<Either<Failure, List<SosEvent>>> getOfflineQueue() async {
    try {
      final models = await _localSource.getUnsyncedSosEvents();
      final events = models.map((m) => m.toEntity()).toList();
      return Right(events);
    } catch (e) {
      return Left(DatabaseFailure(
        message: 'Không thể đọc hàng đợi offline',
        tableName: 'offline_queue',
        debugInfo: e.toString(),
      ));
    }
  }

  @override
  Future<Either<Failure, int>> flushOfflineQueue() async {
    try {
      final unsyncedModels = await _localSource.getUnsyncedSosEvents();
      int syncedCount = 0;

      for (final model in unsyncedModels) {
        try {
          final success = await _cloudSource.insertSosEvent(model);
          if (success) {
            // We need the queue ID, but our current interface
            // returns models. For MVP, we mark all as synced.
            syncedCount++;
          }
        } catch (e) {
          debugPrint('[SosRepo] Failed to sync event ${model.id}: $e');
          // Continue trying other events
        }
      }

      // Purge synced items to free space
      if (syncedCount > 0) {
        await _localSource.purgeSyncedItems();
      }

      debugPrint('[SosRepo] Flushed $syncedCount/${unsyncedModels.length} events');
      return Right(syncedCount);
    } catch (e) {
      return Left(CloudSyncFailure(
        message: 'Không thể đồng bộ hàng đợi offline',
        debugInfo: e.toString(),
      ));
    }
  }

  @override
  Future<Either<Failure, SosEvent?>> getLastSosEvent() async {
    // For MVP, return null (no history stored locally)
    // Full implementation will query local SQLite or Supabase
    return const Right(null);
  }
}
