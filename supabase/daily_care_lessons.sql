-- Supabase SQL Editor. Chạy lại giữ nguyên các bài có cùng slug.
begin;

create table if not exists public.daily_care_lessons (
    slug text primary key check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    frequency text not null check (frequency in ('daily', 'weekly')),
    topic text not null check (topic in ('movement', 'hydration', 'nutrition', 'sleep')),
    title text not null check (btrim(title) <> ''),
    summary text not null check (btrim(summary) <> ''),
    steps text[] not null check (
        cardinality(steps) > 0
        and array_ndims(steps) = 1
        and array_position(steps, null) is null
    ),
    source_name text not null check (btrim(source_name) <> ''),
    source_url text not null check (source_url ~ '^https://[^[:space:]]+$'),
    sort_order integer not null default 0 check (sort_order >= 0),
    is_published boolean not null default false
);

alter table public.daily_care_lessons enable row level security;
revoke all on table public.daily_care_lessons from public, anon, authenticated;
grant select on table public.daily_care_lessons to anon, authenticated;

drop policy if exists "Read published daily care lessons" on public.daily_care_lessons;
create policy "Read published daily care lessons"
    on public.daily_care_lessons
    for select to anon, authenticated
    using (is_published);

insert into public.daily_care_lessons (
    slug, frequency, topic, title, summary, steps,
    source_name, source_url, sort_order, is_published
) values
(
    'van-dong-buoi-sang', 'daily', 'movement', 'Vận động nhẹ buổi sáng',
    'Nếu mới bắt đầu, thử đi bộ vài phút rồi tăng dần theo sức của mình.',
    array[
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
    array[
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
    array[
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
    array[
        'Giữ giờ thức dậy tương đối ổn định, kể cả cuối tuần.',
        'Tắt thiết bị điện tử ít nhất 30 phút trước khi ngủ. CDC khuyến nghị người từ 18–60 tuổi ngủ ít nhất 7 giờ mỗi ngày.'
    ],
    'CDC – Giấc ngủ',
    'https://www.cdc.gov/sleep/about/index.html',
    40, true
),
(
    'lap-lich-van-dong-tuan', 'weekly', 'movement', 'Lên lịch vận động trong tuần',
    'Chia thời gian vận động thành các buổi phù hợp với lịch sinh hoạt.',
    array[
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
    array[
        'Chọn rau và trái cây theo mùa để đổi món trong tuần.',
        'Luân phiên đậu, trứng, cá hoặc thịt nạc tùy sở thích và nhu cầu ăn uống.'
    ],
    'NHS – Ăn uống cân bằng',
    'https://www.nhs.uk/live-well/eat-well/how-to-eat-a-balanced-diet/eating-a-balanced-diet/',
    20, true
),
(
    'sap-xep-thoi-gian-nghi-ngoi', 'weekly', 'sleep', 'Dành thời gian nghỉ ngơi',
    'Chừa một khoảng nghỉ trong tuần cho hoạt động bạn thấy thư giãn.',
    array[
        'Chọn một khoảng thời gian phù hợp để đọc sách, gặp người thân hoặc làm việc mình thích.',
        'Cuối tuần, xem khung giờ nào dễ duy trì và đặt trước thời gian nghỉ cho tuần sau.'
    ],
    'Vinmec – Thói quen có lợi cho sức khỏe',
    'https://www.vinmec.com/vie/bai-viet/15-thoi-quen-co-loi-cho-suc-khoe-cua-minh-moi-ngay-vi',
    30, true
)
on conflict (slug) do nothing;

commit;
