# SaViCam T-Mod & ReLap Ecosystem

**SaViCam T-Mod** is an intelligent software solution that transforms a smartphone into a pair of "eyes" to assist the visually impaired. This project focuses on optimizing Edge AI performance directly on mobile devices, ensuring safety, efficiency, and continuous operation in real-world conditions.

## 📱 SaViCam T-Mod (Edge Device)

The core application designed for the visually impaired, featuring breakthrough capabilities:

* **Headless Mode:** Runs continuously as a stable Foreground Service. It allows the user to lock the screen completely to save battery and system resources while maintaining 24/7 background recognition.
* **Hybrid Edge AI Architecture:**
    * **YOLOv8n:** Real-time object detection. The model is optimized using **Quantization Aware Training (QAT)** and exported to TFLite format (INT8) for maximum efficiency.
    * **AI Agent (multilingual-MiniLM-L6-v2):** Handles natural language processing and multi-step contextual analysis, enabling users to execute complex voice commands.
* **Native Performance:** Integrates a C++ core layer via JNI/FFI to configure the **NNAPI Delegate**, maximizing the NPU/GPU hardware acceleration on the smartphone.
* **4-Level Warning System:** Ranging from general environmental descriptions (Level 4) to critical life-threatening alerts (Level 1 - intervening with sharp audio cues and maximum haptic feedback).

## 👥 SaViCam ReLap (Companion App)

A dedicated app connecting relatives and guardians for support and safety monitoring:

* **Critical Alert Override:** Pierces through the relative's phone "Do Not Disturb" or silent mode when an emergency SOS signal is triggered.
* **Live Feed:** Allows relatives to access real-time Video/Audio streams via **WebRTC** to assist the user remotely in difficult situations.
* **Route Monitoring & Geofencing:** Tracks real-time location and instantly pushes alerts if the user deviates from the defined "Safe Zone".

## 🛠 Tech Stack

### Mobile & AI
* **Framework:** Flutter (Cross-platform UI).
* **Native Core:** Android C++ (NDK) for core computer vision logic and Object Tracking (ByteTrack).
* **AI Engine:** TensorFlow Lite (GPU/NNAPI acceleration).
* **Navigation:** OpenStreetMap + GraphHopper (Supports compressed Offline "Route Handbooks").

### Infrastructure & Backend
* **Cloud Infrastructure:** Oracle Cloud Free Tier (API Gateway, gRPC, WebSockets).
* **Object Storage:** Cloudflare R2 (For map data and AI model storage).
* **Database:** MongoDB Atlas (Remote User Management) & SQLite (Local Device Storage).
* **Communication:** WebRTC (Live Stream), MQTT (Telemetry), and Firebase FCM (High-priority notifications).

## 🏗 Project Structure (essential components)

```text
.
├── android/                # Native Android & C++ JNI configurations
│   └── app/src/main/cpp/   # Core TFLite execution & Object Tracking (C++)
├── assets/                 # Contains YOLOv8n (QAT) and MiniLM (INT8) models
├── lib/
│   ├── ai_engine/          # AI Agent and YOLO orchestration logic
│   ├── features/           # Core modules: SOS, Navigation, Essential Mode
│   ├── native_bridge/      # MethodChannel linking Flutter and Native C++
│   └── main.dart           # Entry point & Foreground Service initialization
└── README.md