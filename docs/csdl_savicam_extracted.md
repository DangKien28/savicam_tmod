2.3. Cơ sở dữ liệu phân mảnh giữa tầng Cloud và tầng Edge

Để hệ thống có khả năng sống sót trong điều kiện mất kết nối mạng, kiến trúc cơ sở dữ liệu được phân mảnh có chủ đích.

Tầng Cloud Database (Quản trị tập trung và Thời gian thực):

Triển khai trên nền tảng Supabase / PostgreSQL, đóng vai trò quản lý tài khoản và đồng bộ dữ liệu.

profiles: Quản lý định danh người dùng và ghép nối thiết bị T-Mod với ứng dụng Relap qua khóa ngoại (linked_id).

device_telemetry: Lưu trữ trạng thái phần cứng (pin, mạng, màn hình). Ứng dụng Relap sẽ "lắng nghe" bảng này qua WebSockets để cập nhật giao diện ngay lập tức.

location_macros & sos_events: Quản lý các tọa độ ưu tiên và ghi nhận sự cố khẩn cấp. Khi có dòng dữ liệu mới tại sos_events, hệ thống kích hoạt tự động tin nhắn báo động Firebase Cloud Messaging (FCM) sang Relap.

Table 3: Cấu trúc bảng profiles (Tầng Cloud)

| Tên trường (Field Name) | Kiểu dữ liệu (Data Type) | Ràng buộc (Constraint) | Mô tả chi tiết |
| --- | --- | --- | --- |
| id | UUID | Primary Key (PK) | Khóa chính, định danh tài khoản người dùng (liên kết với Supabase Auth). |
| role | Enum | None | Vai trò của tài khoản (giá trị: t_mod hoặc relap). |
| full_name | Text | None | Họ và tên đầy đủ của người dùng. |
| linked_id | UUID | Foreign Key (FK) | Khóa ngoại dùng để ghép nối tài khoản thiết bị T-Mod với tài khoản Relap của người thân. |

|  |
| --- |

Table 4: Cấu trúc bảng device_telemetry (Tầng Cloud)

| Tên trường (Field Name) | Kiểu dữ liệu (Data Type) | Ràng buộc (Constraint) | Mô tả chi tiết |
| --- | --- | --- | --- |
| device_id | UUID | Primary Key (PK) | Khóa chính, đồng thời là mã định danh của thiết bị T-Mod. |
| battery_percentage | Int | None | Phần trăm pin hiện tại của thiết bị T-Mod (sẽ phát cảnh báo nếu < 15%). |
| network_status | Boolean | None | Trạng thái kết nối mạng của thiết bị (True = Online, False = Offline). |
| is_headless_active | Boolean | None | Trạng thái màn hình, xác định T-Mod có đang chạy ở chế độ Vận hành mù hay không. |
| last_updated | Timestamp | None | Thời gian cập nhật trạng thái hệ thống gần nhất. |

Table 5: Cấu trúc bảng location_macros (Tầng Cloud)

| Tên trường (Field Name) | Kiểu dữ liệu (Data Type) | Ràng buộc (Constraint) | Mô tả chi tiết |
| --- | --- | --- | --- |
| id | UUID | Primary Key (PK) | Khóa chính, định danh ngẫu nhiên cho mỗi địa điểm. |
| user_id | UUID | Foreign Key (FK) | Khóa ngoại trỏ tới tài khoản T-Mod sở hữu điểm đến này. |
| keyword | Text | None | Từ khóa nhận diện giọng nói (Ví dụ: "Nhà", "Công ty", "Bệnh viện"). |
| lat | Float | None | Vĩ độ (Latitude) của điểm đến trên bản đồ. |
| lng | Float | None | Kinh độ (Longitude) của điểm đến trên bản đồ. |
| is_synced | Boolean | None | Cờ đánh dấu dữ liệu đã được đồng bộ thành công xuống thiết bị T-Mod hay chưa. |

Table 6: Cấu trúc bảng sos_events (Tầng Cloud)

| Tên trường (Field Name) | Kiểu dữ liệu (Data Type) | Ràng buộc (Constraint) | Mô tả chi tiết |
| --- | --- | --- | --- |
| id | UUID | Primary Key (PK) | Khóa chính, định danh của phiên báo động khẩn cấp. |
| device_id | UUID | Foreign Key (FK) | Khóa ngoại trỏ tới thiết bị T-Mod phát ra tín hiệu cầu cứu. |
| trigger_method | Text | None | Phương thức kích hoạt SOS (giá trị: voice hoặc physical_button). |
| lat | Float | None | Vĩ độ tại thời điểm phát sinh cảnh báo khẩn cấp. |
| lng | Float | None | Kinh độ tại thời điểm phát sinh cảnh báo khẩn cấp. |
| status | Text | None | Trạng thái xử lý sự cố (giá trị: active - đang xảy ra, resolved - đã giải quyết). |
| created_at | Timestamp | None | Thời gian chính xác sự cố được kích hoạt. |

Tầng Object Storage (Phân phối tài nguyên bản đồ):

Sử dụng Cloudflare R2 (Bucket savicam-map-data) để lưu trữ các "Sổ tay lộ trình" (.zip) chứa dữ liệu định tuyến đã được “nướng” sẵn qua GitHub Actions. Thiết bị T-Mod gọi API để tải tệp đồ thị này về máy một lần duy nhất.

Tầng Local Database (Vận hành ngoại tuyến tại Edge):

Triển khai bằng SQLite trực tiếp trên bộ nhớ máy điện thoại T-Mod.

Local_Macros: Bản sao đồng bộ của location_macros. Khi AI Agent bóc tách được ý định "về nhà", ứng dụng sẽ chọc thẳng vào bảng này để lấy tọa độ trong 0.01 giây mà không cần gọi API lên mạng.

App_Settings: Lưu cấu hình hệ thống, tốc độ đọc văn bản (TTS) và danh sách liên hệ khẩn cấp.

Offline_Queue: Bộ đệm lưu trữ các cảnh báo đo lường tạm thời khi T-Mod mất mạng, tự động xả dữ liệu đồng bộ lên Cloud ngay khi có kết nối trở lại.

Table 7: Cấu trúc bảng Local_Macros (Tầng Edge)

| Tên trường (Field Name) | Kiểu dữ liệu (Data Type) | Ràng buộc (Constraint) | Mô tả chi tiết |
| --- | --- | --- | --- |
| id | UUID | Primary Key (PK) | Khóa chính, đồng bộ 1:1 với ID từ bảng location_macros trên Cloud. |
| keyword | Text | None | Từ khóa nhận diện giọng nói để AI Agent chọc vào truy xuất (VD: "nhà"). |
| lat | Float | None | Vĩ độ (Latitude) của điểm đến. |
| lng | Float | None | Kinh độ (Longitude) của điểm đến. |

Table 8: Cấu trúc bảng App_Settings (Tầng Edge)

| Tên trường (Field Name) | Kiểu dữ liệu (Data Type) | Ràng buộc (Constraint) | Mô tả chi tiết |
| --- | --- | --- | --- |
| id | Int | Primary Key (PK) | Khóa chính (Thường cố định là 1 do chỉ có một dòng cấu hình). |
| tts_speed | Float | None | Cấu hình tốc độ giọng đọc của hệ thống Text-to-Speech (TTS). |
| tts_volume | Float | None | Cấu hình âm lượng mặc định của trợ lý AI. |
| emergency_contacts | Text | None | Danh sách các số điện thoại khẩn cấp lưu dưới dạng chuỗi (dùng để gọi trực tiếp qua viễn thông khi mất mạng). |

Table 9: Cấu trúc bảng Offline_Queue (Tầng Edge)

| Tên trường (Field Name) | Kiểu dữ liệu (Data Type) | Ràng buộc (Constraint) | Mô tả chi tiết |
| --- | --- | --- | --- |
| id | Int | Primary Key (PK) | Khóa chính định danh dòng dữ liệu lưu đệm (tự động tăng). |
| payload_type | Text | None | Loại dữ liệu đang chờ đồng bộ (VD: telemetry_update, sos_alert). |
| data | JSON | None | Nội dung dữ liệu được đóng gói dưới dạng JSON để xả lên Cloud khi có mạng. |
| created_at | Timestamp | None | Thời gian dữ liệu được đưa vào hàng đợi. |

Figure 4: Sơ đồ phân mảnh cơ sở dữ liệu giữa Tầng Cloud và Tầng Edge
