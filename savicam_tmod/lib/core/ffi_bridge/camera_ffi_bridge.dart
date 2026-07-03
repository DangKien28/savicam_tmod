// lib/core/ffi_bridge/camera_ffi_bridge.dart
import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:camera/camera.dart';
import '../ffi_bindings/c_structs.dart';

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

// Class Dart thuần để chứa dữ liệu an toàn, tách biệt với con trỏ C++
class DartFrameResult {
  final int riskLevel;
  final double ttcSeconds;
  final double nearestDistanceM;
  final int numDetections;
  final int nearestClassId;

  DartFrameResult({
    required this.riskLevel,
    required this.ttcSeconds,
    required this.nearestDistanceM,
    required this.numDetections,
    required this.nearestClassId,
  });
}

class CameraFfiBridge {
  static final CameraFfiBridge _instance = CameraFfiBridge._internal();
  factory CameraFfiBridge() => _instance;

  late ffi.DynamicLibrary _nativeLib;
  late ProcessFrameDart _processFrame;

  CameraFfiBridge._internal() {
    _nativeLib = Platform.isAndroid
        ? ffi.DynamicLibrary.open('libtmod_vision.so')
        : ffi.DynamicLibrary.process();

    _processFrame = _nativeLib.lookupFunction<ProcessFrameC, ProcessFrameDart>('tmod_process_frame');
  }

  DartFrameResult? processCameraFrame(CameraImage image) {
    final Uint8List yPlane = image.planes[0].bytes;
    final int width = image.width;
    final int height = image.height;

    final ffi.Pointer<ffi.Uint8> pFrameData = calloc<ffi.Uint8>(yPlane.length);
    final ffi.Pointer<FrameResult> pResult = calloc<FrameResult>();

    try {
      final Uint8List nativeBytes = pFrameData.asTypedList(yPlane.length);
      nativeBytes.setAll(0, yPlane);

      final int success = _processFrame(pFrameData, width, height, pResult);

      if (success == 1) {
        final ref = pResult.ref;
        return DartFrameResult(
          riskLevel: ref.riskLevel,
          ttcSeconds: ref.ttcSeconds,
          nearestDistanceM: ref.nearestDistanceM,
          numDetections: ref.numDetections,
          nearestClassId: ref.nearestClassId,
        );
      }
      return null;
    } finally {
      calloc.free(pFrameData);
      calloc.free(pResult);
    }
  }
}