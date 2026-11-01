import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/rule_engine/rule_engine_service.dart';
import '../../../core/rule_engine/rule_models.dart';
import '../../../core/url_launcher_helper.dart';
import '../models/admin_management_models.dart';
import '../viewmodels/admin_viewmodel.dart';

// =============================================================================
// 1. VIEW QUẢN LÝ KNOWLEDGE BASE (Tùy chỉnh sâu kiến thức & phác đồ sơ cứu)
// =============================================================================
class AdminKnowledgeBaseView extends StatelessWidget {
  const AdminKnowledgeBaseView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminViewModel>();
    final articles = viewModel.filteredKnowledgeArticles;
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
                      'Tùy chỉnh sâu nội dung phác đồ sơ cứu theo từng phạm trù vết thương',
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: articles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final article = articles[index];
                return _buildArticleItemCard(context, viewModel, article);
              },
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
                label: const Text('Tùy chỉnh sâu'),
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
                      isEditing ? 'Tùy chỉnh sâu phác đồ sơ cứu' : 'Thêm bài viết kiến thức mới',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B)),
                    ),
                    Text(
                      isEditing ? 'Cập nhật nội dung, các bước xử lý và phạm trù vết thương' : 'Đăng tải phác đồ sơ cứu chuẩn y tế vào hệ thống',
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

                    // 1. CHẾ ĐỘ ĐỘ NHẠY NHẬN DIỆN AI (Thay thế thanh trượt % khó hiểu)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Độ nhạy nhận diện AI:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.sensitivityMode.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: t.sensitivityMode.color.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '${t.sensitivityMode.shortLabel} (>= ${t.sensitivityMode.thresholdPercent}%)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: t.sensitivityMode.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Đã quét: ${t.totalScansRecorded} lượt',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 3 nút chọn chế độ nhạy trực quan
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AiSensitivityMode.values.map((mode) {
                        final isSelected = t.sensitivityMode == mode;
                        return ChoiceChip(
                          selected: isSelected,
                          onSelected: (_) => viewModel.updateInjuryTypeSensitivity(t.id, mode),
                          avatar: Icon(
                            mode.icon,
                            size: 16,
                            color: isSelected ? Colors.white : mode.color,
                          ),
                          label: Text('${mode.shortLabel} (${mode.thresholdPercent}%)'),
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                          selectedColor: mode.color,
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: BorderSide(
                            color: isSelected ? mode.color : const Color(0xFFE2E8F0),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.sensitivityMode.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
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
                    'Tùy biến logic đánh giá lâm sàng, cấp cứu 115 và các bước sơ cứu cho 4 phạm trù vết thương',
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rules.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final rule = rules[index];
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

                      // Dấu hiệu lâm sàng kích hoạt
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (rule.requireBleedingHeavy)
                            _buildConditionBadge('🩸 Chảy máu nhiều / phun tia', const Color(0xFFDC2626)),
                          if (rule.requireForeignBody)
                            _buildConditionBadge('📌 Dị vật cắm sâu / hở sâu', const Color(0xFFB45309)),
                          if (rule.requireLargeBurnOrChemical)
                            _buildConditionBadge('🔥 Bỏng diện rộng / hóa chất', const Color(0xFFEA580C)),
                          if (rule.requireSeverePainOrFracture)
                            _buildConditionBadge('🦴 Đau dữ dội / nghi gãy xương', const Color(0xFF7C3AED)),
                          if (rule.requireInfection)
                            _buildConditionBadge('⚠️ Nhiễm trùng / sưng mủ', const Color(0xFFC026D3)),
                          if (!rule.requireBleedingHeavy &&
                              !rule.requireForeignBody &&
                              !rule.requireLargeBurnOrChemical &&
                              !rule.requireSeverePainOrFracture &&
                              !rule.requireInfection)
                            _buildConditionBadge('✅ Xử lý tiêu chuẩn tại nhà', const Color(0xFF16A34A)),
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

                      // Hàng nút hành động chỉnh sửa sâu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showDeepEditRuleDialog(context, viewModel, existingRule: rule),
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: const Text('Tùy biến chuyên sâu'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          if (rule.id.startsWith('rule_custom_') || !rule.code.startsWith('RULE-'))
                            IconButton(
                              onPressed: () => viewModel.deleteAdminRule(rule.id),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                              tooltip: 'Xóa quy tắc này',
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),

          // 5. BẢNG THAM CHIẾU NGUỒN Y KHOA & LIÊN KẾT NGOÀI (Click mở trình duyệt)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060D2B6B),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.link_rounded, color: Color(0xFF2563EB), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Cơ sở dữ liệu liên kết tham chiếu y tế chuẩn:',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0D2B6B)),
                        ),
                      ],
                    ),
                    Text('Bấm vào link để nhảy trực tiếp ra web', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 12),
                ...RuleEngineService.standardMedicalSources.map((src) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => UrlLauncherHelper.launchWebUrl(context, src.url),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.open_in_browser_rounded, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${src.organization} (${src.publishYear}): ${src.title}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                  ),
                                  Text(
                                    src.url,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
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
    bool requireLargeBurnOrChemical = existingRule?.requireLargeBurnOrChemical ?? false;
    bool requireSeverePainOrFracture = existingRule?.requireSeverePainOrFracture ?? false;
    bool requireInfection = existingRule?.requireInfection ?? false;

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

                      // 4. Cờ điều kiện lâm sàng kích hoạt (5 Checkbox)
                      const Text(
                        'Điều kiện lâm sàng kích hoạt luật này:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Chọn các dấu hiệu khiến luật này được Rule Engine kích hoạt tự động:',
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
                          children: [
                            _buildAdminRuleCheckboxTile(
                              title: 'Chảy máu nghiêm trọng / Khó cầm sau 10-15 phút',
                              value: requireBleedingHeavy,
                              activeColor: const Color(0xFFDC2626),
                              onChanged: (v) => setModalState(() => requireBleedingHeavy = v ?? false),
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            _buildAdminRuleCheckboxTile(
                              title: 'Có dị vật đâm vào / Vết thương rách hở sâu',
                              value: requireForeignBody,
                              activeColor: const Color(0xFFB45309),
                              onChanged: (v) => setModalState(() => requireForeignBody = v ?? false),
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            _buildAdminRuleCheckboxTile(
                              title: 'Bỏng diện rộng / Bỏng hóa chất / Bọng nước lớn',
                              value: requireLargeBurnOrChemical,
                              activeColor: const Color(0xFFEA580C),
                              onChanged: (v) => setModalState(() => requireLargeBurnOrChemical = v ?? false),
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            _buildAdminRuleCheckboxTile(
                              title: 'Đau đớn dữ dội / Nghi ngờ biến dạng hoặc gãy xương',
                              value: requireSeverePainOrFracture,
                              activeColor: const Color(0xFF7C3AED),
                              onChanged: (v) => setModalState(() => requireSeverePainOrFracture = v ?? false),
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            _buildAdminRuleCheckboxTile(
                              title: 'Dấu hiệu nhiễm trùng (sưng đỏ lan rộng, chảy dịch mủ, sốt)',
                              value: requireInfection,
                              activeColor: const Color(0xFFC026D3),
                              onChanged: (v) => setModalState(() => requireInfection = v ?? false),
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
                        requireLargeBurnOrChemical: requireLargeBurnOrChemical,
                        requireSeverePainOrFracture: requireSeverePainOrFracture,
                        requireInfection: requireInfection,
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
                        requireLargeBurnOrChemical: requireLargeBurnOrChemical,
                        requireSeverePainOrFracture: requireSeverePainOrFracture,
                        requireInfection: requireInfection,
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
class AdminDocumentsView extends StatelessWidget {
  const AdminDocumentsView({super.key});

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
        children: const [
          Text(
            'Quản lý tài liệu y tế',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Quản lý thông tin và tài liệu được sử dụng trong hệ thống lưu trữ thiết bị',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          SizedBox(height: 24),
          Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'Tài liệu y tế được đồng bộ trực tiếp từ phân hệ Kho tài liệu cục bộ.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
              _buildStatCard('Ca can thiệp khẩn cấp (115)', '1 ca', Icons.emergency, const Color(0xFFDC2626)),
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
// 6. VIEW CẤU HÌNH HỆ THỐNG (Settings)
// =============================================================================
class AdminSettingsView extends StatelessWidget {
  const AdminSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminViewModel>();
    final config = viewModel.systemConfig;
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
            'Cấu hình hệ thống',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Quản lý các thiết lập vận hành của mô hình AI, Rule Engine và thông tin y tế khẩn cấp',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

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
                  '1. Chế độ nhận diện AI toàn hệ thống',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2B6B)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Quyết định mức độ nhạy và kiểm duyệt khi quét ảnh AI trên toàn hệ thống (thay thế cho thanh trượt % khó quản lý).',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: AiSensitivityMode.values.map((mode) {
                    final isSelected = config.globalSensitivityMode == mode;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => viewModel.setGlobalSensitivityMode(mode),
                      child: Container(
                        width: isMobile ? double.infinity : 240,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? mode.color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? mode.color : const Color(0xFFCBD5E1),
                            width: isSelected ? 1.8 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(mode.icon, color: mode.color, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    mode.shortLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: isSelected ? mode.color : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Text(
                                  '>= ${mode.thresholdPercent}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: mode.color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              mode.description,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 28),

                const Text(
                  '2. Cảnh báo cấp cứu khẩn cấp (Emergency 115)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2B6B)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Hiển thị nút gọi 115 nổi bật và đổi giao diện sang màu đỏ khi Rule Engine phát hiện tổn thương nguy kịch.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ),
                    Switch(
                      value: config.isEmergency115AlertEnabled,
                      activeTrackColor: const Color(0xFF2563EB),
                      onChanged: (val) => viewModel.toggleEmergencyAlert(val),
                    ),
                  ],
                ),
                const Divider(height: 28),

                const Text(
                  '3. Thông tin mô hình AI nhận diện',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D2B6B)),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Phiên bản mô hình:', config.yoloModelVersion),
                const SizedBox(height: 6),
                _buildInfoRow('Endpoint API cục bộ:', config.aiServerEndpoint),
                const SizedBox(height: 6),
                _buildInfoRow('Hotline y tế khẩn cấp:', config.emergencyPhone),
              ],
            ),
          ),
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
