/// SaViCam T-Mod — SOS BLoC
///
/// Business logic component managing the SOS trigger state machine.
///
/// State flow:
/// ```
/// SosIdle → (hold start) → SosHolding → (release < 3s) → SosCancelled → SosIdle
///                                      → (release ≥ 3s) → SosTriggering → SosTriggered → SosIdle
///                                      → (5s reached)   → SosTriggering → SosTriggered → SosIdle
/// ```
///
/// Timer architecture:
/// - A periodic timer updates [SosHolding.progress] every 100ms
/// - At 5 seconds, [SosMaxHoldReached] auto-fires
/// - On release before 3 seconds, SOS is cancelled
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/sos_constants.dart';
import '../../domain/entities/sos_event.dart';
import '../../domain/usecases/flush_offline_queue.dart';
import '../../domain/usecases/trigger_sos.dart';
import 'sos_bloc_event.dart';
import 'sos_bloc_state.dart';

/// BLoC managing the SOS trigger lifecycle.
class SosBloc extends Bloc<SosBlocEvent, SosBlocState> {
  final TriggerSos _triggerSos;
  final FlushOfflineQueue _flushOfflineQueue;

  /// Periodic timer that updates hold progress.
  Timer? _holdTimer;

  /// Timestamp when the hold began.
  DateTime? _holdStartTime;

  /// Update interval for the progress indicator (100ms for smooth animation).
  static const _progressUpdateInterval = Duration(milliseconds: 100);

  SosBloc({
    required TriggerSos triggerSos,
    required FlushOfflineQueue flushOfflineQueue,
  })  : _triggerSos = triggerSos,
        _flushOfflineQueue = flushOfflineQueue,
        super(const SosIdle()) {
    on<SosHoldStarted>(_onHoldStarted);
    on<SosHoldReleased>(_onHoldReleased);
    on<SosMaxHoldReached>(_onMaxHoldReached);
    on<SosTriggerCompleted>(_onTriggerCompleted);
    on<SosFlushQueueRequested>(_onFlushQueue);
    on<SosReset>(_onReset);
  }

  /// Handles the start of a long-press on the SOS zone.
  void _onHoldStarted(
    SosHoldStarted event,
    Emitter<SosBlocState> emit,
  ) {
    // Only start from idle state
    if (state is! SosIdle) return;

    _holdStartTime = DateTime.now();
    debugPrint('[SosBloc] Hold started');

    // Emit initial holding state
    emit(const SosHolding(
      progress: 0.0,
      holdDuration: Duration.zero,
    ));

    // Start periodic progress updates
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(_progressUpdateInterval, (_) {
      if (_holdStartTime == null) return;

      final elapsed = DateTime.now().difference(_holdStartTime!);
      final maxDuration = SosConstants.maxHoldDuration;
      final progress = (elapsed.inMilliseconds / maxDuration.inMilliseconds)
          .clamp(0.0, 1.0);

      // Check if max hold duration reached (5 seconds)
      if (elapsed >= maxDuration) {
        _holdTimer?.cancel();
        add(const SosMaxHoldReached());
        return;
      }

      // Update progress
      // ignore: invalid_use_of_visible_for_testing_member
      emit(SosHolding(
        progress: progress,
        holdDuration: elapsed,
      ));
    });
  }

  /// Handles the release of the SOS zone.
  void _onHoldReleased(
    SosHoldReleased event,
    Emitter<SosBlocState> emit,
  ) {
    _holdTimer?.cancel();
    _holdStartTime = null;

    if (state is! SosHolding) return;

    final holdDuration = event.holdDuration;
    final minDuration = SosConstants.minHoldDuration;

    if (holdDuration < minDuration) {
      // Released too early → cancel (anti-accidental touch)
      debugPrint('[SosBloc] Hold cancelled: ${holdDuration.inMilliseconds}ms '
          '< ${minDuration.inMilliseconds}ms minimum');
      emit(const SosCancelled());

      // Auto-reset to idle after a brief pause
      Future.delayed(const Duration(seconds: 1), () {
        if (!isClosed) add(const SosReset());
      });
    } else {
      // Held long enough → trigger SOS
      debugPrint('[SosBloc] Hold completed: ${holdDuration.inMilliseconds}ms');
      _executeSosTrigger(emit);
    }
  }

  /// Handles the max hold duration being reached (auto-trigger).
  void _onMaxHoldReached(
    SosMaxHoldReached event,
    Emitter<SosBlocState> emit,
  ) {
    _holdTimer?.cancel();
    _holdStartTime = null;

    debugPrint('[SosBloc] Max hold reached — auto-triggering SOS');
    _executeSosTrigger(emit);
  }

  /// Executes the actual SOS trigger via the use case.
  Future<void> _executeSosTrigger(Emitter<SosBlocState> emit) async {
    emit(const SosTriggering());

    final result = await _triggerSos();

    result.fold(
      (failure) {
        debugPrint('[SosBloc] SOS trigger failed: ${failure.message}');
        add(SosTriggerCompleted(
          success: false,
          errorMessage: failure.message,
        ));
      },
      (sosEvent) {
        debugPrint('[SosBloc] SOS triggered: ${sosEvent.id}');
        add(const SosTriggerCompleted(success: true));
      },
    );
  }

  /// Handles the completion of the SOS trigger flow.
  void _onTriggerCompleted(
    SosTriggerCompleted event,
    Emitter<SosBlocState> emit,
  ) {
    if (event.success) {
      emit(SosTriggered(
        event: SosEvent(
          id: 'triggered',
          latitude: 0,
          longitude: 0,
          triggeredAt: DateTime.now(),
        ),
      ));
    } else {
      emit(SosError(message: event.errorMessage ?? 'Lỗi không xác định'));
    }

    // Auto-reset to idle after showing confirmation
    Future.delayed(const Duration(seconds: 3), () {
      if (!isClosed) add(const SosReset());
    });
  }

  /// Handles the flush queue request.
  Future<void> _onFlushQueue(
    SosFlushQueueRequested event,
    Emitter<SosBlocState> emit,
  ) async {
    final result = await _flushOfflineQueue();
    result.fold(
      (failure) => debugPrint('[SosBloc] Queue flush failed: ${failure.message}'),
      (count) => debugPrint('[SosBloc] Flushed $count events from queue'),
    );
  }

  /// Resets the state back to idle.
  void _onReset(
    SosReset event,
    Emitter<SosBlocState> emit,
  ) {
    emit(const SosIdle());
  }

  @override
  Future<void> close() {
    _holdTimer?.cancel();
    return super.close();
  }
}
