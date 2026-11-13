-- Migration: 20261111_create_consultation_tables.sql
-- Description: Create conversations and doctor_chat_messages tables, indexes, triggers, RLS, and Realtime publication for Milestone 2

-- =============================================================================
-- 1. Table: conversations (Consultation Sessions between Patient & Doctor)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.conversations (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  patient_id TEXT NOT NULL,
  patient_name TEXT NOT NULL DEFAULT 'Bệnh nhân',
  patient_phone TEXT,
  doctor_id TEXT NOT NULL,
  doctor_name TEXT NOT NULL DEFAULT 'BS. CKI Nguyễn Văn An',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed', 'waiting', 'transferred')),
  unread_doctor_count INTEGER NOT NULL DEFAULT 0,
  unread_patient_count INTEGER NOT NULL DEFAULT 0,
  last_message_content TEXT DEFAULT '',
  last_message_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  has_ai_fallback_response BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =============================================================================
-- 2. Table: doctor_chat_messages (2-Way Realtime Chat Messages)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.doctor_chat_messages (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  conversation_id TEXT NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('patient', 'doctor', 'ai', 'system')),
  sender_id TEXT NOT NULL,
  sender_name TEXT,
  content TEXT NOT NULL DEFAULT '',
  attachment_url TEXT,
  attachment_type TEXT NOT NULL DEFAULT 'none' CHECK (attachment_type IN ('none', 'image', 'document', 'woundScanSummary')),
  status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sending', 'sent', 'delivered', 'read', 'failed')),
  is_emergency_warning BOOLEAN NOT NULL DEFAULT false,
  doctor_note TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =============================================================================
-- 3. Indexes for Low-Latency Realtime Queries
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_conversations_doctor_id ON public.conversations (doctor_id);
CREATE INDEX IF NOT EXISTS idx_conversations_patient_id ON public.conversations (patient_id);
CREATE INDEX IF NOT EXISTS idx_conversations_status ON public.conversations (status);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message_time ON public.conversations (last_message_time DESC);

CREATE INDEX IF NOT EXISTS idx_doctor_chat_messages_conversation_id ON public.doctor_chat_messages (conversation_id);
CREATE INDEX IF NOT EXISTS idx_doctor_chat_messages_created_at ON public.doctor_chat_messages (created_at ASC);
CREATE INDEX IF NOT EXISTS idx_doctor_chat_messages_sender_type ON public.doctor_chat_messages (sender_type);
CREATE INDEX IF NOT EXISTS idx_doctor_chat_messages_status ON public.doctor_chat_messages (status);

-- =============================================================================
-- 4. Triggers for Auto-updating updated_at & Syncing Conversation Summary
-- =============================================================================
CREATE OR REPLACE FUNCTION public.update_conversations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_conversations_updated_at ON public.conversations;
CREATE TRIGGER trigger_set_conversations_updated_at
BEFORE UPDATE ON public.conversations
FOR EACH ROW
EXECUTE FUNCTION public.update_conversations_updated_at();

-- Database trigger to keep conversation last_message and unread counts in sync
CREATE OR REPLACE FUNCTION public.sync_conversation_on_new_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.conversations
  SET
    last_message_content = NEW.content,
    last_message_time = NEW.created_at,
    unread_doctor_count = CASE WHEN NEW.sender_type = 'patient' THEN unread_doctor_count + 1 ELSE unread_doctor_count END,
    unread_patient_count = CASE WHEN NEW.sender_type IN ('doctor', 'ai') THEN unread_patient_count + 1 ELSE unread_patient_count END,
    has_ai_fallback_response = CASE WHEN NEW.sender_type = 'ai' THEN true ELSE has_ai_fallback_response END,
    updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_sync_conversation_on_message ON public.doctor_chat_messages;
CREATE TRIGGER trigger_sync_conversation_on_message
AFTER INSERT ON public.doctor_chat_messages
FOR EACH ROW
EXECUTE FUNCTION public.sync_conversation_on_new_message();

-- =============================================================================
-- 5. Row Level Security (RLS) Policies
-- =============================================================================
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_chat_messages ENABLE ROW LEVEL SECURITY;

-- Conversations RLS
DROP POLICY IF EXISTS "Allow select conversations for all" ON public.conversations;
CREATE POLICY "Allow select conversations for all"
  ON public.conversations FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert conversations for all" ON public.conversations;
CREATE POLICY "Allow insert conversations for all"
  ON public.conversations FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update conversations for all" ON public.conversations;
CREATE POLICY "Allow update conversations for all"
  ON public.conversations FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete conversations for all" ON public.conversations;
CREATE POLICY "Allow delete conversations for all"
  ON public.conversations FOR DELETE USING (true);

-- Doctor Chat Messages RLS
DROP POLICY IF EXISTS "Allow select messages for all" ON public.doctor_chat_messages;
CREATE POLICY "Allow select messages for all"
  ON public.doctor_chat_messages FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert messages for all" ON public.doctor_chat_messages;
CREATE POLICY "Allow insert messages for all"
  ON public.doctor_chat_messages FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update messages for all" ON public.doctor_chat_messages;
CREATE POLICY "Allow update messages for all"
  ON public.doctor_chat_messages FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete messages for all" ON public.doctor_chat_messages;
CREATE POLICY "Allow delete messages for all"
  ON public.doctor_chat_messages FOR DELETE USING (true);

-- =============================================================================
-- 6. Supabase Realtime Publication Registration
-- =============================================================================
ALTER TABLE public.conversations REPLICA IDENTITY FULL;
ALTER TABLE public.doctor_chat_messages REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'doctor_chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.doctor_chat_messages;
  END IF;
END $$;

-- =============================================================================
-- 7. Seed Initial Consultation & Messages
-- =============================================================================
INSERT INTO public.conversations (
  id,
  patient_id,
  patient_name,
  patient_phone,
  doctor_id,
  doctor_name,
  status,
  unread_doctor_count,
  unread_patient_count,
  last_message_content,
  last_message_time
) VALUES (
  'conv_an_nguyen_01',
  'pat_default_01',
  'Nguyễn Văn Bình',
  '0912345678',
  'doc_an_nguyen',
  'BS. CKI Nguyễn Văn An',
  'active',
  0,
  0,
  'Xin chào, tôi là BS. CKI Nguyễn Văn An. Tôi có thể hỗ trợ sơ cứu gì cho bạn?',
  now() - INTERVAL '10 minutes'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.doctor_chat_messages (
  id,
  conversation_id,
  sender_type,
  sender_id,
  sender_name,
  content,
  status,
  created_at
) VALUES (
  'msg_seed_01',
  'conv_an_nguyen_01',
  'doctor',
  'doc_an_nguyen',
  'BS. CKI Nguyễn Văn An',
  'Xin chào, tôi là BS. CKI Nguyễn Văn An. Tôi có thể hỗ trợ sơ cứu gì cho bạn?',
  'read',
  now() - INTERVAL '10 minutes'
) ON CONFLICT (id) DO NOTHING;
