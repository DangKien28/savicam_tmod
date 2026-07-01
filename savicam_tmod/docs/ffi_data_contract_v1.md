# FFI Data Contract — SaViCam T-Mod
## Dart ↔ C++ JNI Bridge Interface Specification

> **Trạng thái:** DRAFT — cần xác nhận từ Huỳnh Minh Tiến (C++ core)
> **Phiên bản spec:** `v1.0.0-draft`
> **Ngày:** 2026-07-01
> **Soạn bởi:** Nguyễn Trung Kiên (Edge Logic & Integration)
> **Cần review:** Huỳnh Minh Tiến (C++ — `yolov8n_engine.cpp`, `ttc_calculator.cpp`)

---

## 1. Mục đích & Phạm vi

Tài liệu này chốt định dạng dữ liệu trao đổi qua JNI/FFI giữa tầng Dart (Flutter) và tầng lõi C++ (`libtmod_core.so`). Mọi thay đổi struct sau khi được hai bên ký duyệt **phải tạo Pull Request riêng** và tăng `CONTRACT_VERSION`.

> ⚠️ **Cross-dependency Sprint 3:** Nếu format không được chốt trước khi Sprint 3 bắt đầu, luồng dữ liệu AI → UI sẽ bị block hoàn toàn.

---

## 2. Kiến trúc luồng dữ liệu

```
Camera Frame (RGBA)
        │
        ▼
  [C++ Engine — libtmod_core.so]
  ┌─────────────────────────────────────────┐
  │  tmod_process_frame()                   │
  │    → YOLOv8n TFLite (NPU/NNAPI)        │
  │    → ByteTrack Object Tracking          │
  │    → TTC Calculator (Pinhole + ARCore)  │
  │    → Risk Classifier (4 levels)         │
  └─────────────┬───────────────────────────┘
                │ FFI/JNI (shared memory, no copy)
                ▼
  [Dart — VisionAlertController]
  ┌─────────────────────────────────────────┐
  │  FrameResult  (1 per frame)             │
  │  DetectionResult[] (N objects/frame)    │
  └─────────────┬───────────────────────────┘
                │
                ▼
  AudioHapticManager → TTS + Vibration
```

---

## 3. C++ Struct Definitions (`ffi_exports.h`)

> Đây là **nguồn sự thật** phía C++. Dart side mirror 1:1 bằng `dart:ffi Struct`.

```cpp
// ffi_exports.h
// CONTRACT_VERSION = 1

#pragma once
#include <stdint.h>

// ─── Payload 1: Kết quả tổng hợp 1 frame ────────────────────────────────────
typedef struct {
    int32_t risk_level;         // 1–4 (xem bảng §4)
    float   ttc_seconds;        // Time-to-Collision của vật gần nhất (giây)
    float   nearest_distance_m; // Khoảng cách vật gần nhất (mét)
    int32_t num_detections;     // Số vật thể phát hiện trong frame (0–N)
    int32_t nearest_class_id;   // Class ID của vật gần nhất (xem bảng §5)
} TmodFrameResult;
// static_assert(sizeof(TmodFrameResult) == 20, "ABI mismatch");

// ─── Payload 2: Chi tiết 1 vật thể phát hiện ────────────────────────────────
typedef struct {
    int32_t class_id;    // Class ID (xem bảng §5)
    float   confidence;  // [0.0, 1.0] — độ chắc chắn nhận diện
    float   x_min;       // Bounding box — tọa độ tương đối [0.0, 1.0]
    float   y_min;       //   (chuẩn hóa theo width/height của frame input)
    float   x_max;
    float   y_max;
    int32_t track_id;    // ByteTrack ID; -1 nếu chưa được assign
    float   distance_m;  // Khoảng cách ước lượng (mét); -1.0 nếu không tính được
} TmodDetectionResult;
// static_assert(sizeof(TmodDetectionResult) == 32, "ABI mismatch");
```

> **Lưu ý:** Tất cả tọa độ bounding box là **normalized** (chia theo input frame width/height). Dart side nhân lại với kích thước preview để render overlay.

---

## 4. Risk Level Taxonomy

| `risk_level` | Tên | Ngưỡng (TTC / Distance) | Hành động hệ thống |
|:---:|---|---|---|
| `4` | **CRITICAL** (Sinh Tử) | TTC < 1.0s hoặc dist < 0.8m | Ghi đè tối cao · ngắt TTS · lệnh gắt · rung giật cục |
| `3` | **HIGH** (Nguy Hiểm Cao) | TTC < 2.0s hoặc dist < 1.5m | Lệnh điều hướng dứt khoát · rung mạnh ngắt quãng |
| `2` | **WARNING** (Cảnh Báo) | TTC < 4.0s hoặc dist < 3.0m | Beep ngắn · rung nhịp đều nhẹ |
| `1` | **ATTENTION** (Chú Ý) | TTC < 7.0s hoặc dist < 5.0m | Đọc tên vật thể và khoảng cách (TTS) |
| `0` | **SAFE** (An Toàn) | Lớn hơn các mức trên hoặc 0 vật cản | Im lặng · chỉ phản hồi khi được hỏi |

**Quy tắc đặc biệt:**
- Nếu `num_detections == 0` → `risk_level` **bắt buộc** là `0`, `ttc_seconds = 999.0f`, `nearest_distance_m = 99.0f`.
- `risk_level` phản ánh vật có rủi ro cao nhất trong frame.

---

## 5. Class ID Taxonomy (Dataset 300 class)

> ✅ Đã được cập nhật khớp với dataset 300 class mới nhất.

| `class_id` | Ghi chú |
|:---:|---|
| `0` | `unknown` (vật thể không xác định - fallback sentinel) |
| `1` → `300` | Khớp 1:1 với index trong dataset 300 class (không cần offset) |

*(Xem file `lib/core/ffi_bindings/class_taxonomy.dart` để biết danh sách chi tiết 300 class được mapping trong Flutter)*

---

## 6. C++ Function Signatures (`ffi_exports.h`)

```cpp
// Khởi tạo engine với đường dẫn model TFLite
// Return: 0 = success, -1 = model not found, -2 = NNAPI error
int32_t tmod_init_core(const char* model_path);

// Xử lý 1 frame RGBA. Kết quả ghi vào *result.
// Return: số vật thể phát hiện (>= 0), hoặc -1 nếu lỗi
int32_t tmod_process_frame(
    const uint8_t* rgba_data,
    int32_t width,
    int32_t height,
    TmodFrameResult* result       // OUT: caller cấp phát
);

// Lấy chi tiết N vật thể từ frame gần nhất
// Return: số vật thể thực sự đã copy vào out_buffer
int32_t tmod_get_detections(
    TmodDetectionResult* out_buffer,  // OUT: caller cấp phát, size = max_count
    int32_t max_count
);

// Giải phóng engine
void tmod_release_core(void);

// Kiểm tra engine đã init chưa — Return: 1 = đã init, 0 = chưa
int32_t tmod_is_initialized(void);
```

---

## 7. Dart FFI Mirror (`c_structs.dart`)

File: `lib/core/ffi_bindings/c_structs.dart`

```dart
final class FrameResult extends Struct {
  @Int32() external int riskLevel;        // 1–4
  @Float()  external double ttcSeconds;       // giây; -1.0 nếu N/A
  @Float()  external double nearestDistanceM; // mét; -1.0 nếu N/A
  @Int32() external int numDetections;    // 0–N
  @Int32() external int nearestClassId;   // 0–10
}

final class DetectionResult extends Struct {
  @Int32() external int classId;       // 0–10
  @Float()  external double confidence;    // 0.0–1.0
  @Float()  external double xMin;          // normalized [0.0, 1.0]
  @Float()  external double yMin;
  @Float()  external double xMax;
  @Float()  external double yMax;
  @Int32() external int trackId;       // ByteTrack ID; -1 nếu chưa assign
  @Float()  external double distanceM;     // mét; -1.0 nếu không tính được
}
```

> **Thứ tự field và kiểu dữ liệu** phải khớp byte-by-byte với C struct (không có padding tùy ý).

---

## 8. Memory & Threading Contract

| Quy tắc | Mô tả |
|---|---|
| **Caller cấp phát** | Dart cấp phát `FrameResult` và `DetectionResult[]` trước khi gọi C++. C++ ghi vào buffer, không tự malloc. |
| **Thread safety** | `tmod_process_frame()` **KHÔNG** thread-safe. Dart phải gọi từ 1 Isolate duy nhất (camera isolate). |
| **Lifetime** | `DetectionResult` buffer chỉ valid cho đến lần gọi `tmod_process_frame()` tiếp theo. |
| **Max detections** | Buffer `DetectionResult[]` cấp phát cố định `MAX_DETECTIONS = 20`. C++ không bao giờ ghi quá giới hạn này. |
| **Encoding** | `rgba_data`: raw RGBA, stride = width × 4 bytes, không padding dòng. |

---

## 9. JSON Schema — EventChannel risk-callback (tương lai)

Nếu sau này chuyển từ FFI polling sang `EventChannel` push, payload JSON:

```jsonc
{
  "$schema": "https://savicam.vn/schemas/risk-callback/v1.json",
  "contract_version": 1,
  "frame_result": {
    "risk_level": 1,
    "ttc_seconds": 1.2,
    "nearest_distance_m": 0.8,
    "num_detections": 3,
    "nearest_class_id": 1
  },
  "detections": [
    {
      "class_id": 1,
      "confidence": 0.91,
      "bbox": { "x_min": 0.32, "y_min": 0.41, "x_max": 0.68, "y_max": 0.89 },
      "track_id": 7,
      "distance_m": 0.8
    }
  ],
  "timestamp_ms": 1751342400000
}
```

---

## 10. Contract Versioning

| Thay đổi | Quy tắc |
|---|---|
| Thêm field mới vào **cuối** struct | Tăng minor: `v1.1.0` · Backward-compatible |
| Đổi kiểu dữ liệu / thứ tự field | Tăng major: `v2.0.0` · Breaking · Cần migration cả hai phía |
| Thêm `class_id` mới | Tăng minor · Dart side xử lý gracefully giá trị không biết |
| Đổi ngưỡng TTC risk | Chỉ update doc · Không thay đổi struct |

```cpp
// C++ (ffi_exports.h)
#define TMOD_CONTRACT_VERSION 1
```
```dart
// Dart (c_structs.dart)
const int kTmodContractVersion = 1;
```

---

## 11. Open Questions cho Huỳnh Minh Tiến

Cần được chốt trước khi Sprint 3 bắt đầu:

| # | Câu hỏi | Tác động |
|:---:|---|---|
| **Q1** | Class taxonomy (§5) có khớp với label map training không? Có class nào thêm/bớt? | TTS alert text, UI mapping |
| **Q2** | `tmod_process_frame()` blocking hay async callback? | Thiết kế Dart Isolate |
| **Q3** | Đã có `static_assert` kích thước struct (20 và 32 bytes) chưa? | Phòng ABI mismatch |
| **Q4** | ARCore Depth có available trên tất cả thiết bị test không? Fallback? | Reliability của `distance_m` |
| **Q5** | `MAX_DETECTIONS = 20` có phù hợp throughput YOLOv8n Nano không? | Buffer size Dart side |

---

## 12. Checklist phê duyệt

- [ ] Nguyễn Trung Kiên — review struct layout & Dart side ✅ (soạn thảo)
- [ ] Huỳnh Minh Tiến — xác nhận C++ side, class taxonomy, trả lời Q1–Q5
- [ ] Commit `ffi_exports.h` vào repo với `static_assert` kích thước struct
- [ ] Merge/update `c_structs.dart` nếu có thay đổi sau review
- [ ] Cập nhật `CONTRACT_VERSION` ở cả C++ và Dart khi merge

---

*Lưu tại: `docs/ffi_data_contract_v1.md`*
*Mọi cập nhật phải đi kèm PR riêng và cần approval của cả hai engineer.*
