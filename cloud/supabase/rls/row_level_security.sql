-- SaViCam Supabase row-level security policies.
-- Rerunnable in the Supabase SQL editor.

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_macros ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_events ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'profiles_self_access'
  ) THEN
    CREATE POLICY "profiles_self_access" ON profiles
      FOR ALL
      USING (auth.uid() = id)
      WITH CHECK (auth.uid() = id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'device_telemetry'
      AND policyname = 'telemetry_device_write'
  ) THEN
    CREATE POLICY "telemetry_device_write" ON device_telemetry
      FOR INSERT
      WITH CHECK (auth.uid() = device_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'device_telemetry'
      AND policyname = 'telemetry_paired_read'
  ) THEN
    CREATE POLICY "telemetry_paired_read" ON device_telemetry
      FOR SELECT
      USING (
        auth.uid() = device_id OR
        auth.uid() IN (
          SELECT id FROM profiles
          WHERE linked_id = device_telemetry.device_id
        ) OR
        auth.uid() IN (
          SELECT linked_id FROM profiles
          WHERE id = device_telemetry.device_id
        )
      );
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'location_macros'
      AND policyname = 'macros_owner_all'
  ) THEN
    CREATE POLICY "macros_owner_all" ON location_macros
      FOR ALL
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'location_macros'
      AND policyname = 'macros_paired_read'
  ) THEN
    CREATE POLICY "macros_paired_read" ON location_macros
      FOR SELECT
      USING (
        auth.uid() IN (
          SELECT id FROM profiles
          WHERE linked_id = location_macros.user_id
        ) OR
        auth.uid() IN (
          SELECT linked_id FROM profiles
          WHERE id = location_macros.user_id
        )
      );
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'sos_events'
      AND policyname = 'sos_device_insert'
  ) THEN
    CREATE POLICY "sos_device_insert" ON sos_events
      FOR INSERT
      WITH CHECK (auth.uid() = device_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'sos_events'
      AND policyname = 'sos_paired_read'
  ) THEN
    CREATE POLICY "sos_paired_read" ON sos_events
      FOR SELECT
      USING (
        auth.uid() = device_id OR
        auth.uid() IN (
          SELECT id FROM profiles
          WHERE linked_id = sos_events.device_id
        ) OR
        auth.uid() IN (
          SELECT linked_id FROM profiles
          WHERE id = sos_events.device_id
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'sos_events'
      AND policyname = 'sos_relap_resolve'
  ) THEN
    CREATE POLICY "sos_relap_resolve" ON sos_events
      FOR UPDATE
      USING (
        auth.uid() IN (
          SELECT id FROM profiles
          WHERE linked_id = sos_events.device_id
        ) OR
        auth.uid() IN (
          SELECT linked_id FROM profiles
          WHERE id = sos_events.device_id
        )
      )
      WITH CHECK (
        auth.uid() IN (
          SELECT id FROM profiles
          WHERE linked_id = sos_events.device_id
        ) OR
        auth.uid() IN (
          SELECT linked_id FROM profiles
          WHERE id = sos_events.device_id
        )
      );
  END IF;
END
$$;
