-- SaViCam Supabase initial schema.
-- TASK-D02-DEV04-01: create the four cloud tables from CONTRACT-03.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('t_mod', 'relap')),
  display_name TEXT,
  fcm_token TEXT,
  paired_device_id UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS device_telemetry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  battery_pct INT CHECK (battery_pct >= 0 AND battery_pct <= 100),
  network_status TEXT DEFAULT 'unknown',
  is_headless_active BOOLEAN DEFAULT FALSE,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_telemetry_device_id
  ON device_telemetry(device_id);

CREATE INDEX IF NOT EXISTS idx_telemetry_recorded_at
  ON device_telemetry(recorded_at DESC);

CREATE TABLE IF NOT EXISTS location_macros (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  keyword TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  is_synced BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_macros_owner_id
  ON location_macros(owner_id);

CREATE INDEX IF NOT EXISTS idx_macros_is_synced
  ON location_macros(is_synced);

CREATE TABLE IF NOT EXISTS sos_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  trigger_method TEXT DEFAULT 'physical_button' CHECK (trigger_method IN ('voice', 'physical_button')),
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sos_device_id
  ON sos_events(device_id);

CREATE INDEX IF NOT EXISTS idx_sos_status
  ON sos_events(status);

CREATE INDEX IF NOT EXISTS idx_sos_created_at
  ON sos_events(created_at DESC);
