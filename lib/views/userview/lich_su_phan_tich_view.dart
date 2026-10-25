import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../viewmodels/user_viewmodel.dart';

class LichSuPhanTichView extends StatelessWidget {
  const LichSuPhanTichView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final historyItems = viewModel.filteredAnalysisHistoryItems;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tiêu đề màn hình "Lịch sử phân tích"
          const Text(
            'Lịch sử phân tích',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),

          // 2. Hàng bộ lọc: Ô chọn khoảng ngày ("Từ ngày - Đến ngày") & Dropdown ("Tất cả kết quả")
          _buildFilterRow(context, viewModel),
          const SizedBox(height: 20),

          // 3. Danh sách các thẻ lịch sử phân tích
          if (historyItems.isEmpty)
            _buildEmptyState(context, viewModel)
          else
            Column(
              children: List.generate(historyItems.length, (index) {
                final item = historyItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildHistoryItemCard(context, viewModel, item),
                );
              }),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // THANH BỘ LỌC NGÀY & LOẠI KẾT QUẢ
  // ===========================================================================

  Widget _buildFilterRow(BuildContext context, UserViewModel viewModel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;

        final dateFilterBox = _buildDateRangeFilterButton(context, viewModel);
        final resultDropdownBox = _buildResultTypeDropdown(context, viewModel);

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dateFilterBox,
              const SizedBox(height: 12),
              resultDropdownBox,
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 5, child: dateFilterBox),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: resultDropdownBox),
          ],
        );
      },
    );
  }

  Widget _buildDateRangeFilterButton(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final hasDateFilter =
        viewModel.historyFromDate != null || viewModel.historyToDate != null;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final pickedRange = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          initialDateRange:
              viewModel.historyFromDate != null &&
                  viewModel.historyToDate != null
              ? DateTimeRange(
                  start: viewModel.historyFromDate!,
                  end: viewModel.historyToDate!,
                )
              : null,
          helpText: 'Chọn khoảng thời gian phân tích',
          cancelText: 'Hủy',
          confirmText: 'Áp dụng',
        );
        if (pickedRange != null) {
          viewModel.setHistoryDateRange(pickedRange);
        }
      },
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD8E2EE), width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_outlined,
              size: 19,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                viewModel.formattedDateRangeLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasDateFilter ? FontWeight.w600 : FontWeight.w500,
                  color: hasDateFilter
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasDateFilter)
              InkWell(
                onTap: () => viewModel.clearHistoryDateRange(),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTypeDropdown(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8E2EE), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 19,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: viewModel.selectedHistoryResultFilter,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF475569),
                  size: 22,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
                items: viewModel.historyResultFilterOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) => viewModel.setHistoryResultFilter(value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // THẺ HIỂN THỊ TỪNG BẢN GHI LỊCH SỬ PHÂN TÍCH
  // ===========================================================================

  Widget _buildHistoryItemCard(
    BuildContext context,
    UserViewModel viewModel,
    AnalysisHistoryItemModel item,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => viewModel.onHistoryItemTapped(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EEF5), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060D2B6B),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Ảnh thu nhỏ (Thumbnail) mô phỏng vùng da tổn thương bo góc
              _buildWoundThumbnail(item),
              const SizedBox(width: 16),

              // Cột giữa: Tên loại tổn thương (kèm %) và Vị trí tổn thương
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayTitle,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.locationLabel,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Cột phải: Ngày giờ phân tích & Icon mũi tên '>'
              Text(
                item.timestamp,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vẽ ảnh thu nhỏ (Thumbnail) bo góc mô phỏng trực quan vùng da và vết thương
  Widget _buildWoundThumbnail(AnalysisHistoryItemModel item) {
    final isClear = item.confidencePercent == null;

    return Container(
      width: 64,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            item.baseSkinColor,
            Color.lerp(item.baseSkinColor, const Color(0xFFB57B62), 0.35)!,
          ],
        ),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vùng tấy đỏ nhẹ quanh tổn thương
          Container(
            width: isClear ? 14 : 28,
            height: isClear ? 14 : 22,
            decoration: BoxDecoration(
              color: item.woundAccentColor.withValues(
                alpha: isClear ? 0.25 : 0.42,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // Điểm trung tâm vết thương
          if (!isClear)
            Container(
              width: 14,
              height: 8,
              decoration: BoxDecoration(
                color: item.woundAccentColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, UserViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_toggle_off_outlined,
            size: 44,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          const Text(
            'Không tìm thấy bản ghi lịch sử phù hợp với bộ lọc.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              viewModel.clearHistoryDateRange();
              viewModel.setHistoryResultFilter('Tất cả kết quả');
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Đặt lại bộ lọc'),
          ),
        ],
      ),
    );
  }
}
