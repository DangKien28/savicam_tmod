# SaViCam - Supabase Schema Contract (CONTRACT-03 + CONTRACT-04)

> ⚠️ SCHEMA FROZEN — Day 3, Week 1
> Bất kỳ thay đổi nào sau mốc này PHẢI đi kèm file migration SQL được đánh số
> (002_*.sql, 003_*.sql...). Không ALTER TABLE trực tiếp trên dashboard.
> Owner: DEV-04 | Violations sẽ break Flutter client queries silently.

Version: 1.0 | Status: FROZEN as of Day 3, Week 1 | Owner: DEV-04

This is the canonical cloud schema reference for SaViCam. The deployable SQL lives in `cloud/supabase/migrations/001_initial_schema.sql`; row-level security lives in `cloud/supabase/rls/row_level_security.sql`.

## Cloud Tables

### `profiles`

| Column | Type | Constraints / Default |
|---|---|---|
| `id` | `uuid` | Primary key, references `auth.users(id)` on delete cascade |
| `role` | `text` | Required, one of `t_mod`, `relap` |
| `full_name` | `text` | Optional |
| `fcm_token` | `text` | Optional |
| `linked_id` | `uuid` | Optional, references `profiles(id)` |
| `created_at` | `timestamptz` | Defaults to `now()` |

RLS: authenticated users can read, insert, update, and delete only their own profile row where `id = auth.uid()`.

### `device_telemetry`

| Column | Type | Constraints / Default |
|---|---|---|
| `device_id` | `uuid` | Primary key, references `profiles(id)` on delete cascade |
| `battery_percentage` | `int` | Optional, must be between 0 and 100 |
| `network_status` | `boolean` | Defaults to `false` |
| `is_headless_active` | `boolean` | Defaults to `false` |
| `last_updated` | `timestamptz` | Defaults to `now()` |

Indexes: `idx_telemetry_last_updated`.

RLS: T-Mod inserts telemetry for its own `device_id`; the device owner and paired Relap profile can read telemetry. Paired reads support either profile-pairing direction to avoid blocking legitimate guardian access during early account setup.

### `location_macros`

| Column | Type | Constraints / Default |
|---|---|---|
| `id` | `uuid` | Primary key, defaults to `gen_random_uuid()` |
| `user_id` | `uuid` | Required, references `profiles(id)` on delete cascade |
| `keyword` | `text` | Required |
| `lat` | `double precision` | Required |
| `lng` | `double precision` | Required |
| `is_synced` | `boolean` | Defaults to `false` |
| `created_at` | `timestamptz` | Defaults to `now()` |

Indexes: `idx_macros_user_id`, `idx_macros_is_synced`.

RLS: the owner can read and write their macros; the paired profile can read them. Paired reads support either profile-pairing direction to avoid blocking legitimate guardian access during early account setup.

### `sos_events`

| Column | Type | Constraints / Default |
|---|---|---|
| `id` | `uuid` | Primary key, defaults to `gen_random_uuid()` |
| `device_id` | `uuid` | Required, references `profiles(id)` on delete cascade |
| `trigger_method` | `text` | Defaults to `physical_button`, one of `voice`, `physical_button` |
| `lat` | `double precision` | Required |
| `lng` | `double precision` | Required |
| `status` | `text` | Defaults to `active`, one of `active`, `resolved` |
| `created_at` | `timestamptz` | Defaults to `now()` |

Indexes: `idx_sos_device_id`, `idx_sos_status`, `idx_sos_created_at`.

RLS: T-Mod inserts SOS rows for its own `device_id`; the device owner and paired Relap profile can read SOS rows; paired Relap can update SOS rows to resolve an event. Paired reads and updates support either profile-pairing direction to avoid blocking legitimate guardian access during early account setup.

## Naming Decision

`implementation_guide.md` CONTRACT-03 lists `sos_events.triggered_at` and `resolved bool`. `architecture_lock.md` Table 6 and TASK-D02-DEV04-01 require `created_at` and `status text`. Version 1.0 uses `created_at` plus `status` because it is consistent with the other cloud tables and leaves room for additional SOS states beyond a boolean resolved flag.

For CONTRACT-04 payload compatibility, Realtime consumers should map `created_at` to their display timestamp and `status = 'resolved'` to any legacy resolved boolean.

## WebSocket Event Payloads (CONTRACT-04)

Telemetry insert event:

```json
{
  "event": "INSERT",
  "table": "device_telemetry",
  "record": {
    "device_id": "uuid",
    "battery_percentage": 72,
    "network_status": true,
    "is_headless_active": true,
    "last_updated": "2025-01-01T10:00:00Z"
  }
}
```

SOS insert event:

```json
{
  "event": "INSERT",
  "table": "sos_events",
  "record": {
    "id": "uuid",
    "device_id": "uuid",
    "lat": 16.0544,
    "lng": 108.2022,
    "trigger_method": "physical_button",
    "status": "active",
    "created_at": "2025-01-01T10:05:00Z"
  }
}
```

## Offline_Queue Mapping

The edge SQLite `Offline_Queue` buffers cloud-bound payloads while the T-Mod device is offline. Supported `payload_type` values for this contract:

| `payload_type` | Cloud target | Notes |
|---|---|---|
| `telemetry_update` | `device_telemetry` | Flushes battery, network, headless mode, and timestamp snapshots. |
| `sos_alert` | `sos_events` | Flushes SOS trigger method and coordinates; FCM handling is a later task. |

## Deployment Checklist

1. Run `cloud/supabase/migrations/001_initial_schema.sql` in the Supabase SQL editor.
2. Run `cloud/supabase/rls/row_level_security.sql` in the Supabase SQL editor.
3. Confirm all four tables exist.
4. Confirm Row Level Security is enabled on all four tables.
5. Test with two authenticated users that user A cannot read user B private rows except through the paired-device policies.

## Changelog

- v1.0 (Day 3): Initial schema deployed and seeded.
