# SaViCam - Hệ thống hỗ trợ di chuyển và sinh hoạt thông minh cho người khiếm thị
### (Bản cải tiến từ SafeVision)

**Đại học Duy Tân** — Báo cáo tổng kết đề tài Nghiên cứu Khoa học của Sinh viên
Đà Nẵng, tháng 5/2026

**Nhóm nghiên cứu:**
- Đặng Trung Kiên (Trưởng nhóm)
- Nguyễn Thị Thu Ánh
- Trần Tiến Đạt
- Nguyễn Trung Kiên
- Huỳnh Minh Tiến

**Khoa:** Đào Tạo Quốc Tế — **Ngành:** CMU-TPM
**Người hướng dẫn:** ThS. Lê Văn Tịnh

---

## Mục tiêu đề tài

Nâng cao sự an toàn và thuận tiện trong sinh hoạt của người khiếm thị, hỗ trợ họ dễ dàng hòa nhập và tự chủ trong quá trình di chuyển thông qua các công nghệ trợ năng hiện đại.

## Tính mới và sáng tạo

- Gậy dò đường truyền thống có giới hạn nghiêm trọng về phạm vi/nhận diện rủi ro; thiết bị ngoại nhập (kính thông minh) đắt (90–115 triệu VNĐ) và không tương thích môi trường bản địa.
- SaViCam là giải pháp Edge AI chạy cục bộ trên thiết bị di động phổ thông, không phụ thuộc mạng, giảm độ trễ, tối ưu cho giao thông Việt Nam.
- Tích hợp AI Agent đa tầng (NLP) xử lý tiếng Việt, kỹ thuật lượng tử hóa mô hình (QAT) để duy trì hiệu năng cao khi vận hành dài.
- Dữ liệu huấn luyện lấy từ môi trường thực tế Việt Nam.
- TTS/STT giúp người khiếm thị dễ sử dụng trong sinh hoạt hằng ngày.

## Kết quả nghiên cứu (tóm tắt)

- Nền tảng: Flutter + C++ (lõi hiệu năng) + Kotlin (backend biên) + SQLite (DB nội bộ).
- AI: fine-tune multilingual-MiniLM-L6-v2 (cơ chế Attention) cho NLP.
- Hệ sinh thái 2 app: **SaViCam T-Mod** (người khiếm thị) và **SaViCam Relap** (người giám hộ).
- Phiên bản hiện tại: hoàn thiện module nhận diện, dữ liệu giao thông nội địa, lõi dẫn đường ngoại tuyến giới hạn khu vực Đà Nẵng.

## Đóng góp kinh tế - xã hội

- **Kinh tế:** Tận dụng phần cứng có sẵn (camera, micro, cảm biến, GPS) thay vì phần cứng chuyên dụng đắt đỏ.
- **Xã hội:** "Đôi mắt kỹ thuật số", giảm tai nạn giao thông, giảm áp lực tâm lý cho gia đình qua SaViCam Relap.
- **Giáo dục:** Hỗ trợ học sinh/sinh viên khiếm thị di chuyển an toàn; minh chứng ứng dụng Model Quantization + Edge AI.
- **Khả năng áp dụng thực tiễn:** Hoạt động ngoại tuyến hoàn toàn (SQLite + TFLite qua NPU) kể cả khi mất sóng 4G; AI huấn luyện riêng cho dữ liệu giao thông nội địa (vỉa hè lấn chiếm, xe máy, hố ga).

---

# CHƯƠNG 1. TỔNG QUAN VỀ HỆ THỐNG VÀ CÔNG NGHỆ LIÊN QUAN

## 1.1. Tổng quan về đề tài

**Bối cảnh:** Người khiếm thị tại Việt Nam đối mặt hạ tầng giao thông phức tạp (xe máy đông đúc, vỉa hè lấn chiếm, biển báo thấp, hố ga). Gậy trắng truyền thống hạn chế tầm quét; thiết bị nhập ngoại đắt và không hợp dữ liệu nội địa; ứng dụng di động phổ biến (vd. Seeing AI) phụ thuộc Cloud → độ trễ mạng nguy hiểm.

**Mục tiêu nghiên cứu:** Xây dựng hệ sinh thái SaViCam T-Mod (xử lý biên) + SaViCam Relap (kiểm soát từ xa), tối ưu AI chạy trực tiếp trên thiết bị, cảnh báo vật cản, dẫn đường ngoại tuyến, đồng bộ trạng thái an toàn với người thân.

**Phạm vi nghiên cứu:** Phần mềm thuần túy (không chế tạo phần cứng mới), huấn luyện/tối ưu YOLOv8n + MiniLM cho giao thông Việt Nam, kết hợp OpenStreetMap cho làn đường đi bộ.

**Ý nghĩa thực tiễn:** Biến điện thoại thành "đôi mắt kỹ thuật số", giúp di chuyển độc lập, giải tỏa áp lực tâm lý người thân qua mạng lưới giám sát/SOS khép kín.

## 1.2. Tổng quan công nghệ cốt lõi

### 1.2.1. Kiến trúc Edge AI
Đưa suy luận AI trực tiếp xuống thiết bị người dùng thay vì đẩy lên Cloud. Đảm bảo phản hồi mili-giây cho cảnh báo sinh tử. Dùng NPU qua Android NNAPI để chạy mô hình TFLite (tăng tốc 2–3 lần, tiết kiệm năng lượng so với CPU).

### 1.2.2. Mô hình thị giác máy tính YOLOv8n
- Phiên bản Nano, tối ưu cho di động.
- Huấn luyện mới hoàn toàn với dữ liệu Việt Nam (xe máy, hố ga, biển báo thấp).
- Áp dụng QAT (Quantization Aware Training) → TFLite; kết hợp Object Tracking để duy trì 15–22 FPS trên điện thoại.

### 1.2.3. AI xử lý ngôn ngữ MiniLM
- multilingual-MiniLM-L6-v2 làm lõi AI Agent.
- Fine-tune cho 2 tác vụ: Multi-label Classification (nhận diện ý định) + NER (bóc tách địa điểm/đồ vật).
- Lượng tử hóa Float32 → INT8: từ >100MB xuống 20–30MB, chạy ổn định ở Headless Mode.

### 1.2.4. Hệ sinh thái bản đồ OpenStreetMap (OSM)
- Loại bỏ API thương mại (Google Maps); dùng OSM + GraphHopper.
- Kỹ thuật "nướng bản đồ" (Pre-build): server lọc dữ liệu, giữ lại làn đường đi bộ (Pedestrian-Only), tính toán trước lộ trình.
- Đóng gói thành file đồ thị ("Sổ tay lộ trình"), tải về máy 1 lần, hoạt động hoàn toàn ngoại tuyến.

### 1.2.5. Nền tảng lập trình Flutter
- Dùng cho cả T-Mod và Relap → tái sử dụng mã nguồn, đồng bộ hệ sinh thái.
- T-Mod: giao diện "Accessibility First" (màu tương phản cao, vuốt toàn màn hình).
- Kết nối Flutter ↔ tầng lõi C++ qua MethodChannel (FFI).

---

# CHƯƠNG 2. NGHIÊN CỨU VÀ PHÂN TÍCH HỆ THỐNG SAVICAM

## 2.1. Kiến trúc phần mềm mô hình lai (Edge-Cloud Hybrid)

**Tầng thiết bị biên (Edge – SaViCam T-Mod):**
- Trung tâm xử lý cốt lõi, chạy Headless Mode (Foreground Service) để hoạt động ngầm liên tục.
- Chạy cục bộ YOLOv8n + MiniLM (đã lượng tử hóa, tăng tốc qua NPU).
- Lưu trữ lõi bản đồ GraphHopper + bộ định tuyến OSM → cảnh báo/dẫn đường độ trễ thấp kể cả mất mạng.

**Tầng đám mây (Cloud/Trạm kiểm soát Relap):**
- API Gateway duy trì gRPC/WebSockets với T-Mod.
- Xử lý tác vụ không cần real-time siêu tốc: telemetry, UserMacros, kích hoạt SOS đến Relap qua Supabase.

## 2.2. Thiết kế giao diện "Accessibility First"

### SaViCam T-Mod (người khiếm thị)
Không dùng nút bấm vật lý nhỏ/biểu mẫu phức tạp — dựa trên màu tương phản cao + cử chỉ toàn màn hình.

- **Chế độ Trợ lý an toàn (xanh lá):** AI quét chướng ngại vật, cảnh báo âm thanh + rung.
- **Chế độ Di chuyển (xanh dương):** Kích hoạt bản đồ, định hướng/chỉ đường ngoại tuyến.
- **Chế độ Sinh hoạt (vàng):** OCR bóc tách văn bản, nhận diện đồ vật tĩnh.
- **Thao tác:** Vuốt trái/phải đổi chế độ; nút SOS đỏ tràn viền nửa dưới màn hình (nhấn giữ 3–5s).

**Bảng đặc tả UI T-Mod:**

| Component | Gestures | Chức năng | Data Mapping |
| --- | --- | --- | --- |
| Trợ lý an toàn (Xanh lá) | Vuốt ngang chuyển màn hình; chạm 1 lần đọc lại thông báo | Luồng CV (YOLOv8n) quét chướng ngại vật, cảnh báo theo TTC | Suy luận trực tiếp RAM/NPU, không lưu DB |
| Di chuyển (Xanh dương) | Vuốt ngang; chạm 1 lần kích hoạt Mic ra lệnh thoại | AI Agent NLP trích điểm đến, gọi GraphHopper | Truy vấn `Local_Macros` (SQLite) + file bản đồ .zip |
| Sinh hoạt (Vàng) | Vuốt ngang; chạm đúp chụp/quét | OCR đọc bảng hiệu, mệnh giá tiền, đồ vật tĩnh | Camera cục bộ; cấu hình từ `App_Settings` |
| SOS (Đỏ, tràn viền) | Nhấn giữ 3–5s | Ghi đè mọi tác vụ, gửi tọa độ, mở đàm thoại ưu tiên tới Relap | Có mạng: INSERT `sos_events`. Mất mạng: lưu `Offline_Queue` |
| Phím cứng (Nguồn/Âm lượng) | Bấm phím cứng | Kích hoạt Headless Mode / chỉnh âm lượng | Cập nhật `is_headless_active` trong `device_telemetry` |

### SaViCam Relap (người thân/giám hộ)
Dashboard trực quan cho người giám hộ.

- Màn hình Cảnh báo SOS (Red Alert toàn màn hình, tọa độ + đàm thoại ưu tiên).
- Màn hình Giám sát Thiết bị (Telemetry: pin, mạng, độ trễ).
- Từ điển vị trí (UserMacros): nhập từ khóa + kéo thả ghim tọa độ, đồng bộ xuống T-Mod.

**Bảng đặc tả UI Relap:**

| Màn hình | Loại UI | Component | Chức năng | Data Mapping |
| --- | --- | --- | --- | --- |
| Giám sát Thiết bị | Data Grid | Telemetry | Hiển thị real-time pin/mạng/headless | Lắng nghe `device_telemetry` qua WebSockets (Supabase) |
| Giám sát Thiết bị | Bản đồ | Live Tracking | Vị trí GPS hiện tại | Tọa độ từ hệ thống định vị T-Mod |
| Quản lý Từ điển vị trí | Danh sách | Danh sách địa điểm | Hiển thị từ khóa + tọa độ đã lưu | `location_macros` |
| Quản lý Từ điển vị trí | Input Text | Ô nhập từ khóa | Nhập danh từ để AI Agent nhận diện | Trường `keyword` |
| Quản lý Từ điển vị trí | Input Tọa độ | Ghim bản đồ | Lấy Lat/Lng qua thao tác kéo thả | Trường `lat`, `lng` |
| Quản lý Từ điển vị trí | Button | "Lưu & Đồng bộ" | Đẩy dữ liệu lên Cloud, cờ cập nhật SQLite | INSERT/UPDATE `location_macros`, `is_synced` |
| Cảnh báo Khẩn cấp | Card | Red Alert | Pop-up toàn màn hình, tọa độ/thời gian sự cố | Bản ghi mới nhất `sos_events` |
| Cảnh báo Khẩn cấp | Button | "Kết nối đàm thoại" | Gọi 2 chiều ưu tiên tới T-Mod | VoIP / viễn thông |
| Cảnh báo Khẩn cấp | Button | "Đã xử lý" | Tắt báo động đỏ | `status = "resolved"` trong `sos_events` |

## 2.3. Cơ sở dữ liệu phân mảnh Cloud / Edge

### Tầng Cloud Database (Supabase / PostgreSQL)

**`profiles`** — quản lý định danh & ghép nối T-Mod ↔ Relap qua `linked_id`

| Field | Type | Constraint | Mô tả |
| --- | --- | --- | --- |
| id | UUID | PK | Định danh tài khoản (Supabase Auth) |
| role | Enum | — | `t_mod` hoặc `relap` |
| full_name | Text | — | Họ tên |
| linked_id | UUID | FK | Ghép nối T-Mod ↔ Relap |

**`device_telemetry`** — trạng thái phần cứng, Relap lắng nghe qua WebSockets

| Field | Type | Constraint | Mô tả |
| --- | --- | --- | --- |
| device_id | UUID | PK | Mã thiết bị T-Mod |
| battery_percentage | Int | — | % pin (cảnh báo nếu <15%) |
| network_status | Boolean | — | True=Online |
| is_headless_active | Boolean | — | Trạng thái Headless Mode |
| last_updated | Timestamp | — | Cập nhật gần nhất |

**`location_macros`** — tọa độ ưu tiên (Từ điển vị trí)

| Field | Type | Constraint | Mô tả |
| --- | --- | --- | --- |
| id | UUID | PK | Định danh địa điểm |
| user_id | UUID | FK | Chủ sở hữu (tài khoản T-Mod) |
| keyword | Text | — | Từ khóa giọng nói (vd "Nhà") |
| lat | Float | — | Vĩ độ |
| lng | Float | — | Kinh độ |
| is_synced | Boolean | — | Đã đồng bộ xuống T-Mod chưa |

**`sos_events`** — ghi nhận sự cố khẩn cấp, trigger FCM sang Relap

| Field | Type | Constraint | Mô tả |
| --- | --- | --- | --- |
| id | UUID | PK | Định danh phiên báo động |
| device_id | UUID | FK | Thiết bị phát tín hiệu |
| trigger_method | Text | — | `voice` hoặc `physical_button` |
| lat | Float | — | Vĩ độ lúc phát sinh |
| lng | Float | — | Kinh độ lúc phát sinh |
| status | Text | — | `active` / `resolved` |
| created_at | Timestamp | — | Thời điểm kích hoạt |

### Tầng Object Storage
Cloudflare R2 (bucket `savicam-map-data`) lưu "Sổ tay lộ trình" (.zip) đã "nướng" qua GitHub Actions. T-Mod tải về 1 lần duy nhất.

### Tầng Local Database (SQLite trên T-Mod)

**`Local_Macros`** — bản sao của `location_macros`

| Field | Type | Constraint | Mô tả |
| --- | --- | --- | --- |
| id | UUID | PK | Đồng bộ 1:1 với `location_macros` |
| keyword | Text | — | Từ khóa để AI Agent truy xuất |
| lat | Float | — | Vĩ độ |
| lng | Float | — | Kinh độ |

**`App_Settings`**

| Field | Type | Constraint | Mô tả |
| --- | --- | --- | --- |
| id | Int | PK | Cố định = 1 |
| tts_speed | Float | — | Tốc độ đọc TTS |
| tts_volume | Float | — | Âm lượng mặc định |
| emergency_contacts | Text | — | Danh sách SĐT khẩn cấp |

**`Offline_Queue`** — đệm dữ liệu khi mất mạng

| Field | Type | Constraint | Mô tả |
| --- | --- | --- | --- |
| id | Int | PK, auto-increment | Định danh dòng đệm |
| payload_type | Text | — | vd `telemetry_update`, `sos_alert` |
| data | JSON | — | Nội dung đóng gói |
| created_at | Timestamp | — | Thời điểm vào hàng đợi |

> **Lưu ý kỹ thuật (đã phát hiện trong quá trình phát triển thực tế — tham chiếu `BR-03-04`):** RLS trên `location_macros` hiện chỉ cấp quyền `SELECT` cho Relap, thiếu policy `INSERT`/`UPDATE`, khiến luồng tạo macro từ Relap trả về lỗi `403 rls_violation`. Cần migration `003_fix_macros_rls.sql` để khắc phục.

---

# CHƯƠNG 3. XÂY DỰNG ỨNG DỤNG TRÊN THIẾT BỊ DI ĐỘNG

## 3.1. Định nghĩa bài toán và các kỹ thuật xử lý cốt lõi

**Bài toán:** AI (CV+NLP) + Navigation trên di động dễ hao pin, nóng máy, cần mạng liên tục. Với người khiếm thị, độ trễ/sập ứng dụng có thể gây hậu quả nghiêm trọng → cần hệ thống ngầm nhẹ, offline hoàn toàn cho tác vụ sinh tử/dẫn đường, phân loại ưu tiên luồng âm thanh.

### Kỹ thuật Vận hành Mù (Headless Mode)
T-Mod chạy dưới dạng Foreground Service; người dùng khóa màn hình, ngừng render UI để tiết kiệm RAM/pin khi di chuyển dài.

### Kỹ thuật định tuyến ngoại tuyến – "Nướng bản đồ" (Pre-build Map)
1. **Lọc rác:** Server tải bản đồ thô OSM, loại cao tốc/trạm thu phí, chỉ giữ làn đi bộ (vỉa hè, hẻm, vạch qua đường).
2. **Tính toán trước:** Server tính sẵn mọi tuyến ngắn nhất giữa các điểm giao cắt, nén thành file ZIP ("Sổ tay lộ trình"), đẩy lên Cloudflare R2.
3. **Tra cứu cục bộ:** T-Mod tải file 1 lần; khi có lệnh, chỉ "mở sổ tay" và dò trong vài chục mili-giây, kể cả khi tắt Wi-Fi/4G.

*(Pipeline: OpenStreetMap → GitHub Actions → Cloudflare R2 → Thiết bị T-Mod)*

### Đo khoảng cách & đánh giá rủi ro (Core Logic)
- Kết hợp Pinhole Camera geometry (Bounding Box) + Google ARCore Depth API để ước lượng khoảng cách.
- Tính Time-to-Collision (TTC) → phân loại 4 mức độ rủi ro.

### Cơ chế Ghi đè khẩn cấp (Preemptive Multitasking)
Luồng AI Vision chạy ngầm liên tục; khi phát hiện rủi ro Mức 1/2, ngắt ngay TTS hiện hành, phát lệnh gắt ("LÙI LẠI!", "NÉ TRÁI!") + rung.

**Ma trận phân loại rủi ro (TTC):**

| Cấp độ | TTC | Phản ứng hệ thống | Hành động yêu cầu |
| --- | --- | --- | --- |
| Mức 1 (Sinh Tử) | < 1.5s | Ghi đè tối cao, ngắt TTS, lệnh gắt + rung giật cục liên tục | Dừng/lùi ngay theo phản xạ |
| Mức 2 (Nguy Hiểm Cao) | 1.5s – 3.0s | Lệnh điều hướng dứt khoát ("Tấp lề phải"...) + rung mạnh ngắt quãng | Chủ động đổi hướng/hạ trọng tâm |
| Mức 3 (Cảnh Báo) | 3.0s – 5.0s | Beep ngắn + rung nhịp đều nhẹ | Đi chậm, dùng gậy dò |
| Mức 4 (An Toàn) | > 5.0s hoặc không vật cản | AI im lặng, chỉ đọc khi được yêu cầu | Tiếp tục di chuyển bình thường |

## 3.2. Quy trình vận hành AI Agent đa tầng

### 3.2.1. Luồng nhận diện hình ảnh (YOLOv8n – Computer Vision)
- Sau huấn luyện, áp dụng QAT → TFLite.
- Delegate chạy trên NPU qua NNAPI (tránh nghẽn CPU).
- Kết hợp YOLO (5–10 FPS) + Object Tracking (ByteTrack/SORT, C++) nội suy lên 30 FPS, tiết kiệm 70% sức tính toán.

*(Pipeline: Camera → Tiền xử lý → YOLOv8n TFLite (NPU) → Object Tracking → Đánh giá TTC)*

### 3.2.2. Luồng AI Agent xử lý ngôn ngữ đa tầng (NLP) — 3 tầng

**Tầng 1 – Tiền xử lý âm thanh:**
STT đôi khi sai từ vựng tiếng Việt → dùng FastText + Levenshtein Distance. Nếu từ không có trong từ điển và số bước biến đổi ≤ 2, tự động sửa (vd "tỉ" → "chỉ") trong ~1ms.

**Tầng 2 – AI phân tích ngữ cảnh & Đa ý định:**
multilingual-MiniLM-L6-v2 (đã fine-tune) → Multi-label Classification (nhiều ý định) + NER (bóc tách địa điểm/đồ vật). Lượng tử hóa Float32→INT8 (100MB → 20–30MB).

**Tầng 3 – Điều phối & Truy xuất dữ liệu cục bộ (Rule-based Mapping):**
Thực thể bóc tách (vd "nhà") không đẩy thẳng vào bản đồ mà qua Rule-based chọc vào bảng `Local_Macros` (SQLite) để lấy tọa độ GPS (đã đồng bộ từ Relap) → truyền vào GraphHopper.

---

# CHƯƠNG 4. ĐÁNH GIÁ VÀ KẾT QUẢ ĐẠT ĐƯỢC

## 4.1. Kết quả huấn luyện AI
- Huấn luyện YOLOv8n (Nano) trên Google Colab Pro, dữ liệu tự thu thập Việt Nam.
- 50 epochs, imgsz 640x640; loss giảm nhanh, hội tụ tốt.
- mAP50 trung bình > 88% cho các lớp vật thể quan trọng.
- Lượng tử hóa: file .pt gốc (~11–12MB) → .tflite (~3–4MB).

## 4.2. Hiệu năng ứng dụng
- Frame rate: 15–22 FPS tùy phần cứng thiết bị.
- Dẫn đường: kết quả chỉ dẫn trong vài chục mili-giây kể cả offline hoàn toàn.

## 4.3. Đánh giá thực địa (Đà Nẵng)
- Tầm nhận diện mở rộng: 3–5m so với 1–1.5m của gậy trắng truyền thống.
- Ban ngày: hiệu suất tối đa. Thiếu sáng/ngược sáng: độ chính xác giảm ~15–20% nhưng vẫn phát hiện vật thể lớn.

**Thống kê hiệu năng thực địa theo điều kiện môi trường:**

| Điều kiện | FPS | Độ chính xác | Độ trễ cảnh báo |
| --- | --- | --- | --- |
| Ban ngày (nắng ráo) | 20–22 | 88.5% | 40–50 ms |
| Ban đêm (thiếu sáng) | 16–18 | 72.0% | 55–65 ms |
| Ngược sáng mạnh | 18–20 | 73.5% | 45–55 ms |
| Trời mưa (nhiễu camera) | 15–17 | 68.0% | 60–75 ms |

## 4.4. Ưu / nhược điểm & khả năng áp dụng

**Ưu điểm:**
- Loại bỏ chi phí phần cứng chuyên dụng đắt đỏ.
- Tối ưu cho giao thông nội địa (dữ liệu địa phương hóa).
- Edge AI + dẫn đường offline → không phụ thuộc mạng, an toàn sinh tử.

**Nhược điểm:**
- Tiêu hao pin/quá nhiệt nếu dùng liên tục >2 giờ.
- Motion blur khi cầm điện thoại di chuyển làm giảm độ chính xác nhận diện.

**Khả năng áp dụng:** Cao — nhờ phổ biến của smartphone Android giá rẻ, phù hợp thu nhập thấp–trung bình tại Việt Nam.

---

# CHƯƠNG 5. KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN

## 5.1. Thành quả đạt được
- Làm chủ Edge AI + lượng tử hóa mô hình (YOLOv8n, MiniLM) trên dữ liệu địa phương hóa.
- Mở rộng tầm nhìn hỗ trợ lên 3–5m (so với 1–1.5m của gậy trắng).
- Vận hành độc lập, offline hoàn toàn (SQLite + Sổ tay lộ trình OSM).
- Hoàn thiện SaViCam Relap (Supabase/PostgreSQL) cho giám sát/SOS thời gian thực.

## 5.2. Hướng phát triển tương lai
- **Phụ kiện vật lý (Mounting clips):** ngàm kẹp cố định điện thoại lên ngực/mũ, giảm motion blur, hands-free.
- **Cải tiến thời tiết khắc nghiệt:** bộ lọc khử nhiễu sương mù/mưa; mở rộng dữ liệu ban đêm.
- **Nhận diện người quen (Familiar Face Recognition):** nhận diện khuôn mặt cục bộ, thông báo danh tính.
- **Tự động hóa SOS (Emergency Contact Integration):** kết hợp Accelerometer + Gyroscope để tự phát hiện té ngã/va chạm mạnh, tự động gửi SOS.

---


