# SaViCam — ARCHITECTURE LOCK

> Governing document for 5-student team | 28-day delivery window
> Dual-mode: MODE A = Research Report, MODE B = MVP Android Prototype

---

## SECTION A — ARCHITECTURE ASSUMPTIONS

---

**ARCH-01 | Platform | Hard | BOTH**

STATEMENT: SaViCam targets Android only (minSdk 26+); iOS is out of scope.
JUSTIFICATION: The SaViCam document specifies a Flutter + Native Android implementation and benchmarks APK delivery on mid-range Android devices. All AI acceleration references (NNAPI/NPU) are Android-specific APIs.
28-DAY FILTER: GREEN — Flutter + Android is the team's declared stack; no cross-platform overhead.
RISK IF WRONG: iOS CoreML substitution would require 7+ days of engine porting.

---

**ARCH-02 | AI/ML | Hard | BOTH**

STATEMENT: YOLOv8n TFLite (INT8-quantized, ~3–4 MB) runs on-device via NNAPI delegate; no cloud inference path exists for CV.
JUSTIFICATION: The document explicitly states QAT ε Float32→INT8 shrinks the model to 3–4 MB and mandates NPU acceleration to sustain 15–22 FPS on mid-range hardware. Offline safety is non-negotiable.
28-DAY FILTER: YELLOW — Model is pre-trained; integration risk is TFLite delegate config. Stub: static bounding-box feed from a pre-recorded video file.
RISK IF WRONG: NNAPI unavailability on test device forces CPU fallback, dropping to <8 FPS.

---

**ARCH-03 | AI/ML | Hard | BOTH**

STATEMENT: MiniLM-L6-v2 (INT8, ~20–30 MB) is the sole NLP layer in the MVP; FastText+Levenshtein pre-processing is designed but not implemented.
JUSTIFICATION: The document's 3-layer NLP pipeline (FastText → MiniLM → SQLite dispatch) is the designed architecture. The Levenshtein corrector is explicitly flagged as a master's-thesis-level effort; the MVP fine-tunes MiniLM on STT-error variants instead.
28-DAY FILTER: YELLOW — Fine-tuned model must be ready by Day 14. Stub: hardcoded intent map for 5 Vietnamese commands.
RISK IF WRONG: MiniLM mis-classifies noisy STT input; fallback to stub degrades navigation UX but does not break safety.

---

**ARCH-04 | Network | Soft | BOTH**

STATEMENT: All safety-critical functions (CV, TTC, navigation) operate fully offline; cloud sync is best-effort and never blocks the user.
JUSTIFICATION: The document states that even total 4G loss must not degrade warnings or routing. The Offline_Queue table buffers telemetry/SOS payloads and flushes on reconnect.
28-DAY FILTER: GREEN — Offline-first is the architecture's core thesis; no additional implementation cost.
RISK IF WRONG: SOS events silently queue and never flush if Supabase schema is misconfigured.

---

**ARCH-05 | Navigation | Hard | BOTH**

STATEMENT: GraphHopper pre-built pedestrian graph (.zip on Cloudflare R2) is fetched once at first launch and stored locally; no runtime OSM API calls occur.
JUSTIFICATION: The document describes a "Pre-build Map" pipeline: GitHub Actions processes OSM data, retains pedestrian-only paths, and pushes the route graph to Cloudflare R2 for one-time device download.
28-DAY FILTER: ORANGE — Map pre-build pipeline takes 2–3 days to script and validate. Simplified MVP: pre-build a small Da Nang tile manually and ship it in APK assets.
RISK IF WRONG: A large/corrupted graph file causes first-launch failure; pre-bundle a validated 50 MB tile as fallback.

---

**ARCH-06 | Database | Hard | BOTH**

STATEMENT: SQLite (via Flutter sqflite) is the sole local storage engine; Room DB is not used to keep the stack to a single language bridge.
JUSTIFICATION: The document lists three SQLite tables on the edge layer (Local_Macros, App_Settings, Offline_Queue) and maps them directly to Flutter Dart code paths. Supabase/PostgreSQL handles only cloud-side tables.
28-DAY FILTER: GREEN — sqflite is well-documented and installs in < 0.5 days.
RISK IF WRONG: Schema migration logic missing; cold-start after APK update corrupts Local_Macros.

---

**ARCH-07 | Team/Process | Soft | IMPLEMENTED**

STATEMENT: Mock-first mandate: the Flutter app is fully demo-able with stubs by Day 14; real AI models plug in during Week 3.
JUSTIFICATION: With 5 students and concurrent tracks, AI integration before UI completion creates merge conflicts and blocked testing. Stubs enable parallel development of Relap and T-Mod UI while ML engineers finalize models.
28-DAY FILTER: GREEN — Stub interfaces are defined at contract boundaries (MethodChannel); no extra build cost.
RISK IF WRONG: Late stub definition causes Relap UI to stall waiting for T-Mod data contracts.

---

**ARCH-08 | Safety | Hard | BOTH**

STATEMENT: The Preemptive Interrupt System holds OS-level audio priority and can kill any TTS stream within one frame cycle (~50 ms) to issue a Level 1 alert.
JUSTIFICATION: The document's TTC matrix defines Level 1 (TTC < 1.5 s) as requiring instant audio override. The Foreground Service architecture and Android AudioFocus API are the mechanism.
28-DAY FILTER: YELLOW — AudioFocus GAIN_TRANSIENT_MAY_DUCK implementation is 1–2 days. Stub: beep tone with hardcoded trigger on dummy TTC value.
RISK IF WRONG: Android battery optimization kills Foreground Service mid-session; must add wake lock.

---

**ARCH-09 | Framework | Hard | BOTH**

STATEMENT: Clean Architecture tiers are applied selectively: Full BLoC for safety_assistant/navigation/sos, MVVM+Provider for live_tracking/telemetry/macros, plain StatefulWidget for settings/onboarding.
JUSTIFICATION: The document identifies SaViCam as a Flutter ecosystem. Applying full Clean Architecture to thin settings screens generates meaningless boilerplate; tiered architecture matches complexity to cost.
28-DAY FILTER: GREEN — Tier assignment prevents over-engineering; saves ~3 days vs. uniform BLoC.
RISK IF WRONG: Inconsistent tier usage causes cross-module state leaks between BLoC and Provider layers.

---

**ARCH-10 | Safety | Hard | BOTH**

STATEMENT: SOS events are written to Supabase sos_events; when offline they queue in SQLite Offline_Queue and flush automatically on reconnect. FCM pushes the alert to Relap.
JUSTIFICATION: The document defines the full SOS data flow: sos_events table schema, FCM trigger on new rows, and Offline_Queue as the offline buffer. This is a non-negotiable safety feature for the visually impaired user.
28-DAY FILTER: YELLOW — Supabase row-level triggers + FCM integration takes 1.5–2 days. Stub: local notification on the same device simulates Relap alert.
RISK IF WRONG: FCM token not persisted after app reinstall silently breaks alert delivery.

---

## SECTION B — SUBSYSTEM CATALOG

---

**1. CV Pipeline (YOLO Inference)**
Boundary: Edge-T-Mod | Status: IMPLEMENTED | 28-Day: YELLOW
Purpose: Runs YOLOv8n TFLite on-device at 5–10 FPS, outputs bounding boxes for downstream TTC evaluation.
Depends on: Object Tracker, TTC Evaluator, Foreground Service
Failure UX: Silent camera freeze; user receives no obstacle warnings and walks into danger.

**2. Object Tracker (IoU Kotlin — MVP downgrade from ByteTrack C++)**
Boundary: Edge-T-Mod | Status: IMPLEMENTED | 28-Day: GREEN
Purpose: Interpolates YOLO detections from 10 FPS to ~30 FPS using simple IoU matching in Kotlin, called from Flutter via MethodChannel.
Depends on: CV Pipeline
Failure UX: Bounding boxes flicker; TTC jitter may generate false Level 1 alerts.

**3. TTC Evaluator (4-level risk classifier)**
Boundary: Edge-T-Mod | Status: IMPLEMENTED | 28-Day: GREEN
Purpose: Computes Time-to-Collision via Pinhole Camera geometry + ARCore Depth; classifies into 4 risk levels to drive audio/haptic output.
Depends on: Object Tracker
Failure UX: All obstacles treated as Level 4 (safe); no urgent audio warnings issued.

**4. Preemptive Interrupt System (audio override)**
Boundary: Edge-T-Mod | Status: IMPLEMENTED | 28-Day: YELLOW
Purpose: Holds Android AudioFocus; kills active TTS stream and fires priority alert within one frame on Level 1/2 detection.
Depends on: TTC Evaluator, STT/TTS Engine
Failure UX: Navigation instructions continue playing over an incoming collision alert; user may not react in time.

**5. NLP Agent (MiniLM single-layer — MVP downgrade from 3-layer)**
Boundary: Edge-T-Mod | Status: IMPLEMENTED | 28-Day: YELLOW
Purpose: Fine-tuned MiniLM-L6-v2 (INT8) performs intent classification + NER on Vietnamese voice commands, then dispatches to SQLite or GraphHopper.
Depends on: STT/TTS Engine, SQLite Local Database
Failure UX: Voice commands unrecognised; user cannot trigger navigation by speech and must retry.

**6. STT/TTS Engine**
Boundary: Edge-T-Mod | Status: IMPLEMENTED | 28-Day: GREEN
Purpose: Android SpeechRecognizer for STT; Flutter TTS package for audio output; both operate offline on-device.
Depends on: Preemptive Interrupt System
Failure UX: User cannot issue voice commands or hear any AI guidance; app becomes non-functional for blind users.

**7. GraphHopper Offline Router**
Boundary: Edge-T-Mod | Status: IMPLEMENTED | 28-Day: ORANGE
Purpose: Queries pre-built pedestrian route graph to produce turn-by-turn instructions in <50 ms with zero network dependency.
Depends on: OSM Map Pre-builder, SQLite Local Database
Failure UX: Navigation mode silent; user hears "route unavailable" and cannot be guided to destination.

**8. OSM Map Pre-builder (Build-time)**
Boundary: Build-Pipeline | Status: SCAFFOLD | 28-Day: ORANGE
Purpose: GitHub Actions job filters OSM PBF data to pedestrian-only paths for Da Nang, runs GraphHopper pre-build, and pushes output .zip to Cloudflare R2.
Depends on: (none — build-time only)
Failure UX: If pipeline fails, stale or missing map file ships in APK; navigation silently falls back to stub directions.

**9. SQLite Local Database**
Boundary: Edge-T-Mod | Status: IMPLEMENTED | 28-Day: GREEN
Purpose: Hosts Local_Macros, App_Settings, Offline_Queue for fully offline operation and sub-10 ms keyword lookups.
Depends on: (none)
Failure UX: App cannot load user macros or settings; navigation and SOS queue are lost on restart.

**10. Foreground Service / Headless Mode Manager**
Boundary: Edge-T-Mod | Status: IMPLEMENTED | 28-Day: YELLOW
Purpose: Android Foreground Service keeps CV and NLP pipelines alive with screen off; updates is_headless_active telemetry to cloud.
Depends on: SQLite Local Database, Supabase Cloud Backend
Failure UX: App killed by OS after 2–3 minutes of screen-off; user loses all real-time protection during hands-free travel.

**11. SOS Module**
Boundary: Edge-T-Mod | Status: IMPLEMENTED | 28-Day: YELLOW
Purpose: Long-press (3–5 s) trigger captures GPS, writes to sos_events or Offline_Queue, fires FCM to Relap, opens priority audio channel.
Depends on: SQLite Local Database, Supabase Cloud Backend, FCM Push Notifications
Failure UX: Distressed user cannot summon help; SOS payload silently queues but Relap guardian receives no alert.

**12. Supabase Cloud Backend**
Boundary: Cloud | Status: IMPLEMENTED | 28-Day: GREEN
Purpose: PostgreSQL via Supabase hosts profiles, device_telemetry, location_macros, sos_events; provides Auth and row-level security.
Depends on: (none)
Failure UX: Cloud sync fails silently; Relap shows stale telemetry and never receives SOS alerts.

**13. WebSocket Realtime Sync**
Boundary: Cloud | Status: IMPLEMENTED | 28-Day: GREEN
Purpose: Supabase Realtime channel pushes device_telemetry and location_macros updates to Relap UI without polling.
Depends on: Supabase Cloud Backend
Failure UX: Relap dashboard shows static data; guardian cannot see live battery/location updates.

**14. FCM Push Notifications**
Boundary: Cloud | Status: IMPLEMENTED | 28-Day: YELLOW
Purpose: Supabase database trigger on sos_events INSERT fires FCM message to Relap guardian's device, waking screen with red alert.
Depends on: Supabase Cloud Backend
Failure UX: Guardian's Relap app does not wake on SOS; alert only visible when app is manually opened.

**15. Relap Live Tracking UI**
Boundary: Relap-App | Status: IMPLEMENTED | 28-Day: GREEN
Purpose: Map screen in Relap shows real-time GPS position of T-Mod user pulled via WebSocket from device_telemetry.
Depends on: WebSocket Realtime Sync, Supabase Cloud Backend
Failure UX: Guardian sees no map pin; cannot confirm user's location during movement.

**16. Relap SOS Alert UI**
Boundary: Relap-App | Status: IMPLEMENTED | 28-Day: GREEN
Purpose: Full-screen red overlay triggered by FCM; shows incident coordinates, timestamp, and one-tap priority call button.
Depends on: FCM Push Notifications, Supabase Cloud Backend
Failure UX: Guardian misses SOS entirely if FCM delivery fails; no secondary alerting mechanism.

**17. Relap Telemetry Dashboard**
Boundary: Relap-App | Status: IMPLEMENTED | 28-Day: GREEN
Purpose: Data grid displaying battery %, network status, and headless mode state of the paired T-Mod device in real time.
Depends on: WebSocket Realtime Sync
Failure UX: Guardian cannot detect low-battery risk or lost connectivity before a critical incident.

**18. Relap UserMacros Manager**
Boundary: Relap-App | Status: IMPLEMENTED | 28-Day: GREEN
Purpose: Form UI for guardian to create keyword→GPS mappings (e.g., "Nhà"); syncs to location_macros on cloud, sets is_synced flag for T-Mod pull.
Depends on: Supabase Cloud Backend, SQLite Local Database (T-Mod pull)
Failure UX: T-Mod NLP Agent cannot resolve voice-commanded destinations; navigation commands fail silently.

---

## SECTION C — 4-WEEK SWIM-LANE

### Developer Roles

| ID | Role | Primary Skills |
|---|---|---|
| DEV-01 | Flutter UI Lead | Flutter, BLoC, Accessibility, Dart |
| DEV-02 | AI/ML Engineer | Python, TFLite, ONNX, Android NNAPI |
| DEV-03 | Android Native / Edge | Kotlin, Android Services, MethodChannel, C++ |
| DEV-04 | Backend / Cloud | Supabase, PostgreSQL, FCM, WebSockets |
| DEV-05 | Navigation / Build | GraphHopper, OSM, GitHub Actions, Cloudflare R2 |

---

### Swim-Lane Table

| Week | DEV-01 | DEV-02 | DEV-03 | DEV-04 | DEV-05 |
|---|---|---|---|---|---|
| **W1** | Scaffold Flutter mono-repo; build 3 T-Mod screens (Safety/Nav/Daily) with stub data `[STUB-READY]` | Set up Colab training env; begin YOLOv8n fine-tune on Da Nang dataset | Implement Foreground Service skeleton; wire MethodChannel bridge | Deploy Supabase schema (all 4 cloud tables); configure Auth `[SYNC]` | Download Da Nang OSM PBF; run first local GraphHopper pre-build test |
| **W1 end** | APK installs, 3 screens visible, SOS button fires fake alert to Relap `[DEMO-CHECK]` | | | Supabase schema live, fake SOS event visible in Relap | |
| **W2** | Integrate real TTC → audio pipeline into Safety screen; build Relap Live Tracking + Telemetry UI | Export YOLOv8n INT8 TFLite; validate NNAPI delegate on test device `[STUB-READY]` | Implement IoU Kotlin tracker; wire YOLO TFLite inference via MethodChannel | Implement WebSocket listener in Relap; wire device_telemetry realtime feed | Script GitHub Actions OSM pre-build; push .zip to Cloudflare R2; load graph in T-Mod `[STUB-READY]` |
| **W2 end** | Real YOLOv8n integrated (≥ any FPS), GraphHopper map loaded, NLP responds to 3 Vietnamese commands `[DEMO-CHECK]` `[SYNC]` | | | | |
| **W3** | Polish Preemptive Interrupt (AudioFocus); complete Relap SOS Alert UI + UserMacros form | Fine-tune MiniLM on Vietnamese STT-error variants; export INT8 TFLite; integrate via MethodChannel | Implement TTC Evaluator (Pinhole + ARCore); wire Level 1/2 audio override | Implement FCM trigger on sos_events INSERT; test end-to-end SOS push | Verify offline routing accuracy; tune pedestrian-only filter for Da Nang streets |
| **W3 end** | Full SOS flow end-to-end; first field test on Da Nang sidewalk `[DEMO-CHECK]` `[SYNC]` | | | | |
| **W4** | Bug fixes, accessibility audit; demo script prep | Write AI training results section for report `[REPORT]` | Stability pass on Foreground Service wake lock; thermal throttle test | Write cloud architecture section for report `[REPORT]` | Write navigation/map section for report; finalize APK build CI `[REPORT]` |
| **W4 — Day 24** | **CODE FREEZE** — only critical bug fixes after this point `[SYNC]` | | | | |

---

### Top 5 Blocking Dependencies

| Dependency | Blocked Task | Stub Strategy |
|---|---|---|
| YOLOv8n TFLite ready (DEV-02) blocks CV Pipeline integration (DEV-03) | Object Tracker, TTC Evaluator | Pre-recorded video file replays static bounding boxes at fixed coordinates |
| GraphHopper .zip on Cloudflare R2 (DEV-05) blocks offline navigation (DEV-01) | Nav screen turn-by-turn audio | Hardcoded instruction array: "Đi thẳng 20m, rẽ trái" repeated on tap |
| Supabase schema live (DEV-04) blocks SOS flow and Relap UI (DEV-01) | Relap screens, FCM push | Local SQLite simulates cloud tables; Relap shows data from same device |
| MiniLM TFLite ready (DEV-02) blocks NLP voice commands (DEV-03) | Navigation via voice | Intent map: 5 hardcoded Vietnamese phrases → 5 fixed GPS coordinates |
| Foreground Service stable (DEV-03) blocks Headless Mode + telemetry sync (DEV-04) | is_headless_active field in Relap | Boolean flag toggled manually in dev settings; telemetry row updated on button press |
