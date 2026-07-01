// ffi_bridge — Edge Logic & Integration layer
//
// Export barrel cho toàn bộ module ffi_bridge.
// Import file này để truy cập MethodChannelBridge, BridgeException,
// IRiskSource, RiskEvent, và các implementations.
//
// Dùng BridgeRoundTripTestScreen trong debug/QA để kiểm thử TASK-W1-01.
// Dùng RiskSimulatorScreen (lib/ui/screens/debug/) để kiểm thử TASK-W6.

export 'method_channel_bridge.dart';
export 'bridge_round_trip_test_screen.dart';

// Risk source abstraction + implementations (TASK-W6-NGKIEN-01)
export 'risk_source.dart';                // IRiskSource + RiskEvent
export 'ffi_polling_risk_source.dart';    // Production: FFI Timer polling
export 'event_channel_risk_source.dart';  // Test/Debug: Kotlin EventChannel push
