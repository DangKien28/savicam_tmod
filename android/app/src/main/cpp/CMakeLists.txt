cmake_minimum_required(VERSION 3.18.1)
project(tmod_core)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# =============================================================================
# nlohmann/json — thư viện header-only để parse JSON (không cần build riêng)
# Được dùng bởi DepthEstimator::LoadCustomHeights() để đọc custom_heights.json.
# FetchContent tự tải về khi configure lần đầu, sau đó cache lại.
# =============================================================================
include(FetchContent)
FetchContent_Declare(
    nlohmann_json
    URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.hpp
    DOWNLOAD_NO_EXTRACT TRUE
    DOWNLOAD_DIR ${CMAKE_CURRENT_BINARY_DIR}/nlohmann
)
FetchContent_MakeAvailable(nlohmann_json)
# Tạo thư mục include ảo cho #include <nlohmann/json.hpp>
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/nlohmann_include/nlohmann)
add_custom_command(
    OUTPUT  ${CMAKE_CURRENT_BINARY_DIR}/nlohmann_include/nlohmann/json.hpp
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_CURRENT_BINARY_DIR}/nlohmann/json.hpp
            ${CMAKE_CURRENT_BINARY_DIR}/nlohmann_include/nlohmann/json.hpp
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/nlohmann/json.hpp
    COMMENT "Sao chep nlohmann/json.hpp vao thu muc include"
)
add_custom_target(nlohmann_copy DEPENDS
    ${CMAKE_CURRENT_BINARY_DIR}/nlohmann_include/nlohmann/json.hpp
)

# =============================================================================
# Tối ưu biên dịch cho Android Edge Device
# -O3          : Tối ưu tốc độ tối đa
# -ffast-math  : Phép toán float nhanh hơn (chấp nhận sai số nhỏ)
# -DNDEBUG     : Tắt assert trong release build
# =============================================================================
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3 -ffast-math -DNDEBUG")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fexceptions -frtti")

# =============================================================================
# Nguồn: ffi_exports.cpp là cổng FFI duy nhất cho Dart.
# Core & Vision là logic xử lý nội bộ.
# =============================================================================
set(SOURCE_FILES
    ffi_exports.cpp
    core/nnapi_delegate.cpp
    core/tflite_runner.cpp
    vision/yolov8n_engine.cpp
    vision/byte_track.cpp
    vision/depth_estimator.cpp
    vision/ttc_calculator.cpp
)

# Bao gồm thư mục header cho các module + nlohmann/json header-only
include_directories(
    .
    core
    vision
    ${CMAKE_CURRENT_BINARY_DIR}/nlohmann_include
)

# Tạo shared library (.so) để Dart DynamicLibrary.open() nạp
add_library(tmod_core SHARED ${SOURCE_FILES})

# Đảm bảo nlohmann/json.hpp được copy trước khi compile
add_dependencies(tmod_core nlohmann_copy)

# Tìm thư viện hệ thống Android cần thiết
find_library(log-lib     log)
find_library(android-lib android)

target_link_libraries(tmod_core
    ${log-lib}
    ${android-lib}
    dl          # Cần cho dlopen (NNAPI detection)
    m           # Math library (sqrt, fabs...)
    atomic      # std::atomic support
)

# Đảm bảo chỉ các symbol extern "C" được export, ẩn các symbol C++ nội bộ
set_target_properties(tmod_core PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# Strip debug symbols trong release để giảm kích thước .so
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_link_options(tmod_core PRIVATE -Wl,--strip-debug)
endif()
