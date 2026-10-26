// File: lib/views/userview/tra_cuu_kien_thuc_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../viewmodels/user_viewmodel.dart';
import 've_do_hoa_view.dart';

class TraCuuKienThucView extends StatelessWidget {
  const TraCuuKienThucView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 36,
        vertical: isMobile ? 16 : 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isMobile) ...[
            const Text(
              'Kiến thức sơ cứu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D2B6B),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 20),
          ],
          _buildKnowledgeSearchBarRow(context, isMobile: isMobile),
          const SizedBox(height: 14),
          _buildKnowledgeCategoryFilterRow(
            context,
            viewModel,
            isMobile: isMobile,
          ),
          const SizedBox(height: 18),
          _buildKnowledgeTopicsGrid(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildKnowledgeSearchBarRow(
    BuildContext context, {
    bool isMobile = false,
  }) {
    final searchInputBox = Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8E3F2), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      child: TextField(
        onChanged: (value) =>
            context.read<UserViewModel>().updateKnowledgeSearchQuery(value),
        onSubmitted: (_) =>
            context.read<UserViewModel>().onKnowledgeSearchSubmitted(),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          icon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
          hintText: 'Tìm kiếm kiến thức, ví dụ: bỏng, vết cắt...',
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );

    if (isMobile) {
      return searchInputBox;
    }

    return Row(
      children: [
        Expanded(child: searchInputBox),
        const SizedBox(width: 12),
        SizedBox(
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () =>
                context.read<UserViewModel>().onKnowledgeSearchSubmitted(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.search_rounded, size: 19),
            label: const Text(
              'Tìm kiếm',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKnowledgeCategoryFilterRow(
    BuildContext context,
    UserViewModel viewModel, {
    bool isMobile = false,
  }) {
    final chips = viewModel.knowledgeCategories.map((category) {
      final isSelected = viewModel.selectedKnowledgeCategoryId == category.id;

      return Padding(
        padding: EdgeInsets.only(right: isMobile ? 8 : 0),
        child: Material(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.read<UserViewModel>().selectKnowledgeCategory(
              category.id,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Text(
                category.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      );
    }

    return Wrap(spacing: 10, runSpacing: 10, children: chips);
  }

  Widget _buildKnowledgeTopicsGrid(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final topics = viewModel.filteredKnowledgeTopics;

    if (topics.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'Không tìm thấy kiến thức sơ cứu phù hợp với từ khóa.',
            style: TextStyle(
              fontSize: 14.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final int columns = maxWidth >= 560 ? 2 : 1;
        const double spacing = 16;
        const double runSpacing = 14;
        final double cardWidth =
            (maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: topics.map((topic) {
            return SizedBox(
              width: cardWidth,
              child: _buildSingleKnowledgeTopicCard(context, topic),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSingleKnowledgeTopicCard(
    BuildContext context,
    KnowledgeTopicModel topic,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.read<UserViewModel>().onKnowledgeTopicCardTapped(topic),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060D2B6B),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 74,
                  height: 68,
                  child: _buildSafeKnowledgeThumbnail(topic),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2B6B),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      topic.subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeKnowledgeThumbnail(KnowledgeTopicModel topic) {
    if (topic.imageUrl != null && topic.imageUrl!.isNotEmpty) {
      return Image.network(
        topic.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return CustomPaint(
            painter: KnowledgeTopicThumbnailPainter(topicId: topic.id),
          );
        },
      );
    }
    return CustomPaint(
      painter: KnowledgeTopicThumbnailPainter(topicId: topic.id),
    );
  }
}
