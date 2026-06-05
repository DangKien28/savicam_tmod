/// SaViCam T-Mod — Supabase SOS Data Source (Stub)
///
/// Cloud data source for writing SOS events to Supabase `sos_events`.
/// Currently a **stub implementation** per ARCH-07 (Stub-First Mandate).
///
/// The real Supabase client will be wired in Week 2 when DEV-04
/// delivers the deployed schema (CONTRACT-03).
///
/// Stub behavior: simulates a cloud write with a small delay,
/// returns success. Configurable to simulate failures for testing.
library;

import 'package:flutter/foundation.dart';

import '../models/sos_event_model.dart';

/// Data source for Supabase `sos_events` table operations.
///
/// Current status: STUB (Week 1)
/// Real implementation: Wire `supabase.from('sos_events').insert()`
abstract class SupabaseSosSource {
  /// Inserts an SOS event into the cloud `sos_events` table.
  /// Returns `true` on success, `false` on failure.
  Future<bool> insertSosEvent(SosEventModel event);

  /// Marks an SOS event as resolved in the cloud.
  Future<bool> resolveEvent(String eventId);
}

/// Stub implementation for development without a live Supabase connection.
///
/// See ARCH-07: Stubs must be merged to `main` before any feature branch.
/// See CONTRACT-03: SQLite mirror tables allow offline development.
class StubSupabaseSosSource implements SupabaseSosSource {
  /// If true, simulates a cloud failure for testing offline fallback.
  final bool simulateFailure;

  /// Simulated network latency.
  final Duration simulatedLatency;

  const StubSupabaseSosSource({
    this.simulateFailure = false,
    this.simulatedLatency = const Duration(milliseconds: 300),
  });

  @override
  Future<bool> insertSosEvent(SosEventModel event) async {
    debugPrint('[StubSupabase] INSERT sos_events: ${event.toJson()}');

    // Simulate network latency
    await Future.delayed(simulatedLatency);

    if (simulateFailure) {
      debugPrint('[StubSupabase] Simulated failure — event will be queued');
      return false;
    }

    debugPrint('[StubSupabase] Event inserted successfully (stub)');
    return true;
  }

  @override
  Future<bool> resolveEvent(String eventId) async {
    debugPrint('[StubSupabase] RESOLVE sos_events: $eventId');
    await Future.delayed(simulatedLatency);

    if (simulateFailure) return false;

    debugPrint('[StubSupabase] Event resolved successfully (stub)');
    return true;
  }
}
