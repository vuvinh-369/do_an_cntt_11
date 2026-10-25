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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          _buildKnowledgeSearchBarRow(context),
          const SizedBox(height: 18),
          _buildKnowledgeCategoryFilterRow(context, viewModel),
          const SizedBox(height: 22),
          _buildKnowledgeTopicsGrid(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildKnowledgeSearchBarRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;

        final searchInputBox = Container(
          height: 48,
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
              fontSize: 14.5,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              icon: Icon(
                Icons.search_rounded,
                color: Color(0xFF64748B),
                size: 21,
              ),
              hintText: 'Tìm kiếm kiến thức, ví dụ: bỏng, vết cắt...',
              hintStyle: TextStyle(
                fontSize: 14.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        );

        final searchButton = SizedBox(
          height: 48,
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
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchInputBox,
              const SizedBox(height: 10),
              searchButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchInputBox),
            const SizedBox(width: 12),
            searchButton,
          ],
        );
      },
    );
  }

  Widget _buildKnowledgeCategoryFilterRow(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: viewModel.knowledgeCategories.map((category) {
        final isSelected = viewModel.selectedKnowledgeCategoryId == category.id;

        return Material(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.read<UserViewModel>().selectKnowledgeCategory(
              category.id,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
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
        const double spacing = 20;
        const double runSpacing = 18;
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
          padding: const EdgeInsets.all(16),
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
                  width: 82,
                  height: 76,
                  child: _buildSafeKnowledgeThumbnail(topic),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2B6B),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      topic.subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
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
