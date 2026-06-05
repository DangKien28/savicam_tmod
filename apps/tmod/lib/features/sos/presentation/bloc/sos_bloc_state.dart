/// SaViCam T-Mod — SOS BLoC States
///
/// States representing the SOS trigger lifecycle.
/// The UI renders different visuals based on these states.
library;

import 'package:equatable/equatable.dart';

import '../../domain/entities/sos_event.dart';

/// Base class for all SOS BLoC states.
sealed class SosBlocState extends Equatable {
  const SosBlocState();

  @override
  List<Object?> get props => [];
}

/// Initial state — SOS zone is visible but inactive.
/// Bottom 50% of screen shows a subtle colored zone.
class SosIdle extends SosBlocState {
  const SosIdle();
}

/// User is holding the SOS zone.
///
/// [progress] is 0.0 → 1.0 representing the hold progress
/// from 0 seconds to [SosConstants.maxHoldDuration] (5 seconds).
///
/// [holdDuration] is the actual time held so far.
///
/// The UI shows a circular progress indicator and haptic feedback.
class SosHolding extends SosBlocState {
  /// Progress from 0.0 to 1.0 (maps to 0s to 5s).
  final double progress;

  /// Actual hold duration so far.
  final Duration holdDuration;

  /// Whether the minimum hold threshold (3s) has been reached.
  /// When true, releasing will trigger SOS.
  bool get hasReachedMinimum => holdDuration.inSeconds >= 3;

  const SosHolding({
    required this.progress,
    required this.holdDuration,
  });

  @override
  List<Object?> get props => [progress, holdDuration];
}

/// SOS has been triggered and is being sent.
/// UI shows a pulsing red overlay.
class SosTriggering extends SosBlocState {
  const SosTriggering();
}

/// SOS was cancelled (hold released before 3 seconds).
/// UI briefly shows cancellation feedback, then returns to idle.
class SosCancelled extends SosBlocState {
  const SosCancelled();
}

/// SOS was successfully triggered and sent/queued.
/// UI shows confirmation with event details.
class SosTriggered extends SosBlocState {
  /// The SOS event that was created.
  final SosEvent event;

  /// Whether the event was sent to cloud or queued locally.
  final bool sentToCloud;

  const SosTriggered({
    required this.event,
    this.sentToCloud = true,
  });

  @override
  List<Object?> get props => [event, sentToCloud];
}

/// SOS trigger failed — both cloud and local persist failed.
/// This is extremely rare and indicates a critical device issue.
class SosError extends SosBlocState {
  final String message;

  const SosError({required this.message});

  @override
  List<Object?> get props => [message];
}
