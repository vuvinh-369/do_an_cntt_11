import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/gemini/gemini_config_model.dart';
import '../../../core/gemini/gemini_service.dart';
import '../../../core/rule_engine/rule_models.dart';
import '../../../core/url_launcher_helper.dart';
import '../models/admin_management_models.dart';
import '../viewmodels/admin_management_viewmodel.dart';
import '../viewmodels/admin_viewmodel.dart';

/// Thanh phân trang chuẩn phong cách Kho tài liệu y tế dành cho trang Quản trị (Admin)
Widget _buildAdminPaginationFooter({
  required int currentPage,
  required int totalPages,
  required int totalItems,
  required int pageSize,
  required String itemLabel,
  required ValueChanged<int> onPageSelected,
  required VoidCallback onPrevious,
  required VoidCallback onNext,
  bool isMobile = false,
}) {
  if (totalItems == 0) return const SizedBox.shrink();

  final startItem = (currentPage - 1) * pageSize + 1;
  final endItem = math.min(currentPage * pageSize, totalItems);
  final infoText = 'Hiển thị $startItem - $endItem trên tổng số $totalItems $itemLabel';

  final paginationControls = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Nút Trước (<)
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: currentPage > 1 ? onPrevious : null,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: currentPage > 1 ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: currentPage > 1 ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),

      // Các nút số trang (1, 2, 3...)
      ...List.generate(totalPages, (index) {
        final page = index + 1;
        final isSelected = page == currentPage;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: isSelected ? const Color(0xFF2563EB) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onPageSelected(page),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '$page',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
      const SizedBox(width: 6),

      // Nút Sau (>)
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: currentPage < totalPages ? onNext : null,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: currentPage < totalPages ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: currentPage < totalPages ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    ],
  );

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x060D2B6B),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: isMobile
        ? Column(
            children: [
              Text(
                infoText,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              paginationControls,
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_rows_rounded, size: 17, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Text(
                    infoText,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              paginationControls,
            ],
          ),
  );
}

// =============================================================================
// 1. VIEW QUẢN LÝ KNOWLEDGE BASE (Tùy chỉnh sâu kiến thức & phác đồ sơ cứu)
// =============================================================================
class AdminKnowledgeBaseView extends StatelessWidget {
  const AdminKnowledgeBaseView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminViewModel>();
    final articles = viewModel.filteredKnowledgeArticles;
    final paginatedArticles = viewModel.paginatedKnowledgeArticles;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Quản lý Knowledge Base & Kiến thức sơ cứu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2B6B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kho cẩm nang & phác đồ chuẩn y khoa (Bộ - Tổ chức Y tế) – Cung cấp nội dung sơ cứu các bước chuẩn',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showAddOrEditArticleDialog(context, viewModel),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Thêm bài viết mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Banner phân biệt vai trò: Knowledge Base vs Rule Engine
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cơ sở Tri thức Y khoa (Knowledge Base) – Phác đồ điều trị chuẩn',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Knowledge Base lưu trữ các bài viết, cẩm nang và quy trình sơ cứu 4 bước chuẩn theo bệnh học. Rule Engine sẽ tự động trích xuất các phác đồ này khi điều kiện lâm sàng thực tế của người dùng được kích hoạt.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Thanh lọc theo Phạm trù vết thương (Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTopicFilterChip(context, viewModel, 'all', 'Tất cả (${viewModel.knowledgeArticles.length})'),
                const SizedBox(width: 8),
                _buildTopicFilterChip(context, viewModel, 'abrasion', '🩹 Trầy xước'),
                const SizedBox(width: 8),
                _buildTopicFilterChip(context, viewModel, 'cut_laceration', '✂️ Vết cắt / rách'),
                const SizedBox(width: 8),
                _buildTopicFilterChip(context, viewModel, 'burn', '🔥 Bỏng'),
                const SizedBox(width: 8),
                _buildTopicFilterChip(context, viewModel, 'bruise', '🟣 Bầm tím'),
                const SizedBox(width: 8),
                _buildTopicFilterChip(context, viewModel, 'other_wounds', '🩺 Vết thương khác'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Ô tìm kiếm
          TextField(
            onChanged: (val) => viewModel.setKbSearchQuery(val),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm bài viết theo tiêu đề, phạm trù vết thương, nội dung...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Danh sách bài viết
          if (articles.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.menu_book_outlined, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text(
                    'Không tìm thấy bài viết kiến thức nào cho phạm trù này.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showAddOrEditArticleDialog(
                      context,
                      viewModel,
                      initialTopicId: viewModel.selectedInjuryTopicFilter != 'all'
                          ? viewModel.selectedInjuryTopicFilter
                          : 'other_wounds',
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Thêm bài viết cho phạm trù này'),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paginatedArticles.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final article = paginatedArticles[index];
                    return _buildArticleItemCard(context, viewModel, article);
                  },
                ),
                const SizedBox(height: 16),
                _buildAdminPaginationFooter(
                  currentPage: viewModel.currentKbPage,
                  totalPages: viewModel.totalKbPages,
                  totalItems: articles.length,
                  pageSize: AdminManagementViewModel.kbPageSize,
                  itemLabel: 'bài viết phác đồ',
                  onPageSelected: (page) => viewModel.selectKbPage(page),
                  onPrevious: () => viewModel.goToPreviousKbPage(),
                  onNext: () => viewModel.goToNextKbPage(),
                  isMobile: isMobile,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopicFilterChip(
    BuildContext context,
    AdminViewModel viewModel,
    String topicId,
    String label,
  ) {
    final isSelected = viewModel.selectedInjuryTopicFilter == topicId;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFEFF6FF),
      side: BorderSide(
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => viewModel.setSelectedInjuryTopicFilter(topicId),
    );
  }

  Widget _buildArticleItemCard(
    BuildContext context,
    AdminViewModel viewModel,
    KnowledgeArticleModel article,
  ) {
    // Màu badge theo phạm trù vết thương
    Color topicBgColor = const Color(0xFFEFF6FF);
    Color topicTextColor = const Color(0xFF2563EB);
    IconData topicIcon = Icons.healing_rounded;

    switch (article.targetInjuryTypeId) {
      case 'abrasion':
        topicBgColor = const Color(0xFFEFF6FF);
        topicTextColor = const Color(0xFF1D4ED8);
        topicIcon = Icons.grain;
        break;
      case 'cut_laceration':
        topicBgColor = const Color(0xFFFFF7ED);
        topicTextColor = const Color(0xFFC2410C);
        topicIcon = Icons.content_cut_rounded;
        break;
      case 'burn':
        topicBgColor = const Color(0xFFFEF2F2);
        topicTextColor = const Color(0xFFB91C1C);
        topicIcon = Icons.local_fire_department_rounded;
        break;
      case 'bruise':
        topicBgColor = const Color(0xFFFAF5FF);
        topicTextColor = const Color(0xFF7E22CE);
        topicIcon = Icons.blur_circular_rounded;
        break;
      case 'other_wounds':
      default:
        topicBgColor = const Color(0xFFF0FDF4);
        topicTextColor = const Color(0xFF15803D);
        topicIcon = Icons.medical_services_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: article.isPublished ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
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
          // Dải badge thông tin đầu thẻ
          Row(
            children: [
              // Badge phạm trù vết thương
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: topicBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: topicTextColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(topicIcon, size: 14, color: topicTextColor),
                    const SizedBox(width: 5),
                    Text(
                      'Phạm trù: ${article.effectiveInjuryTypeName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: topicTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Badge danh mục
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  article.categoryName,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),

              // Switch trạng thái xuất bản
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    article.isPublished ? 'Đang xuất bản' : 'Tạm ẩn',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: article.isPublished ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: article.isPublished,
                      activeTrackColor: const Color(0xFF2563EB),
                      onChanged: (_) => viewModel.toggleArticlePublished(article.id),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tiêu đề bài viết
          Text(
            article.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),

          // Tóm tắt
          Text(
            article.summary,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.45),
          ),
          const SizedBox(height: 14),

          // Thống kê chi tiết
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.format_list_numbered_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text('${article.steps.length} bước sơ cứu chi tiết',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text('${article.warnings.length} dấu hiệu cảnh báo',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                ],
              ),
              if (article.contraindications.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.block_rounded, size: 15, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Text('${article.contraindications.length} Không được làm',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  ],
                ),
              Text(
                '• Cập nhật: ${article.lastUpdated}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          if (article.sourceUrl != null && article.sourceUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => UrlLauncherHelper.launchWebUrl(context, article.sourceUrl),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      '${article.sourceOrganization ?? "Nguồn y tế"}: ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                    ),
                    Flexible(
                      child: Text(
                        article.sourceUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2563EB),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Thanh nút hành động: Xem trước, Chỉnh sửa sâu, Xóa
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showPreviewArticleDialog(context, article),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Xem trước'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showAddOrEditArticleDialog(context, viewModel, articleToEdit: article),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Tùy chỉnh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                tooltip: 'Xóa bài viết này',
                onPressed: () => _showConfirmDeleteDialog(context, viewModel, article),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showConfirmDeleteDialog(
    BuildContext context,
    AdminViewModel viewModel,
    KnowledgeArticleModel article,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Xác nhận xóa bài viết'),
        content: Text('Bạn có chắc chắn muốn xóa bài viết "${article.title}" khỏi Knowledge Base?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              viewModel.deleteKnowledgeArticle(article.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
  }

  /// Dialog xem trước chi tiết bài viết phác đồ sơ cứu chuẩn
  void _showPreviewArticleDialog(BuildContext context, KnowledgeArticleModel article) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.medical_services_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B))),
                  Text('Phạm trù: ${article.effectiveInjuryTypeName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tóm tắt
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                  child: Text(article.summary, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                ),
                const SizedBox(height: 18),

                // Các bước sơ cứu
                const Text('CÁC BƯỚC SƠ CỨU CHI TIẾT:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF2563EB))),
                const SizedBox(height: 8),
                ...article.steps.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final step = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: const Color(0xFF2563EB),
                          child: Text('$idx', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(step, style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), height: 1.4))),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Cảnh báo nguy hiểm
                if (article.warnings.isNotEmpty) ...[
                  const Text('DẤU HIỆU CẢNH BÁO NGUY HIỂM / ĐI KHÁM:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFD97706))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: article.warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('⚠️ ', style: TextStyle(fontSize: 12)),
                            Expanded(child: Text(w, style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)))),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Điều cấm kỵ
                if (article.contraindications.isNotEmpty) ...[
                  const Text('NHỮNG ĐIỀU TUYỆT ĐỐI KHÔNG ĐƯỢC LÀM:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFDC2626))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: article.contraindications.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🚫 ', style: TextStyle(fontSize: 12)),
                            Expanded(child: Text(c, style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B)))),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ],
                if (article.sourceUrl != null && article.sourceUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('NGUỒN THẨM ĐỊNH Y KHOA:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E3A8A))),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => UrlLauncherHelper.launchWebUrl(context, article.sourceUrl),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  article.sourceOrganization ?? 'Nguồn y khoa chính thức',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                                ),
                                Text(
                                  article.sourceUrl!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => UrlLauncherHelper.launchWebUrl(context, article.sourceUrl),
                            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                            label: const Text('Mở Web'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  /// Modal Dialog "Thêm bài viết mới" hoặc "Tùy chỉnh sâu bài viết"
  void _showAddOrEditArticleDialog(
    BuildContext context,
    AdminViewModel viewModel, {
    KnowledgeArticleModel? articleToEdit,
    String? initialTopicId,
  }) {
    final bool isEditing = articleToEdit != null;

    final titleController = TextEditingController(text: articleToEdit?.title ?? '');
    final summaryController = TextEditingController(text: articleToEdit?.summary ?? '');
    final stepsController = TextEditingController(
      text: articleToEdit?.steps.join('\n') ?? 'Rửa sạch vết thương bằng nước muối sinh lý 0.9%\nSát trùng nhẹ nhàng mép da bị thương\nBăng gạc vô trùng che phủ bảo vệ',
    );
    final warningsController = TextEditingController(
      text: articleToEdit?.warnings.join('\n') ?? 'Vết thương sưng mủ, sốt cao hoặc đỏ tấy lan rộng\nChảy máu nhiều không cầm sau 10 - 15 phút ép trực tiếp',
    );
    final contraindicationsController = TextEditingController(
      text: articleToEdit?.contraindications.join('\n') ?? 'Không đắp lá cây, tro than hay bột thuốc chưa chỉ định',
    );
    final sourceOrgController = TextEditingController(
      text: articleToEdit?.sourceOrganization ?? 'Hội Chữ Thập Đỏ Việt Nam',
    );
    final sourceUrlController = TextEditingController(
      text: articleToEdit?.sourceUrl ?? 'https://redcross.org.vn/so-cap-cuu',
    );

    String selectedTopicId = articleToEdit?.targetInjuryTypeId ?? initialTopicId ?? 'abrasion';
    String selectedCategory = articleToEdit?.categoryId ?? 'wound';
    String selectedCategoryName = articleToEdit?.categoryName ?? 'Vết thương';
    RuleSeverityLevel selectedSeverity = articleToEdit?.defaultSeverity ?? RuleSeverityLevel.normal;
    bool isPublished = articleToEdit?.isPublished ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEditing ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.post_add_rounded,
                  color: isEditing ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Tùy chỉnh nội dung sơ cứu' : 'Thêm bài viết kiến thức mới',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B)),
                    ),
                    Text(
                      isEditing ? 'Cập nhật nội dung, các bước xử lý vết thương' : 'Đăng tải nội dung sơ cứu chuẩn y tế vào hệ thống',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- PHẦN 1: PHẠM TRÙ VẾT THƯƠNG (TRỌNG TÂM) ---
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.category_rounded, size: 18, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Text(
                              'Phạm trù vết thương áp dụng kiến thức này:',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E3A8A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: selectedTopicId,
                          items: const [
                            DropdownMenuItem(value: 'abrasion', child: Text('🩹 Trầy xước ngoài da (abrasion)')),
                            DropdownMenuItem(value: 'cut_laceration', child: Text('✂️ Vết cắt / rách da (cut_laceration)')),
                            DropdownMenuItem(value: 'burn', child: Text('🔥 Bỏng nhiệt / hóa chất (burn)')),
                            DropdownMenuItem(value: 'bruise', child: Text('🟣 Bầm tím phần mềm (bruise)')),
                            DropdownMenuItem(value: 'other_wounds', child: Text('🩺 Vết thương khác / Sơ cứu chung (other_wounds)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => selectedTopicId = val);
                            }
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tiêu đề
                  const Text('Tiêu đề bài viết:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1E293B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Phác đồ cầm máu và vô trùng vết rách da...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Danh mục và Mức độ nghiêm trọng
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Danh mục y tế:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: selectedCategory,
                              items: const [
                                DropdownMenuItem(value: 'wound', child: Text('Vết thương')),
                                DropdownMenuItem(value: 'burn', child: Text('Bỏng')),
                                DropdownMenuItem(value: 'musculoskeletal', child: Text('Xương khớp')),
                                DropdownMenuItem(value: 'other', child: Text('Vết thương khác')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    selectedCategory = val;
                                    if (val == 'wound') selectedCategoryName = 'Vết thương';
                                    if (val == 'burn') selectedCategoryName = 'Bỏng';
                                    if (val == 'musculoskeletal') selectedCategoryName = 'Xương khớp';
                                    if (val == 'other') selectedCategoryName = 'Vết thương khác';
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mức độ cảnh báo:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<RuleSeverityLevel>(
                              initialValue: selectedSeverity,
                              items: const [
                                DropdownMenuItem(value: RuleSeverityLevel.normal, child: Text('🟢 Nhẹ (Thường gặp)')),
                                DropdownMenuItem(value: RuleSeverityLevel.warning, child: Text('🟠 Cần chú ý (Quan trọng)')),
                                DropdownMenuItem(value: RuleSeverityLevel.emergency, child: Text('🔴 Nguy cấp (Báo động đỏ)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => selectedSeverity = val);
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tóm tắt
                  const Text('Tóm tắt tổng quan:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: summaryController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Tóm tắt ngắn gọn mục tiêu của bài hướng dẫn sơ cứu...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- PHẦN 2: CÁC BƯỚC SƠ CỨU CHI TIẾT ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Các bước thực hiện sơ cứu chi tiết:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF2563EB))),
                      Text('(Mỗi dòng là 1 bước)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: stepsController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Bước 1: Rửa tay...\nBước 2: Cầm máu...\nBước 3: Băng bảo vệ...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- PHẦN 3: CẢNH BÁO NGUY HIỂM ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Dấu hiệu nguy hiểm / Cần chuyển viện:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFFD97706))),
                      Text('(Mỗi dòng là 1 cảnh báo)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: warningsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Chảy máu phun thành tia...\nNạn nhân choáng váng hoặc khó thở...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- PHẦN 4: ĐIỀU CẤM KỴ ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Những việc TUYỆT ĐỐI KHÔNG LÀM', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFFDC2626))),
                      Text('(Mỗi dòng 1 điều)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: contraindicationsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Không tự ý rút dị vật cắm sâu...\nKhông bôi kem đánh răng lên vết bỏng...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // --- PHẦN 5: TÙY BIẾN ĐƯỜNG DẪN LIÊN KẾT WEB (URL) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Nguồn tài liệu y khoa & Đường dẫn web (URL):',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1D4ED8)),
                      ),
                      Text('(Bấm vào sẽ nhảy trực tiếp ra trình duyệt)', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: sourceOrgController,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Tổ chức thẩm định',
                            hintText: 'VD: Bộ Y Tế, WHO...',
                            prefixIcon: const Icon(Icons.verified_outlined, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: sourceUrlController,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Đường dẫn liên kết web (URL)',
                            hintText: 'https://...',
                            prefixIcon: const Icon(Icons.link_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Thử nhảy ra web ngay',
                        onPressed: () {
                          UrlLauncherHelper.launchWebUrl(context, sourceUrlController.text);
                        },
                        icon: const Icon(Icons.open_in_browser_rounded, color: Color(0xFF2563EB)),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFEFF6FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Xuất bản
                  Row(
                    children: [
                      Checkbox(
                        value: isPublished,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) => setState(() => isPublished = val ?? true),
                      ),
                      const Text(
                        'Kích hoạt xuất bản (Người dùng có thể tra cứu và xem hướng dẫn bài viết này)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
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
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                // Tách các bước
                final steps = stepsController.text
                    .split('\n')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                final warnings = warningsController.text
                    .split('\n')
                    .map((w) => w.trim())
                    .where((w) => w.isNotEmpty)
                    .toList();
                final contraindications = contraindicationsController.text
                    .split('\n')
                    .map((c) => c.trim())
                    .where((c) => c.isNotEmpty)
                    .toList();

                final updatedArticle = KnowledgeArticleModel(
                  id: articleToEdit?.id ?? 'kb_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  categoryId: selectedCategory,
                  categoryName: selectedCategoryName,
                  summary: summaryController.text.trim().isNotEmpty
                      ? summaryController.text.trim()
                      : 'Phác đồ sơ cứu chuẩn y tế được cập nhật bởi quản trị viên.',
                  targetInjuryTypeId: selectedTopicId,
                  targetInjuryTypeName: getInjuryTopicName(selectedTopicId),
                  defaultSeverity: selectedSeverity,
                  steps: steps.isNotEmpty ? steps : const ['Rửa sạch vết thương', 'Băng bảo vệ'],
                  warnings: warnings.isNotEmpty ? warnings : const ['Đến viện nếu đau tăng hoặc sưng phù'],
                  contraindications: contraindications,
                  lastUpdated: 'Hôm nay',
                  isPublished: isPublished,
                  sourceOrganization: sourceOrgController.text.trim().isNotEmpty
                      ? sourceOrgController.text.trim()
                      : null,
                  sourceUrl: sourceUrlController.text.trim().isNotEmpty
                      ? sourceUrlController.text.trim()
                      : null,
                );

                if (isEditing) {
                  viewModel.updateKnowledgeArticle(updatedArticle);
                } else {
                  viewModel.addKnowledgeArticle(updatedArticle);
                }

                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isEditing ? 'Lưu thay đổi' : 'Thêm bài viết'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. VIEW QUẢN LÝ LOẠI TỔN THƯƠNG (Injury Types)
// =============================================================================
class AdminInjuryTypesView extends StatelessWidget {
  const AdminInjuryTypesView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminViewModel>();
    final types = viewModel.supportedInjuryTypes;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Quản lý nhóm loại tổn thương',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cấu hình các loại tổn thương mô hình YOLO nhận diện và ngưỡng tin cậy áp dụng',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: types.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final t = types[index];
              final severity = t.defaultSeverity;

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            color: severity.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: severity.borderColor),
                          ),
                          child: Icon(severity.icon, color: severity.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    t.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0D2B6B),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: severity.backgroundColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: severity.borderColor),
                                    ),
                                    child: Text(
                                      severity.label,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: severity.color),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(t.description, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Switch(
                          value: t.isAiDetectionEnabled,
                          activeTrackColor: const Color(0xFF2563EB),
                          onChanged: (_) => viewModel.toggleInjuryTypeAiDetection(t.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // Thông tin số lượt quét và trạng thái nhận diện AI
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              t.isAiDetectionEnabled ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                              size: 16,
                              color: t.isAiDetectionEnabled ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t.isAiDetectionEnabled ? 'Mô hình YOLO đang nhận diện nhóm này' : 'Tạm dừng nhận diện AI',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: t.isAiDetectionEnabled ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Đã quét: ${t.totalScansRecorded} lượt',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. MỨC ĐỘ NGHIÊM TRỌNG Y TẾ MẶC ĐỊNH
                    Row(
                      children: [
                        const Text(
                          'Mức độ y tế mặc định:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ...RuleSeverityLevel.values.map((sev) {
                          final isSelected = t.defaultSeverity == sev;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => viewModel.updateInjuryTypeSeverity(t.id, sev),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected ? sev.backgroundColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? sev.color : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      sev.icon,
                                      size: 13,
                                      color: isSelected ? sev.color : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      sev.label.split(' - ').first,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? sev.color : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 3. VIEW QUẢN LÝ RULE ENGINE (TÙY BIẾN SÂU 4 PHẠM TRÙ VẾT THƯƠNG)
// =============================================================================
class AdminRuleEngineView extends StatelessWidget {
  const AdminRuleEngineView({super.key});

  static const Map<String, String> categoryLabels = {
    'all': 'Áp dụng chung',
    'abrasion': 'Trầy xước',
    'cut_laceration': 'Vết cắt / rách',
    'burn': 'Bỏng',
    'bruise': 'Bầm tím',
  };

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminViewModel>();
    final allRules = viewModel.adminRuleList;
    final rules = viewModel.filteredAdminRules;
    final paginatedRules = viewModel.paginatedAdminRules;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    final activeCount = allRules.where((r) => r.isEnabled).length;
    final emergencyCount = allRules.where((r) => r.severity == RuleSeverityLevel.emergency).length;
    final warningCount = allRules.where((r) => r.severity == RuleSeverityLevel.warning).length;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. HEADER & THAO TÁC HỆ THỐNG
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Quản lý Rule Engine Sơ cứu',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D2B6B),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Bộ máy quy tắc suy luận lâm sàng – Đánh giá tình huống dựa trên triệu chứng, mức độ đau & liên kết phác đồ Knowledge Base',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showResetRulesConfirmationDialog(context, viewModel),
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('Khôi phục chuẩn y tế'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showDeepEditRuleDialog(context, viewModel),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('Thêm quy tắc mới'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Banner phân biệt vai trò: Rule Engine vs Knowledge Base
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.tune_rounded, color: Color(0xFF16A34A), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bộ máy Quy tắc Lâm sàng Động (Rule Engine) – Xử lý tình huống theo thời gian thực',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Rule Engine đánh giá tình trạng thực tế của nạn nhân dựa trên 3 triệu chứng (chảy máu, dị vật, sưng mủ), cảm giác đau (Không đau/Đau nhẹ/Đau nặng) và loại vết thương. Rule Engine phân loại mức độ khẩn cấp (Nhẹ/Cần chú ý/Khẩn cấp), đưa ra việc cấm kỵ và liên kết tới Phác đồ chuẩn tương ứng trong Knowledge Base.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. THẺ THỐNG KÊ NHANH CÁC QUY TẮC
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final statCards = [
                _buildStatMetricCard('Tổng quy tắc', '${allRules.length}', Icons.rule_rounded, const Color(0xFF2563EB)),
                _buildStatMetricCard('Đang kích hoạt', '$activeCount', Icons.check_circle_rounded, const Color(0xFF16A34A)),
                _buildStatMetricCard('Quy tắc Khẩn cấp', '$emergencyCount', Icons.emergency_rounded, const Color(0xFFDC2626)),
                _buildStatMetricCard('Cần chú ý', '$warningCount', Icons.warning_amber_rounded, const Color(0xFFD97706)),
              ];

              if (isWide) {
                return Row(
                  children: statCards.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: w))).toList(),
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: statCards.map((w) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: w)).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // 3. THANH FILTER CHIPS THEO 4 PHẠM TRÙ VẾT THƯƠNG
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryFilterChip(context, viewModel, 'all', 'Tất cả (${allRules.length})'),
                const SizedBox(width: 8),
                _buildCategoryFilterChip(context, viewModel, 'abrasion', 'Trầy xước'),
                const SizedBox(width: 8),
                _buildCategoryFilterChip(context, viewModel, 'cut_laceration', 'Vết cắt / rách'),
                const SizedBox(width: 8),
                _buildCategoryFilterChip(context, viewModel, 'burn', 'Bỏng'),
                const SizedBox(width: 8),
                _buildCategoryFilterChip(context, viewModel, 'bruise', 'Bầm tím'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. DANH SÁCH QUY TẮC (CARD HIỂN THỊ CHI TIẾT & HÀNH ĐỘNG TÙY BIẾN)
          if (rules.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'Không có quy tắc nào thuộc phạm trù này.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paginatedRules.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final rule = paginatedRules[index];
                    final severity = rule.severity;
                    final categoryName = categoryLabels[rule.targetInjuryTypeId] ?? rule.targetInjuryTypeId;

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: rule.isEnabled
                          ? (severity == RuleSeverityLevel.emergency
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFCBD5E1))
                          : const Color(0xFFE2E8F0),
                      width: rule.isEnabled ? 1.5 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x080D2B6B),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hàng Header của Rule
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              rule.code,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: severity.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: severity.borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(severity.icon, size: 12, color: severity.color),
                                const SizedBox(width: 4),
                                Text(
                                  severity.label.split(' - ').first,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: severity.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            rule.isEnabled ? 'Kích hoạt' : 'Đang tắt',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: rule.isEnabled ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Switch(
                            value: rule.isEnabled,
                            activeTrackColor: const Color(0xFF2563EB),
                            onChanged: (_) => viewModel.toggleAdminRule(rule.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Tên luật
                      Text(
                        rule.name,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rule.description,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                      ),
                      const SizedBox(height: 12),

                      // Dấu hiệu lâm sàng kích hoạt (Khớp 100% với giao diện quét ảnh & kết quả)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (rule.requireBleedingHeavy)
                            _buildConditionBadge('🩸 Vết thương đang chảy máu', const Color(0xFFDC2626)),
                          if (rule.requireForeignBody)
                            _buildConditionBadge('📌 Có dị vật cắm vào', const Color(0xFFB45309)),
                          if (rule.requireInfection)
                            _buildConditionBadge('⚠️ Chảy mủ / Sưng đỏ tấy', const Color(0xFFC026D3)),
                          if (rule.requiredPainLevel == PainLevel.severe || rule.requireSeverePainOrFracture)
                            _buildConditionBadge('⚡ Cảm giác Đau nặng (7-10)', const Color(0xFFDC2626))
                          else if (rule.requiredPainLevel == PainLevel.mild)
                            _buildConditionBadge('⚡ Đau nhẹ trở lên (1-10)', const Color(0xFFD97706)),
                          if (rule.requireMultipleInjuries)
                            _buildConditionBadge('🩹 Đa tổn thương (2-3 vết thương)', const Color(0xFF2563EB)),
                          if (!rule.requireBleedingHeavy &&
                              !rule.requireForeignBody &&
                              !rule.requireInfection &&
                              rule.requiredPainLevel == null &&
                              !rule.requireMultipleInjuries &&
                              !rule.requireLargeBurnOrChemical &&
                              !rule.requireSeverePainOrFracture)
                            _buildConditionBadge('✅ Áp dụng tiêu chuẩn', const Color(0xFF16A34A)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Khung hành động sơ cứu
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hành động sơ cứu khuyến nghị:',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...rule.primaryActions.map(
                              (act) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        act,
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Khung chống chỉ định nếu có
                      if (rule.contraindications.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.block_rounded, size: 14, color: Color(0xFFDC2626)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Tuyệt đối không được làm:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ...rule.contraindications.map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text('• $c', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Khuyến nghị y tế
                      if (rule.emergencyRecommendation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.medical_services_outlined, size: 15, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Khuyến cáo: ${rule.emergencyRecommendation}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 8),

                      // Hàng nút hành động: Phác đồ Knowledge Base + Tùy biến + Xóa quy tắc
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Phác đồ liên kết từ Knowledge Base
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.menu_book_rounded, size: 15, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Phác đồ Knowledge Base: $categoryName',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E40AF),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showDeepEditRuleDialog(context, viewModel, existingRule: rule),
                                icon: const Icon(Icons.tune_rounded, size: 15),
                                label: const Text('Tùy biến'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () => _showDeleteRuleConfirmationDialog(context, viewModel, rule),
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                tooltip: 'Xóa quy tắc này',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildAdminPaginationFooter(
              currentPage: viewModel.currentRulePage,
              totalPages: viewModel.totalRulePages,
              totalItems: rules.length,
              pageSize: AdminManagementViewModel.rulePageSize,
              itemLabel: 'quy tắc lâm sàng',
              onPageSelected: (page) => viewModel.selectRulePage(page),
              onPrevious: () => viewModel.goToPreviousRulePage(),
              onNext: () => viewModel.goToNextRulePage(),
              isMobile: isMobile,
            ),
          ],
        ),
      ],
    ),
  );
}

  void _showDeleteRuleConfirmationDialog(
    BuildContext context,
    AdminViewModel viewModel,
    FirstAidRule rule,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Xóa quy tắc ${rule.code}?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa quy tắc "${rule.name}" (${rule.code}) khỏi Rule Engine không?\n\nBạn có thể bấm "Khôi phục chuẩn y tế" ở phía trên bất cứ lúc nào để phục hồi.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              viewModel.deleteAdminRule(rule.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã xóa quy tắc ${rule.code} khỏi hệ thống.'),
                  backgroundColor: const Color(0xFFDC2626),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa quy tắc'),
          ),
        ],
      ),
    );
  }

  static Widget _buildAdminRuleCheckboxTile({
    required String title,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                activeColor: activeColor,
                onChanged: onChanged,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                Text(title, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(
    BuildContext context,
    AdminViewModel viewModel,
    String categoryId,
    String label,
  ) {
    final isSelected = viewModel.selectedRuleCategoryFilter == categoryId;

    return FilterChip(
      selected: isSelected,
      onSelected: (_) => viewModel.selectRuleCategoryFilter(categoryId),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  Widget _buildConditionBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // ===========================================================================
  // MODAL TÙY BIẾN SÂU QUY TẮC RULE ENGINE
  // ===========================================================================
  void _showDeepEditRuleDialog(
    BuildContext context,
    AdminViewModel viewModel, {
    FirstAidRule? existingRule,
  }) {
    final isEditing = existingRule != null;
    final codeController = TextEditingController(
      text: existingRule?.code ?? 'RULE-CUSTOM-0${viewModel.adminRuleList.length + 1}',
    );
    final nameController = TextEditingController(text: existingRule?.name ?? '');
    final descController = TextEditingController(text: existingRule?.description ?? '');
    final emergencyRecController = TextEditingController(
      text: existingRule?.emergencyRecommendation ?? 'Đến ngay cơ sở y tế gần nhất nếu có dấu hiệu nặng lên.',
    );

    String targetInjuryTypeId = existingRule?.targetInjuryTypeId ?? 'abrasion';
    RuleSeverityLevel severity = existingRule?.severity ?? RuleSeverityLevel.normal;

    bool requireBleedingHeavy = existingRule?.requireBleedingHeavy ?? false;
    bool requireForeignBody = existingRule?.requireForeignBody ?? false;
    bool requireInfection = existingRule?.requireInfection ?? false;
    PainLevel? requiredPainLevel = existingRule?.requiredPainLevel ??
        (existingRule?.requireSeverePainOrFracture == true ? PainLevel.severe : null);
    bool requireMultipleInjuries = existingRule?.requireMultipleInjuries ?? false;
    bool requireLargeBurnOrChemical = existingRule?.requireLargeBurnOrChemical ?? false;
    bool requireSeverePainOrFracture = existingRule?.requireSeverePainOrFracture ?? false;

    final List<TextEditingController> actionControllers = (existingRule?.primaryActions ?? [
      'Rửa sạch vùng tổn thương bằng nước muối sinh lý.',
      'Sát khuẩn nhẹ nhàng bằng dung dịch chuyên dụng.',
    ]).map((a) => TextEditingController(text: a)).toList();

    final List<TextEditingController> contraControllers = (existingRule?.contraindications ?? [
      'Không tự ý bôi các chất lạ hoặc thuốc chưa rõ nguồn gốc.',
    ]).map((c) => TextEditingController(text: c)).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing ? 'Tùy biến chuyên sâu: ${existingRule.code}' : 'Thêm quy tắc mới cho Rule Engine',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B)),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Mã & Tên luật
                      Row(
                        children: [
                          SizedBox(
                            width: 170,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Mã quy tắc:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: codeController,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tên quy tắc:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: nameController,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'VD: Bỏng diện rộng, Trầy xước nhẹ...',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 2. Phạm trù áp dụng (4 phạm trù cốt lõi)
                      const Text(
                        'Phạm trù tổn thương áp dụng:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: categoryLabels.entries.map((entry) {
                          final isSelected = targetInjuryTypeId == entry.key;
                          return ChoiceChip(
                            selected: isSelected,
                            onSelected: (_) => setModalState(() => targetInjuryTypeId = entry.key),
                            label: Text(entry.value),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                            selectedColor: const Color(0xFF2563EB),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // 3. Mức độ nghiêm trọng y tế
                      const Text(
                        'Mức độ đánh giá y tế:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: RuleSeverityLevel.values.map((sev) {
                          final isSelected = severity == sev;
                          return ChoiceChip(
                            selected: isSelected,
                            onSelected: (_) => setModalState(() => severity = sev),
                            avatar: Icon(sev.icon, size: 14, color: isSelected ? Colors.white : sev.color),
                            label: Text(sev.label),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : sev.color,
                            ),
                            selectedColor: sev.color,
                            backgroundColor: sev.backgroundColor,
                            side: BorderSide(color: sev.borderColor),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // 4. Điều kiện lâm sàng kích hoạt (Khớp 100% với giao diện quét ảnh & kết quả)
                      const Text(
                        'Điều kiện lâm sàng kích hoạt quy tắc:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Khớp trực tiếp với các triệu chứng quan sát, mức độ đau và phát hiện trên giao diện người dùng:',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 3 Checkbox lâm sàng khớp giao diện người dùng
                            _buildAdminRuleCheckboxTile(
                              title: '🩸 Vết thương đang chảy máu (chảy nhiều hoặc liên tục)',
                              value: requireBleedingHeavy,
                              activeColor: const Color(0xFFDC2626),
                              onChanged: (v) => setModalState(() => requireBleedingHeavy = v ?? false),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            _buildAdminRuleCheckboxTile(
                              title: '📌 Dị vật cắm vào vết thương (kim loại, dằm, thủy tinh...)',
                              value: requireForeignBody,
                              activeColor: const Color(0xFFB45309),
                              onChanged: (v) => setModalState(() => requireForeignBody = v ?? false),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            _buildAdminRuleCheckboxTile(
                              title: '⚠️ Vết thương chảy mủ / Sưng đỏ tấy (dấu hiệu nhiễm trùng)',
                              value: requireInfection,
                              activeColor: const Color(0xFFC026D3),
                              onChanged: (v) => setModalState(() => requireInfection = v ?? false),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            _buildAdminRuleCheckboxTile(
                              title: '🩹 Phát hiện từ 2-3 vết thương cùng lúc trên ảnh (Đa tổn thương)',
                              value: requireMultipleInjuries,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (v) => setModalState(() => requireMultipleInjuries = v ?? false),
                            ),
                            const SizedBox(height: 10),

                            // Điều kiện mức độ đau
                            const Text(
                              'Yêu cầu cảm giác đau (khớp thanh gạt 3 mức):',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                ChoiceChip(
                                  label: const Text('Bất kỳ mức đau'),
                                  selected: requiredPainLevel == null,
                                  onSelected: (_) => setModalState(() => requiredPainLevel = null),
                                  selectedColor: const Color(0xFF2563EB),
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    color: requiredPainLevel == null ? Colors.white : const Color(0xFF334155),
                                    fontWeight: requiredPainLevel == null ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Từ Đau nhẹ trở lên (1-10)'),
                                  selected: requiredPainLevel == PainLevel.mild,
                                  onSelected: (_) => setModalState(() => requiredPainLevel = PainLevel.mild),
                                  selectedColor: const Color(0xFFD97706),
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    color: requiredPainLevel == PainLevel.mild ? Colors.white : const Color(0xFF334155),
                                    fontWeight: requiredPainLevel == PainLevel.mild ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Chỉ khi Đau nặng (7-10)'),
                                  selected: requiredPainLevel == PainLevel.severe,
                                  onSelected: (_) => setModalState(() => requiredPainLevel = PainLevel.severe),
                                  selectedColor: const Color(0xFFDC2626),
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    color: requiredPainLevel == PainLevel.severe ? Colors.white : const Color(0xFF334155),
                                    fontWeight: requiredPainLevel == PainLevel.severe ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 5. Mô tả quy tắc
                      const Text('Mô tả quy tắc:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Mô tả ngắn gọn khi nào nên áp dụng luật này...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 6. Hành động sơ cứu ưu tiên (Thêm / Xóa / Sửa từng bước)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Hành động sơ cứu ưu tiên:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                actionControllers.add(TextEditingController(text: 'Bước mới...'));
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text('Thêm bước'),
                          ),
                        ],
                      ),
                      ...List.generate(actionControllers.length, (idx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: const Color(0xFFEFF6FF),
                                child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: actionControllers[idx],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setModalState(() {
                                    actionControllers.removeAt(idx);
                                  });
                                },
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                tooltip: 'Xóa bước này',
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),

                      // 7. Chống chỉ định (Những việc TUYỆT ĐỐI KHÔNG ĐƯỢC LÀM)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Chống chỉ định (Tuyệt đối không làm):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFDC2626))),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                contraControllers.add(TextEditingController(text: 'Điều cấm mới...'));
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFFDC2626)),
                            label: const Text('Thêm điều cấm', style: TextStyle(color: Color(0xFFDC2626))),
                          ),
                        ],
                      ),
                      ...List.generate(contraControllers.length, (idx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.block_rounded, size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: contraControllers[idx],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setModalState(() {
                                    contraControllers.removeAt(idx);
                                  });
                                },
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                tooltip: 'Xóa điều cấm này',
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),

                      // 8. Khuyến cáo cơ sở y tế
                      const Text('Khuyến cáo y tế / Khi nào cần đi viện:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emergencyRecController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Cần đi viện khi nào...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isEditing)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _showDeleteRuleConfirmationDialog(context, viewModel, existingRule);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    label: const Text('Xóa quy tắc này', style: TextStyle(color: Color(0xFFDC2626))),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;

                    final acts = actionControllers
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
                    final contras = contraControllers
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    if (isEditing) {
                      final updatedRule = existingRule.copyWith(
                        code: codeController.text.trim(),
                        name: nameController.text.trim(),
                        description: descController.text.trim(),
                        severity: severity,
                        targetInjuryTypeId: targetInjuryTypeId,
                        requireBleedingHeavy: requireBleedingHeavy,
                        requireForeignBody: requireForeignBody,
                        requireInfection: requireInfection,
                        requiredPainLevel: requiredPainLevel,
                        requireMultipleInjuries: requireMultipleInjuries,
                        requireLargeBurnOrChemical: requireLargeBurnOrChemical,
                        requireSeverePainOrFracture: requireSeverePainOrFracture,
                        linkedKnowledgeTopicId: targetInjuryTypeId,
                        primaryActions: acts.isNotEmpty ? acts : ['Sơ cứu cẩn thận'],
                        contraindications: contras,
                        emergencyRecommendation: emergencyRecController.text.trim(),
                      );
                      viewModel.updateAdminRule(updatedRule);
                    } else {
                      final newRule = FirstAidRule(
                        id: 'rule_custom_${DateTime.now().millisecondsSinceEpoch}',
                        code: codeController.text.trim(),
                        name: nameController.text.trim(),
                        description: descController.text.trim(),
                        severity: severity,
                        targetInjuryTypeId: targetInjuryTypeId,
                        requireBleedingHeavy: requireBleedingHeavy,
                        requireForeignBody: requireForeignBody,
                        requireInfection: requireInfection,
                        requiredPainLevel: requiredPainLevel,
                        requireMultipleInjuries: requireMultipleInjuries,
                        requireLargeBurnOrChemical: requireLargeBurnOrChemical,
                        requireSeverePainOrFracture: requireSeverePainOrFracture,
                        linkedKnowledgeTopicId: targetInjuryTypeId,
                        condition: (ctx) => true,
                        primaryActions: acts.isNotEmpty ? acts : ['Sơ cứu cẩn thận'],
                        contraindications: contras,
                        emergencyRecommendation: emergencyRecController.text.trim(),
                      );
                      viewModel.addAdminRule(newRule);
                    }
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEditing ? 'Đã lưu thay đổi quy tắc!' : 'Đã thêm quy tắc mới vào Rule Engine!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEditing ? 'Lưu thay đổi' : 'Tạo quy tắc'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showResetRulesConfirmationDialog(BuildContext context, AdminViewModel viewModel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Khôi phục quy tắc chuẩn y tế?'),
        content: const Text(
          'Thao tác này sẽ đặt lại toàn bộ quy tắc Rule Engine về mặc định chuẩn y tế (Bộ Y Tế / WHO) cho 4 phạm trù vết thương.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () {
              viewModel.resetRulesToDefault();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã khôi phục Rule Engine về mặc định chuẩn y tế!')),
              );
            },
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 4. VIEW QUẢN LÝ TÀI LIỆU Y TẾ
// =============================================================================
// 5. VIEW LỊCH SỬ & THỐNG KÊ (History & Analytics)
// =============================================================================
class AdminHistoryAnalyticsView extends StatelessWidget {
  const AdminHistoryAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Lịch sử & Thống kê hệ thống',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Theo dõi lịch sử phân tích hình ảnh (lưu tạm trong RAM) và các số liệu sử dụng',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          // 3 Thẻ chỉ số
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              _buildStatCard('Tổng ca quét trong RAM', '5 ca mẫu', Icons.memory, const Color(0xFF2563EB)),
              _buildStatCard('Độ tin cậy trung bình', '82.5%', Icons.verified_outlined, const Color(0xFF16A34A)),
              _buildStatCard('Ca tổn thương nặng', '1 ca', Icons.warning_amber_rounded, const Color(0xFFDC2626)),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Ghi chú lưu trữ:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFF0D2B6B)),
                ),
                SizedBox(height: 6),
                Text(
                  'Toàn bộ lịch sử phân tích hiện tại được lưu tạm trong bộ nhớ RAM của ứng dụng theo kế hoạch ban đầu (tắt app sẽ tự giải phóng bộ nhớ). Sau khi hoàn thiện các tính năng, hệ thống sẽ kết nối với PostgreSQL để lưu trữ vĩnh viễn.',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 6. VIEW CẤU HÌNH HỆ THỐNG (Settings & Google Gemini API)
// =============================================================================
class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  late TextEditingController _apiKeyController;
  late TextEditingController _promptController;
  late TextEditingController _maxTokensController;
  late bool _geminiEnabled;
  bool _obscureApiKey = true;

  bool _isTestingGemini = false;
  GeminiTestResult? _geminiTestResult;

  @override
  void initState() {
    super.initState();
    final config = GeminiService.instance.config;
    _apiKeyController = TextEditingController(text: config.apiKey);
    _promptController = TextEditingController(text: config.systemInstruction);
    _maxTokensController = TextEditingController(text: config.maxTokens.toString());
    _geminiEnabled = config.isEnabled;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _promptController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }

  Future<void> _pasteApiKeyFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _apiKeyController.text = data.text!.trim();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã dán API Key từ bộ nhớ tạm thành công!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bộ nhớ tạm (Clipboard) không có văn bản!'),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _resetSystemPromptToStandard() {
    setState(() {
      _promptController.text = defaultWoundCareSystemInstruction;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã khôi phục System Prompt chuẩn y khoa cho 4 nhóm vết thương!'),
          backgroundColor: Color(0xFF2563EB),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testGeminiConnection(AdminViewModel viewModel) async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập API Key trước khi kiểm tra kết nối!'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isTestingGemini = true;
      _geminiTestResult = null;
    });

    final result = await viewModel.testGeminiConnection(
      apiKey: apiKey,
      model: 'gemini-3.8-flash',
    );

    if (!mounted) return;
    setState(() {
      _isTestingGemini = false;
      _geminiTestResult = result;
    });
  }

  void _saveGeminiConfiguration(AdminViewModel viewModel) {
    final maxTok = int.tryParse(_maxTokensController.text.trim()) ?? 1024;
    final newConfig = GeminiConfigModel(
      isEnabled: _geminiEnabled,
      apiKey: _apiKeyController.text.trim(),
      selectedModel: 'gemini-3.8-flash',
      systemInstruction: _promptController.text.trim().isEmpty
          ? defaultWoundCareSystemInstruction
          : _promptController.text.trim(),
      temperature: 0.4,
      maxTokens: maxTok,
    );

    viewModel.updateGeminiConfig(newConfig);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Đã lưu cấu hình Google Gemini API thành công!'),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminViewModel>();
    final config = viewModel.systemConfig;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cấu hình hệ thống & Trợ lý AI',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Quản lý các thiết lập vận hành của mô hình YOLO, Rule Engine và Google Gemini API cho ChatBox sơ cứu',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          // ===================================================================
          // CARD 1: THÔNG TIN MÔ HÌNH NHẬN DIỆN AI (YOLO)
          // ===================================================================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Thông tin mô hình AI nhận diện (YOLO v11 / FastAPI)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2B6B)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mô hình Deep Learning YOLO chịu trách nhiệm phân loại 4 nhóm vết thương (Trầy xước, Vết cắt, Bỏng, Bầm tím). Mức độ nghiêm trọng y tế được xác định qua phản hồi triệu chứng và cảm giác đau thực tế.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Phiên bản mô hình:', config.yoloModelVersion),
                const SizedBox(height: 6),
                _buildInfoRow('Endpoint API cục bộ:', config.aiServerEndpoint),
                const SizedBox(height: 6),
                _buildInfoRow('Cơ chế đánh giá:', 'YOLO phân loại vết thương -> Rule Engine kết hợp triệu chứng quan sát và mức độ đau.'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ===================================================================
          // CARD 2: CẤU HÌNH CHATBOX GOOGLE GEMINI API
          // ===================================================================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x082563EB),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '2. Cấu hình ChatBox Gemini',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0D2B6B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _geminiEnabled && _apiKeyController.text.trim().isNotEmpty
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _geminiEnabled && _apiKeyController.text.trim().isNotEmpty
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Text(
                                  _geminiEnabled && _apiKeyController.text.trim().isNotEmpty
                                      ? 'Đang hoạt động'
                                      : (_geminiEnabled ? 'Chờ API Key' : 'Đã tắt'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _geminiEnabled && _apiKeyController.text.trim().isNotEmpty
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Gọi trực tiếp Gemini API để giải đáp thắc mắc và tư vấn sơ cứu chuyên sâu theo ngôn ngữ tự nhiên.',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _geminiEnabled,
                      activeTrackColor: const Color(0xFF2563EB),
                      onChanged: (val) {
                        setState(() {
                          _geminiEnabled = val;
                        });
                      },
                    ),
                  ],
                ),
                const Divider(height: 28),

                // 4.1 Khóa Gemini API Key
                Row(
                  children: [
                    const Text(
                      'Khóa API Key của Google Gemini:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => UrlLauncherHelper.launchWebUrl(
                        context,
                        'https://aistudio.google.com/app/apikey',
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Lấy API Key miễn phí tại Google AI Studio',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureApiKey,
                        decoration: InputDecoration(
                          hintText: 'Dán khóa API Key của bạn (Bắt đầu bằng AIzaSy...)',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF64748B), size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureApiKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF64748B),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureApiKey = !_obscureApiKey;
                              });
                            },
                            tooltip: _obscureApiKey ? 'Hiện khóa API' : 'Ẩn khóa API',
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _pasteApiKeyFromClipboard,
                      icon: const Icon(Icons.paste_rounded, size: 17),
                      label: const Text('Dán từ Clipboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF1E293B),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2.2 Thông tin mô hình Gemini & Nhiệt độ y khoa chuẩn
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 20, color: Color(0xFF2563EB)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mô hình AI: Google Gemini Flash (Mới nhất)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Hệ thống tự động sử dụng phiên bản Flash mới nhất với nhiệt độ 0.4 (chuẩn độ chính xác y khoa).',
                              style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 4.3 System Instruction (Prompt định hướng y tế cho 4 loại vết thương)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lời nhắc hệ thống (System Prompt) cho vết thương:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    TextButton.icon(
                      onPressed: _resetSystemPromptToStandard,
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('Khôi phục mẫu chuẩn y tế', style: TextStyle(fontSize: 12.5)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _promptController,
                  maxLines: 7,
                  minLines: 4,
                  style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', height: 1.4, color: Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: 'Nhập lời nhắc định hướng phản hồi của Gemini...',
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mẫu prompt này được thiết kế để Gemini bám sát 4 phạm trù: Trầy xước, Vết cắt/rách, Bỏng, Bầm tím, tự động cảnh báo khẩn cấp đi viện khi nguy kịch và nhắc nhở tiêm uốn ván.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Hiển thị kết quả Test Connection nếu có
                if (_geminiTestResult != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _geminiTestResult!.isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _geminiTestResult!.isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _geminiTestResult!.isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: _geminiTestResult!.isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _geminiTestResult!.isSuccess ? 'Kiểm tra thành công!' : 'Kiểm tra thất bại:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _geminiTestResult!.isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _geminiTestResult!.message,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _geminiTestResult!.isSuccess ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4.4 Các nút hành động: Kiểm tra kết nối & Lưu cấu hình
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isTestingGemini ? null : () => _testGeminiConnection(viewModel),
                      icon: _isTestingGemini
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                            )
                          : const Icon(Icons.network_check_rounded, size: 18),
                      label: Text(_isTestingGemini ? 'Đang kiểm tra...' : 'Kiểm tra kết nối Gemini'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _saveGeminiConfiguration(viewModel),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Lưu cấu hình Gemini'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 170, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
        Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      ],
    );
  }
}

