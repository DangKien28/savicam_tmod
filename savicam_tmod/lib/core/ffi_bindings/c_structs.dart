// lib/core/ffi_bindings/c_structs.dart
import 'dart:ffi' as ffi;

final class DetectionResult extends ffi.Struct {
  @ffi.Int32()
  external int classId;

  @ffi.Float()
  external double confidence;

  @ffi.Float()
  external double xMin;

  @ffi.Float()
  external double yMin;

  @ffi.Float()
  external double xMax;

  @ffi.Float()
  external double yMax;

  @ffi.Int32()
  external int trackId;

  @ffi.Float()
  external double distanceM;
}

final class FrameResult extends ffi.Struct {
  @ffi.Int32()
  external int riskLevel;

  @ffi.Float()
  external double ttcSeconds;

  @ffi.Float()
  external double nearestDistanceM;

  @ffi.Int32()
  external int numDetections;

  @ffi.Int32()
  external int nearestClassId;
}