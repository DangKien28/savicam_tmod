import 'dart:ffi';

// ============================================================================
// Struct FFI khớp 1:1 với ffi_exports.h (phía C++)
// CONTRACT_VERSION = 1  →  khớp với #define TMOD_CONTRACT_VERSION 1
// Mọi thay đổi struct phải tăng version ở CẢ HAI phía.
// ============================================================================

/// Version của FFI data contract Dart ↔ C++.
/// Phải khớp với `TMOD_CONTRACT_VERSION` trong `ffi_exports.h`.
const int kTmodContractVersion = 1;

/// Số lượng DetectionResult tối đa mỗi frame.
/// C++ cam kết không bao giờ ghi quá giá trị này vào out_buffer.
const int kMaxDetectionsPerFrame = 20;

/// Tổng số class trong dataset (class_id 1 → 300).
/// class_id = 0 là sentinel "không xác định" (unknown).
/// Tra cứu tên tiếng Việt qua ClassTaxonomy.of(classId).
const int kMaxClassId = 300;


/// Kết quả xử lý 1 frame camera từ C++
/// sizeof = 20 bytes — phải khớp static_assert phía C++.
final class FrameResult extends Struct {
  @Int32() external int riskLevel;        // 0=an toàn … 4=sinh tử
  @Float()  external double ttcSeconds;       // giây; 999.0 nếu N/A
  @Float()  external double nearestDistanceM; // mét;  99.0  nếu N/A
  @Int32() external int numDetections;    // 0 – kMaxDetectionsPerFrame
  @Int32() external int nearestClassId;   // 0 (unknown) – kMaxClassId
}

/// Chi tiết 1 đối tượng phát hiện
/// sizeof = 32 bytes — phải khớp static_assert phía C++.
final class DetectionResult extends Struct {
  @Int32() external int classId;       // 0 (unknown) – kMaxClassId
  @Float()  external double confidence;    // [0.0, 1.0]
  @Float()  external double xMin;          // normalized [0.0, 1.0]
  @Float()  external double yMin;          // normalized [0.0, 1.0]
  @Float()  external double xMax;          // normalized [0.0, 1.0]
  @Float()  external double yMax;          // normalized [0.0, 1.0]
  @Int32() external int trackId;       // ByteTrack ID; -1 nếu chưa assign
  @Float()  external double distanceM;     // mét; -1.0 nếu không tính được
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
