# SaViCam Agent Instructions

## Source of Truth — Read Order
1. `docs/architecture_lock.md` — highest authority, do not override
2. `docs/implementation_guide.md` — weekly execution plan
3. `docs/directory_tree.md` — reflects decisions, does not define new spec

## Hard Constraints
- Android only, minSdk 26+
- Offline-first for CV, TTC, and navigation
- No cloud inference for safety-critical AI
- No C++ JNI during MVP sprint
- No large model, map, or dataset binaries in Git
- Never remove or mute Level 1 safety audio without explicit confirmation

## Stub-First Mandate (ARCH-07)
- Stubs must be merged to `main` before any feature branch that depends on them
- Stub locations: `models/*/stub/`, Flutter `shared/stubs/`, Relap `shared/stubs/`
- Swap to real artifacts only when contract acceptance tests pass and Week >= 3
- Never call real model paths directly; route through `App_Settings.useStubModels`

## Schema Constraints
- Supabase schema is frozen after Day 7
- Any schema change after Day 7 must be a new numbered migration: `002_`, `003_`, ...
- Never alter, drop, or rename columns without a migration file

## Code Freeze
- Day 24 is CODE FREEZE
- No new features after Day 24
- After freeze, only critical bug fixes are allowed
- Do not introduce new dependencies, new architecture layers, or new feature folders after freeze

## Safety Audio Rule (RULE-10)
- Never remove, mute, or permanently disable Level 1 preemptive interrupt audio silently
- Any mute or disable path must require explicit 2-step user confirmation
- Any suppression event must be logged to `App_Settings`
- Foreground Service must restore safety audio on next app restart

## Architecture Rules
- T-Mod safety/navigation/sos: BLoC + Clean Architecture
- T-Mod daily_living/live_tracking/user_macros/telemetry: MVVM + Provider
- T-Mod settings/onboarding: StatefulWidget only
- Relap is display-heavy; prefer simple feature folders and widget tests

## Blocking Dependencies
- DEV-02 YOLOv8n TFLite -> blocks DEV-03 CV Pipeline; stub: static bbox feed
- DEV-05 GraphHopper zip -> blocks DEV-01 Navigation screen; stub: 3-instruction array
- DEV-04 Supabase schema -> blocks DEV-01 SOS + Relap UI; stub: local SQLite mirror
- DEV-02 MiniLM TFLite -> blocks DEV-03 NLP commands; stub: 5-phrase intent map
- DEV-03 Foreground Service -> blocks DEV-04 Headless telemetry; stub: manual toggle

## Ownership Boundaries
- Kotlin `channels/`: DEV-03
- Dart `channel_wrappers/`: DEV-01
- Supabase schema, RLS, FCM: DEV-04
- AI training/export: DEV-02
- GraphHopper, maps, scripts: DEV-05
