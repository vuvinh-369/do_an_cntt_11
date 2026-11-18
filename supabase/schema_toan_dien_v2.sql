-- ==============================================================================
-- TỔNG KHOA SCHEMA TOÀN DIỆN V2: HỆ THỐNG CƠ SỞ DỮ LIỆU SUPABASE CHUẨN HÓA
-- Tên file: supabase/schema_toan_dien_v2.sql
-- 
-- MỤC TIÊU:
-- 1. Xóa sạch các bảng cũ rời rạc, thiết kế lại cơ sở dữ liệu với khóa chính (PK)
--    và khóa ngoại (FK) chặt chẽ, ràng buộc toàn vẹn dữ liệu (Integrity Constraints).
-- 2. Quy tắc xóa dữ liệu:
--    - Xóa người dùng -> CASCADE xóa sạch thông tin liên quan (lịch sử quét, hồ sơ sức khỏe, nhật ký, khiếu nại).
--    - Xóa bác sĩ -> SET NULL (bảo toàn lịch sử trò chuyện & tin nhắn của bệnh nhân).
--    - Xóa phiên trò chuyện -> CASCADE xóa toàn bộ tin nhắn bên trong.
-- 3. Chỉ lưu lịch sử quét phân tích AI vào Supabase với người dùng đã đăng nhập (username NOT NULL FK).
-- 4. BẢO VỆ TUYỆT ĐỐI MEDGEMMA: Schema medgemma_kb hoàn toàn không bị ảnh hưởng.
-- ==============================================================================

BEGIN;

-- 0. KÍCH HOẠT EXTENSIONS CẦN THIẾT
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- BƯỚC 1: XÓA SẠCH CÁC BẢNG VÀ HÀM CŨ TRONG SCHEMA PUBLIC (CASCADE)
-- ==============================================================================
DROP TABLE IF EXISTS public.doctor_chat_messages CASCADE;
DROP TABLE IF EXISTS public.conversations CASCADE;
DROP TABLE IF EXISTS public.ai_feedbacks CASCADE;
DROP TABLE IF EXISTS public.analysis_history CASCADE;
DROP TABLE IF EXISTS public.daily_health_completed_lessons CASCADE;
DROP TABLE IF EXISTS public.daily_health_logs CASCADE;
DROP TABLE IF EXISTS public.user_health_profiles CASCADE;
DROP TABLE IF EXISTS public.daily_care_lessons CASCADE;
DROP TABLE IF EXISTS public.daily_health_admin_configs CASCADE;
DROP TABLE IF EXISTS public.account_unlock_appeals CASCADE;
DROP TABLE IF EXISTS public.admin_profiles CASCADE;
DROP TABLE IF EXISTS public.doctor_profiles CASCADE;
DROP TABLE IF EXISTS public.user_accounts CASCADE;

-- Xóa sạch các hàm trigger và hàm RPC cũ để tránh lỗi 42P13: cannot change return type
DROP FUNCTION IF EXISTS public.fn_set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.update_doctor_profiles_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.update_conversations_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.fn_sync_conversation_on_new_message() CASCADE;
DROP FUNCTION IF EXISTS public.sync_conversation_on_new_message() CASCADE;

DROP FUNCTION IF EXISTS public.register_user_account(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.register_user_account(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.register_user_account CASCADE;

DROP FUNCTION IF EXISTS public.authenticate_user_account(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.authenticate_user_account CASCADE;

DROP FUNCTION IF EXISTS public.change_user_password(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.change_user_password CASCADE;

DROP FUNCTION IF EXISTS public.authenticate_admin(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.authenticate_admin CASCADE;

DROP FUNCTION IF EXISTS public.reset_admin_password(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.reset_admin_password CASCADE;

DROP FUNCTION IF EXISTS public.cleanup_expired_doctor_chat_messages(INTEGER) CASCADE;
DROP FUNCTION IF EXISTS public.cleanup_expired_doctor_chat_messages() CASCADE;
DROP FUNCTION IF EXISTS public.cleanup_expired_doctor_chat_messages CASCADE;

-- ==============================================================================
-- BƯỚC 2: TẠO MỚI CÁC BẢNG VỚI KHÓA CHÍNH & KHÓA NGOẠI CHUẨN HÓA
-- ==============================================================================

-- 2.1 BẢNG HỒ SƠ BÁC SĨ (doctor_profiles)
CREATE TABLE public.doctor_profiles (
  id TEXT PRIMARY KEY DEFAULT ('doc_' || lower(replace(gen_random_uuid()::text, '-', ''))),
  full_name TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT 'Bác sĩ Chuyên khoa',
  specialty TEXT NOT NULL DEFAULT 'Đa khoa',
  hospital TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  workplace_address TEXT NOT NULL,
  avatar_initials TEXT DEFAULT 'BS',
  avatar_color TEXT DEFAULT '#2563EB',
  avatar_url TEXT,
  rating NUMERIC(3, 2) DEFAULT 4.90 CHECK (rating >= 0 AND rating <= 5.0),
  consultation_count INTEGER DEFAULT 0 CHECK (consultation_count >= 0),
  is_online BOOLEAN DEFAULT true,
  status_text TEXT DEFAULT 'Đang trực tuyến • Sẵn sàng hỗ trợ sơ cứu',
  is_verified BOOLEAN DEFAULT true,
  experience_years INTEGER DEFAULT 5 CHECK (experience_years >= 0),
  consultation_fee TEXT DEFAULT 'Tư vấn sơ cứu miễn phí',
  account_username TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.2 BẢNG TÀI KHOẢN NGƯỜI DÙNG & BÁC SĨ (user_accounts)
CREATE TABLE public.user_accounts (
  username TEXT PRIMARY KEY,
  password_hash TEXT NOT NULL,
  full_name TEXT DEFAULT '',
  email_or_phone TEXT,
  role TEXT NOT NULL DEFAULT 'patient' CHECK (role IN ('patient', 'doctor', 'admin')),
  doctor_id TEXT REFERENCES public.doctor_profiles(id) ON DELETE SET NULL,
  gender TEXT,
  weight_kg NUMERIC CHECK (weight_kg IS NULL OR weight_kg > 0),
  height_cm NUMERIC CHECK (height_cm IS NULL OR height_cm > 0),
  blood_type TEXT,
  rh_factor TEXT,
  allergies JSONB DEFAULT '[]'::jsonb,
  medical_conditions JSONB DEFAULT '[]'::jsonb,
  other_notes TEXT,
  is_locked BOOLEAN NOT NULL DEFAULT false,
  lock_reason TEXT,
  medical_profile JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ràng buộc liên kết 2 chiều giữa doctor_profiles và user_accounts
ALTER TABLE public.doctor_profiles
  ADD CONSTRAINT fk_doctor_profiles_account_username
  FOREIGN KEY (account_username) REFERENCES public.user_accounts(username) ON DELETE SET NULL;

-- 2.3 BẢNG HỒ SƠ QUẢN TRỊ VIÊN (admin_profiles)
CREATE TABLE public.admin_profiles (
  username TEXT PRIMARY KEY,
  password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT 'Quản trị viên AI',
  email TEXT NOT NULL DEFAULT 'cuuho.ai.system@gmail.com',
  role_label TEXT NOT NULL DEFAULT 'Quản trị viên cấp cao',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_login_at TIMESTAMPTZ
);

-- 2.4 BẢNG KHIẾU NẠI MỞ KHÓA TÀI KHOẢN (account_unlock_appeals)
CREATE TABLE public.account_unlock_appeals (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  username TEXT NOT NULL REFERENCES public.user_accounts(username) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (btrim(reason) <> ''),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

-- 2.5 BẢNG PHIÊN HỘI THOẠI TƯ VẤN (conversations)
CREATE TABLE public.conversations (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  doctor_id TEXT REFERENCES public.doctor_profiles(id) ON DELETE SET NULL,
  doctor_name TEXT NOT NULL DEFAULT 'BS. CKI Nguyễn Văn An',
  patient_id TEXT NOT NULL,
  patient_username TEXT REFERENCES public.user_accounts(username) ON DELETE CASCADE,
  patient_name TEXT NOT NULL DEFAULT 'Bệnh nhân',
  patient_phone TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed', 'waiting', 'transferred')),
  unread_doctor_count INTEGER NOT NULL DEFAULT 0 CHECK (unread_doctor_count >= 0),
  unread_patient_count INTEGER NOT NULL DEFAULT 0 CHECK (unread_patient_count >= 0),
  last_message_content TEXT DEFAULT '',
  last_message_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  has_ai_fallback_response BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.6 BẢNG TIN NHẮN TƯ VẤN THỜI GIAN THỰC (doctor_chat_messages)
CREATE TABLE public.doctor_chat_messages (
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

-- 2.7 BẢNG LỊCH SỬ PHÂN TÍCH HÌNH ẢNH AI (analysis_history)
-- Ràng buộc: Chỉ lưu trữ lịch sử cho người dùng đã đăng ký/đăng nhập
CREATE TABLE public.analysis_history (
  id TEXT PRIMARY KEY DEFAULT ('hist_' || floor(extract(epoch from now()) * 1000)::text),
  username TEXT NOT NULL REFERENCES public.user_accounts(username) ON DELETE CASCADE,
  injury_type_id TEXT NOT NULL DEFAULT 'abrasion',
  injury_type_name TEXT NOT NULL DEFAULT 'Trầy xước ngoài da',
  confidence_score NUMERIC NOT NULL DEFAULT 80.0 CHECK (confidence_score >= 0 AND confidence_score <= 100.0),
  severity_level TEXT NOT NULL DEFAULT 'moderate',
  location_label TEXT DEFAULT 'Chưa xác định',
  image_url TEXT,
  symptoms TEXT[] DEFAULT '{}',
  pain_level INTEGER DEFAULT 0 CHECK (pain_level >= 0 AND pain_level <= 10),
  first_aid_summary TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.8 BẢNG PHẢN HỒI & ĐÁNH GIÁ CHẤT LƯỢNG AI (ai_feedbacks)
CREATE TABLE public.ai_feedbacks (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  analysis_id TEXT REFERENCES public.analysis_history(id) ON DELETE SET NULL,
  user_id TEXT REFERENCES public.user_accounts(username) ON DELETE SET NULL,
  user_display_name TEXT NOT NULL DEFAULT 'Khách ẩn danh',
  source_model TEXT NOT NULL DEFAULT 'yoloVision' CHECK (source_model IN ('yoloVision', 'medgemma', 'gemini')),
  feedback_type TEXT NOT NULL CHECK (feedback_type IN ('helpful', 'inaccurate')),
  issue_category TEXT NOT NULL DEFAULT '',
  user_comment TEXT NOT NULL DEFAULT '',
  user_proposed_label TEXT,
  detected_wound_summary TEXT NOT NULL DEFAULT '',
  wound_location TEXT,
  pain_level TEXT,
  observed_symptoms TEXT[] NOT NULL DEFAULT '{}',
  image_file_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.9 BẢNG CẨM NANG BÀI HỌC SỨC KHỎE (daily_care_lessons)
CREATE TABLE public.daily_care_lessons (
  slug TEXT PRIMARY KEY CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly')),
  topic TEXT NOT NULL CHECK (topic IN ('movement', 'hydration', 'nutrition', 'sleep')),
  title TEXT NOT NULL CHECK (btrim(title) <> ''),
  summary TEXT NOT NULL CHECK (btrim(summary) <> ''),
  steps TEXT[] NOT NULL CHECK (
    cardinality(steps) > 0
    AND array_ndims(steps) = 1
    AND array_position(steps, null) IS NULL
  ),
  source_name TEXT NOT NULL CHECK (btrim(source_name) <> ''),
  source_url TEXT NOT NULL CHECK (source_url ~ '^https://[^[:space:]]+$'),
  sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  is_published BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.10 BẢNG HỒ SƠ THỂ TRẠNG SỨC KHỎE HẰNG NGÀY (user_health_profiles)
CREATE TABLE public.user_health_profiles (
  user_id TEXT PRIMARY KEY REFERENCES public.user_accounts(username) ON DELETE CASCADE,
  height_cm NUMERIC NOT NULL DEFAULT 170.0 CHECK (height_cm > 0),
  weight_kg NUMERIC NOT NULL DEFAULT 65.0 CHECK (weight_kg > 0),
  age INTEGER NOT NULL DEFAULT 26 CHECK (age > 0),
  gender TEXT NOT NULL DEFAULT 'male' CHECK (gender IN ('male', 'female', 'other')),
  activity_level TEXT NOT NULL DEFAULT 'moderate' CHECK (activity_level IN ('sedentary', 'light', 'moderate', 'active', 'veryActive')),
  health_goal TEXT NOT NULL DEFAULT 'maintenance' CHECK (health_goal IN ('maintenance', 'weightLoss', 'muscleGain', 'cardioHealth', 'generalWellness')),
  target_calories NUMERIC NOT NULL DEFAULT 2000.0,
  target_water_ml INTEGER NOT NULL DEFAULT 2275,
  target_sleep_hours NUMERIC NOT NULL DEFAULT 7.5,
  target_exercise_minutes INTEGER NOT NULL DEFAULT 30,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.11 BẢNG NHẬT KÝ CHỈ SỐ HẰNG NGÀY (daily_health_logs)
CREATE TABLE public.daily_health_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.user_health_profiles(user_id) ON DELETE CASCADE,
  log_date DATE NOT NULL,
  calories_in NUMERIC NOT NULL DEFAULT 0.0 CHECK (calories_in >= 0),
  calories_burned NUMERIC NOT NULL DEFAULT 0.0 CHECK (calories_burned >= 0),
  water_ml INTEGER NOT NULL DEFAULT 0 CHECK (water_ml >= 0),
  sleep_hours NUMERIC NOT NULL DEFAULT 0.0 CHECK (sleep_hours >= 0),
  exercise_minutes INTEGER NOT NULL DEFAULT 0 CHECK (exercise_minutes >= 0),
  weight_kg NUMERIC CHECK (weight_kg IS NULL OR weight_kg > 0),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_daily_health_logs_user_date UNIQUE (user_id, log_date)
);

-- 2.12 BẢNG BÀI HỌC SỨC KHỎE ĐÃ HOÀN THÀNH (daily_health_completed_lessons)
CREATE TABLE public.daily_health_completed_lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES public.user_health_profiles(user_id) ON DELETE CASCADE,
  lesson_slug TEXT NOT NULL REFERENCES public.daily_care_lessons(slug) ON DELETE CASCADE,
  completed_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_daily_completed_lessons_user_date UNIQUE (user_id, lesson_slug, completed_date)
);

-- 2.13 BẢNG CẤU HÌNH THAM SỐ ADMIN (daily_health_admin_configs)
CREATE TABLE public.daily_health_admin_configs (
  id TEXT PRIMARY KEY DEFAULT 'default_config',
  default_water_multiplier_ml_per_kg INTEGER NOT NULL DEFAULT 35,
  default_daily_exercise_min INTEGER NOT NULL DEFAULT 30,
  default_sleep_standard_hours NUMERIC NOT NULL DEFAULT 7.5,
  weight_loss_deficit_kcal INTEGER NOT NULL DEFAULT 400,
  muscle_gain_surplus_kcal INTEGER NOT NULL DEFAULT 300,
  auto_adaptive_adjustment_enabled BOOLEAN NOT NULL DEFAULT true,
  system_health_notice TEXT DEFAULT 'Hệ thống khuyến nghị tuân thủ tiêu chuẩn WHO & Viện Dinh Dưỡng Quốc Gia.',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==============================================================================
-- BƯỚC 3: TẠO CHỈ MỤC (INDEXES) TỐI ƯU TRUY VẤN
-- ==============================================================================
CREATE INDEX idx_doctor_profiles_specialty ON public.doctor_profiles (specialty);
CREATE INDEX idx_doctor_profiles_is_online ON public.doctor_profiles (is_online);
CREATE INDEX idx_doctor_profiles_hospital ON public.doctor_profiles (hospital);
CREATE INDEX idx_doctor_profiles_account_username ON public.doctor_profiles (account_username);

CREATE INDEX idx_user_accounts_role ON public.user_accounts (role);
CREATE INDEX idx_user_accounts_doctor_id ON public.user_accounts (doctor_id);
CREATE INDEX idx_user_accounts_email_or_phone ON public.user_accounts (email_or_phone);
CREATE INDEX idx_user_accounts_is_locked ON public.user_accounts (is_locked);

CREATE INDEX idx_account_unlock_appeals_username ON public.account_unlock_appeals (username);
CREATE INDEX idx_account_unlock_appeals_status ON public.account_unlock_appeals (status);

CREATE INDEX idx_conversations_doctor_id ON public.conversations (doctor_id);
CREATE INDEX idx_conversations_patient_id ON public.conversations (patient_id);
CREATE INDEX idx_conversations_patient_username ON public.conversations (patient_username);
CREATE INDEX idx_conversations_status ON public.conversations (status);
CREATE INDEX idx_conversations_last_message_time ON public.conversations (last_message_time DESC);

CREATE INDEX idx_doctor_chat_messages_conversation_id ON public.doctor_chat_messages (conversation_id);
CREATE INDEX idx_doctor_chat_messages_created_at ON public.doctor_chat_messages (created_at ASC);
CREATE INDEX idx_doctor_chat_messages_sender_type ON public.doctor_chat_messages (sender_type);
CREATE INDEX idx_doctor_chat_messages_status ON public.doctor_chat_messages (status);

CREATE INDEX idx_analysis_history_username ON public.analysis_history (username);
CREATE INDEX idx_analysis_history_created_at ON public.analysis_history (created_at DESC);
CREATE INDEX idx_analysis_history_injury_type_id ON public.analysis_history (injury_type_id);

CREATE INDEX idx_ai_feedbacks_created_at ON public.ai_feedbacks (created_at DESC);
CREATE INDEX idx_ai_feedbacks_analysis_id ON public.ai_feedbacks (analysis_id);
CREATE INDEX idx_ai_feedbacks_feedback_type ON public.ai_feedbacks (feedback_type);

CREATE INDEX idx_daily_care_lessons_frequency ON public.daily_care_lessons (frequency);
CREATE INDEX idx_daily_care_lessons_topic ON public.daily_care_lessons (topic);
CREATE INDEX idx_daily_care_lessons_is_published ON public.daily_care_lessons (is_published);

CREATE INDEX idx_daily_health_logs_user_date ON public.daily_health_logs (user_id, log_date DESC);
CREATE INDEX idx_completed_lessons_user_date ON public.daily_health_completed_lessons (user_id, completed_date DESC);

-- ==============================================================================
-- BƯỚC 4: DATABASE TRIGGERS
-- ==============================================================================

-- 4.1 Hàm chung cập nhật timestamp updated_at
DROP FUNCTION IF EXISTS public.fn_set_updated_at() CASCADE;
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_doctor_profiles_updated_at BEFORE UPDATE ON public.doctor_profiles FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE TRIGGER trg_conversations_updated_at BEFORE UPDATE ON public.conversations FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE TRIGGER trg_analysis_history_updated_at BEFORE UPDATE ON public.analysis_history FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE TRIGGER trg_ai_feedbacks_updated_at BEFORE UPDATE ON public.ai_feedbacks FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE TRIGGER trg_daily_care_lessons_updated_at BEFORE UPDATE ON public.daily_care_lessons FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE TRIGGER trg_user_health_profiles_updated_at BEFORE UPDATE ON public.user_health_profiles FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE TRIGGER trg_daily_health_logs_updated_at BEFORE UPDATE ON public.daily_health_logs FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
CREATE TRIGGER trg_daily_health_admin_configs_updated_at BEFORE UPDATE ON public.daily_health_admin_configs FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- 4.2 Trigger tự động cập nhật thống kê hội thoại khi có tin nhắn mới
DROP FUNCTION IF EXISTS public.fn_sync_conversation_on_new_message() CASCADE;
CREATE OR REPLACE FUNCTION public.fn_sync_conversation_on_new_message()
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

CREATE TRIGGER trg_sync_conversation_on_message
AFTER INSERT ON public.doctor_chat_messages
FOR EACH ROW EXECUTE FUNCTION public.fn_sync_conversation_on_new_message();

-- ==============================================================================
-- BƯỚC 5: STORED PROCEDURES & RPC FUNCTIONS (Bcrypt Security & Auto Cleanup)
-- ==============================================================================

-- 5.1 Đăng ký tài khoản người dùng
DROP FUNCTION IF EXISTS public.register_user_account CASCADE;
CREATE OR REPLACE FUNCTION public.register_user_account(
  p_username TEXT,
  p_password TEXT,
  p_email_or_phone TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_clean_user TEXT;
  v_hash TEXT;
  v_account RECORD;
BEGIN
  v_clean_user := lower(trim(p_username));

  IF length(v_clean_user) < 3 THEN
    RETURN json_build_object('success', false, 'message', 'Tên đăng nhập phải có ít nhất 3 ký tự.');
  END IF;

  IF length(trim(p_password)) < 6 THEN
    RETURN json_build_object('success', false, 'message', 'Mật khẩu phải có ít nhất 6 ký tự.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.user_accounts WHERE lower(username) = v_clean_user) THEN
    RETURN json_build_object('success', false, 'message', 'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác.');
  END IF;

  v_hash := crypt(trim(p_password), gen_salt('bf', 8));

  INSERT INTO public.user_accounts (
    username, password_hash, email_or_phone, role, created_at, last_active_at, is_locked
  ) VALUES (
    v_clean_user, v_hash, nullif(trim(p_email_or_phone), ''), 'patient', now(), now(), false
  )
  RETURNING * INTO v_account;

  -- Tự động tạo hồ sơ sức khỏe mặc định cho tài khoản mới
  INSERT INTO public.user_health_profiles (user_id, height_cm, weight_kg, age)
  VALUES (v_account.username, 170.0, 65.0, 26)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN json_build_object(
    'success', true,
    'message', 'Đăng ký tài khoản thành công.',
    'account', json_build_object(
      'username', v_account.username,
      'role', v_account.role,
      'email_or_phone', v_account.email_or_phone,
      'created_at', v_account.created_at
    )
  );
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', 'Lỗi khi tạo tài khoản: ' || SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.2 Xác thực tài khoản người dùng / bác sĩ
DROP FUNCTION IF EXISTS public.authenticate_user_account CASCADE;
CREATE OR REPLACE FUNCTION public.authenticate_user_account(
  p_username TEXT,
  p_password TEXT
)
RETURNS JSON AS $$
DECLARE
  v_clean_user TEXT;
  v_account RECORD;
  v_password_valid BOOLEAN := false;
BEGIN
  v_clean_user := lower(trim(p_username));

  SELECT * INTO v_account
  FROM public.user_accounts
  WHERE lower(username) = v_clean_user;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Tài khoản không tồn tại. Vui lòng kiểm tra lại.',
      'error', 'TÀI_KHOẢN_KHÔNG_TỒN_TẠI'
    );
  END IF;

  IF v_account.is_locked THEN
    RETURN json_build_object(
      'success', false,
      'is_locked', true,
      'lock_reason', coalesce(v_account.lock_reason, 'Tài khoản đang bị tạm khóa để xác minh.'),
      'message', 'Tài khoản đã bị khóa: ' || coalesce(v_account.lock_reason, 'Vui lòng gửi khiếu nại tới Admin.')
    );
  END IF;

  -- Kiểm tra mật khẩu Bcrypt hoặc đối chiếu trực tiếp an toàn
  IF v_account.password_hash = crypt(trim(p_password), v_account.password_hash)
     OR v_account.password_hash = trim(p_password) THEN
    v_password_valid := true;
  END IF;

  IF NOT v_password_valid THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Mật khẩu không chính xác. Vui lòng kiểm tra lại.',
      'error', 'SAI_MẬT_KHẨU'
    );
  END IF;

  UPDATE public.user_accounts
  SET last_active_at = now()
  WHERE username = v_account.username;

  RETURN json_build_object(
    'success', true,
    'account', json_build_object(
      'username', v_account.username,
      'full_name', v_account.full_name,
      'email_or_phone', v_account.email_or_phone,
      'role', v_account.role,
      'doctor_id', v_account.doctor_id,
      'gender', v_account.gender,
      'weight_kg', v_account.weight_kg,
      'height_cm', v_account.height_cm,
      'blood_type', v_account.blood_type,
      'rh_factor', v_account.rh_factor,
      'allergies', v_account.allergies,
      'medical_conditions', v_account.medical_conditions,
      'other_notes', v_account.other_notes,
      'is_locked', v_account.is_locked,
      'medical_profile', v_account.medical_profile,
      'created_at', v_account.created_at,
      'last_active_at', now()
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.3 Đổi mật khẩu người dùng
DROP FUNCTION IF EXISTS public.change_user_password CASCADE;
CREATE OR REPLACE FUNCTION public.change_user_password(
  p_username TEXT,
  p_old_password TEXT,
  p_new_password TEXT
)
RETURNS JSON AS $$
DECLARE
  v_clean_user TEXT;
  v_account RECORD;
BEGIN
  v_clean_user := lower(trim(p_username));

  SELECT * INTO v_account
  FROM public.user_accounts
  WHERE lower(username) = v_clean_user;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Tài khoản không tồn tại.');
  END IF;

  IF NOT (v_account.password_hash = crypt(trim(p_old_password), v_account.password_hash)
          OR v_account.password_hash = trim(p_old_password)) THEN
    RETURN json_build_object('success', false, 'message', 'Mật khẩu hiện tại không đúng.');
  END IF;

  IF length(trim(p_new_password)) < 6 THEN
    RETURN json_build_object('success', false, 'message', 'Mật khẩu mới phải có ít nhất 6 ký tự.');
  END IF;

  UPDATE public.user_accounts
  SET password_hash = crypt(trim(p_new_password), gen_salt('bf', 8)),
      last_active_at = now()
  WHERE username = v_account.username;

  RETURN json_build_object('success', true, 'message', 'Đổi mật khẩu thành công.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.4 Xác thực Quản trị viên
DROP FUNCTION IF EXISTS public.authenticate_admin CASCADE;
CREATE OR REPLACE FUNCTION public.authenticate_admin(
  p_username TEXT,
  p_password TEXT
)
RETURNS JSON AS $$
DECLARE
  v_admin RECORD;
  v_valid BOOLEAN := false;
BEGIN
  SELECT * INTO v_admin
  FROM public.admin_profiles
  WHERE lower(username) = lower(trim(p_username));

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Tài khoản hoặc mật khẩu Quản trị không chính xác.');
  END IF;

  IF v_admin.password_hash = crypt(trim(p_password), v_admin.password_hash)
     OR v_admin.password_hash = trim(p_password) THEN
    v_valid := true;
  END IF;

  IF NOT v_valid THEN
    RETURN json_build_object('success', false, 'message', 'Tài khoản hoặc mật khẩu Quản trị không chính xác.');
  END IF;

  UPDATE public.admin_profiles
  SET last_login_at = now()
  WHERE username = v_admin.username;

  RETURN json_build_object(
    'success', true,
    'admin', json_build_object(
      'username', v_admin.username,
      'display_name', v_admin.display_name,
      'email', v_admin.email,
      'role_label', v_admin.role_label,
      'last_login_at', now()
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.5 Đặt lại mật khẩu Quản trị viên
DROP FUNCTION IF EXISTS public.reset_admin_password CASCADE;
CREATE OR REPLACE FUNCTION public.reset_admin_password(
  p_username TEXT,
  p_new_password TEXT
)
RETURNS JSON AS $$
BEGIN
  UPDATE public.admin_profiles
  SET password_hash = crypt(trim(p_new_password), gen_salt('bf', 8))
  WHERE lower(username) = lower(trim(p_username));

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Tài khoản quản trị không tồn tại.');
  END IF;

  RETURN json_build_object('success', true, 'message', 'Đặt lại mật khẩu quản trị thành công.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.6 Tự động dọn dẹp lịch sử tin nhắn tư vấn cũ hơn 24 giờ
DROP FUNCTION IF EXISTS public.cleanup_expired_doctor_chat_messages CASCADE;
CREATE OR REPLACE FUNCTION public.cleanup_expired_doctor_chat_messages(retention_hours INTEGER DEFAULT 24)
RETURNS JSONB AS $$
DECLARE
  deleted_messages_count INTEGER := 0;
  deleted_conversations_count INTEGER := 0;
  cutoff_time TIMESTAMPTZ := now() - (retention_hours || ' hours')::INTERVAL;
BEGIN
  WITH deleted_msgs AS (
    DELETE FROM public.doctor_chat_messages
    WHERE created_at < cutoff_time
    RETURNING id
  )
  SELECT COUNT(*) INTO deleted_messages_count FROM deleted_msgs;

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

-- ==============================================================================
-- BƯỚC 6: PHÂN QUYỀN ROW LEVEL SECURITY (RLS) & GRANTS
-- ==============================================================================
ALTER TABLE public.doctor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_unlock_appeals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analysis_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_feedbacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_care_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_health_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_health_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_health_completed_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_health_admin_configs ENABLE ROW LEVEL SECURITY;

GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "policy_doctor_profiles_all" ON public.doctor_profiles;
CREATE POLICY "policy_doctor_profiles_all" ON public.doctor_profiles FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_user_accounts_all" ON public.user_accounts;
CREATE POLICY "policy_user_accounts_all" ON public.user_accounts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_admin_profiles_all" ON public.admin_profiles;
CREATE POLICY "policy_admin_profiles_all" ON public.admin_profiles FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_appeals_all" ON public.account_unlock_appeals;
CREATE POLICY "policy_appeals_all" ON public.account_unlock_appeals FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_conversations_all" ON public.conversations;
CREATE POLICY "policy_conversations_all" ON public.conversations FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_chat_messages_all" ON public.doctor_chat_messages;
CREATE POLICY "policy_chat_messages_all" ON public.doctor_chat_messages FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_analysis_history_all" ON public.analysis_history;
CREATE POLICY "policy_analysis_history_all" ON public.analysis_history FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_ai_feedbacks_all" ON public.ai_feedbacks;
CREATE POLICY "policy_ai_feedbacks_all" ON public.ai_feedbacks FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_daily_care_lessons_all" ON public.daily_care_lessons;
CREATE POLICY "policy_daily_care_lessons_all" ON public.daily_care_lessons FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_user_health_profiles_all" ON public.user_health_profiles;
CREATE POLICY "policy_user_health_profiles_all" ON public.user_health_profiles FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_daily_health_logs_all" ON public.daily_health_logs;
CREATE POLICY "policy_daily_health_logs_all" ON public.daily_health_logs FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_completed_lessons_all" ON public.daily_health_completed_lessons;
CREATE POLICY "policy_completed_lessons_all" ON public.daily_health_completed_lessons FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_daily_health_admin_configs_all" ON public.daily_health_admin_configs;
CREATE POLICY "policy_daily_health_admin_configs_all" ON public.daily_health_admin_configs FOR ALL USING (true) WITH CHECK (true);

-- ==============================================================================
-- BƯỚC 7: CẤU HÌNH SUPABASE REALTIME REPLICATION
-- ==============================================================================
ALTER TABLE public.doctor_profiles REPLICA IDENTITY FULL;
ALTER TABLE public.conversations REPLICA IDENTITY FULL;
ALTER TABLE public.doctor_chat_messages REPLICA IDENTITY FULL;
ALTER TABLE public.user_accounts REPLICA IDENTITY FULL;
ALTER TABLE public.account_unlock_appeals REPLICA IDENTITY FULL;
ALTER TABLE public.admin_profiles REPLICA IDENTITY FULL;
ALTER TABLE public.analysis_history REPLICA IDENTITY FULL;
ALTER TABLE public.ai_feedbacks REPLICA IDENTITY FULL;
ALTER TABLE public.user_health_profiles REPLICA IDENTITY FULL;
ALTER TABLE public.daily_health_logs REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

DO $$
DECLARE
  v_table text;
  v_tables text[] := ARRAY[
    'doctor_profiles', 'conversations', 'doctor_chat_messages',
    'user_accounts', 'account_unlock_appeals', 'admin_profiles',
    'analysis_history', 'ai_feedbacks', 'user_health_profiles', 'daily_health_logs'
  ];
BEGIN
  FOREACH v_table IN ARRAY v_tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = v_table
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I;', v_table);
    END IF;
  END LOOP;
END $$;

-- ==============================================================================
-- BƯỚC 8: NẠP DỮ LIỆU MẪU CHUẨN (COMPLETE SEED DATA)
-- ==============================================================================

-- 8.1 Seed 5 Bác sĩ chuyên khoa y tế
INSERT INTO public.doctor_profiles (
  id, full_name, title, specialty, hospital, phone_number, workplace_address,
  avatar_initials, avatar_color, avatar_url, rating, consultation_count, is_online,
  status_text, is_verified, experience_years, consultation_fee
) VALUES
(
  'doc_an_nguyen',
  'BS. CKI Nguyễn Văn An',
  'Bác sĩ Chuyên khoa I',
  'Ngoại Chấn thương & Xử trí Vết thương cấp',
  'Bệnh viện Đa khoa Trung ương',
  '0912345678',
  'Bệnh viện Chợ Rẫy, 201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
  'AN', '#1D4ED8', NULL, 4.95, 2180, true,
  'Đang trực tuyến • Sẵn sàng hỗ trợ sơ cứu', true, 14, 'Hỗ trợ sơ cấp cứu miễn phí'
),
(
  'doc_tran_thanh_nga',
  'ThS. BS Trần Thanh Nga',
  'Thạc sĩ Bác sĩ',
  'Bỏng - Tạo hình Thẩm mỹ & Phục hồi chức năng',
  'Bệnh viện Chợ Rẫy',
  '0987654321',
  'Bệnh viện Chợ Rẫy, 201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
  'TN', '#EC4899', NULL, 4.90, 1640, true,
  'Đang trực tuyến • Chuyên sâu bỏng & sẹo', true, 11, '150.000đ / lượt tư vấn'
),
(
  'doc_le_hoang_nam',
  'BS. CKII Lê Hoàng Nam',
  'Bác sĩ Chuyên khoa II',
  'Cấp cứu Tim mạch & Can thiệp hồi sức',
  'Bệnh viện Đại học Y Dược TP.HCM',
  '0903123456',
  '215 Hồng Bàng, Phường 11, Quận 5, TP.HCM',
  'HN', '#059669', NULL, 4.98, 3120, false,
  'Ngoại tuyến • Tiếp nhận lại lúc 14:00', true, 18, 'Tư vấn sơ cứu miễn phí'
),
(
  'doc_pham_quynh_chi',
  'BS. Phạm Quỳnh Chi',
  'Bác sĩ Nội trú',
  'Da liễu & Nhiễm trùng ngoài da',
  'Bệnh viện Da Liễu TP.HCM',
  '0938987654',
  '02 Nguyễn Thông, Phường Võ Thị Sáu, Quận 3, TP.HCM',
  'QC', '#8B5CF6', NULL, 4.88, 980, true,
  'Đang trực tuyến • Phản hồi trong 5 phút', true, 7, '100.000đ / lượt tư vấn'
),
(
  'doc_vu_minh_tri',
  'PGS. TS Vũ Minh Trí',
  'Phó Giáo sư, Tiến sĩ Bác sĩ',
  'Chấn thương Chỉnh hình & Cơ Xương Khớp',
  'Bệnh viện Chấn thương Chỉnh hình TP.HCM',
  '0918765432',
  '929 Trần Hưng Đạo, Phường 1, Quận 5, TP.HCM',
  'MT', '#D97706', NULL, 4.99, 4500, true,
  'Đang trực tuyến • Chuyên gia đầu ngành', true, 25, 'Tư vấn sơ cứu miễn phí'
);

-- 8.2 Seed Quản trị viên (admin / admin)
INSERT INTO public.admin_profiles (
  username, password_hash, display_name, email, role_label, created_at, last_login_at
) VALUES (
  'admin',
  crypt('admin', gen_salt('bf', 8)),
  'Quản trị viên AI',
  'cuuho.ai.system@gmail.com',
  'Quản trị viên cấp cao',
  now(),
  now()
);

-- 8.3 Seed Danh sách Tài khoản Người dùng & Bác sĩ (user_accounts)
-- Mật khẩu mặc định: 'password123' cho người dùng & bác sĩ; 'admin' cho tài khoản admin
INSERT INTO public.user_accounts (
  username, password_hash, full_name, email_or_phone, role, doctor_id,
  medical_profile, is_locked, created_at, last_active_at
) VALUES
(
  'admin',
  crypt('admin', gen_salt('bf', 8)),
  'Quản trị viên AI',
  'cuuho.ai.system@gmail.com',
  'admin',
  NULL,
  '{"role": "admin"}'::jsonb,
  false, now(), now()
),
(
  'default_user',
  crypt('password123', gen_salt('bf', 8)),
  'Người dùng mặc định',
  'default.user@cuuho.vn',
  'patient',
  NULL,
  '{"role": "patient"}'::jsonb,
  false, now(), now()
),
(
  'patient_test',
  crypt('password123', gen_salt('bf', 8)),
  'Bệnh nhân kiểm thử',
  'patient.test@cuuho.vn',
  'patient',
  NULL,
  '{"role": "patient"}'::jsonb,
  false, now(), now()
),
(
  'benhnhan_01',
  crypt('password123', gen_salt('bf', 8)),
  'Nguyễn Văn Bình',
  '0912345678',
  'patient',
  NULL,
  '{"role": "patient"}'::jsonb,
  false, now(), now()
),
(
  'benhnhan_02',
  crypt('password123', gen_salt('bf', 8)),
  'Trần Thị Hoa',
  '0987654321',
  'patient',
  NULL,
  '{"role": "patient"}'::jsonb,
  false, now(), now()
),
(
  'bs_an',
  crypt('password123', gen_salt('bf', 8)),
  'BS. CKI Nguyễn Văn An',
  'bs.an.nguyen@bv-trunguong.vn',
  'doctor',
  'doc_an_nguyen',
  '{"role": "doctor", "doctor_id": "doc_an_nguyen"}'::jsonb,
  false, now(), now()
),
(
  'bs_nga',
  crypt('password123', gen_salt('bf', 8)),
  'ThS. BS Trần Thanh Nga',
  'bs.nga.tran@choray.vn',
  'doctor',
  'doc_tran_thanh_nga',
  '{"role": "doctor", "doctor_id": "doc_tran_thanh_nga"}'::jsonb,
  false, now(), now()
),
(
  'bs_nam',
  crypt('password123', gen_salt('bf', 8)),
  'BS. CKII Lê Hoàng Nam',
  'bs.nam.le@umc.edu.vn',
  'doctor',
  'doc_le_hoang_nam',
  '{"role": "doctor", "doctor_id": "doc_le_hoang_nam"}'::jsonb,
  false, now(), now()
),
(
  'bs_chi',
  crypt('password123', gen_salt('bf', 8)),
  'BS. Phạm Quỳnh Chi',
  'bs.chi.pham@dalieu.vn',
  'doctor',
  'doc_pham_quynh_chi',
  '{"role": "doctor", "doctor_id": "doc_pham_quynh_chi"}'::jsonb,
  false, now(), now()
),
(
  'bs_tri',
  crypt('password123', gen_salt('bf', 8)),
  'PGS. TS Vũ Minh Trí',
  'pgs.tri.vu@ctch.vn',
  'doctor',
  'doc_vu_minh_tri',
  '{"role": "doctor", "doctor_id": "doc_vu_minh_tri"}'::jsonb,
  false, now(), now()
);

-- Cập nhật liên kết tài khoản bác sĩ ngược lại bảng doctor_profiles
UPDATE public.doctor_profiles SET account_username = 'bs_an' WHERE id = 'doc_an_nguyen';
UPDATE public.doctor_profiles SET account_username = 'bs_nga' WHERE id = 'doc_tran_thanh_nga';
UPDATE public.doctor_profiles SET account_username = 'bs_nam' WHERE id = 'doc_le_hoang_nam';
UPDATE public.doctor_profiles SET account_username = 'bs_chi' WHERE id = 'doc_pham_quynh_chi';
UPDATE public.doctor_profiles SET account_username = 'bs_tri' WHERE id = 'doc_vu_minh_tri';

-- 8.4 Seed Cấu hình chuẩn định mức Admin (daily_health_admin_configs)
INSERT INTO public.daily_health_admin_configs (
  id, default_water_multiplier_ml_per_kg, default_daily_exercise_min,
  default_sleep_standard_hours, weight_loss_deficit_kcal, muscle_gain_surplus_kcal,
  auto_adaptive_adjustment_enabled, system_health_notice
) VALUES (
  'default_config', 35, 30, 7.5, 400, 300, true,
  'Hệ thống khuyến nghị tuân thủ tiêu chuẩn WHO & Viện Dinh Dưỡng Quốc Gia.'
);

-- 8.5 Seed 9 Bài học cẩm nang Y tế Chuẩn WHO / NHS / CDC (daily_care_lessons)
INSERT INTO public.daily_care_lessons (
  slug, frequency, topic, title, summary, steps,
  source_name, source_url, sort_order, is_published
) VALUES
(
  'van-dong-buoi-sang', 'daily', 'movement', 'Vận động nhẹ buổi sáng',
  'Nếu mới bắt đầu, thử đi bộ vài phút rồi tăng dần theo sức của mình.',
  ARRAY['Chọn đoạn đường bằng phẳng và bắt đầu bằng nhịp đi bộ thoải mái.', 'Khi đã quen, bạn có thể đi lâu hơn hoặc đi nhanh hơn nếu thấy phù hợp.'],
  'WHO – Hướng dẫn về vận động thể chất', 'https://www.who.int/europe/publications/i/item/9789240014886', 10, true
),
(
  'uong-nuoc-trong-ngay', 'daily', 'hydration', 'Uống nước đều trong ngày',
  'NHS dùng 6–8 cốc chất lỏng mỗi ngày làm mốc tham khảo chung.',
  ARRAY['Để nước lọc trong tầm tay và uống rải đều trong ngày. Một số đồ uống khác như sữa hoặc trà không đường cũng được tính.', 'Nhu cầu có thể tăng khi trời nóng hoặc vận động lâu. Nếu bác sĩ đã dặn hạn chế chất lỏng, hãy theo mức được hướng dẫn.'],
  'NHS – Nước và bù đủ dịch', 'https://www.nhs.uk/live-well/eat-well/food-guidelines-and-food-labels/water-drinks-nutrition/', 20, true
),
(
  'bua-an-da-dang', 'daily', 'nutrition', 'Chọn bữa ăn đa dạng',
  'Thêm rau và kết hợp món giàu đạm với thực phẩm giàu tinh bột.',
  ARRAY['Gợi ý bữa sáng: yến mạch, sữa chua không đường và trái cây nguyên quả.', 'Gợi ý bữa chính: cơm gạo lứt, cá hoặc đậu phụ, và một món rau.'],
  'NHS – Ăn uống cân bằng', 'https://www.nhs.uk/live-well/eat-well/how-to-eat-a-balanced-diet/eating-a-balanced-diet/', 30, true
),
(
  'gio-ngu-deu-dan', 'daily', 'sleep', 'Giữ giờ ngủ đều đặn',
  'Chọn giờ đi ngủ và thức dậy có thể duy trì mỗi ngày.',
  ARRAY['Giữ giờ thức dậy tương đối ổn định, kể cả cuối tuần.', 'Tắt thiết bị điện tử ít nhất 30 phút trước khi ngủ. CDC khuyến nghị người từ 18–60 tuổi ngủ ít nhất 7 giờ mỗi ngày.'],
  'CDC – Giấc ngủ', 'https://www.cdc.gov/sleep/about/index.html', 40, true
),
(
  'giam-ngoi-tinh-tai', 'daily', 'movement', 'Ngắt quãng thời gian ngồi tĩnh tại',
  'WHO khuyến cáo đứng dậy và vươn vai sau mỗi 45–60 phút làm việc liên tục.',
  ARRAY['Đặt lời nhắc đứng dậy đi lại nhẹ nhàng hoặc leo cầu thang 2–3 phút.', 'Thực hiện các động tác xoay cổ vai gáy và kéo giãn cột sống đơn giản tại chỗ.'],
  'WHO – Hạn chế hành vi ngồi tĩnh tại', 'https://www.who.int/news-room/fact-sheets/detail/physical-activity', 50, true
),
(
  'kiem-soat-duong-muoi', 'daily', 'nutrition', 'Kiểm soát muối và đường bổ sung',
  'Giảm tiêu thụ muối dưới 5g/ngày và hạn chế đồ uống có đường tinh luyện.',
  ARRAY['Ưu tiên nêm nếm bằng thảo mộc, hạt tiêu và chanh thay vì dùng quá nhiều nước mắm mặn.', 'Uống nước lọc hoặc trà thảo mộc thay vì nước ngọt có gas và trà sữa đóng chai.'],
  'WHO – Hướng dẫn giảm muối và đường', 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet', 60, true
),
(
  'lap-lich-van-dong-tuan', 'weekly', 'movement', 'Lên lịch vận động trong tuần',
  'Chia thời gian vận động thành các buổi phù hợp với lịch sinh hoạt.',
  ARRAY['Với người trưởng thành, WHO khuyến nghị 150–300 phút vận động aerobic mức vừa mỗi tuần. Khi mới bắt đầu, chọn mức vừa sức và tăng dần.', 'Ví dụ khi đã quen: đi bộ nhanh 30 phút trong 5 ngày. Có thể bố trí thêm 2 ngày tập tăng sức mạnh cho các nhóm cơ lớn.'],
  'WHO – Khuyến nghị vận động thể chất', 'https://www.who.int/europe/news-room/fact-sheets/item/physical-activity', 10, true
),
(
  'chuan-bi-thuc-don-tuan', 'weekly', 'nutrition', 'Chuẩn bị thực đơn cho tuần',
  'Chọn trước vài món có thể nấu và viết danh sách mua thực phẩm.',
  ARRAY['Chọn rau và trái cây theo mùa để đổi món trong tuần.', 'Luân phiên đậu, trứng, cá hoặc thịt nạc tùy sở thích và nhu cầu ăn uống.'],
  'NHS – Ăn uống cân bằng', 'https://www.nhs.uk/live-well/eat-well/how-to-eat-a-balanced-diet/eating-a-balanced-diet/', 20, true
),
(
  'danh-gia-chat-luong-ngu-tuan', 'weekly', 'sleep', 'Đánh giá & cân bằng giấc ngủ tuần',
  'Xem lại số giờ ngủ trung bình trong tuần và điều chỉnh nợ ngủ an toàn.',
  ARRAY['Kiểm tra xem bạn có bị thiếu ngủ dồn dập vào các ngày trong tuần hay không.', 'Tránh ngủ nướng bù quá 2 giờ vào cuối tuần để không phá vỡ nhịp sinh học tự nhiên.'],
  'CDC – Thói quen ngủ lành mạnh', 'https://www.cdc.gov/sleep/about/index.html', 30, true
);

-- 8.6 Seed Hồ sơ thể trạng sức khỏe mẫu (user_health_profiles)
INSERT INTO public.user_health_profiles (
  user_id, height_cm, weight_kg, age, gender, activity_level, health_goal,
  target_calories, target_water_ml, target_sleep_hours, target_exercise_minutes
) VALUES
(
  'default_user', 170.0, 65.0, 26, 'male', 'moderate', 'maintenance',
  2000.0, 2275, 7.5, 30
),
(
  'patient_test', 165.0, 58.0, 24, 'female', 'light', 'generalWellness',
  1800.0, 2030, 8.0, 30
)
ON CONFLICT (user_id) DO NOTHING;

-- 8.7 Seed dữ liệu Lịch sử phân tích mẫu (analysis_history)
INSERT INTO public.analysis_history (
  id, username, injury_type_id, injury_type_name, confidence_score,
  severity_level, location_label, image_url, symptoms, pain_level,
  first_aid_summary, created_at, updated_at
) VALUES
(
  'hist_seed_001',
  'admin',
  'abrasion',
  'Trầy xước ngoài da',
  92.5,
  'mild',
  'Cẳng tay phải',
  'assets/images/sample_abrasion.jpg',
  ARRAY['Chảy máu rỉ rỉ', 'Rát bề mặt biểu bì', 'Bụi cát bám dính'],
  2,
  'Rửa sạch bằng nước muối sinh lý 0.9%, sát khuẩn bằng Povidone-Iodine và dán gạc vô trùng thoáng.',
  now() - interval '35 minutes',
  now() - interval '35 minutes'
),
(
  'hist_seed_002',
  'patient_test',
  'cut_laceration',
  'Vết cắt / rách da',
  88.0,
  'severe',
  'Ngón tay trỏ trái',
  'assets/images/sample_cut.jpg',
  ARRAY['Chảy máu nhiều', 'Vết rách sâu quá 0.5cm', 'Vết cắt kim loại sắc'],
  7,
  'Ấn ép trực tiếp gạc vô trùng cầm máu khẩn cấp, nâng cao chi tổn thương và khẩn trương đến viện khâu vết thương.',
  now() - interval '3 hours',
  now() - interval '3 hours'
),
(
  'hist_seed_003',
  'patient_test',
  'burn',
  'Bỏng nhiệt',
  85.0,
  'moderate',
  'Mu bàn tay phải',
  'assets/images/sample_burn.jpg',
  ARRAY['Da đỏ rát', 'Phồng rộp bọng nước', 'Bỏng nước sôi diện tích nhỏ'],
  5,
  'Xả nước mát sạch (15-25°C) liên tục trong 15-20 phút. Tuyệt đối không chườm đá lạnh buốt hay chọc vỡ bọng nước.',
  now() - interval '8 hours',
  now() - interval '8 hours'
),
(
  'hist_seed_004',
  'default_user',
  'bruise',
  'Bầm tím phần mềm',
  79.5,
  'mild',
  'Đầu gối trái',
  'assets/images/sample_bruise.jpg',
  ARRAY['Tụ máu dưới da', 'Đổi màu xanh tím', 'Đau khi ấn vào'],
  3,
  'Chườm lạnh gián tiếp qua khăn sạch 15 phút để co mạch giảm phù nề, nghỉ ngơi vùng va đập.',
  now() - interval '1 day',
  now() - interval '1 day'
);

COMMIT;
