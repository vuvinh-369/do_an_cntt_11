-- ==============================================================================
-- Migration: 20261114_create_daily_health_care_tables.sql
-- Description: Hệ thống Chăm sóc sức khỏe hằng ngày (Daily Health Care & Handbook)
--              Bao gồm:
--              1. public.daily_care_lessons (Cẩm nang bài học chuẩn WHO, NHS, CDC)
--              2. public.user_health_profiles (Thể trạng, chỉ số BMI/BMR/TDEE & mục tiêu)
--              3. public.daily_health_logs (Nhật ký Calo, Nước, Giấc ngủ, Vận động thật)
--              4. public.daily_health_completed_lessons (Theo dõi bài học đã thực hành)
--              5. public.daily_health_admin_configs (Cấu hình định mức & trợ lý AI thích ứng)
-- ==============================================================================

BEGIN;

-- 1. BẢNG CẨM NANG BÀI HỌC Y KHOA (daily_care_lessons)
CREATE TABLE IF NOT EXISTS public.daily_care_lessons (
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

-- Tự động bổ sung các cột nếu bảng đã tồn tại từ trước (tránh lỗi 42703 column does not exist)
ALTER TABLE public.daily_care_lessons 
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_daily_care_lessons_frequency ON public.daily_care_lessons (frequency);
CREATE INDEX IF NOT EXISTS idx_daily_care_lessons_topic ON public.daily_care_lessons (topic);
CREATE INDEX IF NOT EXISTS idx_daily_care_lessons_is_published ON public.daily_care_lessons (is_published);
CREATE INDEX IF NOT EXISTS idx_daily_care_lessons_sort_order ON public.daily_care_lessons (sort_order);

-- 2. BẢNG HỒ SƠ THỂ TRẠNG & MỤC TIÊU SỨC KHỎE (user_health_profiles)
CREATE TABLE IF NOT EXISTS public.user_health_profiles (
    user_id TEXT PRIMARY KEY,
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

CREATE INDEX IF NOT EXISTS idx_user_health_profiles_goal ON public.user_health_profiles (health_goal);

-- 3. BẢNG NHẬT KÝ CHỈ SỐ HÀNG NGÀY THỰC TẾ (daily_health_logs)
-- Lưu ý: Mỗi người dùng có duy nhất 1 bản ghi cho 1 ngày (uq_daily_health_logs_user_date)
CREATE TABLE IF NOT EXISTS public.daily_health_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_daily_health_logs_user_date ON public.daily_health_logs (user_id, log_date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_health_logs_date ON public.daily_health_logs (log_date DESC);

-- 4. BẢNG THEO DÕI BÀI HỌC ĐÃ THỰC HÀNH (daily_health_completed_lessons)
CREATE TABLE IF NOT EXISTS public.daily_health_completed_lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    lesson_slug TEXT NOT NULL REFERENCES public.daily_care_lessons(slug) ON DELETE CASCADE,
    completed_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_daily_completed_lessons_user_date UNIQUE (user_id, lesson_slug, completed_date)
);

CREATE INDEX IF NOT EXISTS idx_completed_lessons_user_date ON public.daily_health_completed_lessons (user_id, completed_date DESC);

-- 5. BẢNG CẤU HÌNH THAM SỐ CHUẨN ADMIN (daily_health_admin_configs)
CREATE TABLE IF NOT EXISTS public.daily_health_admin_configs (
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
-- PHÂN QUYỀN ROW LEVEL SECURITY (RLS) & GRANTS
-- ==============================================================================

ALTER TABLE public.daily_care_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_health_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_health_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_health_completed_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_health_admin_configs ENABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE public.daily_care_lessons TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.user_health_profiles TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.daily_health_logs TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.daily_health_completed_lessons TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.daily_health_admin_configs TO anon, authenticated, service_role;

-- Policies: Cho phép đọc/ghi an toàn
DROP POLICY IF EXISTS "daily_care_lessons_policy" ON public.daily_care_lessons;
CREATE POLICY "daily_care_lessons_policy" ON public.daily_care_lessons FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "user_health_profiles_policy" ON public.user_health_profiles;
CREATE POLICY "user_health_profiles_policy" ON public.user_health_profiles FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "daily_health_logs_policy" ON public.daily_health_logs;
CREATE POLICY "daily_health_logs_policy" ON public.daily_health_logs FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "daily_health_completed_lessons_policy" ON public.daily_health_completed_lessons;
CREATE POLICY "daily_health_completed_lessons_policy" ON public.daily_health_completed_lessons FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "daily_health_admin_configs_policy" ON public.daily_health_admin_configs;
CREATE POLICY "daily_health_admin_configs_policy" ON public.daily_health_admin_configs FOR ALL USING (true) WITH CHECK (true);

-- ==============================================================================
-- DỮ LIỆU BAN ĐẦU: 9 BÀI HỌC CẨM NANG CHUẨN WHO / NHS / CDC & CẤU HÌNH ADMIN
-- ==============================================================================

INSERT INTO public.daily_care_lessons (
    slug, frequency, topic, title, summary, steps,
    source_name, source_url, sort_order, is_published
) VALUES
(
    'van-dong-buoi-sang', 'daily', 'movement', 'Vận động nhẹ buổi sáng',
    'Nếu mới bắt đầu, thử đi bộ vài phút rồi tăng dần theo sức của mình.',
    ARRAY[
        'Chọn đoạn đường bằng phẳng và bắt đầu bằng nhịp đi bộ thoải mái.',
        'Khi đã quen, bạn có thể đi lâu hơn hoặc đi nhanh hơn nếu thấy phù hợp.'
    ],
    'WHO – Hướng dẫn về vận động thể chất',
    'https://www.who.int/europe/publications/i/item/9789240014886',
    10, true
),
(
    'uong-nuoc-trong-ngay', 'daily', 'hydration', 'Uống nước đều trong ngày',
    'NHS dùng 6–8 cốc chất lỏng mỗi ngày làm mốc tham khảo chung.',
    ARRAY[
        'Để nước lọc trong tầm tay và uống rải đều trong ngày. Một số đồ uống khác như sữa hoặc trà không đường cũng được tính.',
        'Nhu cầu có thể tăng khi trời nóng hoặc vận động lâu. Nếu bác sĩ đã dặn hạn chế chất lỏng, hãy theo mức được hướng dẫn.'
    ],
    'NHS – Nước và bù đủ dịch',
    'https://www.nhs.uk/live-well/eat-well/food-guidelines-and-food-labels/water-drinks-nutrition/',
    20, true
),
(
    'bua-an-da-dang', 'daily', 'nutrition', 'Chọn bữa ăn đa dạng',
    'Thêm rau và kết hợp món giàu đạm với thực phẩm giàu tinh bột.',
    ARRAY[
        'Gợi ý bữa sáng: yến mạch, sữa chua không đường và trái cây nguyên quả.',
        'Gợi ý bữa chính: cơm gạo lứt, cá hoặc đậu phụ, và một món rau.'
    ],
    'NHS – Ăn uống cân bằng',
    'https://www.nhs.uk/live-well/eat-well/how-to-eat-a-balanced-diet/eating-a-balanced-diet/',
    30, true
),
(
    'gio-ngu-deu-dan', 'daily', 'sleep', 'Giữ giờ ngủ đều đặn',
    'Chọn giờ đi ngủ và thức dậy có thể duy trì mỗi ngày.',
    ARRAY[
        'Giữ giờ thức dậy tương đối ổn định, kể cả cuối tuần.',
        'Tắt thiết bị điện tử ít nhất 30 phút trước khi ngủ. CDC khuyến nghị người từ 18–60 tuổi ngủ ít nhất 7 giờ mỗi ngày.'
    ],
    'CDC – Giấc ngủ',
    'https://www.cdc.gov/sleep/about/index.html',
    40, true
),
(
    'giam-ngoi-tinh-tai', 'daily', 'movement', 'Ngắt quãng thời gian ngồi tĩnh tại',
    'WHO khuyến cáo đứng dậy và vươn vai sau mỗi 45–60 phút làm việc liên tục.',
    ARRAY[
        'Đặt lời nhắc đứng dậy đi lại nhẹ nhàng hoặc leo cầu thang 2–3 phút.',
        'Thực hiện các động tác xoay cổ vai gáy và kéo giãn cột sống đơn giản tại chỗ.'
    ],
    'WHO – Hạn chế hành vi ngồi tĩnh tại',
    'https://www.who.int/news-room/fact-sheets/detail/physical-activity',
    50, true
),
(
    'kiem-soat-duong-muoi', 'daily', 'nutrition', 'Kiểm soát muối và đường bổ sung',
    'Giảm tiêu thụ muối dưới 5g/ngày và hạn chế đồ uống có đường tinh luyện.',
    ARRAY[
        'Ưu tiên nêm nếm bằng thảo mộc, hạt tiêu và chanh thay vì dùng quá nhiều nước mắm mặn.',
        'Uống nước lọc hoặc trà thảo mộc thay vì nước ngọt có gas và trà sữa đóng chai.'
    ],
    'WHO – Hướng dẫn giảm muối và đường',
    'https://www.who.int/news-room/fact-sheets/detail/healthy-diet',
    60, true
),
(
    'lap-lich-van-dong-tuan', 'weekly', 'movement', 'Lên lịch vận động trong tuần',
    'Chia thời gian vận động thành các buổi phù hợp với lịch sinh hoạt.',
    ARRAY[
        'Với người trưởng thành, WHO khuyến nghị 150–300 phút vận động aerobic mức vừa mỗi tuần. Khi mới bắt đầu, chọn mức vừa sức và tăng dần.',
        'Ví dụ khi đã quen: đi bộ nhanh 30 phút trong 5 ngày. Có thể bố trí thêm 2 ngày tập tăng sức mạnh cho các nhóm cơ lớn.'
    ],
    'WHO – Khuyến nghị vận động thể chất',
    'https://www.who.int/europe/news-room/fact-sheets/item/physical-activity',
    10, true
),
(
    'chuan-bi-thuc-don-tuan', 'weekly', 'nutrition', 'Chuẩn bị thực đơn cho tuần',
    'Chọn trước vài món có thể nấu và viết danh sách mua thực phẩm.',
    ARRAY[
        'Chọn rau và trái cây theo mùa để đổi món trong tuần.',
        'Luân phiên đậu, trứng, cá hoặc thịt nạc tùy sở thích và nhu cầu ăn uống.'
    ],
    'NHS – Ăn uống cân bằng',
    'https://www.nhs.uk/live-well/eat-well/how-to-eat-a-balanced-diet/eating-a-balanced-diet/',
    20, true
),
(
    'danh-gia-chat-luong-ngu-tuan', 'weekly', 'sleep', 'Đánh giá & cân bằng giấc ngủ tuần',
    'Xem lại số giờ ngủ trung bình trong tuần và điều chỉnh nợ ngủ an toàn.',
    ARRAY[
        'Kiểm tra xem bạn có bị thiếu ngủ dồn dập vào các ngày trong tuần hay không.',
        'Tránh ngủ nướng bù quá 2 giờ vào cuối tuần để không phá vỡ nhịp sinh học tự nhiên.'
    ],
    'CDC – Thói quen ngủ lành mạnh',
    'https://www.cdc.gov/sleep/about/index.html',
    30, true
)
ON CONFLICT (slug) DO UPDATE SET
    frequency = EXCLUDED.frequency,
    topic = EXCLUDED.topic,
    title = EXCLUDED.title,
    summary = EXCLUDED.summary,
    steps = EXCLUDED.steps,
    source_name = EXCLUDED.source_name,
    source_url = EXCLUDED.source_url,
    sort_order = EXCLUDED.sort_order,
    is_published = EXCLUDED.is_published,
    updated_at = now();

-- 6. Khởi tạo cấu hình Admin mặc định
INSERT INTO public.daily_health_admin_configs (
    id, default_water_multiplier_ml_per_kg, default_daily_exercise_min,
    default_sleep_standard_hours, weight_loss_deficit_kcal, muscle_gain_surplus_kcal,
    auto_adaptive_adjustment_enabled, system_health_notice
) VALUES (
    'default_config', 35, 30, 7.5, 400, 300, true,
    'Hệ thống khuyến nghị tuân thủ tiêu chuẩn WHO & Viện Dinh Dưỡng Quốc Gia.'
)
ON CONFLICT (id) DO NOTHING;

COMMIT;
