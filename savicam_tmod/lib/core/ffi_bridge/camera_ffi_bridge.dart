// lib/core/ffi_bridge/camera_ffi_bridge.dart
import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:camera/camera.dart';
import '../ffi_bindings/c_structs.dart';

// Định nghĩa Signature cho hàm C và Dart FFI
typedef ProcessFrameC = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8> frameData, 
  ffi.Int32 width, 
  ffi.Int32 height, 
  ffi.Pointer<FrameResult> result
);

typedef ProcessFrameDart = int Function(
  ffi.Pointer<ffi.Uint8> frameData, 
  int width, 
  int height, 
  ffi.Pointer<FrameResult> result
);

class CameraFfiBridge {
  static final CameraFfiBridge _instance = CameraFfiBridge._internal();
  factory CameraFfiBridge() => _instance;

  late ffi.DynamicLibrary _nativeLib;
  late ProcessFrameDart _processFrame;

  CameraFfiBridge._internal() {
    // Tải thư viện C++ được biên dịch
    _nativeLib = Platform.isAndroid
        ? ffi.DynamicLibrary.open('libtmod_vision.so')
        : ffi.DynamicLibrary.process();

    _processFrame = _nativeLib.lookupFunction<ProcessFrameC, ProcessFrameDart>('tmod_process_frame');
  }

  /// Nhận khung hình từ luồng camera, đẩy xuống C++ và trả về FrameResult
  FrameResult? processCameraFrame(CameraImage image) {
    // Trích xuất mặt phẳng Y (Luminance) để lấy ảnh xám (Grayscale). 
    // YUV_420_888 luôn có mặt phẳng Y ở index 0.
    final Uint8List yPlane = image.planes[0].bytes;
    final int width = image.width;
    final int height = image.height;

    // Cấp phát vùng nhớ trên C cho dữ liệu ảnh và struct kết quả
    final ffi.Pointer<ffi.Uint8> pFrameData = calloc<ffi.Uint8>(yPlane.length);
    final ffi.Pointer<FrameResult> pResult = calloc<FrameResult>();

    try {
      // Sao chép mảng byte từ Dart sang vùng nhớ C
      final Uint8List nativeBytes = pFrameData.asTypedList(yPlane.length);
      nativeBytes.setAll(0, yPlane);

      // Gọi hàm nhận diện bên lõi C++
      final int success = _processFrame(pFrameData, width, height, pResult);

      if (success == 1) {
        // Sao chép giá trị từ struct C sang Dart class (để không phụ thuộc vào con trỏ sẽ bị hủy)
        final ref = pResult.ref;
        return FrameResult(
          riskLevel: ref.risk_level,
          ttcSeconds: ref.ttc_seconds,
          nearestDistanceM: ref.nearest_distance_m,
          numDetections: ref.num_detections,
          nearestClassId: ref.nearest_class_id,
        );
      }
      return null;
    } finally {
      // TUYỆT ĐỐI PHẢI GIẢI PHÓNG VÙNG NHỚ NGAY SAU KHI XỬ LÝ XONG FRAME
      calloc.free(pFrameData);
      calloc.free(pResult);
    }
  }
}