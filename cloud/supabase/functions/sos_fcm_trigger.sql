-- FILE: cloud/supabase/functions/sos_fcm_trigger.sql
-- OWNER: DEV-04
-- Tạo PostgreSQL trigger kích hoạt Edge Function khi INSERT vào sos_events

-- Bước 1: Enable pg_net extension (gọi HTTP từ PostgreSQL)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Bước 2: Tạo function gọi Edge Function
CREATE OR REPLACE FUNCTION notify_sos_relap()
RETURNS TRIGGER AS $$
DECLARE
  edge_function_url TEXT;
  service_role_key TEXT;
BEGIN
  edge_function_url := current_setting('app.supabase_url') || '/functions/v1/fcm_edge_function';
  service_role_key  := current_setting('app.supabase_service_role_key');

  PERFORM net.http_post(
    url     := edge_function_url,
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'Authorization', 'Bearer ' || service_role_key
               ),
    body    := jsonb_build_object(
                 'type',   'INSERT',
                 'table',  'sos_events',
                 'record', row_to_json(NEW)
               )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bước 3: Gắn trigger vào bảng sos_events
DROP TRIGGER IF EXISTS on_sos_event_insert ON sos_events;
CREATE TRIGGER on_sos_event_insert
  AFTER INSERT ON sos_events
  FOR EACH ROW EXECUTE FUNCTION notify_sos_relap();
