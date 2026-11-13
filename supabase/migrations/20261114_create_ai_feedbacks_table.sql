-- ==============================================================================
-- Migration: 20261114_create_ai_feedbacks_table.sql
-- Description: Bảng lưu trữ phản hồi & đánh giá kết quả AI từ người dùng (ai_feedbacks)
-- ==============================================================================

BEGIN;

-- 1. Xóa bảng cũ nếu bị lệch cấu trúc để khởi tạo lại chuẩn 100%
DROP TABLE IF EXISTS public.ai_feedbacks CASCADE;

-- 2. BẢNG PHẢN HỒI & ĐÁNH GIÁ AI TỪ NGƯỜI DÙNG (ai_feedbacks)
CREATE TABLE public.ai_feedbacks (
    id TEXT PRIMARY KEY,
    analysis_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
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
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. TẠO CHỈ MỤC TÌM KIẾM NHANH (INDEXES)
CREATE INDEX idx_ai_feedbacks_created_at ON public.ai_feedbacks (created_at DESC);
CREATE INDEX idx_ai_feedbacks_feedback_type ON public.ai_feedbacks (feedback_type);
CREATE INDEX idx_ai_feedbacks_source_model ON public.ai_feedbacks (source_model);

-- 4. PHÂN QUYỀN ROW LEVEL SECURITY (RLS) & GRANTS
ALTER TABLE public.ai_feedbacks ENABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE public.ai_feedbacks TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "ai_feedbacks_policy" ON public.ai_feedbacks;
CREATE POLICY "ai_feedbacks_policy" ON public.ai_feedbacks FOR ALL USING (true) WITH CHECK (true);

COMMIT;
