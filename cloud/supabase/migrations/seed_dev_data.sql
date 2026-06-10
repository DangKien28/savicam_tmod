-- =====================================================
-- SaViCam Dev Seed Data — Day 3
-- Chạy trên Supabase SQL Editor
-- UUID giả — chỉ dùng cho development/testing
-- =====================================================

-- Seed auth.users để thỏa mãn foreign key profiles_id_fkey
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'tmod@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'relap@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
ON CONFLICT (id) DO NOTHING;

-- Seed profiles (2 users: 1 T-Mod + 1 Relap)
INSERT INTO profiles (id, role, full_name, fcm_token, linked_id)
VALUES
  ('00000000-0000-0000-0000-000000000001',
   't_mod',
   'Người khiếm thị Test',
   'fcm_token_tmod_placeholder',
   '00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000002',
   'relap',
   'Người thân Test',
   'fcm_token_relap_placeholder',
   '00000000-0000-0000-0000-000000000001');

-- Seed device_telemetry (1 row — Relap Telemetry screen dùng row này)
INSERT INTO device_telemetry (device_id, battery_percentage, network_status, is_headless_active)
VALUES
  ('00000000-0000-0000-0000-000000000001', 78, true, false);

-- Seed sos_events (2 rows — Relap SOS screen test)
ALTER TABLE sos_events DISABLE TRIGGER on_sos_event_insert;

INSERT INTO sos_events (device_id, trigger_method, lat, lng, status)
VALUES
  ('00000000-0000-0000-0000-000000000001',
   'physical_button',
   16.0544,    -- Đà Nẵng center lat
   108.2022,   -- Đà Nẵng center lng
   'active'),
  ('00000000-0000-0000-0000-000000000001',
   'voice',
   16.0600,
   108.2100,
   'resolved');

ALTER TABLE sos_events ENABLE TRIGGER on_sos_event_insert;

-- Seed location_macros (2 rows — NLP navigation test)
INSERT INTO location_macros (user_id, keyword, lat, lng, is_synced)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'nhà', 16.0544, 108.2022, true),
  ('00000000-0000-0000-0000-000000000001', 'trường', 16.0720, 108.1520, true);
