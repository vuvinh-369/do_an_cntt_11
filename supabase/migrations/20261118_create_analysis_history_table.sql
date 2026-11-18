-- Migration: 20261118_create_analysis_history_table.sql
-- Description: Create analysis_history table for AI scan history synchronization with RLS and initial seeds

CREATE TABLE IF NOT EXISTS public.analysis_history (
    id TEXT PRIMARY KEY DEFAULT ('hist_' || floor(extract(epoch from now()) * 1000)::text),
    username TEXT,
    injury_type_id TEXT NOT NULL DEFAULT 'abrasion',
    injury_type_name TEXT NOT NULL,
    confidence_score NUMERIC NOT NULL DEFAULT 80.0,
    severity_level TEXT NOT NULL DEFAULT 'moderate',
    location_label TEXT DEFAULT 'Chưa xác định',
    image_url TEXT,
    symptoms TEXT[] DEFAULT '{}',
    pain_level INTEGER DEFAULT 0,
    first_aid_summary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS injury_type_id TEXT NOT NULL DEFAULT 'abrasion';
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS injury_type_name TEXT NOT NULL DEFAULT 'Trầy xước ngoài da';
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS confidence_score NUMERIC NOT NULL DEFAULT 80.0;
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS severity_level TEXT NOT NULL DEFAULT 'moderate';
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS location_label TEXT DEFAULT 'Chưa xác định';
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS symptoms TEXT[] DEFAULT '{}';
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS pain_level INTEGER DEFAULT 0;
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS first_aid_summary TEXT;
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.analysis_history ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_analysis_history_created_at ON public.analysis_history (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analysis_history_username ON public.analysis_history (username);
CREATE INDEX IF NOT EXISTS idx_analysis_history_injury_type_id ON public.analysis_history (injury_type_id);
CREATE INDEX IF NOT EXISTS idx_analysis_history_severity_level ON public.analysis_history (severity_level);

ALTER TABLE public.analysis_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Cho phép đọc toàn bộ lịch sử phân tích" ON public.analysis_history;
CREATE POLICY "Cho phép đọc toàn bộ lịch sử phân tích"
    ON public.analysis_history FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Cho phép thêm lịch sử phân tích" ON public.analysis_history;
CREATE POLICY "Cho phép thêm lịch sử phân tích"
    ON public.analysis_history FOR INSERT
    WITH CHECK (true);

DROP POLICY IF EXISTS "Cho phép cập nhật lịch sử phân tích" ON public.analysis_history;
CREATE POLICY "Cho phép cập nhật lịch sử phân tích"
    ON public.analysis_history FOR UPDATE
    USING (true);

DROP POLICY IF EXISTS "Cho phép xóa lịch sử phân tích" ON public.analysis_history;
CREATE POLICY "Cho phép xóa lịch sử phân tích"
    ON public.analysis_history FOR DELETE
    USING (true);

GRANT ALL ON public.analysis_history TO anon, authenticated, service_role;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.analysis_history LIMIT 1) THEN
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
            now() - INTERVAL '35 minutes',
            now() - INTERVAL '35 minutes'
        ),
        (
            'hist_seed_002',
            'benhnhan_01',
            'cut_laceration',
            'Vết cắt / rách da',
            88.0,
            'severe',
            'Ngón tay trỏ trái',
            'assets/images/sample_cut.jpg',
            ARRAY['Chảy máu nhiều', 'Vết rách sâu quá 0.5cm', 'Vết cắt kim loại sắc'],
            7,
            'Ấn ép trực tiếp gạc vô trùng cầm máu khẩn cấp, nâng cao chi tổn thương và khẩn trương đến viện khâu vết thương.',
            now() - INTERVAL '3 hours',
            now() - INTERVAL '3 hours'
        ),
        (
            'hist_seed_003',
            'benhnhan_02',
            'burn',
            'Bỏng nhiệt',
            85.0,
            'moderate',
            'Mu bàn tay phải',
            'assets/images/sample_burn.jpg',
            ARRAY['Da đỏ rát', 'Phồng rộp bọng nước', 'Bỏng nước sôi diện tích nhỏ'],
            5,
            'Xả nước mát sạch (15-25°C) liên tục trong 15-20 phút. Tuyệt đối không chườm đá lạnh buốt hay chọc vỡ bọng nước.',
            now() - INTERVAL '8 hours',
            now() - INTERVAL '8 hours'
        ),
        (
            'hist_seed_004',
            NULL,
            'bruise',
            'Bầm tím phần mềm',
            79.5,
            'mild',
            'Đầu gối trái',
            'assets/images/sample_bruise.jpg',
            ARRAY['Tụ máu dưới da', 'Đổi màu xanh tím', 'Đau khi ấn vào'],
            3,
            'Chườm lạnh gián tiếp qua khăn sạch 15 phút để co mạch giảm phù nề, nghỉ ngơi vùng va đập.',
            now() - INTERVAL '1 day',
            now() - INTERVAL '1 day'
        );
    END IF;
END $$;
