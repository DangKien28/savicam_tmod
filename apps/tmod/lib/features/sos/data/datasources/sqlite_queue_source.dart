/// SaViCam T-Mod — SQLite Queue Data Source
///
/// Local SQLite operations for the `offline_queue` table.
/// Buffers SOS events when the device is offline and provides
/// retrieval for sync when connectivity is restored.
///
/// See ARCH-04: cloud sync is best-effort and never blocks the user.
/// See ARCH-06: sqflite is the sole local storage engine.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../shared/database/sqlite_helper.dart';
import '../models/sos_event_model.dart';

/// Data source for local SQLite offline queue operations.
class SqliteQueueSource {
  final SqliteHelper _dbHelper;

  const SqliteQueueSource({required SqliteHelper dbHelper})
      : _dbHelper = dbHelper;

  /// Enqueues an SOS event to the offline queue.
  ///
  /// The event is serialized to JSON and stored with type 'sos'.
  /// Returns the queue item ID on success.
  Future<int> enqueueSosEvent(SosEventModel event) async {
    try {
      final payload = jsonEncode(event.toJson());
      return await _dbHelper.enqueue(
        eventType: 'sos',
        payload: payload,
      );
    } catch (e) {
      debugPrint('[SqliteQueueSource] Enqueue error: $e');
      rethrow;
    }
  }

  /// Retrieves all unsynced SOS events from the offline queue.
  ///
  /// Events are returned in chronological order (oldest first)
  /// to ensure correct ordering when flushing to cloud.
  Future<List<SosEventModel>> getUnsyncedSosEvents() async {
    try {
      final rows = await _dbHelper.getUnsyncedQueue();

      return rows
          .where((row) => row['event_type'] == 'sos')
          .map((row) {
            final payload = jsonDecode(row['payload'] as String);
            return SosEventModel.fromJson(
                payload as Map<String, dynamic>);
          })
          .toList();
    } catch (e) {
      debugPrint('[SqliteQueueSource] Get unsynced error: $e');
      rethrow;
    }
  }

  /// Marks a queue item as synced by its ID.
  Future<void> markSynced(int queueId) async {
    await _dbHelper.markSynced(queueId);
  }

  /// Records a sync failure for a queue item.
  Future<void> recordSyncError(int queueId, String error) async {
    await _dbHelper.recordSyncError(queueId, error);
  }

  /// Returns the count of unsynced items in the queue.
  Future<int> getUnsyncedCount() async {
    final rows = await _dbHelper.getUnsyncedQueue();
    return rows.length;
  }

  /// Purges all successfully synced items from the queue.
  Future<int> purgeSyncedItems() async {
    return _dbHelper.purgeSyncedItems();
  }
}
