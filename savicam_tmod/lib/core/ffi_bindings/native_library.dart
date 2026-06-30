import 'dart:ffi';
import 'dart:io';

import 'c_structs.dart';

/// Singleton quản lý DynamicLibrary và lookup toàn bộ symbol C++.
/// Đây là điểm giao tiếp DUY NHẤT giữa Dart và C++.
class NativeLibrary {
  static NativeLibrary? _instance;
  late final DynamicLibrary _lib;

  // Cached function pointers
  late final TmodInitCore initCore;
  late final TmodProcessFrame processFrame;
  late final TmodGetDetections getDetections;
  late final TmodReleaseCore releaseCore;
  late final TmodIsInitialized isInitialized;

  NativeLibrary._() {
    _lib = _loadLibrary();
    _bindFunctions();
  }

  factory NativeLibrary() {
    _instance ??= NativeLibrary._();
    return _instance!;
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libtmod_core.so');
    }
    // Fallback cho test trên Desktop (nếu có)
    throw UnsupportedError('Platform ${Platform.operatingSystem} chưa được hỗ trợ.');
  }

  void _bindFunctions() {
    initCore = _lib
        .lookup<NativeFunction<TmodInitCoreNative>>('tmod_init_core')
        .asFunction<TmodInitCore>();

    processFrame = _lib
        .lookup<NativeFunction<TmodProcessFrameNative>>('tmod_process_frame')
        .asFunction<TmodProcessFrame>();

    getDetections = _lib
        .lookup<NativeFunction<TmodGetDetectionsNative>>('tmod_get_detections')
        .asFunction<TmodGetDetections>();

    releaseCore = _lib
        .lookup<NativeFunction<TmodReleaseCoreNative>>('tmod_release_core')
        .asFunction<TmodReleaseCore>();

    isInitialized = _lib
        .lookup<NativeFunction<TmodIsInitializedNative>>('tmod_is_initialized')
        .asFunction<TmodIsInitialized>();
  }
}
