# SaViCam — Complete Monorepo Directory Tree

> Principal Software Architect Document | 28-Day MVP | 5-Student Team | Android Only
> All 4 architecture downgrades applied: (1) IoU Kotlin tracker replaces ByteTrack C++; (2) MiniLM-only NLP, FastText+Levenshtein deferred; (3) Only flutter-test.yml + apk-build.yml CI active; (4) Tiered BLoC/MVVM/StatefulWidget per ARCH-09

---

## PART 1 — COMPLETE ANNOTATED DIRECTORY TREE

```
savicam/
│
├── apps/                                          [OWNER: DEV-01] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │                                              # All Flutter application source — both T-Mod and Relap APKs
│   │
│   ├── tmod/                                      [OWNER: DEV-01 + DEV-03] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │   │                                          # SaViCam T-Mod: primary app for the visually impaired user
│   │   │
│   │   ├── android/                               [OWNER: DEV-03] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │   │   │                                      # Native Android layer — Foreground Service, NNAPI, Camera2
│   │   │   │
│   │   │   ├── app/src/main/kotlin/com/savicam/tmod/
│   │   │   │   ├── MainActivity.kt                # Entry point; requests permissions, binds Foreground Service
│   │   │   │   │
│   │   │   │   ├── services/                      [OWNER: DEV-03] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │   │   │   │   ├── SaViCamForegroundService.kt  # Keeps CV + NLP alive with screen off; manages wake lock
│   │   │   │   │   └── HeadlessModeManager.kt       # Toggles headless state; updates is_headless_active telemetry
│   │   │   │   │
│   │   │   │   ├── inference/                     [OWNER: DEV-03] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │   │   │   │   ├── TfliteInferenceEngine.kt   # Loads .tflite model; configures NNAPI delegate (INT8)
│   │   │   │   │   ├── NnapiDelegateConfig.kt     # NNAPI fallback to CPU when NPU unavailable
│   │   │   │   │   └── BoundingBoxParser.kt       # Converts raw tensor output to BoundingBox data class
│   │   │   │   │
│   │   │   │   ├── tracking/                      [OWNER: DEV-03] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │   │   │   │   │                              # Downgrade 1: IoU Kotlin tracker (replaces ByteTrack C++)
│   │   │   │   │   ├── IouTracker.kt              # Frame-to-frame IoU matching; interpolates 10→30 FPS
│   │   │   │   │   └── TrackedObject.kt           # Data class: id, bbox, velocity, lastSeen
│   │   │   │   │
│   │   │   │   ├── camera/                        [OWNER: DEV-03] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │   │   │   │   ├── Camera2Controller.kt       # Camera2 API; targets 30 FPS YUV_420_888 stream
│   │   │   │   │   └── FramePreprocessor.kt       # Resize + normalize frames for TFLite input tensor
│   │   │   │   │
│   │   │   │   ├── tts_stt/                       [OWNER: DEV-03] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │   │   │   │   ├── TtsWrapper.kt              # Android TextToSpeech; AudioFocus GAIN_TRANSIENT_MAY_DUCK
│   │   │   │   │   └── SttWrapper.kt              # SpeechRecognizer offline mode; Vietnamese locale
│   │   │   │   │
│   │   │   │   └── channels/                      [OWNER: DEV-03] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│   │   │   │       ├── InferenceChannel.kt        # MethodChannel: Flutter ↔ TFLite bridge
│   │   │   │       ├── TrackingChannel.kt         # MethodChannel: Flutter ↔ IoU tracker
│   │   │   │       ├── TtsSttChannel.kt           # MethodChannel: Flutter ↔ TTS/STT
│   │   │   │       └── ServiceChannel.kt          # MethodChannel: start/stop Foreground Service
│   │   │   │
│   │   │   ├── app/src/main/cpp/                  [OWNER: DEV-03] [STATUS: SCAFFOLD] [SAFETY: NO] [TIER: N/A]
│   │   │   │   └── README.md                      # ByteTrack/SORT C++ — Planned v2.0
│   │   │   │
│   │   │   └── app/src/main/res/
│   │   │       ├── raw/                           # Bundled TFLite stub models (Week 1–2)
│   │   │       └── values/                        # strings.xml, colors.xml
│   │   │
│   │   └── lib/                                   [OWNER: DEV-01] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │       │                                      # Flutter Dart source for T-Mod UI + business logic
│   │       │
│   │       ├── main.dart                          # App entry; registers BLoC providers, initialises SQLite
│   │       ├── app.dart                           # MaterialApp config; accessibility theme; TTS locale
│   │       ├── core/                              [OWNER: DEV-01] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│   │       │   ├── constants/
│   │       │   │   ├── ttc_thresholds.dart        # Level 1–4 TTC constants (1.5 s, 3 s, 5 s)
│   │       │   │   └── channel_names.dart         # MethodChannel string constants
│   │       │   ├── di/
│   │       │   │   └── injector.dart              # get_it service locator wiring
│   │       │   └── theme/
│   │       │       └── accessibility_theme.dart   # High-contrast colours; WCAG-AA font sizes
│   │       │
│   │       ├── features/                          [OWNER: DEV-01] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │       │   │
│   │       │   ├── safety_assistant/              # TIER 1 — Full Clean Architecture + BLoC
│   │       │   │   [OWNER: DEV-01] [STATUS: FULL] [SAFETY: YES] [TIER: 1]
│   │       │   │   ├── data/
│   │       │   │   │   ├── datasources/
│   │       │   │   │   │   ├── inference_channel_source.dart   # Calls InferenceChannel MethodChannel
│   │       │   │   │   │   └── tracking_channel_source.dart    # Calls TrackingChannel MethodChannel
│   │       │   │   │   ├── models/
│   │       │   │   │   │   ├── bounding_box_model.dart
│   │       │   │   │   │   └── ttc_result_model.dart
│   │       │   │   │   └── repositories/
│   │       │   │   │       └── safety_repository_impl.dart
│   │       │   │   ├── domain/
│   │       │   │   │   ├── entities/
│   │       │   │   │   │   ├── obstacle.dart
│   │       │   │   │   │   └── risk_level.dart              # Enum: SAFE, WATCH, WARN, CRITICAL
│   │       │   │   │   ├── repositories/
│   │       │   │   │   │   └── safety_repository.dart
│   │       │   │   │   └── usecases/
│   │       │   │   │       ├── evaluate_ttc.dart
│   │       │   │   │       └── trigger_preemptive_interrupt.dart
│   │       │   │   └── presentation/
│   │       │   │       ├── bloc/
│   │       │   │       │   ├── safety_bloc.dart
│   │       │   │       │   ├── safety_event.dart
│   │       │   │       │   └── safety_state.dart
│   │       │   │       ├── pages/
│   │       │   │       │   └── safety_page.dart
│   │       │   │       └── widgets/
│   │       │   │           ├── obstacle_overlay.dart
│   │       │   │           └── risk_indicator.dart
│   │       │   │
│   │       │   ├── navigation/                    # TIER 1 — Full Clean Architecture + BLoC
│   │       │   │   [OWNER: DEV-01 + DEV-05] [STATUS: FULL] [SAFETY: YES] [TIER: 1]
│   │       │   │   ├── data/
│   │       │   │   │   ├── datasources/
│   │       │   │   │   │   ├── graphhopper_local_source.dart  # Queries pre-built .zip graph on device
│   │       │   │   │   │   └── sqlite_macro_source.dart       # Resolves voice→GPS via Local_Macros
│   │       │   │   │   ├── models/
│   │       │   │   │   │   ├── route_model.dart
│   │       │   │   │   │   └── waypoint_model.dart
│   │       │   │   │   └── repositories/
│   │       │   │   │       └── navigation_repository_impl.dart
│   │       │   │   ├── domain/
│   │       │   │   │   ├── entities/
│   │       │   │   │   │   ├── route.dart
│   │       │   │   │   │   └── turn_instruction.dart
│   │       │   │   │   ├── repositories/
│   │       │   │   │   │   └── navigation_repository.dart
│   │       │   │   │   └── usecases/
│   │       │   │   │       ├── compute_route.dart
│   │       │   │   │       └── resolve_voice_destination.dart
│   │       │   │   └── presentation/
│   │       │   │       ├── bloc/
│   │       │   │       │   ├── navigation_bloc.dart
│   │       │   │       │   ├── navigation_event.dart
│   │       │   │       │   └── navigation_state.dart
│   │       │   │       ├── pages/
│   │       │   │       │   └── navigation_page.dart
│   │       │   │       └── widgets/
│   │       │   │           ├── turn_instruction_banner.dart
│   │       │   │           └── destination_input.dart
│   │       │   │
│   │       │   ├── sos/                           # TIER 1 — Full Clean Architecture + BLoC
│   │       │   │   [OWNER: DEV-01 + DEV-04] [STATUS: FULL] [SAFETY: YES] [TIER: 1]
│   │       │   │   ├── data/
│   │       │   │   │   ├── datasources/
│   │       │   │   │   │   ├── supabase_sos_source.dart      # Writes to sos_events; falls back to queue
│   │       │   │   │   │   └── sqlite_queue_source.dart      # Offline_Queue write + flush logic
│   │       │   │   │   ├── models/
│   │       │   │   │   │   └── sos_event_model.dart
│   │       │   │   │   └── repositories/
│   │       │   │   │       └── sos_repository_impl.dart
│   │       │   │   ├── domain/
│   │       │   │   │   ├── entities/
│   │       │   │   │   │   └── sos_event.dart
│   │       │   │   │   ├── repositories/
│   │       │   │   │   │   └── sos_repository.dart
│   │       │   │   │   └── usecases/
│   │       │   │   │       ├── trigger_sos.dart
│   │       │   │   │       └── flush_offline_queue.dart
│   │       │   │   └── presentation/
│   │       │   │       ├── bloc/
│   │       │   │       │   ├── sos_bloc.dart
│   │       │   │       │   ├── sos_event.dart
│   │       │   │       │   └── sos_state.dart
│   │       │   │       ├── pages/
│   │       │   │       │   └── sos_page.dart
│   │       │   │       └── widgets/
│   │       │   │           └── long_press_sos_button.dart
│   │       │   │
│   │       │   ├── daily_living/                  # TIER 2 — MVVM + Provider
│   │       │   │   [OWNER: DEV-01] [STATUS: FULL] [SAFETY: NO] [TIER: 2]
│   │       │   │   ├── viewmodels/
│   │       │   │   │   └── daily_living_viewmodel.dart
│   │       │   │   ├── pages/
│   │       │   │   │   └── daily_living_page.dart
│   │       │   │   └── widgets/
│   │       │   │       └── nlp_command_display.dart
│   │       │   │
│   │       │   ├── live_tracking/                 # TIER 2 — MVVM + Provider (T-Mod side: GPS emit)
│   │       │   │   [OWNER: DEV-01 + DEV-04] [STATUS: FULL] [SAFETY: NO] [TIER: 2]
│   │       │   │   ├── viewmodels/
│   │       │   │   ├── pages/
│   │       │   │   └── widgets/
│   │       │   │
│   │       │   ├── user_macros/                   # TIER 2 — MVVM + Provider
│   │       │   │   [OWNER: DEV-01] [STATUS: FULL] [SAFETY: NO] [TIER: 2]
│   │       │   │   ├── viewmodels/
│   │       │   │   ├── pages/
│   │       │   │   └── widgets/
│   │       │   │
│   │       │   ├── telemetry/                     # TIER 2 — MVVM + Provider
│   │       │   │   [OWNER: DEV-03 + DEV-04] [STATUS: FULL] [SAFETY: NO] [TIER: 2]
│   │       │   │   ├── viewmodels/
│   │       │   │   ├── pages/
│   │       │   │   └── widgets/
│   │       │   │
│   │       │   ├── settings/                      # TIER 3 — StatefulWidget only
│   │       │   │   [OWNER: DEV-01] [STATUS: FULL] [SAFETY: NO] [TIER: 3]
│   │       │   │   ├── pages/
│   │       │   │   └── widgets/
│   │       │   │
│   │       │   └── onboarding/                    # TIER 3 — StatefulWidget only
│   │       │       [OWNER: DEV-01] [STATUS: FULL] [SAFETY: NO] [TIER: 3]
│   │       │       ├── pages/
│   │       │       └── widgets/
│   │       │
│   │       └── shared/                            [OWNER: DEV-01] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│   │           ├── database/
│   │           │   └── sqlite_helper.dart         # sqflite schema init; migrations for Local_Macros, App_Settings, Offline_Queue
│   │           └── services/
│   │               └── location_service.dart      # GPS wrapper; streams coordinates for SOS + telemetry
│   │
│   └── relap/                                     [OWNER: DEV-01 + DEV-04] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│       │                                          # SaViCam Relap: guardian companion app
│       │
│       ├── android/                               [OWNER: DEV-04] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│       │   └── app/src/main/kotlin/com/savicam/relap/
│       │       ├── MainActivity.kt
│       │       └── fcm/
│       │           └── RelapFcmService.kt         # Handles FCM push; triggers full-screen SOS overlay
│       │
│       └── lib/                                   [OWNER: DEV-01 + DEV-04] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│           ├── main.dart
│           └── features/
│               ├── live_tracking/                 # TIER 2 — MVVM + Provider
│               │   [OWNER: DEV-01] [STATUS: FULL] [SAFETY: YES] [TIER: 2]
│               │   ├── viewmodels/
│               │   │   └── tracking_viewmodel.dart    # Subscribes WebSocket; emits GPS to map widget
│               │   ├── pages/
│               │   │   └── tracking_page.dart
│               │   └── widgets/
│               │       └── live_map_pin.dart
│               ├── sos_alert/                     # TIER 2 — MVVM + Provider
│               │   [OWNER: DEV-01 + DEV-04] [STATUS: FULL] [SAFETY: YES] [TIER: 2]
│               │   ├── viewmodels/
│               │   ├── pages/
│               │   │   └── sos_alert_page.dart    # Full-screen red overlay; one-tap priority call
│               │   └── widgets/
│               ├── telemetry_dashboard/           # TIER 2 — MVVM + Provider
│               │   [OWNER: DEV-01] [STATUS: FULL] [SAFETY: NO] [TIER: 2]
│               │   ├── viewmodels/
│               │   ├── pages/
│               │   └── widgets/
│               └── user_macros_manager/           # TIER 2 — MVVM + Provider
│                   [OWNER: DEV-01] [STATUS: FULL] [SAFETY: NO] [TIER: 2]
│                   ├── viewmodels/
│                   ├── pages/
│                   └── widgets/
│
├── ai/                                            [OWNER: DEV-02] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│   │                                              # All AI/ML training, evaluation, and export pipelines
│   │
│   ├── yolo_detector/                             [OWNER: DEV-02] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │   ├── data/
│   │   │   ├── raw/                               # Raw Da Nang traffic images (git-ignored — large binary)
│   │   │   └── annotations/                       # YOLO-format .txt label files
│   │   ├── preprocessing/
│   │   │   ├── augment.py                         # Mosaic, flip, HSV jitter for Vietnamese traffic
│   │   │   └── validate_labels.py
│   │   ├── training/
│   │   │   ├── train_yolov8n.py                   # Ultralytics YOLOv8n fine-tune; QAT Float32→INT8
│   │   │   └── colab_train.ipynb                  # Google Colab entry point (Week 1–2)
│   │   ├── evaluation/
│   │   │   ├── eval_map.py                        # mAP@0.5 on Vietnamese test split
│   │   │   └── benchmark_fps.py                   # FPS benchmark on mid-range Android via ADB
│   │   └── export/
│   │       ├── export_tflite.py                   # Exports INT8 TFLite; validates delegate compatibility
│   │       └── export_metadata.py                 # Writes metadata.json (labels, input shape)
│   │
│   └── nlp_agent/                                 [OWNER: DEV-02] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│       │                                          # Downgrade 2: MiniLM-only; FastText+Levenshtein deferred to v2.0
│       ├── data/
│       │   ├── raw_commands/                      # Vietnamese voice command corpus (git-ignored)
│       │   └── stt_error_samples/                 # STT mis-transcriptions collected from field test
│       ├── preprocessing/
│       │   ├── stt_error_augmentation/            [OWNER: DEV-02] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│       │   │   ├── augment_stt_errors.py          # Injects common STT substitutions (e.g. "nhà"→"nha")
│       │   │   └── generate_variants.py           # Produces STT-error training set at 5× expansion
│       │   ├── fasttext/                          [OWNER: DEV-02] [STATUS: SCAFFOLD] [SAFETY: NO] [TIER: N/A]
│       │   │   └── README.md                      # FastText Pre-filter — v2.0 Planned
│       │   └── levenshtein/                       [OWNER: DEV-02] [STATUS: SCAFFOLD] [SAFETY: NO] [TIER: N/A]
│       │       └── README.md                      # Levenshtein Corrector — v2.0 Planned
│       ├── training/
│       │   ├── finetune_minilm.py                 # Fine-tunes MiniLM-L6-v2 on STT-error variants
│       │   └── colab_nlp.ipynb                    # Colab training notebook (target: Day 14 ready)
│       ├── evaluation/
│       │   ├── eval_intent.py                     # Accuracy on 5-class Vietnamese intent test set
│       │   └── eval_ner.py                        # Named entity (destination) extraction precision
│       └── export/
│           ├── export_tflite_nlp.py               # INT8 TFLite export; ~20–30 MB output
│           └── export_metadata.py
│
├── maps/                                          [OWNER: DEV-05] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │                                              # GraphHopper offline map pipeline for Da Nang
│   ├── raw_osm/                                   # Da Nang .osm.pbf source (git-ignored — large binary)
│   ├── scripts/
│   │   ├── filter_pedestrian.py                   # Strips vehicle ways; retains footpaths, crossings, lanes
│   │   ├── prebuild_graph.sh                      # Runs GraphHopper JAR to build route graph from filtered PBF
│   │   └── upload_r2.sh                           # Pushes validated .zip to Cloudflare R2 bucket
│   ├── output/                                    # Compiled .zip graph (git-ignored — large binary)
│   └── bundled/
│       └── danang_pedestrian_stub.zip             # Validated 50 MB fallback tile bundled in APK assets
│
├── cloud/                                         [OWNER: DEV-04] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │                                              # Supabase schema, migrations, FCM config, RLS policies
│   ├── supabase/
│   │   ├── migrations/
│   │   │   ├── 001_initial_schema.sql             # Creates profiles, device_telemetry, location_macros, sos_events
│   │   │   └── 002_offline_queue_index.sql        # Index on synced flag for queue flush performance
│   │   ├── functions/
│   │   │   └── sos_fcm_trigger.sql                # DB trigger on sos_events INSERT → fires FCM via Edge Function
│   │   └── rls/
│   │       └── row_level_security.sql             # Per-user RLS policies for all 4 cloud tables
│   └── fcm/
│       └── fcm_edge_function.ts                   # Supabase Edge Function: receives trigger, calls FCM API
│
├── packages/                                      [OWNER: DEV-01] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│   │                                              # Shared Dart packages imported by both tmod and relap
│   ├── savicam_core/
│   │   ├── lib/
│   │   │   ├── models/                            # Shared data models (SosEvent, Telemetry, LocationMacro)
│   │   │   └── utils/                             # Date formatters, coordinate helpers
│   │   └── pubspec.yaml
│   └── savicam_ui/
│       ├── lib/
│       │   └── widgets/                           # Shared accessible widgets (SaViButton, SaViCard)
│       └── pubspec.yaml
│
├── datasets/                                      [OWNER: DEV-02] [STATUS: SCAFFOLD] [SAFETY: NO] [TIER: N/A]
│   └── README.md                                  # Dataset Registry — v2.0 Planned (public release)
│
├── models/                                        [OWNER: DEV-02] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │                                              # Versioned model artifacts; stubs available Day 1
│   ├── yolo_detector/
│   │   ├── stub/                                  [OWNER: DEV-02] [STATUS: STUB] [SAFETY: YES] [TIER: N/A]
│   │   │   ├── yolov8n_stub.tflite                # Replays static bounding boxes; deterministic output
│   │   │   └── metadata.json                      # Labels, input_shape, stub=true flag
│   │   └── v1.0/                                  [OWNER: DEV-02] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │       # Populated Week 3 — yolov8n_int8.tflite + metadata.json
│   │
│   └── nlp_agent/
│       ├── stub/                                  [OWNER: DEV-02] [STATUS: STUB] [SAFETY: NO] [TIER: N/A]
│       │   ├── minilm_stub.tflite                 # Hardcoded 5-intent map: nhà/trường/chợ/bệnh viện/dừng lại
│       │   └── metadata.json
│       └── v1.0/                                  [OWNER: DEV-02] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│           # Populated Week 3 — minilm_int8.tflite + metadata.json
│
├── docs/                                          [OWNER: ALL] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│   │                                              # Architecture decisions, API contracts, research references
│   ├── architecture_lock.md                       # This document — source of truth for all decisions
│   ├── api_contracts/
│   │   ├── method_channels.md                     # All MethodChannel names, argument types, return types
│   │   └── supabase_schema.md                     # All 7 table schemas (4 cloud + 3 edge)
│   ├── adr/                                       # Architecture Decision Records
│   │   ├── adr-001-iou-over-bytetrack.md
│   │   ├── adr-002-minilm-only-nlp.md
│   │   └── adr-003-tiered-architecture.md
│   └── research/
│       └── references.bib                         # Academic citations from NCKH report
│
├── tests/                                         [OWNER: ALL] [STATUS: FULL] [SAFETY: YES] [TIER: N/A]
│   │                                              # All test suites — unit, integration, widget
│   ├── tmod/
│   │   ├── unit/
│   │   │   ├── iou_tracker_test.dart              # Unit: IoU matching correctness
│   │   │   ├── ttc_evaluator_test.dart            # Unit: all 4 TTC level thresholds
│   │   │   └── sqlite_helper_test.dart
│   │   └── widget/
│   │       ├── safety_page_test.dart
│   │       └── sos_button_test.dart
│   ├── relap/
│   │   └── widget/
│   │       └── sos_alert_page_test.dart
│   └── ai/
│       ├── eval_yolo_test.py
│       └── eval_nlp_intent_test.py
│
├── scripts/                                       [OWNER: DEV-05] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│   │                                              # Developer utility scripts — setup, lint, release
│   ├── bootstrap.sh                               # Day 1: clones, installs deps, copies stub models to assets
│   ├── lint.sh                                    # Runs dart analyze + ktlint + pylint
│   └── release_apk.sh                             # Tags version, triggers apk-build.yml manually
│
├── .github/                                       [OWNER: DEV-05] [STATUS: FULL] [SAFETY: NO] [TIER: N/A]
│   └── workflows/
│       ├── flutter-test.yml                       [STATUS: FULL]  # Runs on every PR — dart test + analyze
│       ├── apk-build.yml                          [STATUS: FULL]  # Runs on merge to main — builds release APK
│       ├── map-prebuild.yml                       [STATUS: SCAFFOLD] # Downgrade 3: v2.0 — OSM → GH → R2 pipeline
│       │   └── # README inline: "Map pre-build CI — v2.0 Planned (see maps/scripts/)"
│       └── ai-eval.yml                            [STATUS: SCAFFOLD] # Downgrade 3: v2.0 — automated mAP regression
│
└── README.md                                      # Project overview, quickstart, team contacts
```

---

## PART 2 — ANNOTATION SUMMARY TABLE

| Folder Path | Owner | Status | Safety | Tier | Week Needed |
|---|---|---|---|---|---|
| models/yolo_detector/stub | DEV-02 | STUB | YES | N/A | W1 |
| models/nlp_agent/stub | DEV-02 | STUB | NO | N/A | W1 |
| apps/tmod/android/services | DEV-03 | FULL | YES | N/A | W1 |
| apps/tmod/android/channels | DEV-03 | FULL | NO | N/A | W1 |
| cloud/supabase/migrations | DEV-04 | FULL | YES | N/A | W1 |
| cloud/supabase/rls | DEV-04 | FULL | YES | N/A | W1 |
| apps/tmod/lib/features/safety_assistant | DEV-01 | FULL | YES | 1 | W1 |
| apps/tmod/lib/features/sos | DEV-01+DEV-04 | FULL | YES | 1 | W1 |
| apps/tmod/lib/features/onboarding | DEV-01 | FULL | NO | 3 | W1 |
| apps/tmod/lib/features/settings | DEV-01 | FULL | NO | 3 | W1 |
| apps/tmod/lib/shared/database | DEV-01 | FULL | YES | N/A | W1 |
| apps/relap/lib/features/sos_alert | DEV-01+DEV-04 | FULL | YES | 2 | W1 |
| scripts | DEV-05 | FULL | NO | N/A | W1 |
| .github/workflows | DEV-05 | FULL | NO | N/A | W1 |
| apps/tmod/android/inference | DEV-03 | FULL | YES | N/A | W2 |
| apps/tmod/android/tracking | DEV-03 | FULL | YES | N/A | W2 |
| apps/tmod/android/camera | DEV-03 | FULL | YES | N/A | W2 |
| apps/tmod/android/tts_stt | DEV-03 | FULL | YES | N/A | W2 |
| apps/tmod/lib/features/navigation | DEV-01+DEV-05 | FULL | YES | 1 | W2 |
| apps/tmod/lib/features/daily_living | DEV-01 | FULL | NO | 2 | W2 |
| apps/tmod/lib/features/telemetry | DEV-03+DEV-04 | FULL | NO | 2 | W2 |
| apps/relap/lib/features/live_tracking | DEV-01 | FULL | YES | 2 | W2 |
| apps/relap/lib/features/telemetry_dashboard | DEV-01 | FULL | NO | 2 | W2 |
| maps/scripts | DEV-05 | FULL | YES | N/A | W2 |
| maps/bundled | DEV-05 | FULL | YES | N/A | W2 |
| ai/yolo_detector/training | DEV-02 | FULL | YES | N/A | W2 |
| ai/yolo_detector/export | DEV-02 | FULL | YES | N/A | W2 |
| ai/nlp_agent/preprocessing/stt_error_augmentation | DEV-02 | FULL | NO | N/A | W2 |
| cloud/supabase/functions | DEV-04 | FULL | YES | N/A | W2 |
| cloud/fcm | DEV-04 | FULL | YES | N/A | W3 |
| apps/tmod/lib/features/live_tracking | DEV-01+DEV-04 | FULL | NO | 2 | W3 |
| apps/tmod/lib/features/user_macros | DEV-01 | FULL | NO | 2 | W3 |
| apps/relap/lib/features/user_macros_manager | DEV-01 | FULL | NO | 2 | W3 |
| ai/nlp_agent/training | DEV-02 | FULL | NO | N/A | W3 |
| ai/nlp_agent/export | DEV-02 | FULL | NO | N/A | W3 |
| models/yolo_detector/v1.0 | DEV-02 | FULL | YES | N/A | W3 |
| models/nlp_agent/v1.0 | DEV-02 | FULL | NO | N/A | W3 |
| tests/tmod/unit | DEV-01+DEV-03 | FULL | YES | N/A | W3 |
| tests/tmod/widget | DEV-01 | FULL | YES | N/A | W3 |
| apps/tmod/android/cpp | DEV-03 | SCAFFOLD | NO | N/A | v2.0 |
| ai/nlp_agent/preprocessing/fasttext | DEV-02 | SCAFFOLD | NO | N/A | v2.0 |
| ai/nlp_agent/preprocessing/levenshtein | DEV-02 | SCAFFOLD | NO | N/A | v2.0 |
| datasets | DEV-02 | SCAFFOLD | NO | N/A | v2.0 |

---

## PART 3 — .gitignore PATTERNS

### [Large Binary]
```
# Model artifacts — use models/*/stub/ for development
models/yolo_detector/v1.0/*.tflite
models/nlp_agent/v1.0/*.tflite
ai/yolo_detector/data/raw/
ai/nlp_agent/data/raw_commands/
ai/nlp_agent/data/stt_error_samples/
maps/raw_osm/*.pbf
maps/output/*.zip
```

### [Generated]
```
# Flutter / Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
build/
*.g.dart
*.freezed.dart
pubspec.lock          # Commit this for apps; ignore for packages

# Android
*.apk
*.aab
*.keystore
*.jks
local.properties
.gradle/
app/build/

# Python
__pycache__/
*.pyc
*.pyo
.venv/
dist/
*.egg-info/
ai/**/*.pt
ai/**/*.onnx

# Jupyter
.ipynb_checkpoints/
```

### [Secrets]
```
# Environment & credentials — NEVER commit
.env
.env.local
*.env.*
supabase/.env
google-services.json        # Regenerate from Firebase Console
GoogleService-Info.plist
serviceAccountKey.json
r2_credentials.sh
fcm_server_key.txt
**/secrets/
**/*.p12
**/*.pem
```

### [Personal / Colab]
```
# Personal developer configs
.vscode/settings.json
.idea/
*.iml
*.iws
.DS_Store
Thumbs.db
colab_cache/
ai/**/*_personal.ipynb
```

---

## PART 4 — DAY 1 BOOTSTRAP CHECKLIST

1. **Create GitHub repository** — name `savicam`; visibility Private; add all 5 team members with Write access.

2. **Push initial commit** — copy this directory tree structure, add `README.md`, run `git push origin main`.

3. **Run bootstrap script** — execute `./scripts/bootstrap.sh`; this installs Flutter, Dart, Node, Python deps, and copies stub model files into `apps/tmod/android/app/src/main/res/raw/`.

4. **Commit `.gitignore`** — verify `google-services.json`, `*.tflite` (v1.0 only), and `maps/raw_osm/` are all excluded before first `git push`.

5. **DEV-04: Deploy Supabase schema** — run `cloud/supabase/migrations/001_initial_schema.sql` against new Supabase project; confirm all 4 cloud tables visible in dashboard.

6. **DEV-04: Add `google-services.json`** — download from Firebase Console; place in `apps/tmod/android/app/` and `apps/relap/android/app/`; verify FCM project ID matches Supabase Edge Function config.

7. **DEV-04: Set GitHub Actions secrets** — add `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `FCM_SERVER_KEY`, `R2_ACCESS_KEY`, `R2_SECRET_KEY` to repository Secrets.

8. **DEV-01: Verify stub APK builds** — run `flutter build apk --debug` from `apps/tmod/`; APK must install on test device with 3 screens visible and SOS button firing local notification.

9. **DEV-02: Verify stub models load** — confirm `models/yolo_detector/stub/yolov8n_stub.tflite` is loaded by `TfliteInferenceEngine.kt` and returns deterministic bounding boxes on first cold start.

10. **DEV-03: Wire MethodChannels** — confirm `InferenceChannel`, `TrackingChannel`, `TtsSttChannel`, and `ServiceChannel` all register without crash on `MainActivity.kt` start.

11. **DEV-05: Validate bundled map tile** — load `maps/bundled/danang_pedestrian_stub.zip` in GraphHopper; confirm a route query between two Da Nang coordinates returns a valid `TurnInstruction` list.

12. **Run CI check** — open a test PR; confirm `flutter-test.yml` passes (dart analyze + unit tests green).

13. **Create branch protection rule** — require `flutter-test.yml` to pass before merge to `main`; require 1 reviewer approval.

14. **Assign JIRA/Linear tickets** — create one ticket per folder group in the Week Needed = W1 rows of the summary table; assign to respective owners.

15. **Declare Day 1 DONE** — all 5 devs `git clone`, run `flutter pub get`, build debug APK locally; confirm identical output. Unblock parallel Week 1 tracks.
```

---

> **Architecture Downgrades Applied**
> - **Downgrade 1**: `apps/tmod/android/tracking/` — IoU Kotlin tracker; `cpp/` folder is SCAFFOLD only
> - **Downgrade 2**: `ai/nlp_agent/preprocessing/fasttext/` and `levenshtein/` are SCAFFOLD; STT-error augmentation is the active MVP path
> - **Downgrade 3**: `.github/workflows/map-prebuild.yml` and `ai-eval.yml` are SCAFFOLD; only `flutter-test.yml` and `apk-build.yml` run in MVP CI
> - **Downgrade 4**: `apps/tmod/lib/features/` — Tier 1 BLoC for safety/nav/sos; Tier 2 MVVM for daily_living/tracking/macros/telemetry; Tier 3 StatefulWidget for settings/onboarding
