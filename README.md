# SaViCam T-Mod & ReLap

[cite_start]SaViCam T-Mod là giải pháp phần mềm thông minh biến điện thoại di động thành "đôi mắt" hỗ trợ người khiếm thị[cite: 45]. [cite_start]Phiên bản này tận dụng tối đa tài nguyên có sẵn trên Smartphone bao gồm Camera, Micro và GPS[cite: 46]. [cite_start]Hệ sinh thái bao gồm ứng dụng chính SaViCam T-Mod chạy trên thiết bị Edge và ứng dụng đồng hành SaViCam Relap dành cho người thân để theo dõi từ xa[cite: 48, 49].

## Kiến trúc Hệ thống SaViCam T-Mod

* [cite_start]**Vận hành Mù (Headless Mode):** Ứng dụng chạy ngầm dưới dạng Foreground Service để tiết kiệm tối đa RAM và Pin cho hệ thống[cite: 51, 190].
* [cite_start]**Khóa giao diện:** Người dùng có thể khóa hẳn màn hình thiết bị để chấm dứt việc render giao diện UI không cần thiết[cite: 52].
* [cite_start]**Xử lý tại biên (Edge AI):** Hệ thống kết hợp hai mô hình AI là YOLOv8n và AI Agent (multilingual-MiniLM-L6-v2)[cite: 55].
* [cite_start]**Nhận diện bằng YOLOv8n:** Áp dụng Quantization Aware Training (QAT) khi chuyển đổi mô hình sang định dạng TFLite để giảm dung lượng mà vẫn giữ độ chính xác[cite: 66, 67].
* [cite_start]**Tăng tốc phần cứng:** Cấu hình Delegate trong C++ để chạy TFLite trực tiếp trên NPU qua Neural Networks API (NNAPI)[cite: 68, 194].
* [cite_start]**Theo dõi vật thể (Object Tracking):** Kết hợp YOLO với thuật toán ByteTrack/SORT nội suy ở tốc độ 30 FPS bằng C++[cite: 69].
* [cite_start]**Đánh giá rủi ro (Time-to-Collision):** Tính toán chỉ số TTC dựa trên khoảng cách và vận tốc tương đối để phân loại vật cản[cite: 70, 186].
* [cite_start]**Tiền xử lý âm thanh (AI Agent Tầng 1):** Sử dụng FastText và thuật toán Levenshtein Distance để so khớp chuỗi[cite: 74, 77].
* [cite_start]**Phân tích ngữ cảnh (AI Agent Tầng 2):** Mô hình multilingual-MiniLM-L6-v2 thực hiện Multi-label Classification và Token Classification/NER[cite: 82, 84, 85].
* [cite_start]**Lượng tử hóa AI Agent:** Ép trọng số từ Float32 sang INT8 thông qua kỹ thuật QAT để giảm dung lượng mô hình xuống mức lý tưởng 20MB - 30MB[cite: 191, 192].
* [cite_start]**Điều phối cục bộ (AI Agent Tầng 3):** Sử dụng thuật toán Rule-based Mapping kết hợp với SQLite hoặc Room DB trên Android[cite: 97].

## Các Module Cốt Lõi

* [cite_start]**Module Nhận diện (Essential Mode):** Luôn hoạt động ở trạng thái mặc định để nhận diện và phát âm thanh cảnh báo về vật thể[cite: 111, 112].
* [cite_start]**Module SOS:** Kích hoạt gửi tin nhắn trạng thái và vị trí cho tất cả người thân, đồng thời thực hiện cuộc gọi khẩn cấp theo thứ tự thiết lập[cite: 117, 118, 119].
* [cite_start]**Module Hướng dẫn di chuyển:** Lõi dẫn đường được lấy từ OpenStreetMap và sử dụng GraphHopper để tính toán lộ trình[cite: 125].
* [cite_start]**Bản đồ Offline:** Máy chủ tính toán sẵn mọi tuyến đường và nén dữ liệu lộ trình thành tệp Sổ tay tra cứu nhanh cho ứng dụng tải về thiết bị Edge[cite: 203, 204].
* [cite_start]**Module Sinh hoạt thường ngày:** AI Agent xác định rõ yêu cầu người dùng và thực hiện các tác vụ đa bước[cite: 130].
* [cite_start]**Cơ chế Ghi đè (Preemptive Multitasking):** Luồng nền lập tức ngắt bỏ luồng Text-to-Speech (TTS) khi phát hiện nguy hiểm Mức 1 hoặc 2 để chiếm quyền loa[cite: 167, 188].

## Mức độ Cảnh báo An toàn

* [cite_start]**Mức 1 (Sinh Tử):** Trạng thái nguy hiểm tính mạng trực tiếp, hệ thống phát lệnh âm thanh cực gắt và đẩy hiệu ứng rung giật cục tối đa trên tay cầm[cite: 134, 135, 140].
* [cite_start]**Mức 2 (Nguy Hiểm Cao):** Yêu cầu người dùng dạt sang một bên dứt khoát theo các lệnh điều hướng hành động[cite: 142, 148].
* [cite_start]**Mức 3 (Cảnh Báo Tiềm Ẩn):** Cảnh báo nguy cơ va vấp bằng động cơ rung nhịp chậm và sử dụng các tệp âm thanh thu sẵn ngắn gọn[cite: 150, 151, 155, 156].
* [cite_start]**Mức 4 (Thông Tin Môi Trường):** Môi trường an toàn, con mắt AI chạy ngầm và xử lý các yêu cầu thứ cấp như đọc mô tả không gian[cite: 158, 159, 163, 164].

## Ứng dụng Đồng hành SaViCam ReLap

* [cite_start]**Báo động ghi đè (Critical Alert Override):** Xuyên thủng chế độ Im lặng trên điện thoại người thân thông qua Firebase Cloud Messaging với cờ ưu tiên cao[cite: 6, 10].
* [cite_start]**Luồng Trực tiếp:** Người thân có thể yêu cầu truy cập luồng Video/Audio trực tiếp qua WebRTC với độ trễ cực thấp[cite: 7, 9].
* [cite_start]**Hiển thị Màn hình Khẩn cấp:** Tích hợp CallKit (iOS) và ConnectionService (Android) để hiển thị báo động dạng cuộc gọi đến ngay cả khi khóa màn hình[cite: 11].
* [cite_start]**Giám sát An toàn Chủ động:** Vẽ Hàng rào địa lý (Geofencing) để cảnh báo khi người dùng đi ra khỏi vùng an toàn bằng Turf.js hoặc PostGIS[cite: 15, 16, 20].
* [cite_start]**Cảnh báo Lệch tuyến:** Đẩy cảnh báo thời gian thực về ReLap qua kết nối WebSockets hoặc gRPC[cite: 17, 21].
* [cite_start]**Bảng điều khiển Trạng thái:** Hiển thị mức pin và trạng thái kết nối hệ thống liên tục qua giao thức MQTT[cite: 24, 27].
* [cite_start]**Quản lý Cấu hình Từ xa:** Đồng bộ danh bạ khẩn cấp và cài đặt điểm đến mặc định qua RESTful API kết hợp lưu trữ MongoDB Atlas[cite: 32, 33, 35, 36].

## Stack Công nghệ Toàn Hệ Thống

* [cite_start]**Nền tảng Mobile:** Sử dụng Flutter cho phát triển đa nền tảng kết hợp Native Android (C++) ở tầng lõi hiệu năng[cite: 39, 172, 174].
* [cite_start]**Cầu nối Giao tiếp:** Giao tiếp giữa tầng Flutter và Native C++ được thực hiện thông qua MethodChannel (FFI)[cite: 175].
* [cite_start]**Máy chủ Giao tiếp (Cloud):** Triển khai API Gateway trên Oracle Cloud Free Tier để duy trì luồng gRPC/WebSockets và tối ưu hóa chi phí[cite: 218, 225].
* [cite_start]**Lưu trữ Lộ trình:** Lưu trữ Sổ tay lộ trình trên dịch vụ Object Storage Cloudflare R2[cite: 222, 223].
* [cite_start]**Backend & Microservices:** Sử dụng Node.js xử lý kết nối WebSockets thời gian thực và Spring Boot cho việc tích hợp API bên thứ ba[cite: 40, 41].