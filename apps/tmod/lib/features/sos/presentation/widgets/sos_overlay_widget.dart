/// SaViCam T-Mod — SOS Overlay Widget (Re-export)
///
/// The SOS overlay UI logic is integrated directly into [HomeScreen]
/// via the [_SosGestureZone] private widget. This file serves as the
/// original location reference per the directory_tree.md specification.
///
/// The overlay is positioned at the bottom 50% of the screen and uses
/// GestureDetector with long-press callbacks. The 3-5 second validation
/// is handled by [SosBloc]'s timer, not Flutter's built-in longPress.
///
/// Visual states:
/// - Idle: subtle semi-transparent red gradient
/// - Holding: pulsing red with circular progress (0-5 seconds)
/// - Triggering: full red pulse animation
/// - Triggered: confirmation with checkmark
/// - Cancelled: brief fade feedback
/// - Error: error message display
///
/// See: features/safety_assistant/presentation/pages/home_screen.dart
library;

// The SOS overlay is implemented as _SosGestureZone in home_screen.dart
// to avoid circular widget dependencies and keep the Stack composition
// within a single build tree.
//
// Key gesture parameters:
// - GestureDetector.onLongPressStart → SosBloc.add(SosHoldStarted)
// - GestureDetector.onLongPressEnd → SosBloc.add(SosHoldReleased)
// - Timer in SosBloc updates SosHolding.progress every 100ms
// - At 5 seconds → auto-fires SosMaxHoldReached
// - Release before 3 seconds → SosCancelled (anti-accidental touch)
