-- ==============================================================================
-- Migration: 20261113_create_user_accounts.sql
-- Description: Comprehensive User & Doctor Accounts, Appeals, Admin Profiles,
--              RPC Stored Procedures (Bcrypt), RLS, Realtime & Realistic Seeding.
-- Requirements: R3 (Supabase Account Management & Data Seeding)
-- ==============================================================================

-- 1. Enable pgcrypto extension for secure Bcrypt hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Alter doctor_profiles to support two-way account linking
ALTER TABLE public.doctor_profiles 
  ADD COLUMN IF NOT EXISTS account_username TEXT;

CREATE INDEX IF NOT EXISTS idx_doctor_profiles_account_username 
  ON public.doctor_profiles (account_username);

-- 3. Create table user_accounts
CREATE TABLE IF NOT EXISTS public.user_accounts (
  username TEXT PRIMARY KEY,
  password_hash TEXT NOT NULL,
  full_name TEXT DEFAULT '',
  email_or_phone TEXT,
  role TEXT NOT NULL DEFAULT 'patient' CHECK (role IN ('patient', 'doctor', 'admin')),
  doctor_id TEXT REFERENCES public.doctor_profiles(id) ON DELETE SET NULL,
  gender TEXT,
  weight_kg NUMERIC,
  height_cm NUMERIC,
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

-- Indexes for user_accounts
CREATE INDEX IF NOT EXISTS idx_user_accounts_role ON public.user_accounts (role);
CREATE INDEX IF NOT EXISTS idx_user_accounts_doctor_id ON public.user_accounts (doctor_id);
CREATE INDEX IF NOT EXISTS idx_user_accounts_email_or_phone ON public.user_accounts (email_or_phone);
CREATE INDEX IF NOT EXISTS idx_user_accounts_is_locked ON public.user_accounts (is_locked);

-- 4. Create table account_unlock_appeals
CREATE TABLE IF NOT EXISTS public.account_unlock_appeals (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  username TEXT NOT NULL REFERENCES public.user_accounts(username) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_account_unlock_appeals_username ON public.account_unlock_appeals (username);
CREATE INDEX IF NOT EXISTS idx_account_unlock_appeals_status ON public.account_unlock_appeals (status);

-- 5. Create table admin_profiles
CREATE TABLE IF NOT EXISTS public.admin_profiles (
  username TEXT PRIMARY KEY,
  password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT 'Quản trị viên AI',
  email TEXT NOT NULL DEFAULT 'cuuho.ai.system@gmail.com',
  role_label TEXT NOT NULL DEFAULT 'Quản trị viên cấp cao',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_login_at TIMESTAMPTZ
);

-- ==============================================================================
-- 6. RPC AUTHENTICATION FUNCTIONS (Bcrypt & Fail-Safe)
-- ==============================================================================

-- 6.1 Register User Account
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
    RETURN json_build_object(
      'success', false,
      'message', 'Tên đăng nhập phải có ít nhất 3 ký tự.'
    );
  END IF;

  IF length(trim(p_password)) < 6 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Mật khẩu phải có ít nhất 6 ký tự.'
    );
  END IF;

  IF EXISTS (SELECT 1 FROM public.user_accounts WHERE lower(username) = v_clean_user) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác.'
    );
  END IF;

  v_hash := crypt(trim(p_password), gen_salt('bf', 8));

  INSERT INTO public.user_accounts (
    username,
    password_hash,
    email_or_phone,
    role,
    created_at,
    last_active_at,
    is_locked
  ) VALUES (
    v_clean_user,
    v_hash,
    nullif(trim(p_email_or_phone), ''),
    'patient',
    now(),
    now(),
    false
  )
  RETURNING * INTO v_account;

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
  RETURN json_build_object(
    'success', false,
    'message', 'Lỗi khi tạo tài khoản: ' || SQLERRM
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6.2 Authenticate User Account (Supports Bcrypt and plain fallback)
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

  -- Verify password using Bcrypt or plain equality fallback
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

  -- Update last active time
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

-- 6.3 Change User Password
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

-- 6.4 Authenticate Admin
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

-- 6.5 Reset Admin Password
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

-- ==============================================================================
-- 7. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE public.user_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_unlock_appeals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;

-- Development full access policies for user_accounts
DROP POLICY IF EXISTS "Allow select for user_accounts" ON public.user_accounts;
CREATE POLICY "Allow select for user_accounts" ON public.user_accounts FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert for user_accounts" ON public.user_accounts;
CREATE POLICY "Allow insert for user_accounts" ON public.user_accounts FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update for user_accounts" ON public.user_accounts;
CREATE POLICY "Allow update for user_accounts" ON public.user_accounts FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete for user_accounts" ON public.user_accounts;
CREATE POLICY "Allow delete for user_accounts" ON public.user_accounts FOR DELETE USING (true);

-- Development policies for account_unlock_appeals
DROP POLICY IF EXISTS "Allow select for appeals" ON public.account_unlock_appeals;
CREATE POLICY "Allow select for appeals" ON public.account_unlock_appeals FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert for appeals" ON public.account_unlock_appeals;
CREATE POLICY "Allow insert for appeals" ON public.account_unlock_appeals FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update for appeals" ON public.account_unlock_appeals;
CREATE POLICY "Allow update for appeals" ON public.account_unlock_appeals FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete for appeals" ON public.account_unlock_appeals;
CREATE POLICY "Allow delete for appeals" ON public.account_unlock_appeals FOR DELETE USING (true);

-- Development policies for admin_profiles
DROP POLICY IF EXISTS "Allow select for admin_profiles" ON public.admin_profiles;
CREATE POLICY "Allow select for admin_profiles" ON public.admin_profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow update for admin_profiles" ON public.admin_profiles;
CREATE POLICY "Allow update for admin_profiles" ON public.admin_profiles FOR UPDATE USING (true) WITH CHECK (true);

-- ==============================================================================
-- 8. REALTIME REPLICATION CONFIGURATION
-- ==============================================================================

ALTER TABLE public.user_accounts REPLICA IDENTITY FULL;
ALTER TABLE public.account_unlock_appeals REPLICA IDENTITY FULL;
ALTER TABLE public.admin_profiles REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'user_accounts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_accounts;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'account_unlock_appeals'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.account_unlock_appeals;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'admin_profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_profiles;
  END IF;
END $$;

-- ==============================================================================
-- 9. SAMPLE DATA SEEDING (DOCTORS, PATIENTS, ADMIN)
-- ==============================================================================

-- 9.1 Seed 5 Doctor Accounts (password: password123)
-- BS. CKI Nguyễn Văn An
INSERT INTO public.user_accounts (
  username, password_hash, full_name, email_or_phone, role, doctor_id,
  medical_profile, is_locked, created_at, last_active_at
) VALUES (
  'bs_an',
  crypt('password123', gen_salt('bf', 8)),
  'BS. CKI Nguyễn Văn An',
  'bs.an.nguyen@bv-trunguong.vn',
  'doctor',
  'doc_an_nguyen',
  '{"role": "doctor", "doctor_id": "doc_an_nguyen", "full_name": "BS. CKI Nguyễn Văn An", "account_type": "doctor_provisioned"}'::jsonb,
  false,
  now(),
  now()
) ON CONFLICT (username) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  role = 'doctor',
  doctor_id = 'doc_an_nguyen',
  full_name = 'BS. CKI Nguyễn Văn An';

-- ThS. BS Trần Thanh Nga
INSERT INTO public.user_accounts (
  username, password_hash, full_name, email_or_phone, role, doctor_id,
  medical_profile, is_locked, created_at, last_active_at
) VALUES (
  'bs_nga',
  crypt('password123', gen_salt('bf', 8)),
  'ThS. BS Trần Thanh Nga',
  'bs.nga.tran@choray.vn',
  'doctor',
  'doc_tran_thanh_nga',
  '{"role": "doctor", "doctor_id": "doc_tran_thanh_nga", "full_name": "ThS. BS Trần Thanh Nga", "account_type": "doctor_provisioned"}'::jsonb,
  false,
  now(),
  now()
) ON CONFLICT (username) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  role = 'doctor',
  doctor_id = 'doc_tran_thanh_nga',
  full_name = 'ThS. BS Trần Thanh Nga';

-- BS. CKII Lê Hoàng Nam
INSERT INTO public.user_accounts (
  username, password_hash, full_name, email_or_phone, role, doctor_id,
  medical_profile, is_locked, created_at, last_active_at
) VALUES (
  'bs_nam',
  crypt('password123', gen_salt('bf', 8)),
  'BS. CKII Lê Hoàng Nam',
  'bs.nam.le@umc.edu.vn',
  'doctor',
  'doc_le_hoang_nam',
  '{"role": "doctor", "doctor_id": "doc_le_hoang_nam", "full_name": "BS. CKII Lê Hoàng Nam", "account_type": "doctor_provisioned"}'::jsonb,
  false,
  now(),
  now()
) ON CONFLICT (username) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  role = 'doctor',
  doctor_id = 'doc_le_hoang_nam',
  full_name = 'BS. CKII Lê Hoàng Nam';

-- BS. Phạm Quỳnh Chi
INSERT INTO public.user_accounts (
  username, password_hash, full_name, email_or_phone, role, doctor_id,
  medical_profile, is_locked, created_at, last_active_at
) VALUES (
  'bs_chi',
  crypt('password123', gen_salt('bf', 8)),
  'BS. Phạm Quỳnh Chi',
  'bs.chi.pham@dalieu.vn',
  'doctor',
  'doc_pham_quynh_chi',
  '{"role": "doctor", "doctor_id": "doc_pham_quynh_chi", "full_name": "BS. Phạm Quỳnh Chi", "account_type": "doctor_provisioned"}'::jsonb,
  false,
  now(),
  now()
) ON CONFLICT (username) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  role = 'doctor',
  doctor_id = 'doc_pham_quynh_chi',
  full_name = 'BS. Phạm Quỳnh Chi';

-- PGS. TS Vũ Minh Trí
INSERT INTO public.user_accounts (
  username, password_hash, full_name, email_or_phone, role, doctor_id,
  medical_profile, is_locked, created_at, last_active_at
) VALUES (
  'bs_tri',
  crypt('password123', gen_salt('bf', 8)),
  'PGS. TS Vũ Minh Trí',
  'pgs.tri.vu@ctch.vn',
  'doctor',
  'doc_vu_minh_tri',
  '{"role": "doctor", "doctor_id": "doc_vu_minh_tri", "full_name": "PGS. TS Vũ Minh Trí", "account_type": "doctor_provisioned"}'::jsonb,
  false,
  now(),
  now()
) ON CONFLICT (username) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  role = 'doctor',
  doctor_id = 'doc_vu_minh_tri',
  full_name = 'PGS. TS Vũ Minh Trí';

-- Update doctor_profiles two-way link to accounts
UPDATE public.doctor_profiles SET account_username = 'bs_an' WHERE id = 'doc_an_nguyen';
UPDATE public.doctor_profiles SET account_username = 'bs_nga' WHERE id = 'doc_tran_thanh_nga';
UPDATE public.doctor_profiles SET account_username = 'bs_nam' WHERE id = 'doc_le_hoang_nam';
UPDATE public.doctor_profiles SET account_username = 'bs_chi' WHERE id = 'doc_pham_quynh_chi';
UPDATE public.doctor_profiles SET account_username = 'bs_tri' WHERE id = 'doc_vu_minh_tri';

-- 9.2 Seed 3 Patient Accounts (password: password123)
-- Patient 1: benhnhan_01 (Nguyễn Văn Bình)
INSERT INTO public.user_accounts (
  username, password_hash, full_name, email_or_phone, role,
  blood_type, rh_factor, weight_kg, height_cm, is_locked, created_at, last_active_at
) VALUES (
  'benhnhan_01',
  crypt('password123', gen_salt('bf', 8)),
  'Nguyễn Văn Bình',
  '0912345678',
  'patient',
  'O',
  'Rh+',
  68.5,
  172.0,
  false,
  now(),
  now()
) ON CONFLICT (username) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  full_name = 'Nguyễn Văn Bình',
  email_or_phone = '0912345678';

-- Patient 2: benhnhan_02 (Trần Thị Hoa)
INSERT INTO public.user_accounts (
  username, password_hash, full_name, email_or_phone, role,
  blood_type, rh_factor, weight_kg, height_cm, is_locked, created_at, last_active_at
) VALUES (
  'benhnhan_02',
  crypt('password123', gen_salt('bf', 8)),
  'Trần Thị Hoa',
  '0987654321',
  'patient',
  'A',
  'Rh+',
  52.0,
  158.0,
  false,
  now(),
  now()
) ON CONFLICT (username) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  full_name = 'Trần Thị Hoa',
  email_or_phone = '0987654321';

-- Patient 3: test_patient (Bệnh nhân kiểm thử)
INSERT INTO public.user_accounts (
  username, password_hash, full_name, email_or_phone, role,
  blood_type, rh_factor, weight_kg, height_cm, is_locked, created_at, last_active_at
) VALUES (
  'test_patient',
  crypt('password123', gen_salt('bf', 8)),
  'Bệnh nhân kiểm thử',
  'test.patient@example.com',
  'patient',
  'B',
  'Rh+',
  60.0,
  165.0,
  false,
  now(),
  now()
) ON CONFLICT (username) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  full_name = 'Bệnh nhân kiểm thử';

-- 9.3 Seed Admin Account (admin / admin)
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
) ON CONFLICT (username) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  display_name = 'Quản trị viên AI',
  email = 'cuuho.ai.system@gmail.com';
