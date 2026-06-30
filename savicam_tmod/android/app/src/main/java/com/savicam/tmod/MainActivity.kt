package com.savicam.tmod

import io.flutter.embedding.android.FlutterActivity

/// "Vỏ bọc câm" - Chỉ phục vụ Flutter engine lifecycle.
/// KHÔNG chứa MethodChannel, KHÔNG chứa logic.
/// Tất cả giao tiếp native đi qua dart:ffi -> libtmod_core.so
class MainActivity : FlutterActivity()
