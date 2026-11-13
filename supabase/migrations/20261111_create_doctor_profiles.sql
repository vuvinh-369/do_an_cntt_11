-- Migration: 20261111_create_doctor_profiles.sql
-- Description: Create doctor_profiles table, RLS policies, Realtime publication, and initial seed data

-- 1. Create table doctor_profiles
CREATE TABLE IF NOT EXISTS public.doctor_profiles (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  full_name TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT 'Bác sĩ Chuyên khoa',
  specialty TEXT NOT NULL DEFAULT 'Đa khoa',
  hospital TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  workplace_address TEXT NOT NULL,
  avatar_initials TEXT DEFAULT 'BS',
  avatar_color TEXT DEFAULT '#2563EB',
  avatar_url TEXT,
  rating NUMERIC(3, 2) DEFAULT 4.90,
  consultation_count INTEGER DEFAULT 0,
  is_online BOOLEAN DEFAULT true,
  status_text TEXT DEFAULT 'Đang trực tuyến • Phản hồi trong 1-2 phút',
  is_verified BOOLEAN DEFAULT true,
  experience_years INTEGER DEFAULT 5,
  consultation_fee TEXT DEFAULT 'Tư vấn sơ cứu miễn phí',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create indexes for high-frequency queries
CREATE INDEX IF NOT EXISTS idx_doctor_profiles_specialty ON public.doctor_profiles (specialty);
CREATE INDEX IF NOT EXISTS idx_doctor_profiles_is_online ON public.doctor_profiles (is_online);
CREATE INDEX IF NOT EXISTS idx_doctor_profiles_hospital ON public.doctor_profiles (hospital);
CREATE INDEX IF NOT EXISTS idx_doctor_profiles_created_at ON public.doctor_profiles (created_at DESC);

-- 3. Trigger for auto-updating updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_doctor_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_doctor_profiles_updated_at ON public.doctor_profiles;
CREATE TRIGGER trigger_set_doctor_profiles_updated_at
BEFORE UPDATE ON public.doctor_profiles
FOR EACH ROW
EXECUTE FUNCTION public.update_doctor_profiles_updated_at();

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.doctor_profiles ENABLE ROW LEVEL SECURITY;

-- Development RLS Policies: Allow public (anon) and authenticated users full CRUD
DROP POLICY IF EXISTS "Allow select for all users" ON public.doctor_profiles;
CREATE POLICY "Allow select for all users"
  ON public.doctor_profiles FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Allow insert for all users" ON public.doctor_profiles;
CREATE POLICY "Allow insert for all users"
  ON public.doctor_profiles FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update for all users" ON public.doctor_profiles;
CREATE POLICY "Allow update for all users"
  ON public.doctor_profiles FOR UPDATE
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete for all users" ON public.doctor_profiles;
CREATE POLICY "Allow delete for all users"
  ON public.doctor_profiles FOR DELETE
  USING (true);

-- 5. Enable Realtime Replication
ALTER TABLE public.doctor_profiles REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'doctor_profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.doctor_profiles;
  END IF;
END $$;

-- 6. Realistic Vietnamese Doctors Seed Data (Idempotent Upsert)
INSERT INTO public.doctor_profiles (
  id,
  full_name,
  title,
  specialty,
  hospital,
  phone_number,
  workplace_address,
  avatar_initials,
  avatar_color,
  avatar_url,
  rating,
  consultation_count,
  is_online,
  status_text,
  is_verified,
  experience_years,
  consultation_fee
) VALUES
(
  'doc_an_nguyen',
  'BS. CKI Nguyễn Văn An',
  'Bác sĩ Chuyên khoa I',
  'Ngoại Chấn thương & Xử trí Vết thương cấp',
  'Bệnh viện Đa khoa Trung ương',
  '0912345678',
  'Bệnh viện Chợ Rẫy, 201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
  'AN',
  '#1D4ED8',
  NULL,
  4.95,
  2180,
  true,
  'Đang trực tuyến • Sẵn sàng hỗ trợ sơ cứu',
  true,
  14,
  'Hỗ trợ sơ cấp cứu miễn phí'
),
(
  'doc_tran_thanh_nga',
  'ThS. BS Trần Thanh Nga',
  'Thạc sĩ Bác sĩ',
  'Bỏng - Tạo hình Thẩm mỹ & Phục hồi chức năng',
  'Bệnh viện Chợ Rẫy',
  '0987654321',
  'Bệnh viện Chợ Rẫy, 201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
  'TN',
  '#EC4899',
  NULL,
  4.90,
  1640,
  true,
  'Đang trực tuyến • Chuyên sâu bỏng & sẹo',
  true,
  11,
  '150.000đ / lượt tư vấn'
),
(
  'doc_le_hoang_nam',
  'BS. CKII Lê Hoàng Nam',
  'Bác sĩ Chuyên khoa II',
  'Cấp cứu Tim mạch & Can thiệp hồi sức',
  'Bệnh viện Đại học Y Dược TP.HCM',
  '0903123456',
  '215 Hồng Bàng, Phường 11, Quận 5, TP.HCM',
  'HN',
  '#059669',
  NULL,
  4.98,
  3120,
  false,
  'Ngoại tuyến • Tiếp nhận lại lúc 14:00',
  true,
  18,
  'Tư vấn sơ cứu miễn phí'
),
(
  'doc_pham_quynh_chi',
  'BS. Phạm Quỳnh Chi',
  'Bác sĩ Nội trú',
  'Da liễu & Nhiễm trùng ngoài da',
  'Bệnh viện Da Liễu TP.HCM',
  '0938987654',
  '02 Nguyễn Thông, Phường Võ Thị Sáu, Quận 3, TP.HCM',
  'QC',
  '#8B5CF6',
  NULL,
  4.88,
  980,
  true,
  'Đang trực tuyến • Phản hồi trong 5 phút',
  true,
  7,
  '100.000đ / lượt tư vấn'
),
(
  'doc_vu_minh_tri',
  'PGS. TS Vũ Minh Trí',
  'Phó Giáo sư, Tiến sĩ Bác sĩ',
  'Chấn thương Chỉnh hình & Cơ Xương Khớp',
  'Bệnh viện Chấn thương Chỉnh hình TP.HCM',
  '0918765432',
  '929 Trần Hưng Đạo, Phường 1, Quận 5, TP.HCM',
  'MT',
  '#D97706',
  NULL,
  4.99,
  4500,
  true,
  'Đang trực tuyến • Chuyên gia đầu ngành',
  true,
  25,
  'Tư vấn sơ cứu miễn phí'
)
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  title = EXCLUDED.title,
  specialty = EXCLUDED.specialty,
  hospital = EXCLUDED.hospital,
  phone_number = EXCLUDED.phone_number,
  workplace_address = EXCLUDED.workplace_address,
  avatar_initials = EXCLUDED.avatar_initials,
  avatar_color = EXCLUDED.avatar_color,
  avatar_url = EXCLUDED.avatar_url,
  rating = EXCLUDED.rating,
  consultation_count = EXCLUDED.consultation_count,
  is_online = EXCLUDED.is_online,
  status_text = EXCLUDED.status_text,
  is_verified = EXCLUDED.is_verified,
  experience_years = EXCLUDED.experience_years,
  consultation_fee = EXCLUDED.consultation_fee,
  updated_at = now();
