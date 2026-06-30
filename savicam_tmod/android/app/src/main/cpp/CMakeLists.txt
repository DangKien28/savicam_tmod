cmake_minimum_required(VERSION 3.18.1)
project(tmod_core)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# =========================================================================
# Nguồn: ffi_exports.cpp là cổng FFI duy nhất cho Dart.
# Core & Vision là logic xử lý nội bộ.
# =========================================================================
set(SOURCE_FILES
    ffi_exports.cpp
    core/nnapi_delegate.cpp
    core/tflite_runner.cpp
    vision/yolov8n_engine.cpp
    vision/byte_track.cpp
    vision/depth_estimator.cpp
    vision/ttc_calculator.cpp
)

include_directories(. core vision)

# Tạo shared library (.so) để Dart DynamicLibrary.open() nạp
add_library(tmod_core SHARED ${SOURCE_FILES})

find_library(log-lib log)
find_library(android-lib android)

target_link_libraries(tmod_core ${log-lib} ${android-lib})

# Đảm bảo các symbol extern "C" KHÔNG bị strip bởi linker
set_target_properties(tmod_core PROPERTIES
    CXX_VISIBILITY_PRESET hidden
)
