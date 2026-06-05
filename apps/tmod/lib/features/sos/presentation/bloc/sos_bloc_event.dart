/// SaViCam T-Mod — SOS BLoC Events
///
/// Events that drive SOS state transitions. Each event maps to a
/// specific user gesture or system action in the SOS flow.
library;

import 'package:equatable/equatable.dart';

/// Base class for all SOS BLoC events.
sealed class SosBlocEvent extends Equatable {
  const SosBlocEvent();

  @override
  List<Object?> get props => [];
}

/// User began holding the SOS zone.
/// Starts the 3-5 second countdown timer.
class SosHoldStarted extends SosBlocEvent {
  const SosHoldStarted();
}

/// User released the SOS zone.
///
/// If [holdDuration] < 3 seconds → cancelled (anti-accidental touch).
/// If [holdDuration] >= 3 seconds → SOS triggered.
class SosHoldReleased extends SosBlocEvent {
  final Duration holdDuration;

  const SosHoldReleased({required this.holdDuration});

  @override
  List<Object?> get props => [holdDuration];
}

/// The maximum hold time (5 seconds) was reached.
/// Auto-triggers SOS without requiring release.
class SosMaxHoldReached extends SosBlocEvent {
  const SosMaxHoldReached();
}

/// Internal event: the SOS trigger flow completed.
/// Emitted after the use case finishes (success or failure).
class SosTriggerCompleted extends SosBlocEvent {
  final bool success;
  final String? errorMessage;

  const SosTriggerCompleted({
    required this.success,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [success, errorMessage];
}

/// Request to flush the offline queue.
/// Triggered when connectivity is restored.
class SosFlushQueueRequested extends SosBlocEvent {
  const SosFlushQueueRequested();
}

/// Reset SOS state back to idle.
/// Called after the triggered state is acknowledged.
class SosReset extends SosBlocEvent {
  const SosReset();
}
