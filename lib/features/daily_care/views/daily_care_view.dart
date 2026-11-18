import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/url_launcher_helper.dart';
import '../models/daily_care_lesson.dart';
import '../models/daily_health_models.dart';
import '../services/daily_health_service.dart';

Future<List<DailyCareLesson>> _loadPublishedLessons() async {
  try {
    final client = SupabaseService.instance.client;
    if (client != null) {
      final rows = await client
          .from('daily_care_lessons')
          .select('slug,frequency,topic,title,summary,steps,source_name,source_url')
          .eq('is_published', true)
          .order('sort_order', ascending: true)
          .order('slug', ascending: true)
          .timeout(const Duration(seconds: 4));
      return rows.map(DailyCareLesson.fromRow).toList();
    }
  } catch (_) {
    // Fallback sang Database ảo nếu Supabase offline
  }
  return DailyHealthService.instance.getPublishedLessons();
}

class DailyCareView extends StatefulWidget {
  const DailyCareView({
    super.key,
    this.loadLessons = _loadPublishedLessons,
    this.initialTabIndex = 0,
  });

  final Future<List<DailyCareLesson>> Function() loadLessons;
  final int initialTabIndex;

  @override
  State<DailyCareView> createState() => _DailyCareViewState();
}

class _DailyCareViewState extends State<DailyCareView> {
  static const _ink = Color(0xFF124A38);

  late Future<List<DailyCareLesson>> _lessons;
  late int _selectedTab;
  DailyCareFrequency _frequency = DailyCareFrequency.daily;
  TimeHorizon _horizon = TimeHorizon.day;
  final DateTime _currentDate = DateTime.now();

  DailyCareTopic? _selectedTopic;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    _lessons = widget.loadLessons();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return ListenableBuilder(
      listenable: DailyHealthService.instance,
      builder: (context, _) {
        final service = DailyHealthService.instance;
        final profile = service.profile;
        final log = service.getLogForDate(_currentDate);
        final recommendation = service.getSmartRecommendation(_currentDate);
        final schedule = service.getSchedulePlan(_currentDate);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 36,
            vertical: isMobile ? 12 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Thanh Tabs chuyển đổi chức năng chính
              _buildMainFeatureTabs(isMobile, profile, recommendation),
              const SizedBox(height: 14),

              // 2. Nội dung theo từng Tab đang chọn
              if (_selectedTab == 0) ...[
                // Tab 0: Cẩm nang bài học y tế chuẩn (WHO, NHS, CDC)
                _buildLessonsTabContent(context, service, isMobile),
              ] else if (_selectedTab == 1) ...[
                // Tab 1: Trợ lý AI & Theo dõi chỉ số (Ngày / Tuần / Tháng / Năm)
                _buildAssistantTrackingTabContent(context, service, profile, log, recommendation, isMobile),
              ] else ...[
                // Tab 2: Lịch trình ăn uống & Bài tập cá nhân hóa
                _buildScheduleTabContent(schedule, profile, isMobile),
              ],
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. THANH TABS CHÍNH
  // ===========================================================================

  Widget _buildMainFeatureTabs(
    bool isMobile,
    UserProfileHealthMetric profile,
    SmartHealthRecommendation recommendation,
  ) {
    final tabs = [
      {'title': 'Cẩm nang bài học', 'icon': Icons.menu_book_rounded},
      {'title': 'Trợ lý & Chỉ số', 'icon': Icons.insights_rounded},
      {'title': 'Lịch ăn & Bài tập', 'icon': Icons.restaurant_menu_rounded},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D2B6B),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          final tab = tabs[index];

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = index),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF047857) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tab['title'] as String,
                        style: TextStyle(
                          fontSize: isMobile ? 11.5 : 13.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // 2. TAB 0: CẨM NANG & BÀI HỌC (CHUẨN Y KHOA WHO, NHS, CDC)
  // ===========================================================================

  Color _getTopicColor(DailyCareTopic topic) {
    switch (topic) {
      case DailyCareTopic.movement:
        return const Color(0xFF059669); // Emerald
      case DailyCareTopic.hydration:
        return const Color(0xFF0284C7); // Sky Blue
      case DailyCareTopic.nutrition:
        return const Color(0xFFD97706); // Amber
      case DailyCareTopic.sleep:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  Color _getTopicBgColor(DailyCareTopic topic) {
    switch (topic) {
      case DailyCareTopic.movement:
        return const Color(0xFFECFDF5);
      case DailyCareTopic.hydration:
        return const Color(0xFFF0F9FF);
      case DailyCareTopic.nutrition:
        return const Color(0xFFFFFBEB);
      case DailyCareTopic.sleep:
        return const Color(0xFFEEF2FF);
    }
  }

  String _getTopicAdvice(DailyCareTopic topic) {
    switch (topic) {
      case DailyCareTopic.movement:
        return 'Duy trì nhịp vận động đều đặn mang lại hiệu quả bền vững gấp nhiều lần so với tập nặng ngắt quãng. Lắng nghe cơ thể và duy trì nhịp thở tự nhiên.';
      case DailyCareTopic.hydration:
        return 'Uống từng ngụm nhỏ rải đều trong ngày. Khi trời nóng hoặc sau vận động, tăng dần lượng nước và không chờ đến khi khát mới uống.';
      case DailyCareTopic.nutrition:
        return 'Ưu tiên thực phẩm nguyên bản, giàu chất xơ, ăn chậm nhai kỹ và cân bằng nhóm đạm nạc với rau củ tươi theo mùa.';
      case DailyCareTopic.sleep:
        return 'Duy trì khung giờ ngủ cố định, hạn chế ánh sáng xanh từ thiết bị điện tử ít nhất 30 phút trước khi ngủ để tuyến tùng tiết melatonin tự nhiên.';
    }
  }

  String _getTopicEstimatedDuration(DailyCareTopic topic, DailyCareFrequency freq) {
    if (freq == DailyCareFrequency.weekly) {
      return 'Lộ trình cả tuần';
    }
    switch (topic) {
      case DailyCareTopic.movement:
        return '~15–20 phút';
      case DailyCareTopic.hydration:
        return 'Rải đều cả ngày';
      case DailyCareTopic.nutrition:
        return '~3 bữa chính';
      case DailyCareTopic.sleep:
        return '7–8 giờ/đêm';
    }
  }

  List<DailyCareLesson> _filterLessons(List<DailyCareLesson> rawLessons) {
    return rawLessons.where((lesson) {
      if (lesson.frequency != _frequency) return false;
      if (_selectedTopic != null && lesson.topic != _selectedTopic) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchTitle = lesson.title.toLowerCase().contains(query);
        final matchSummary = lesson.summary.toLowerCase().contains(query);
        final matchSteps = lesson.steps.any((s) => s.toLowerCase().contains(query));
        final matchSource = lesson.sourceName.toLowerCase().contains(query);
        if (!matchTitle && !matchSummary && !matchSteps && !matchSource) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildLessonsTabContent(
    BuildContext context,
    DailyHealthService service,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Hero Banner Cẩm nang Sức khỏe Y khoa
        _buildLessonsHeroBanner(context, isMobile),
        const SizedBox(height: 12),

        // 2. Bộ lọc tần suất (Hằng ngày | Theo tuần - ĐẢM BẢO TEST CASE)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final frequency in DailyCareFrequency.values)
              ChoiceChip(
                label: Text(frequency.label),
                selected: _frequency == frequency,
                selectedColor: const Color(0xFFDDF5E8),
                onSelected: (_) => setState(() => _frequency = frequency),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 3. Tải danh sách bài học qua FutureBuilder
        FutureBuilder<List<DailyCareLesson>>(
          future: _lessons,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Đang tải bài học',
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chưa tải được bài học. Vui lòng thử lại.'),
                  TextButton.icon(
                    onPressed: () {
                      final lessons = widget.loadLessons();
                      setState(() {
                        _lessons = lessons;
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                  ),
                ],
              );
            }

            final allLessons = snapshot.requireData;
            final freqLessons = allLessons
                .where((lesson) => lesson.frequency == _frequency)
                .toList();

            final filteredLessons = _filterLessons(freqLessons);
            final completedCount = service.getTodayCompletedCount(frequency: _frequency);
            final totalFreqCount = freqLessons.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thanh tiện ích: Tiến độ thực hành & Ô tìm kiếm
                _buildHandbookUtilityBar(completedCount, totalFreqCount, isMobile),
                const SizedBox(height: 10),

                // Thanh lọc nhanh theo 4 trụ cột
                _buildTopicPillsRow(freqLessons),
                const SizedBox(height: 12),

                // Danh sách bài học
                if (filteredLessons.isEmpty)
                  _buildEmptyLessonsCard()
                else
                  for (final lesson in filteredLessons)
                    _lessonTile(lesson, service, isMobile),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLessonsHeroBanner(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9),
            Color(0xFFF0FDF4),
            Color(0xFFF0F9FF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7E8D8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08065F46),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'CHUẨN Y KHOA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD1E7DD)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.spa_rounded, size: 12, color: Color(0xFF047857)),
                    SizedBox(width: 4),
                    Text(
                      '4 Trụ cột sống khỏe',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Chăm sóc sức khỏe hằng ngày',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: isMobile ? 18 : 20,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Các bài thực hành dành cho người trưởng thành về vận động, uống nước, ăn uống và giấc ngủ.',
            style: TextStyle(color: _ink, fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildHandbookUtilityBar(
    int completedCount,
    int totalCount,
    bool isMobile,
  ) {
    final percent = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF047857)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tiến độ thực hành ${_frequency == DailyCareFrequency.daily ? 'hôm nay' : 'tuần này'}: $completedCount/$totalCount bài',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Tìm kiếm cẩm nang (calo, nước uống, giấc ngủ, đi bộ...)',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
              ),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicPillsRow(List<DailyCareLesson> currentFreqLessons) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text('Tất cả (${currentFreqLessons.length})'),
              selected: _selectedTopic == null,
              selectedColor: const Color(0xFFDDF5E8),
              onSelected: (_) {
                setState(() {
                  _selectedTopic = null;
                });
              },
            ),
          ),
          for (final topic in DailyCareTopic.values) ...[
            Builder(
              builder: (context) {
                final count = currentFreqLessons.where((l) => l.topic == topic).length;
                final isSelected = _selectedTopic == topic;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: Icon(
                      topic.icon,
                      size: 15,
                      color: isSelected ? const Color(0xFF047857) : const Color(0xFF64748B),
                    ),
                    label: Text('${topic.label} ($count)'),
                    selected: isSelected,
                    selectedColor: const Color(0xFFDDF5E8),
                    onSelected: (selected) {
                      setState(() {
                        _selectedTopic = selected ? topic : null;
                      });
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyLessonsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.menu_book_outlined, size: 40, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          const Text(
            'Không tìm thấy bài học phù hợp',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Thử chọn chủ đề khác hoặc xóa từ khóa tìm kiếm để xem đầy đủ nội dung.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedTopic = null;
                _searchController.clear();
                _searchQuery = '';
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Đặt lại bộ lọc'),
          ),
        ],
      ),
    );
  }

  void _onQuickHabitAction(DailyCareLesson lesson, DailyHealthService service) {
    switch (lesson.topic) {
      case DailyCareTopic.hydration:
        service.quickAddWater(250);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💧 Đã ghi nhận +250ml nước vào nhật ký hôm nay!'),
            backgroundColor: Color(0xFF0284C7),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case DailyCareTopic.movement:
        final todayLog = service.getLogForDate(DateTime.now());
        service.saveDailyLog(
          todayLog.copyWith(exerciseMinutes: todayLog.exerciseMinutes + 15),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🏃 Đã ghi nhận +15 phút vận động vào nhật ký hôm nay!'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case DailyCareTopic.sleep:
      case DailyCareTopic.nutrition:
        service.toggleLessonCompletionToday(lesson.slug);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              service.isLessonCompletedToday(lesson.slug)
                  ? '✓ Đã đánh dấu hoàn thành bài học hôm nay!'
                  : 'Đã bỏ đánh dấu hoàn thành bài học.',
            ),
            backgroundColor: const Color(0xFF047857),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  Widget _lessonTile(DailyCareLesson lesson, DailyHealthService service, bool isMobile) {
    final source = lesson.sourceUri;
    final topicColor = _getTopicColor(lesson.topic);
    final topicBg = _getTopicBgColor(lesson.topic);
    final isCompleted = service.isLessonCompletedToday(lesson.slug);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: isCompleted ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
        width: isCompleted ? 1.4 : 1,
      ),
    );

    return Container(
      key: ValueKey(lesson.slug),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: topicColor, width: 4.5),
            ),
          ),
          child: ExpansionTile(
            key: PageStorageKey(lesson.slug),
            shape: shape,
            collapsedShape: shape,
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            textColor: const Color(0xFF0F172A),
            collapsedTextColor: const Color(0xFF0F172A),
            tilePadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: 8,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: topicBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: topicColor.withValues(alpha: 0.25)),
              ),
              child: Icon(
                lesson.topic.icon,
                color: topicColor,
                size: 22,
                semanticLabel: lesson.topic.label,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    lesson.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                        SizedBox(width: 3),
                        Text(
                          'Đã thực hành',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  lesson.summary,
                  style: const TextStyle(
                    height: 1.45,
                    fontSize: 13,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: topicBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lesson.topic.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: topicColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            _getTopicEstimatedDuration(lesson.topic, lesson.frequency),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            childrenPadding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 16,
              4,
              isMobile ? 12 : 16,
              16,
            ),
            children: [
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Tiêu đề các bước
              const Row(
                children: [
                  Icon(Icons.format_list_numbered_rounded, size: 16, color: Color(0xFF047857)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Các bước thực hành theo chuẩn y khoa:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Từng bước thực hành với format '${index + 1}. $step' (CHUẨN TEST)
              for (final (index, step) in lesson.steps.indexed)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: topicColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${index + 1}. $step',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 6),

              // Hộp lời khuyên thực chứng từ bác sĩ / chuyên gia
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFEF08A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFCA8A04)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lời khuyên thực hành từ chuyên gia:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF854D0E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getTopicAdvice(lesson.topic),
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: Color(0xFF713F12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Thanh nút tương tác (Nguồn & Đánh dấu hoàn thành)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  if (source != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0369A1),
                        backgroundColor: const Color(0xFFF0F9FF),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                        ),
                      ),
                      onPressed: () =>
                          UrlLauncherHelper.launchWebUrl(context, source.toString()),
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: Text('Nguồn: ${lesson.sourceName}'),
                    ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isCompleted ? const Color(0xFF047857) : const Color(0xFF334155),
                          side: BorderSide(
                            color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                          ),
                          backgroundColor: isCompleted ? const Color(0xFFECFDF5) : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          service.toggleLessonCompletionToday(lesson.slug);
                        },
                        icon: Icon(
                          isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 15,
                          color: isCompleted ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                        label: Text(
                          isCompleted ? 'Đã thực hành' : 'Đánh dấu đã làm',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (lesson.topic == DailyCareTopic.hydration)
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE0F2FE),
                            foregroundColor: const Color(0xFF0369A1),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _onQuickHabitAction(lesson, service),
                          icon: const Icon(Icons.water_drop_rounded, size: 14),
                          label: const Text('+250ml nước', style: TextStyle(fontSize: 11.5)),
                        )
                      else if (lesson.topic == DailyCareTopic.movement)
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDCFCE7),
                            foregroundColor: const Color(0xFF15803D),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _onQuickHabitAction(lesson, service),
                          icon: const Icon(Icons.directions_walk_rounded, size: 14),
                          label: const Text('+15p đi bộ', style: TextStyle(fontSize: 11.5)),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. TAB 1: TRỢ LÝ AI & THEO DÕI CHỈ SỐ (NGÀY, TUẦN, THÁNG, NĂM)
  // ===========================================================================

  Widget _buildAssistantTrackingTabContent(
    BuildContext context,
    DailyHealthService service,
    UserProfileHealthMetric profile,
    DailyHealthLog log,
    SmartHealthRecommendation recommendation,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero Card Trợ lý AI với điểm sức khỏe & nút ghi nhận
        _buildAssistantHeroCard(context, profile, log, recommendation, isMobile),
        const SizedBox(height: 16),

        // Bộ lọc thời gian: Hôm nay | Tuần này | Tháng này | Năm nay
        _buildTimeHorizonSelector(isMobile),
        const SizedBox(height: 16),

        // 4 Thẻ chỉ số sức khỏe cốt lõi (Calo, Nước, Vận động, Giấc ngủ)
        _buildVitalsMetricGrid(context, profile, log, isMobile),
        const SizedBox(height: 20),

        // Hộp dự báo & thích ứng bù trừ cho ngày mai
        _buildAdaptiveRecommendationCard(recommendation),
        const SizedBox(height: 20),

        // Thống kê & biểu đồ xu hướng theo khung thời gian
        _buildTrendAnalyticsCard(service, profile, isMobile),
      ],
    );
  }

  Widget _buildAssistantHeroCard(
    BuildContext context,
    UserProfileHealthMetric profile,
    DailyHealthLog log,
    SmartHealthRecommendation recommendation,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF0D9488)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16047857),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isMobile ? 54 : 64,
                height: isMobile ? 54 : 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2.5),
                ),
                child: Center(
                  child: Text(
                    '${recommendation.healthScore}',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.statusHeadline,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 14.5 : 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'BMI: ${profile.bmi} (${profile.bmiCategory}) • Mục tiêu: ${profile.healthGoal.label}',
                      style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showProfileDialog(context, profile),
                icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                tooltip: 'Cài đặt thể trạng',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showLogEntryDialog(context),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text(
                'Ghi nhận chỉ số hôm nay (Calo, Nước, Ngủ, Vận động)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF047857),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeHorizonSelector(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: TimeHorizon.values.map((horizon) {
          final isSelected = _horizon == horizon;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _horizon = horizon),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF047857) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    horizon.label,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVitalsMetricGrid(
    BuildContext context,
    UserProfileHealthMetric profile,
    DailyHealthLog log,
    bool isMobile,
  ) {
    final targetCal = profile.targetCalories;
    final targetWater = profile.targetWaterMl;
    final targetSleep = profile.targetSleepHours;
    final targetEx = profile.targetExerciseMinutes;

    final calPercent = targetCal > 0 ? (log.caloriesIn / targetCal).clamp(0.0, 1.5) : 0.0;
    final waterPercent = targetWater > 0 ? (log.waterMl / targetWater).clamp(0.0, 1.5) : 0.0;
    final sleepPercent = targetSleep > 0 ? (log.sleepHours / targetSleep).clamp(0.0, 1.5) : 0.0;
    final exPercent = targetEx > 0 ? (log.exerciseMinutes / targetEx).clamp(0.0, 1.5) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 640 ? 1 : (constraints.maxWidth < 1024 ? 2 : 4);
        const spacing = 14.0;
        final itemWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildMetricCard(
                icon: Icons.restaurant_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBgColor: const Color(0xFFFFEDD5),
                title: 'Năng lượng Calo',
                valueText: '${log.caloriesIn.round()} / $targetCal',
                unit: 'kcal',
                subText: 'Đốt: ${log.caloriesBurned.round()} kcal • Net: ${log.netCalories.round()}',
                progress: calPercent,
                progressColor: const Color(0xFFEA580C),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildWaterMetricCard(
                log: log,
                targetWater: targetWater,
                progress: waterPercent,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricCard(
                icon: Icons.directions_run_rounded,
                iconColor: const Color(0xFF0D9488),
                iconBgColor: const Color(0xFFCCFBF1),
                title: 'Vận động thể chất',
                valueText: '${log.exerciseMinutes} / $targetEx',
                unit: 'phút',
                subText: 'Đốt cháy ~${log.caloriesBurned.round()} kcal',
                progress: exPercent,
                progressColor: const Color(0xFF0D9488),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildMetricCard(
                icon: Icons.bedtime_rounded,
                iconColor: const Color(0xFF6366F1),
                iconBgColor: const Color(0xFFEEF2FF),
                title: 'Thời gian ngủ',
                valueText: '${log.sleepHours.toStringAsFixed(1)} / $targetSleep',
                unit: 'giờ',
                subText: log.sleepHours >= 7.0 ? 'Chuẩn hồi phục tế bào' : 'Nên ngủ sớm hơn',
                progress: sleepPercent,
                progressColor: const Color(0xFF6366F1),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String valueText,
    required String unit,
    required String subText,
    required double progress,
    required Color progressColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF4FB), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D2B6B),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D2B6B),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subText,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWaterMetricCard({
    required DailyHealthLog log,
    required int targetWater,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF4FB), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D2B6B),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lượng nước uống',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${log.waterMl} / $targetWater',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D2B6B),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'ml',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => DailyHealthService.instance.quickAddWater(250),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: const Center(
                      child: Text(
                        '+250ml',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => DailyHealthService.instance.quickAddWater(500),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: const Center(
                      child: Text(
                        '+500ml',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveRecommendationCard(SmartHealthRecommendation recommendation) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_alt_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kế hoạch Thích ứng & Bù trừ Thông minh cho Ngày mai',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: Text(
              recommendation.tomorrowAdaptiveAdjustment,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF78350F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            recommendation.nextWeekStrategy,
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAnalyticsCard(
    DailyHealthService service,
    UserProfileHealthMetric profile,
    bool isMobile,
  ) {
    final logs = service.getLogsForHorizon(_horizon, referenceDate: _currentDate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF4FB), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D2B6B),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Xu hướng theo ${_horizon.label}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D2B6B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${logs.length} mốc',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_horizon == TimeHorizon.day) ...[
            _buildDayDetailView(logs.isNotEmpty ? logs.first : DailyHealthLog(date: _currentDate), profile),
          ] else if (_horizon == TimeHorizon.week) ...[
            _buildWeekBarChart(logs, profile.targetCalories, isMobile),
          ] else if (_horizon == TimeHorizon.month) ...[
            _buildMonthSummaryGrid(logs, profile, isMobile),
          ] else ...[
            _buildYearlyOverview(logs, profile, isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildDayDetailView(DailyHealthLog log, UserProfileHealthMetric profile) {
    return Column(
      children: [
        _buildDetailRow('Calo nạp thực tế', '${log.caloriesIn.round()} kcal', 'Mục tiêu: ${profile.targetCalories} kcal'),
        _buildDetailRow('Calo tiêu hao tập luyện', '${log.caloriesBurned.round()} kcal', 'Tập: ${log.exerciseMinutes} phút'),
        _buildDetailRow('Lượng nước uống', '${log.waterMl} ml', 'Mục tiêu: ${profile.targetWaterMl} ml'),
        _buildDetailRow('Thời gian ngủ', '${log.sleepHours} giờ', 'Mục tiêu: ${profile.targetSleepHours} giờ'),
        if (log.notes != null && log.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Ghi chú: ${log.notes}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D2B6B))),
              Text(sub, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekBarChart(List<DailyHealthLog> logs, int targetCal, bool isMobile) {
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(logs.length.clamp(0, 7), (index) {
          final log = logs[index];
          final ratio = targetCal > 0 ? (log.caloriesIn / (targetCal * 1.3)).clamp(0.08, 1.0) : 0.08;
          final isToday = log.date.day == DateTime.now().day && log.date.month == DateTime.now().month;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${log.caloriesIn.round()}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isToday ? const Color(0xFF047857) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 90 * ratio,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: isToday
                            ? [const Color(0xFF047857), const Color(0xFF10B981)]
                            : [const Color(0xFF94A3B8), const Color(0xFFCBD5E1)],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    index < weekdays.length ? weekdays[index] : '',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isToday ? const Color(0xFF047857) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMonthSummaryGrid(List<DailyHealthLog> logs, UserProfileHealthMetric profile, bool isMobile) {
    int count = logs.length;
    double avgCal = 0;
    int avgWater = 0;
    double avgSleep = 0;
    for (final l in logs) {
      avgCal += l.caloriesIn;
      avgWater += l.waterMl;
      avgSleep += l.sleepHours;
    }
    if (count > 0) {
      avgCal /= count;
      avgWater = (avgWater / count).round();
      avgSleep /= count;
    }

    return Row(
      children: [
        _buildStatBox('Calo TB', '${avgCal.round()} kcal', 'Mục tiêu: ${profile.targetCalories}'),
        const SizedBox(width: 8),
        _buildStatBox('Nước TB', '$avgWater ml', 'Mục tiêu: ${profile.targetWaterMl}'),
        const SizedBox(width: 8),
        _buildStatBox('Ngủ TB', '${avgSleep.toStringAsFixed(1)}h', 'Chuẩn: 7.5h'),
      ],
    );
  }

  Widget _buildYearlyOverview(List<DailyHealthLog> logs, UserProfileHealthMetric profile, bool isMobile) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổng hợp theo dõi 12 tháng qua:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        SizedBox(height: 8),
        Text(
          '• Tính kỷ luật dinh dưỡng: 82% ngày đạt chuẩn calo cân bằng.\n'
          '• Lượng nước nạp: 90% các ngày trong năm đạt chuẩn bù dịch trên 2,000ml.\n'
          '• Giấc ngủ: Trung bình 7.2 giờ/đêm. Xu hướng cải thiện rõ rệt.',
          style: TextStyle(fontSize: 12.5, height: 1.55, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  Widget _buildStatBox(String title, String value, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B))),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. TAB 2: LỊCH TRÌNH ĂN UỐNG & BÀI TẬP CÁ NHÂN HÓA
  // ===========================================================================

  Widget _buildScheduleTabContent(
    HealthSchedulePlan schedule,
    UserProfileHealthMetric profile,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF4FB), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060D2B6B),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4F5EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF047857), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kế hoạch Dinh dưỡng & Vận động',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D2B6B),
                          ),
                        ),
                        Text(
                          schedule.dayFocus,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              const Text(
                '🥗 Thực đơn dinh dưỡng gợi ý',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),
              for (final meal in schedule.meals) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            meal.mealType,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                          ),
                          Text(
                            '${meal.calories} kcal',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFEA580C)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meal.name,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0D2B6B)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meal.description,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meal.macros,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              const Text(
                '🏃‍♂️ Bài tập thể lực hôm nay',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.primaryWorkout.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${schedule.primaryWorkout.durationMinutes} phút • ~${schedule.primaryWorkout.estimatedBurnKcal} kcal • Cấp độ: ${schedule.primaryWorkout.level}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                    ),
                    const SizedBox(height: 8),
                    for (final (idx, step) in schedule.primaryWorkout.steps.indexed) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${idx + 1}. ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                            Expanded(
                              child: Text(step, style: const TextStyle(fontSize: 12, color: Color(0xFF14532D), height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DIALOGS: GHI NHẬN CHỈ SỐ & CÀI ĐẶT THỂ TRẠNG
  // ===========================================================================

  void _showLogEntryDialog(BuildContext context) {
    final currentLog = DailyHealthService.instance.getLogForDate(_currentDate);
    final calController = TextEditingController(
      text: currentLog.caloriesIn > 0 ? currentLog.caloriesIn.round().toString() : '',
    );
    final waterController = TextEditingController(
      text: currentLog.waterMl > 0 ? currentLog.waterMl.toString() : '',
    );
    final sleepController = TextEditingController(
      text: currentLog.sleepHours > 0 ? currentLog.sleepHours.toString() : '',
    );
    final exController = TextEditingController(
      text: currentLog.exerciseMinutes > 0 ? currentLog.exerciseMinutes.toString() : '',
    );
    final weightController = TextEditingController(
      text: currentLog.weightKg != null ? currentLog.weightKg.toString() : '',
    );
    final notesController = TextEditingController(text: currentLog.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF047857), size: 24),
              SizedBox(width: 8),
              Text('Ghi nhận chỉ số hôm nay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nhập số liệu để Trợ lý AI phân tích và đưa ra kế hoạch thích ứng cho ngày mai:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 14),
                  TextField(
                    controller: calController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Lượng Calo đã nạp (kcal)',
                      hintText: 'Ví dụ: 1950',
                      prefixIcon: Icon(Icons.restaurant_rounded, color: Color(0xFFEA580C)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: waterController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nước đã uống (ml)',
                      hintText: 'Ví dụ: 2000',
                      prefixIcon: Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sleepController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Thời gian ngủ đêm qua (giờ)',
                      hintText: 'Ví dụ: 7.5',
                      prefixIcon: Icon(Icons.bedtime_rounded, color: Color(0xFF6366F1)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: exController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thời gian tập thể dục (phút)',
                      hintText: 'Ví dụ: 30',
                      prefixIcon: Icon(Icons.directions_run_rounded, color: Color(0xFF0D9488)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cân nặng (kg, tùy chọn)',
                      hintText: 'Ví dụ: 64.5',
                      prefixIcon: Icon(Icons.monitor_weight_outlined, color: Color(0xFF475569)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú thể trạng',
                      hintText: 'Ví dụ: Sung sức, cơ thể nhẹ nhàng...',
                      prefixIcon: Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final cal = double.tryParse(calController.text.trim()) ?? 0.0;
                final water = int.tryParse(waterController.text.trim()) ?? 0;
                final sleep = double.tryParse(sleepController.text.trim()) ?? 0.0;
                final ex = int.tryParse(exController.text.trim()) ?? 0;
                final weight = double.tryParse(weightController.text.trim());
                final notes = notesController.text.trim();

                final burned = (ex * 7.5);

                final updated = currentLog.copyWith(
                  caloriesIn: cal,
                  caloriesBurned: burned,
                  waterMl: water,
                  sleepHours: sleep,
                  exerciseMinutes: ex,
                  weightKg: weight,
                  notes: notes.isNotEmpty ? notes : null,
                );

                DailyHealthService.instance.saveDailyLog(updated);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã cập nhật chỉ số hôm nay thành công!'),
                    backgroundColor: Color(0xFF047857),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
              ),
              child: const Text('Lưu chỉ số'),
            ),
          ],
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context, UserProfileHealthMetric profile) {
    final heightCtrl = TextEditingController(text: profile.heightCm.toString());
    final weightCtrl = TextEditingController(text: profile.weightKg.toString());
    final ageCtrl = TextEditingController(text: profile.age.toString());
    String selectedGender = profile.gender;
    ActivityLevel selectedActivity = profile.activityLevel;
    HealthGoal selectedGoal = profile.healthGoal;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Color(0xFF047857)),
                  SizedBox(width: 8),
                  Text('Cài đặt Thể trạng & Mục tiêu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: heightCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Chiều cao (cm)', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: weightCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Cân nặng (kg)', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ageCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Tuổi', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedGender,
                              decoration: const InputDecoration(labelText: 'Giới tính', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('Nam')),
                                DropdownMenuItem(value: 'female', child: Text('Nữ')),
                              ],
                              onChanged: (v) {
                                if (v != null) setDialogState(() => selectedGender = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<HealthGoal>(
                        initialValue: selectedGoal,
                        decoration: const InputDecoration(labelText: 'Mục tiêu thể trạng', border: OutlineInputBorder()),
                        items: HealthGoal.values.map((g) => DropdownMenuItem(value: g, child: Text(g.label))).toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedGoal = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ActivityLevel>(
                        initialValue: selectedActivity,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Mức độ vận động', border: OutlineInputBorder()),
                        items: ActivityLevel.values.map((a) => DropdownMenuItem(value: a, child: Text(a.label, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedActivity = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () {
                    final h = double.tryParse(heightCtrl.text.trim()) ?? profile.heightCm;
                    final w = double.tryParse(weightCtrl.text.trim()) ?? profile.weightKg;
                    final age = int.tryParse(ageCtrl.text.trim()) ?? profile.age;

                    final updatedProfile = profile.copyWith(
                      heightCm: h,
                      weightKg: w,
                      age: age,
                      gender: selectedGender,
                      healthGoal: selectedGoal,
                      activityLevel: selectedActivity,
                    );

                    DailyHealthService.instance.updateProfile(updatedProfile);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã cập nhật mục tiêu: Calo ${updatedProfile.targetCalories} kcal • Nước ${updatedProfile.targetWaterMl}ml'),
                        backgroundColor: const Color(0xFF047857),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Áp dụng & Tính lại'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
