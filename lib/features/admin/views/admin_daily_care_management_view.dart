import 'package:flutter/material.dart';

import '../../user/models/daily_care_lesson.dart';
import '../../user/models/daily_health_models.dart';
import '../../user/services/daily_health_service.dart';

/// Màn hình Quản trị viên: Quản lý & Tùy chỉnh chức năng Chăm sóc sức khỏe hằng ngày (/admin)
class AdminDailyCareManagementView extends StatefulWidget {
  const AdminDailyCareManagementView({super.key});

  @override
  State<AdminDailyCareManagementView> createState() => _AdminDailyCareManagementViewState();
}

class _AdminDailyCareManagementViewState extends State<AdminDailyCareManagementView> {
  int _selectedTab = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  DailyCareTopic? _filterTopic;
  DailyCareFrequency? _filterFrequency;
  int _currentPage = 1;
  static const int _pageSize = 8;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return ListenableBuilder(
      listenable: DailyHealthService.instance,
      builder: (context, _) {
        final service = DailyHealthService.instance;
        final allLessons = service.lessons;
        final config = service.adminConfig;
        final analytics = service.getAnalyticsSummary();

        return Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header quản trị
              _buildAdminHeader(context, analytics, isMobile),

              // 2. Thanh Tabs chuyển đổi (Không dùng TabBarView để tránh lỗi Unbounded Height)
              _buildAdminTabBar(isMobile),

              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

              // 3. Nội dung theo Tab đang chọn
              if (_selectedTab == 0)
                _buildLessonsManagementTab(context, service, allLessons, isMobile)
              else if (_selectedTab == 1)
                _buildHealthConfigTab(context, service, config, isMobile)
              else
                _buildAnalyticsTab(analytics, isMobile),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. HEADER QUẢN TRỊ
  // ===========================================================================

  Widget _buildAdminHeader(
    BuildContext context,
    Map<String, dynamic> analytics,
    bool isMobile,
  ) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        isMobile ? 16 : 22,
        isMobile ? 16 : 28,
        isMobile ? 12 : 18,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F5EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.spa_rounded, color: Color(0xFF047857), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Quản lý Chăm sóc sức khỏe',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditLessonDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Thêm bài học mới'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4F5EB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.spa_rounded, color: Color(0xFF047857), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quản lý Chăm sóc sức khỏe hằng ngày',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D2B6B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tùy chỉnh cẩm nang, định mức chuẩn calo, nước uống và thuật toán trợ lý AI thích ứng',
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditLessonDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Thêm bài học mới'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
    );
  }

  // ===========================================================================
  // 2. THANH TAB BAR TỰ TẠO (TRÁNH LỖI UNBOUNDED HEIGHT CỦA TABBARVIEW)
  // ===========================================================================

  Widget _buildAdminTabBar(bool isMobile) {
    final tabs = [
      {'title': 'Quản lý Bài học & Cẩm nang', 'icon': Icons.menu_book_rounded},
      {'title': 'Cấu hình Tiêu chuẩn & Thích ứng', 'icon': Icons.tune_rounded},
      {'title': 'Thống kê & Độ tuân thủ', 'icon': Icons.analytics_outlined},
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTab == index;
            final item = tabs[index];

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  if (_selectedTab != index) {
                    setState(() {
                      _selectedTab = index;
                      _currentPage = 1;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF047857) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item['title'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. TAB 0: QUẢN LÝ BÀI HỌC & CẨM NANG
  // ===========================================================================

  Widget _buildLessonsManagementTab(
    BuildContext context,
    DailyHealthService service,
    List<DailyCareLesson> lessons,
    bool isMobile,
  ) {
    final search = _searchCtrl.text.trim().toLowerCase();
    final filtered = lessons.where((l) {
      if (search.isNotEmpty &&
          !l.title.toLowerCase().contains(search) &&
          !l.summary.toLowerCase().contains(search) &&
          !l.slug.toLowerCase().contains(search)) {
        return false;
      }
      if (_filterTopic != null && l.topic != _filterTopic) return false;
      if (_filterFrequency != null && l.frequency != _filterFrequency) return false;
      return true;
    }).toList();

    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final pageLessons = filtered.skip(startIndex).take(_pageSize).toList();

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh tìm kiếm và bộ lọc (Responsive)
          _buildSearchAndFilterBar(isMobile),
          const SizedBox(height: 16),

          // Danh sách bài học (Dùng Card dạng Column, không dùng Expanded để tránh lỗi RenderFlex)
          if (filtered.isEmpty)
            _buildEmptyPlaceholder()
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pageLessons.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (ctx, index) {
                  final lesson = pageLessons[index];
                  return _buildLessonListTile(context, service, lesson, isMobile);
                },
              ),
            ),

          const SizedBox(height: 16),

          // Phân trang
          if (filtered.isNotEmpty)
            _buildPaginationBar(
              currentPage: currentPage,
              totalPages: totalPages,
              totalItems: filtered.length,
              onPageChanged: (p) => setState(() => _currentPage = p),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() => _currentPage = 1),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm theo tiêu đề, slug, tóm tắt...',
              hintStyle: const TextStyle(fontSize: 12.5),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DailyCareTopic?>(
                  initialValue: _filterTopic,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  hint: const Text('Tất cả chủ đề', style: TextStyle(fontSize: 12)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tất cả chủ đề', style: TextStyle(fontSize: 12))),
                    ...DailyCareTopic.values.map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label, style: const TextStyle(fontSize: 12))),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _filterTopic = v;
                    _currentPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<DailyCareFrequency?>(
                  initialValue: _filterFrequency,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  hint: const Text('Tất cả tần suất', style: TextStyle(fontSize: 12)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tất cả tần suất', style: TextStyle(fontSize: 12))),
                    ...DailyCareFrequency.values.map(
                      (f) => DropdownMenuItem(value: f, child: Text(f.label, style: const TextStyle(fontSize: 12))),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _filterFrequency = v;
                    _currentPage = 1;
                  }),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() => _currentPage = 1),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm theo tiêu đề, slug, tóm tắt...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<DailyCareTopic?>(
            initialValue: _filterTopic,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            hint: const Text('Tất cả chủ đề', style: TextStyle(fontSize: 13)),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tất cả chủ đề')),
              ...DailyCareTopic.values.map(
                (t) => DropdownMenuItem(value: t, child: Text(t.label)),
              ),
            ],
            onChanged: (v) => setState(() {
              _filterTopic = v;
              _currentPage = 1;
            }),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<DailyCareFrequency?>(
            initialValue: _filterFrequency,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            hint: const Text('Tất cả tần suất', style: TextStyle(fontSize: 13)),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tất cả tần suất')),
              ...DailyCareFrequency.values.map(
                (f) => DropdownMenuItem(value: f, child: Text(f.label)),
              ),
            ],
            onChanged: (v) => setState(() {
              _filterFrequency = v;
              _currentPage = 1;
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildLessonListTile(
    BuildContext context,
    DailyHealthService service,
    DailyCareLesson lesson,
    bool isMobile,
  ) {
    Color topicColor;
    Color topicBg;
    switch (lesson.topic) {
      case DailyCareTopic.movement:
        topicColor = const Color(0xFF059669);
        topicBg = const Color(0xFFECFDF5);
        break;
      case DailyCareTopic.hydration:
        topicColor = const Color(0xFF0284C7);
        topicBg = const Color(0xFFF0F9FF);
        break;
      case DailyCareTopic.nutrition:
        topicColor = const Color(0xFFD97706);
        topicBg = const Color(0xFFFFFBEB);
        break;
      case DailyCareTopic.sleep:
        topicColor = const Color(0xFF6366F1);
        topicBg = const Color(0xFFEEF2FF);
        break;
    }

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: topicBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(lesson.topic.icon, color: topicColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      lesson.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lesson.frequency.label,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: topicBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lesson.topic.label,
                        style: TextStyle(fontSize: 10.5, color: topicColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lesson.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                ),
                const SizedBox(height: 6),
                Text(
                  'Slug: ${lesson.slug} • Nguồn: ${lesson.sourceName} • ${lesson.steps.length} bước thực hiện',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: lesson.isPublished ? 'Đang xuất bản' : 'Đang ẩn',
                child: Switch(
                  value: lesson.isPublished,
                  activeThumbColor: const Color(0xFF047857),
                  onChanged: (_) {
                    service.toggleLessonPublishStatus(lesson.slug);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 19),
                tooltip: 'Chỉnh sửa',
                onPressed: () => _showAddEditLessonDialog(context, existingLesson: lesson),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 19),
                tooltip: 'Xóa bài học',
                onPressed: () => _confirmDeleteLesson(context, service, lesson),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.menu_book_outlined, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            const Text(
              'Không tìm thấy bài học nào phù hợp',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Thử đổi từ khóa hoặc bộ lọc chủ đề/tần suất để xem danh sách.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchCtrl.clear();
                  _filterTopic = null;
                  _filterFrequency = null;
                  _currentPage = 1;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Đặt lại bộ lọc'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required ValueChanged<int> onPageChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Hiển thị $totalItems bài học (Trang $currentPage / $totalPages)',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              Text(
                '$currentPage',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF047857)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. TAB 1: CẤU HÌNH TIÊU CHUẨN & THÍCH ỨNG
  // ===========================================================================

  Widget _buildHealthConfigTab(
    BuildContext context,
    DailyHealthService service,
    AdminHealthConfig config,
    bool isMobile,
  ) {
    final waterCtrl = TextEditingController(text: config.defaultWaterMultiplierMlPerKg.toString());
    final exCtrl = TextEditingController(text: config.defaultDailyExerciseMin.toString());
    final sleepCtrl = TextEditingController(text: config.defaultSleepStandardHours.toString());
    final deficitCtrl = TextEditingController(text: config.weightLossDeficitKcal.toString());
    final surplusCtrl = TextEditingController(text: config.muscleGainSurplusKcal.toString());
    final noticeCtrl = TextEditingController(text: config.systemHealthNotice);
    bool autoAdaptive = config.autoAdaptiveAdjustmentEnabled;

    return StatefulBuilder(
      builder: (ctx, setConfigState) {
        return Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 28),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: EdgeInsets.all(isMobile ? 16 : 26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cấu hình Tham số Chuẩn & Thuật toán Trợ lý AI',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Các tham số này sẽ áp dụng để tính toán lượng calo, nước uống và gợi ý bù trừ cho toàn bộ người dùng.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const Divider(height: 28),

                  if (isMobile) ...[
                    TextField(
                      controller: waterCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Định mức nước chuẩn (ml/kg)',
                        helperText: 'Khuyến nghị WHO: 35 ml/kg',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: exCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Vận động tối thiểu (phút/ngày)',
                        helperText: 'Chuẩn tối thiểu: 30 phút',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: waterCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Định mức nước chuẩn (ml/kg)',
                              helperText: 'Khuyến nghị WHO: 35 ml/kg',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: exCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Vận động tối thiểu (phút/ngày)',
                              helperText: 'Chuẩn tối thiểu: 30 phút',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  if (isMobile) ...[
                    TextField(
                      controller: sleepCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Giờ ngủ chuẩn (giờ/đêm)',
                        helperText: 'Chuẩn CDC: 7.0 - 8.0 giờ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: deficitCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Mức thâm hụt giảm mỡ (kcal)',
                        helperText: 'An toàn: 300 - 500 kcal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sleepCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Giờ ngủ chuẩn (giờ/đêm)',
                              helperText: 'Chuẩn CDC: 7.0 - 8.0 giờ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: deficitCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Mức thâm hụt giảm mỡ (kcal)',
                              helperText: 'An toàn: 300 - 500 kcal',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: surplusCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Mức calo dư thừa cho mục tiêu Tăng cơ (kcal)',
                      helperText: 'Khuyến nghị: 250 - 400 kcal sạch',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bật/tắt chế độ bù trừ thích ứng cho ngày mai
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      title: const Text('Bật thuật toán Tự động Thích ứng cho Ngày mai', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Nếu hôm nay người dùng dư/thiếu calo, thiếu nước, thiếu ngủ, hệ thống sẽ tự sinh gợi ý bù trừ cho ngày hôm sau.'),
                      value: autoAdaptive,
                      activeThumbColor: const Color(0xFF047857),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setConfigState(() => autoAdaptive = val),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: noticeCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Thông điệp / Khuyến cáo y tế hệ thống',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final w = int.tryParse(waterCtrl.text.trim()) ?? 35;
                        final ex = int.tryParse(exCtrl.text.trim()) ?? 30;
                        final sl = double.tryParse(sleepCtrl.text.trim()) ?? 7.5;
                        final def = int.tryParse(deficitCtrl.text.trim()) ?? 400;
                        final sur = int.tryParse(surplusCtrl.text.trim()) ?? 300;
                        final not = noticeCtrl.text.trim();

                        final updated = config.copyWith(
                          defaultWaterMultiplierMlPerKg: w,
                          defaultDailyExerciseMin: ex,
                          defaultSleepStandardHours: sl,
                          weightLossDeficitKcal: def,
                          muscleGainSurplusKcal: sur,
                          autoAdaptiveAdjustmentEnabled: autoAdaptive,
                          systemHealthNotice: not.isNotEmpty ? not : null,
                        );

                        service.updateAdminConfig(updated);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã cập nhật cấu hình Chăm sóc sức khỏe toàn hệ thống thành công!'),
                            backgroundColor: Color(0xFF047857),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Lưu & Áp dụng Cấu hình Toàn Hệ thống', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 5. TAB 2: THỐNG KÊ & ĐỘ TUÂN THỦ NGƯỜI DÙNG
  // ===========================================================================

  Widget _buildAnalyticsTab(Map<String, dynamic> analytics, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thống kê Mức độ Tuân thủ & Sử dụng của Người dùng',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tổng hợp tỷ lệ hoàn thành mục tiêu calo, nước uống và thói quen sinh hoạt.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          // 4 Thẻ KPI (Responsive Layout)
          if (isMobile) ...[
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsKpiCard(
                    title: 'Tổng ngày ghi nhận',
                    value: '${analytics['totalLoggedDays']} ngày',
                    subText: 'Dữ liệu nhật ký',
                    icon: Icons.calendar_today_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAnalyticsKpiCard(
                    title: 'Đạt chuẩn Calo',
                    value: '${analytics['metCaloriesRate']}%',
                    subText: 'Cân bằng năng lượng',
                    icon: Icons.restaurant_rounded,
                    color: const Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsKpiCard(
                    title: 'Đạt chuẩn Nước',
                    value: '${analytics['metWaterRate']}%',
                    subText: 'Đủ nước mỗi ngày',
                    icon: Icons.water_drop_rounded,
                    color: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAnalyticsKpiCard(
                    title: 'Ngủ đủ giấc',
                    value: '${analytics['metSleepRate']}%',
                    subText: '≥ 7.0 giờ / đêm',
                    icon: Icons.bedtime_rounded,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsKpiCard(
                    title: 'Tổng ngày ghi nhận',
                    value: '${analytics['totalLoggedDays']} ngày',
                    subText: 'Dữ liệu nhật ký sức khỏe',
                    icon: Icons.calendar_today_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildAnalyticsKpiCard(
                    title: 'Tỷ lệ đạt chuẩn Calo',
                    value: '${analytics['metCaloriesRate']}%',
                    subText: 'Cân bằng năng lượng',
                    icon: Icons.restaurant_rounded,
                    color: const Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildAnalyticsKpiCard(
                    title: 'Tỷ lệ đạt chuẩn Nước',
                    value: '${analytics['metWaterRate']}%',
                    subText: 'Đủ nước mỗi ngày',
                    icon: Icons.water_drop_rounded,
                    color: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildAnalyticsKpiCard(
                    title: 'Tỷ lệ ngủ đủ giấc',
                    value: '${analytics['metSleepRate']}%',
                    subText: '≥ 7.0 giờ / đêm',
                    icon: Icons.bedtime_rounded,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tổng quan Trạng thái Dữ liệu Cẩm nang',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                Text(
                  '• Tổng số bài học cẩm nang trong hệ thống: ${analytics['totalLessonsCount']} bài.\n'
                  '• Số bài học đang xuất bản cho người dùng: ${analytics['publishedLessonsCount']} bài.\n'
                  '• Tỷ lệ đạt chuẩn vận động thể chất: ${analytics['metExerciseRate']}% số ngày.\n'
                  '• Dữ liệu ảo được lưu cục bộ an toàn, sẵn sàng đồng bộ trực tiếp sang Supabase table `daily_care_lessons` khi kết nối.',
                  style: const TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsKpiCard({
    required String title,
    required String value,
    required String subText,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B))),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          Text(subText, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. DIALOG THÊM / SỬA BÀI HỌC
  // ===========================================================================

  void _showAddEditLessonDialog(BuildContext context, {DailyCareLesson? existingLesson}) {
    final isEditing = existingLesson != null;
    final slugCtrl = TextEditingController(text: existingLesson?.slug ?? '');
    final titleCtrl = TextEditingController(text: existingLesson?.title ?? '');
    final summaryCtrl = TextEditingController(text: existingLesson?.summary ?? '');
    final stepsCtrl = TextEditingController(
      text: existingLesson != null ? existingLesson.steps.join('\n') : '',
    );
    final sourceNameCtrl = TextEditingController(text: existingLesson?.sourceName ?? 'WHO – Hướng dẫn y tế');
    final sourceUrlCtrl = TextEditingController(text: existingLesson?.sourceUrl ?? 'https://www.who.int');
    final sortCtrl = TextEditingController(text: (existingLesson?.sortOrder ?? 10).toString());

    DailyCareFrequency freq = existingLesson?.frequency ?? DailyCareFrequency.daily;
    DailyCareTopic topic = existingLesson?.topic ?? DailyCareTopic.movement;
    bool isPublished = existingLesson?.isPublished ?? true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(
                isEditing ? 'Chỉnh sửa bài học cẩm nang' : 'Thêm bài học cẩm nang mới',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: slugCtrl,
                        enabled: !isEditing,
                        decoration: const InputDecoration(
                          labelText: 'Slug (Định danh URL-safe)',
                          hintText: 'vi-du-van-dong-nhe',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề bài học',
                          hintText: 'Ví dụ: Uống đủ nước sau khi thức dậy',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<DailyCareFrequency>(
                              initialValue: freq,
                              decoration: const InputDecoration(labelText: 'Tần suất', border: OutlineInputBorder()),
                              items: DailyCareFrequency.values.map((f) => DropdownMenuItem(value: f, child: Text(f.label))).toList(),
                              onChanged: (v) {
                                if (v != null) setDialogState(() => freq = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<DailyCareTopic>(
                              initialValue: topic,
                              decoration: const InputDecoration(labelText: 'Chủ đề', border: OutlineInputBorder()),
                              items: DailyCareTopic.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                              onChanged: (v) {
                                if (v != null) setDialogState(() => topic = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: summaryCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Tóm tắt bài học',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: stepsCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Các bước thực hiện (Mỗi bước 1 dòng)',
                          hintText: 'Bước 1: Chuẩn bị nước ấm...\nBước 2: Uống từ từ từng ngụm nhỏ...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sourceNameCtrl,
                              decoration: const InputDecoration(labelText: 'Tên nguồn', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: sourceUrlCtrl,
                              decoration: const InputDecoration(labelText: 'URL nguồn (https://)', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sortCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Thứ tự sắp xếp', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: CheckboxListTile(
                                title: const Text('Xuất bản', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                value: isPublished,
                                activeColor: const Color(0xFF047857),
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) => setDialogState(() => isPublished = v ?? true),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () {
                    final slug = slugCtrl.text.trim();
                    final title = titleCtrl.text.trim();
                    final summary = summaryCtrl.text.trim();
                    final steps = stepsCtrl.text
                        .split('\n')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    final sName = sourceNameCtrl.text.trim();
                    final sUrl = sourceUrlCtrl.text.trim();
                    final sort = int.tryParse(sortCtrl.text.trim()) ?? 10;

                    if (slug.isEmpty || title.isEmpty || summary.isEmpty || steps.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng điền đủ slug, tiêu đề, tóm tắt và ít nhất 1 bước thực hiện!')),
                      );
                      return;
                    }

                    final newLesson = DailyCareLesson(
                      slug: slug,
                      frequency: freq,
                      topic: topic,
                      title: title,
                      summary: summary,
                      steps: steps,
                      sourceName: sName,
                      sourceUrl: sUrl,
                      sortOrder: sort,
                      isPublished: isPublished,
                    );

                    DailyHealthService.instance.saveLesson(newLesson);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'Đã cập nhật bài học thành công!' : 'Đã thêm bài học mới!'),
                        backgroundColor: const Color(0xFF047857),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEditing ? 'Lưu thay đổi' : 'Thêm bài học'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteLesson(BuildContext context, DailyHealthService service, DailyCareLesson lesson) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Xác nhận xóa bài học?'),
          content: Text('Bạn có chắc muốn xóa bài học "${lesson.title}" không?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            TextButton(
              onPressed: () {
                service.deleteLesson(lesson.slug);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa bài học khỏi hệ thống.')),
                );
              },
              child: const Text('Xóa', style: TextStyle(color: Color(0xFFEF4444))),
            ),
          ],
        );
      },
    );
  }
}
