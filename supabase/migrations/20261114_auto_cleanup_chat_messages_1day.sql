-- Migration: 20261114_auto_cleanup_chat_messages_1day.sql
-- Description: Tự động xóa lịch sử tin nhắn tư vấn và phiên hội thoại cũ hơn 1 ngày (24 giờ)

BEGIN;

-- 1. Hàm dọn dẹp các tin nhắn và hội thoại cũ hơn 1 ngày
CREATE OR REPLACE FUNCTION public.cleanup_expired_doctor_chat_messages(retention_hours INTEGER DEFAULT 24)
RETURNS JSONB AS $$
DECLARE
  deleted_messages_count INTEGER := 0;
  deleted_conversations_count INTEGER := 0;
  cutoff_time TIMESTAMPTZ := now() - (retention_hours || ' hours')::INTERVAL;
BEGIN
  -- Xoá tin nhắn có thời gian tạo cũ hơn cutoff_time
  WITH deleted_msgs AS (
    DELETE FROM public.doctor_chat_messages
    WHERE created_at < cutoff_time
    RETURNING id
  )
  SELECT COUNT(*) INTO deleted_messages_count FROM deleted_msgs;

  -- Xoá các phiên hội thoại không có hoạt động trong cutoff_time
  WITH deleted_convs AS (
    DELETE FROM public.conversations
    WHERE last_message_time < cutoff_time
    RETURNING id
  )
  SELECT COUNT(*) INTO deleted_conversations_count FROM deleted_convs;

  RETURN jsonb_build_object(
    'status', 'success',
    'retention_hours', retention_hours,
    'cutoff_time', cutoff_time,
    'deleted_messages', deleted_messages_count,
    'deleted_conversations', deleted_conversations_count,
    'executed_at', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Phân quyền thực thi hàm cho các vai trò Supabase
GRANT EXECUTE ON FUNCTION public.cleanup_expired_doctor_chat_messages(INTEGER) TO anon, authenticated, service_role;

-- 3. Hướng dẫn thiết lập tự động hóa định kỳ (Scheduled Job):
-- Nếu dự án Supabase đã kích hoạt extension pg_cron, quản trị viên có thể lên lịch tự động mỗi giờ:
-- SELECT cron.schedule('cleanup-old-doctor-chat-hourly', '0 * * * *', 'SELECT public.cleanup_expired_doctor_chat_messages(24);');

COMMIT;
