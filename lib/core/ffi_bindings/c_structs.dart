import 'dart:ffi';

// ============================================================================
// Struct FFI khớp 1:1 với ffi_exports.cpp
// ============================================================================

/// Kết quả xử lý 1 frame camera từ C++
final class FrameResult extends Struct {
  @Int32()
  external int riskLevel;

  @Float()
  external double ttcSeconds;

  @Float()
  external double nearestDistanceM;

  @Int32()
  external int numDetections;

  @Int32()
  external int nearestClassId;
}

/// Chi tiết 1 đối tượng phát hiện
final class DetectionResult extends Struct {
  @Int32()
  external int classId;

  @Float()
  external double confidence;

  @Float()
  external double xMin;

  @Float()
  external double yMin;

  @Float()
  external double xMax;

  @Float()
  external double yMax;

  @Int32()
  external int trackId;

  @Float()
  external double distanceM;
}

// ============================================================================
// Typedef cho FFI function signatures
// ============================================================================

// C signatures (native)
typedef TmodInitCoreNative = Int32 Function(Pointer<Char> modelPath);
typedef TmodProcessFrameNative = Int32 Function(
    Pointer<Uint8> rgbaData, Int32 width, Int32 height, Pointer<FrameResult> result);
typedef TmodGetDetectionsNative = Int32 Function(
    Pointer<DetectionResult> outBuffer, Int32 maxCount);
typedef TmodReleaseCoreNative = Void Function();
typedef TmodIsInitializedNative = Int32 Function();

// Dart signatures
typedef TmodInitCore = int Function(Pointer<Char> modelPath);
typedef TmodProcessFrame = int Function(
    Pointer<Uint8> rgbaData, int width, int height, Pointer<FrameResult> result);
typedef TmodGetDetections = int Function(
    Pointer<DetectionResult> outBuffer, int maxCount);
typedef TmodReleaseCore = void Function();
typedef TmodIsInitialized = int Function();
