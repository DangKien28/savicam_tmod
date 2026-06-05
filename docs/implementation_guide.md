# SaViCam — 28-Day Survival Kit

---

## PART 1 — WEEK 1 DAY-BY-DAY CHECKLIST (Days 1–7)

**Week 1 goal:** A Flutter APK that installs, shows 3 colored screens, SOS button sends a fake alert visible in Relap, Supabase schema deployed with seed data.

---

**DAY 1 — All 5 devs together (Environment + Repo + Kickoff)**

- □ (DEV-01): Create private GitHub repo `savicam`; add all 5 members with Write access; push initial directory tree + `README.md`; commit `.gitignore` and verify `google-services.json`, `*.tflite` (v1.0), and `maps/raw_osm/` are excluded.
- □ (DEV-01): Run `./scripts/bootstrap.sh` on each machine; confirm `flutter pub get` succeeds and `flutter build apk --debug` produces an installable APK on the test device.
- □ (DEV-02): Create Google Colab notebook `ai/yolo_detector/training/train_yolov8n.ipynb`; mount Drive; verify YOLOv8n base weights load; launch first fine-tune run on the Da Nang dataset subset (even 50 images is enough to confirm the pipeline is not broken). **Training must start today.**
- □ (DEV-03): Open `MainActivity.kt`; register all four MethodChannels (`InferenceChannel`, `TrackingChannel`, `TtsSttChannel`, `ServiceChannel`) and confirm no crash on cold start.
- □ (DEV-04): Create Supabase project; download `google-services.json`; place in both `apps/tmod/android/app/` and `apps/relap/android/app/`; add all five GitHub Actions secrets (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `FCM_SERVER_KEY`, `R2_ACCESS_KEY`, `R2_SECRET_KEY`).
- □ (DEV-05): Download Da Nang OSM PBF file locally; run a minimal GraphHopper pre-build test on one small tile to verify the toolchain works.

**End of Day 1 checkpoint:** Every dev has cloned the repo, `flutter pub get` passes, the APK installs on at least one device, Colab training has submitted its first run, and Supabase project exists with credentials placed correctly.

---

**DAY 2**

- □ (DEV-01): Scaffold 3 T-Mod screens (`safety_page.dart`, `navigation_page.dart`, `daily_living_page.dart`) with distinct background colors and placeholder text; wire `BottomNavigationBar` between them.
- □ (DEV-01): Add stub `SOS` button on Safety screen — on long-press it writes a hardcoded `sos_event` row to the local SQLite `Offline_Queue` and shows a `SnackBar` confirmation.
- □ (DEV-03): Implement `SaViCamForegroundService.kt` skeleton — starts on `ServiceChannel` call, shows a persistent notification, does nothing else yet.
- □ (DEV-04): Write and run `cloud/supabase/migrations/001_initial_schema.sql`; confirm all 4 cloud tables (`profiles`, `device_telemetry`, `location_macros`, `sos_events`) are visible in the Supabase dashboard.
- □ (DEV-05): Script `maps/scripts/prebuild_danang.sh` to automate the GraphHopper pre-build; run it end-to-end and confirm a `.zip` output is produced in `maps/output/`.

**End of Day 2 checkpoint:** 3 screens visible in the APK; Supabase tables exist (even if empty); Foreground Service starts without crashing.

---

**DAY 3**

- □ (DEV-01): Wire Supabase Flutter client in `apps/tmod`; on SOS button press, attempt to `INSERT` into `sos_events` (online path) and fall back to `Offline_Queue` (offline path); log result to console.
- □ (DEV-01): Scaffold Relap APK with one screen showing a static "Waiting for SOS…" label.
- □ (DEV-03): Implement `TfliteInferenceEngine.kt` to load stub model from `res/raw/` and return a fixed list of `BoundingBox` objects via `InferenceChannel`; no real inference yet.
- □ (DEV-04): **Deploy seed data** — insert 2 fake `sos_events` rows and 1 `device_telemetry` row via the Supabase SQL editor; confirm they appear when queried. Schema is now LOCKED for Week 1.
- □ (DEV-05): Copy validated `.zip` to `maps/bundled/danang_pedestrian_stub.zip`; commit to repo (file must be under 50 MB).

**End of Day 3 checkpoint:** Supabase schema **deployed and seeded** (not just designed). SOS insert path exists in code even if the Relap UI does not yet react.

---

**DAY 4**

- □ (DEV-01): Wire Supabase Realtime on the Relap screen to listen for `INSERT` on `sos_events`; when a row arrives, change the label to "🚨 SOS Received" with the row's timestamp.
- □ (DEV-02): Export first Colab checkpoint as `yolov8n_stub.tflite` (even if mAP is <20 %); place in `models/yolo_detector/stub/`; push to repo.
- □ (DEV-03): Implement `IouTracker.kt` with frame-to-frame IoU matching; expose via `TrackingChannel`; unit-test with two hardcoded `BoundingBox` frames.
- □ (DEV-04): Configure FCM: add `google-services.json` plugin to both `build.gradle` files; write the Supabase Edge Function `cloud/supabase/functions/notify_sos.ts` that fires an FCM push on `sos_events` INSERT.
- □ (DEV-05): Load `danang_pedestrian_stub.zip` in `graphhopper_local_source.dart`; confirm a route query between two hardcoded Da Nang coordinates returns a non-null `RouteResult`.

**End of Day 4 checkpoint:** Relap screen updates in real time when a new `sos_events` row is inserted via the Supabase SQL editor. Stub `.tflite` is in the repo.

---

**DAY 5**

- □ (DEV-01): Wire SOS long-press (3–5 s gesture) to the full path: SQLite queue → Supabase insert → Relap Realtime update. Demo this flow on two physical devices.
- □ (DEV-03): Implement `TtsWrapper.kt`; call it from Flutter via `TtsSttChannel`; play "Cảnh báo nguy hiểm" on a button press to verify TTS works offline.
- □ (DEV-04): Test the FCM Edge Function end-to-end: insert a row manually in Supabase → confirm FCM notification appears on Relap device. Document any failures.
- □ (DEV-02): Confirm Colab training run has completed at least one epoch without OOM error; log mAP curve to Drive.
- □ (DEV-05): Create stub `danang_stub.dart` in `models/map_pipeline/stub/` returning the hardcoded 3-step `RouteResult` (see CONTRACT-05 / STUB-3).

**End of Day 5 checkpoint:** Full fake SOS flow works: long-press on T-Mod → Supabase insert → FCM push → Relap alert visible on second device.

---

**DAY 6**

- □ (DEV-01): Apply `accessibility_theme.dart` (high-contrast colors, WCAG-AA font sizes) across all three T-Mod screens; enable TalkBack and do a 5-minute smoke test.
- □ (DEV-01): Build a clean Relap Telemetry screen showing hardcoded battery % and network status pulled from the `device_telemetry` seed row.
- □ (DEV-03): Add `WakeLockTag` to `SaViCamForegroundService`; verify service survives 5 minutes of screen-off on the test device.
- □ (DEV-04): Write `README.md` for `cloud/supabase/` documenting every table, column type, and RLS rule; this is the canonical reference for CONTRACT-03.
- □ (DEV-05): Publish `danang_pedestrian_stub.zip` to Cloudflare R2 (test bucket); write the one-time download script for first-launch in `scripts/download_map.sh`.

**End of Day 6 checkpoint:** Accessibility theme applied; Foreground Service stays alive screen-off; R2 upload script works.

---

**DAY 7 — Week 1 Demo Prep**

- □ (DEV-01): Full rehearsal: install APK on clean device, walk through 3 screens, trigger SOS, confirm Relap alert — all in under 3 minutes.
- □ (ALL): Fix any blocker from Days 1–6; no new features today.
- □ (DEV-04): Create one additional seed `sos_events` row with GPS coordinates; confirm it displays correctly in Relap.
- □ (DEV-02): Note current mAP and ETA for INT8 export; share with team.

**END OF WEEK 1 DEMO-CHECK — Must be demonstrable to supervisor:**

1. Flutter APK installs on Android (minSdk 26+) and launches without crash.
2. Three distinct T-Mod screens are navigable (Safety / Navigation / Daily Living).
3. SOS long-press fires a real insert to Supabase `sos_events` and triggers a visible alert on the Relap APK (FCM or Realtime, either path is acceptable).
4. Supabase schema is fully deployed with seed data visible in the dashboard.
5. Relap Telemetry screen shows seed `device_telemetry` data.

**Recovery plan if any item is missing:**
- Missing Relap FCM alert → accept Realtime channel alert as equivalent; FCM is Week 2.
- Missing Supabase → demo SOS with local SQLite notification on the same device; flag as Day 8 priority.
- APK crashes on launch → revert to previous green commit; do not demo a broken build.

---

## PART 2 — 5 INTEGRATION CONTRACTS

---

**CONTRACT-01**
FROM: DEV-02 (AI/ML Engineer)
TO: DEV-03 (Android Native / Edge)
ARTIFACT: `models/yolo_detector/v1.0/yolov8n_int8.tflite` + `models/yolo_detector/v1.0/metadata.json`
FORMAT:

```json
{
  "model_version": "1.0.0",
  "input_shape": [1, 320, 320, 3],
  "input_dtype": "int8",
  "output_shape": [1, 25200, 9],
  "class_labels": ["motorcycle", "sidewalk_obstruction", "pedestrian", "vehicle", "pothole"],
  "quantization": "int8",
  "delegate": "NNAPI",
  "mAP50_target": 0.88,
  "fps_target": "15-22",
  "trained_on": "vietnamese_traffic_v1"
}
```

STUB AVAILABLE: YES — `models/yolo_detector/stub/yolov8n_stub.tflite`; returns 2 fixed `DetectionResult` objects with `class_label="motorcycle"`, `confidence=0.92`, `bbox={x:0.3,y:0.4,w:0.2,h:0.3}`, `estimated_distance_m=2.5`, `ttc_level=2`.
REAL VERSION DUE: End of Week 2
ACCEPTANCE TEST: `TfliteInferenceEngine.kt` loads the file, runs one inference on a test frame, and returns at least one `BoundingBox` with confidence > 0.5 without crashing the Foreground Service.

---

**CONTRACT-02**
FROM: DEV-02 (AI/ML Engineer)
TO: DEV-03 (Android Native / Edge)
ARTIFACT: `models/nlp_agent/v1.0/minilm_int8.tflite` + `models/nlp_agent/v1.0/metadata.json`
FORMAT:

```json
{
  "model_version": "1.0.0",
  "input_shape": [1, 128],
  "input_dtype": "int8",
  "intent_labels": ["navigate_home", "read_text", "identify_object", "call_guardian", "stop_navigation"],
  "entity_types": ["location_name", "contact_name", "none"],
  "quantization": "int8",
  "inference_target_ms": 100
}
```

STUB AVAILABLE: YES — `models/nlp_agent/stub/minilm_stub.tflite`; cycles through intents on each call: call 1 → `navigate_home`, call 2 → `read_text`, call 3 → `identify_object`, then repeats.
REAL VERSION DUE: End of Week 3
ACCEPTANCE TEST: `InferenceChannel` returns a valid `NLPResult` with a non-null `intent` field within 100 ms on a mid-range test device.

---

**CONTRACT-03**
FROM: DEV-04 (Backend / Cloud)
TO: DEV-01 (Flutter UI Lead)
ARTIFACT: `cloud/supabase/migrations/001_initial_schema.sql` + Supabase project URL/anon key in `.env`
FORMAT — exact tables:

| Table | Key columns |
|---|---|
| `profiles` | `id uuid PK`, `display_name text`, `fcm_token text`, `paired_device_id uuid` |
| `device_telemetry` | `id uuid PK`, `device_id uuid FK`, `battery_pct int`, `network_status text`, `is_headless_active bool`, `recorded_at timestamptz` |
| `location_macros` | `id uuid PK`, `owner_id uuid FK`, `keyword text`, `lat double`, `lng double`, `is_synced bool` |
| `sos_events` | `id uuid PK`, `device_id uuid FK`, `lat double`, `lng double`, `triggered_at timestamptz`, `resolved bool` |

RLS rules: each table has `ENABLE ROW LEVEL SECURITY`; users may only read/write rows where `device_id = auth.uid()` or `owner_id = auth.uid()`.
STUB AVAILABLE: YES — SQLite mirror tables in `apps/tmod/lib/shared/database/` allow offline development without a live Supabase connection.
REAL VERSION DUE: End of Week 1 (already deployed by Day 3)
ACCEPTANCE TEST: Flutter `supabase.from('sos_events').insert({...})` succeeds and the row appears in the Supabase dashboard within 2 seconds.

---

**CONTRACT-04**
FROM: DEV-04 (Backend / Cloud)
TO: DEV-01 (Flutter UI Lead — Relap)
ARTIFACT: Supabase Realtime channel on `device_telemetry` and `sos_events` tables
FORMAT — WebSocket event payloads:

```json
// Telemetry event
{
  "event": "INSERT",
  "table": "device_telemetry",
  "record": {
    "device_id": "uuid",
    "battery_pct": 72,
    "network_status": "4G",
    "is_headless_active": true,
    "recorded_at": "2025-01-01T10:00:00Z"
  }
}

// SOS event
{
  "event": "INSERT",
  "table": "sos_events",
  "record": {
    "id": "uuid",
    "device_id": "uuid",
    "lat": 16.0544,
    "lng": 108.2022,
    "triggered_at": "2025-01-01T10:05:00Z",
    "resolved": false
  }
}
```

STUB AVAILABLE: YES — `apps/relap/lib/shared/stubs/websocket_stub.dart` emits one fake telemetry event every 3 seconds and one fake SOS event on button press.
REAL VERSION DUE: End of Week 2
ACCEPTANCE TEST: Relap `SosAlertPage` renders the full-screen red overlay within 3 seconds of a real `sos_events` INSERT on Supabase.

---

**CONTRACT-05**
FROM: DEV-05 (Navigation / Build)
TO: DEV-01 (Flutter UI Lead — T-Mod)
ARTIFACT: `maps/bundled/danang_pedestrian.zip` (GraphHopper pre-built graph, ≤ 50 MB)
FORMAT: Standard GraphHopper graph directory zipped; loaded by `graphhopper_local_source.dart` via the `graphhopper_java` Flutter plugin; route query returns a `RouteResult`:

```json
{
  "total_distance_m": 350,
  "total_time_s": 280,
  "instructions": [
    { "text": "Đi thẳng 50 mét", "distance_m": 50, "heading_deg": 90 },
    { "text": "Rẽ trái", "distance_m": 0, "heading_deg": 0 },
    { "text": "Đến nơi trong 20 mét", "distance_m": 20, "heading_deg": 270 }
  ]
}
```

STUB AVAILABLE: YES — `models/map_pipeline/stub/danang_stub.dart` returns the hardcoded 3-instruction `RouteResult` above without loading any file.
REAL VERSION DUE: End of Week 2
ACCEPTANCE TEST: `graphhopper_local_source.dart` returns a `RouteResult` with at least 3 instructions for a query between Đà Nẵng train station and Cầu Rồng bridge in under 50 ms on the test device.

---

## PART 3 — 3 STUB SPECIFICATIONS

---

**STUB 1 — `yolov8n_stub.tflite`**
LOCATION: `models/yolo_detector/stub/`
CONTROLLED BY: `App_Settings.use_stub_models` (boolean; `true` in debug builds, `false` in release builds)
WHAT IT RETURNS: A fixed list of 2 `DetectionResult` objects:

```dart
DetectionResult(
  classId: 0,
  classLabel: "motorcycle",
  confidence: 0.92,
  bbox: BoundingBox(x: 0.3, y: 0.4, w: 0.2, h: 0.3), // normalized 0–1
  estimatedDistanceM: 2.5,
  ttcLevel: 2, // Nguy hiểm cao
)
```

HOW TO ACTIVATE:

```dart
final modelPath = AppSettings.useStubModels
    ? 'models/yolo_detector/stub/yolov8n_stub.tflite'
    : 'models/yolo_detector/v1.0/yolov8n_int8.tflite';
await InferenceChannel.loadModel(modelPath);
```

PURPOSE: Lets `TtcEvaluator` and audio warning (`TtsWrapper`) be tested before the real model is trained.

---

**STUB 2 — `minilm_stub.tflite`**
LOCATION: `models/nlp_agent/stub/`
CONTROLLED BY: `App_Settings.use_stub_models`
WHAT IT RETURNS: An `NLPResult` that cycles through 3 intents on successive calls:

```dart
// NLPResult schema
NLPResult(
  intent: String,           // e.g. "navigate_home"
  confidence: double,       // always 0.95
  entityType: String,       // always "location_name"
  entityValue: String?,     // "Nhà" for navigate_home, null otherwise
  inferenceMs: int,         // always 12
)

// Cycling behavior (call index stored in stub state)
// Call 1 → intent: "navigate_home",  entityValue: "Nhà"
// Call 2 → intent: "read_text",      entityValue: null
// Call 3 → intent: "identify_object",entityValue: null
// Call 4 → repeats from Call 1
```

HOW TO ACTIVATE:

```dart
final modelPath = AppSettings.useStubModels
    ? 'models/nlp_agent/stub/minilm_stub.tflite'
    : 'models/nlp_agent/v1.0/minilm_int8.tflite';
await InferenceChannel.loadNlpModel(modelPath);
```

PURPOSE: Lets `NlpAgentDispatcher` and `SQLite` macro lookup be tested with predictable intent cycling before the real model is fine-tuned.

---

**STUB 3 — `danang_stub.zip`**
LOCATION: `models/map_pipeline/stub/`
CONTROLLED BY: `App_Settings.use_stub_models`
WHAT IT RETURNS: A hardcoded `RouteResult`:

```dart
RouteResult(
  totalDistanceM: 350,
  totalTimeS: 280,
  instructions: [
    TurnInstruction(text: "Đi thẳng 50 mét",          distanceM: 50,  headingDeg: 90),
    TurnInstruction(text: "Rẽ trái",                   distanceM: 0,   headingDeg: 0),
    TurnInstruction(text: "Đến nơi trong 20 mét",      distanceM: 20,  headingDeg: 270),
  ],
)
```

HOW TO ACTIVATE:

```dart
final RouteResult result = AppSettings.useStubModels
    ? DanangStub.getRoute()  // returns hardcoded RouteResult instantly
    : await GraphhopperLocalSource.query(origin, destination);
```

PURPOSE: Lets `GraphHopper` integration, turn-by-turn TTS output (`flutter_tts`), and `NavigationBloc` state transitions be tested before the real pre-built graph is available.

---

## PART 4 — TOP 10 "DO NOT DO" RULES

---

**RULE-01: Native Before Kotlin**
❌ DO NOT: Begin any C++ JNI code (`app/src/main/cpp/`) during the 28-day sprint.
✅ DO THIS INSTEAD: Use the `IouTracker.kt` (IoU Kotlin tracker); the `cpp/` folder is a `SCAFFOLD` placeholder for v2.0 only.
WHY: A single C++ ABI mismatch can block the entire Kotlin/Flutter layer for 2–3 days, killing the Week 1 demo.

---

**RULE-02: No Large Files in Git**
❌ DO NOT: Commit `.tflite` v1.0 models, `.pbf` OSM files, `.zip` map outputs, `.pt`/`.onnx` weights, or raw datasets to the repository.
✅ DO THIS INSTEAD: Follow `.gitignore` patterns in `PART 3`; use stub models in `models/*/stub/` for development and Cloudflare R2 for production artifacts.
WHY: A single 200 MB file pushed to Git corrupts the repo history for all five developers and cannot be easily reversed.

---

**RULE-03: Don't Wait for Perfect AI**
❌ DO NOT: Delay Flutter integration until the YOLOv8n model exceeds the 0.88 mAP50 target.
✅ DO THIS INSTEAD: Integrate `yolov8n_stub.tflite` on Day 1 and swap in the real model by the end of Week 2 once NNAPI validation passes, regardless of accuracy.
WHY: Waiting for a perfect model means the TTC Evaluator, audio pipeline, and UI are untested for 2 weeks, compressing all integration risk into Week 3.

---

**RULE-04: No Clean Architecture for Tier-3 Features**
❌ DO NOT: Create BLoC events/states/repositories for `settings/` or `onboarding/` screens.
✅ DO THIS INSTEAD: Use plain `StatefulWidget` for Tier-3 features as specified in `ARCH-09`; save BLoC for `safety_assistant/`, `navigation/`, and `sos/` only.
WHY: Adding a full BLoC layer to a two-field settings screen wastes 4–6 hours and introduces cross-module state leak risk with no safety benefit.

---

**RULE-05: No Local AI Training**
❌ DO NOT: Run YOLOv8n or MiniLM training on a personal laptop or desktop GPU.
✅ DO THIS INSTEAD: All training runs happen in Google Colab (`ai/yolo_detector/training/train_yolov8n.ipynb`); mount Google Drive for dataset persistence.
WHY: A local training crash at 2 AM on Day 12 loses 8 hours of compute with no recovery path; Colab checkpoints survive browser reloads and network drops.

---

**RULE-06: No Merges Without a Green APK**
❌ DO NOT: Merge any branch to `main` if `flutter-test.yml` is red or if `flutter build apk --debug` fails locally.
✅ DO THIS INSTEAD: Enforce the branch protection rule set on Day 1: `flutter-test.yml` must pass and one reviewer must approve before merge.
WHY: A broken `main` blocks all five developers from pulling a working build and collapses the sprint to a single-threaded debug session.

---

**RULE-07: Freeze the Schema After Week 1**
❌ DO NOT: ALTER, DROP, or rename any column in `profiles`, `device_telemetry`, `location_macros`, or `sos_events` after Day 7 without writing a numbered migration SQL file.
✅ DO THIS INSTEAD: Add a `cloud/supabase/migrations/002_*.sql` file, test it against a dev Supabase project first, then apply to production.
WHY: An unchecked schema change silently breaks the Flutter Supabase client queries on every other developer's device with no obvious error message.

---

**RULE-08: Stubs Before Features**
❌ DO NOT: Build the `TtcEvaluator`, `NavigationBloc`, or `NlpAgentDispatcher` without the corresponding stub model returning deterministic data.
✅ DO THIS INSTEAD: Merge all three stub specs (STUB-1, STUB-2, STUB-3) into `main` on Day 1 before any feature branch is created.
WHY: A feature built against real (and unavailable) AI output cannot be unit-tested, and its first test run will be a live-device integration test in Week 3.

---

**RULE-09: Never Export a Model Without `metadata.json`**
❌ DO NOT: Copy a `.tflite` file to `models/*/v1.0/` without the accompanying `metadata.json` as specified in CONTRACT-01 and CONTRACT-02.
✅ DO THIS INSTEAD: Treat `metadata.json` as part of the model artifact; generate it in the same Colab cell that exports the `.tflite`, and push both files together.
WHY: Without `metadata.json`, `TfliteInferenceEngine.kt` has no `input_shape` or `class_labels`, making the model unloadable and CONTRACT acceptance tests impossible to run.

---

**RULE-10: Never Remove or Mute Safety Audio Without a User Confirmation Step**
❌ DO NOT: Add any setting, debug flag, or shortcut that disables the Level 1 Preemptive Interrupt audio permanently or silently.
✅ DO THIS INSTEAD: Any mute/disable path must require an explicit user gesture (minimum 2-step confirmation) and must log the suppression event to `App_Settings`; the Foreground Service must resume audio on the next app restart.
WHY: SaViCam's primary users are visually impaired people navigating real traffic — a silenced Level 1 alert (TTC < 1.5 s) during a field test is a direct physical safety risk, not a UX inconvenience.
