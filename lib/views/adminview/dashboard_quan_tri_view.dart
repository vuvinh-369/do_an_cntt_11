import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin_model.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 've_do_hoa_quan_tri_view.dart';

class DashboardQuanTriView extends StatelessWidget {
  const DashboardQuanTriView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminViewModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tiêu đề chính "Dashboard"
          Text(
            viewModel.dashboardScreenTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),

          // 2. Hàng trên: 3 Thẻ chỉ số KPI (Tổng lượt phân tích, Tổng tài liệu, Người dùng)
          _buildKpiCardsRow(viewModel.kpiCards),
          const SizedBox(height: 22),

          // 3. Hàng dưới: Thẻ "Thống kê loại tổn thương" (Trái) & "Hoạt động gần đây" (Phải)
          _buildBottomAnalyticsSection(viewModel),
        ],
      ),
    );
  }

  // ===========================================================================
  // HÀNG TRÊN: 3 THẺ CHỈ SỐ KPI (KPI SUMMARY CARDS)
  // ===========================================================================

  Widget _buildKpiCardsRow(List<AdminKpiCardModel> kpiCards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 680;

        if (isCompact) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: kpiCards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildSingleKpiCard(card),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(kpiCards.length, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < kpiCards.length - 1 ? 18 : 0,
                ),
                child: _buildSingleKpiCard(kpiCards[index]),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSingleKpiCard(AdminKpiCardModel card) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF5), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080D2B6B),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng tiêu đề thẻ + Icon trong khung vuông xanh nhạt
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: card.iconBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(card.icon, size: 20, color: card.iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  card.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Con số thống kê chính (1,248 | 85 | 2,341)
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              card.mainValue,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: card.valueColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Dòng tăng trưởng (+12% so với tuần trước)
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text: '${card.growthHighlight} ',
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: card.growthComparisonText,
                    style: const TextStyle(color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HÀNG DƯỚI: THỐNG KÊ LOẠI TỔN THƯƠNG (TRÁI) & HOẠT ĐỘNG GẦN ĐÂY (PHẢI)
  // ===========================================================================

  Widget _buildBottomAnalyticsSection(AdminViewModel viewModel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        // Tính toán trước chiều rộng thực tế bên trong thẻ thống kê tổn thương
        // để không cần dùng LayoutBuilder lồng bên trong gây xung đột RenderBox
        final estimatedLeftCardInnerWidth = isWide
            ? ((constraints.maxWidth - 18) * 0.62) - 48
            : constraints.maxWidth - 48;
        final isNarrowInjuryCard = estimatedLeftCardInnerWidth < 430;

        final injuryChartCard = _buildInjuryStatisticsCard(
          viewModel,
          isNarrowCard: isNarrowInjuryCard,
        );
        final recentActivityCard = _buildRecentActivitiesCard(viewModel);

        if (isWide) {
          // ĐÃ XÓA IntrinsicHeight VÀ ĐỔI CrossAxisAlignment.stretch -> CrossAxisAlignment.start
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 62, child: injuryChartCard),
              const SizedBox(width: 18),
              Expanded(flex: 38, child: recentActivityCard),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            injuryChartCard,
            const SizedBox(height: 18),
            recentActivityCard,
          ],
        );
      },
    );
  }

  Widget _buildInjuryStatisticsCard(
    AdminViewModel viewModel, {
    required bool isNarrowCard,
  }) {
    final donutChartWidget = SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(190, 190),
            painter: AdminInjuryDonutChartPainter(
              segments: viewModel.injuryDistributionStats,
              strokeWidth: 34,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                viewModel.donutCenterCountText,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                viewModel.donutCenterUnitText,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final legendWidget = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: viewModel.injuryDistributionStats.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              Text(
                item.formattedPercentage,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 295),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF5), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080D2B6B),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            viewModel.injuryStatsCardTitle,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 24),
          if (isNarrowCard)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                donutChartWidget,
                const SizedBox(height: 20),
                legendWidget,
              ],
            )
          else
            Row(
              children: [
                const SizedBox(width: 8),
                donutChartWidget,
                const SizedBox(width: 32),
                Expanded(child: legendWidget),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesCard(AdminViewModel viewModel) {
    return Container(
      constraints: const BoxConstraints(minHeight: 295),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF5), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080D2B6B),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            viewModel.recentActivitiesCardTitle,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 18),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(viewModel.recentActivities.length, (index) {
              final activity = viewModel.recentActivities[index];
              final isLast = index == viewModel.recentActivities.length - 1;

              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        activity.icon,
                        size: 20,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activity.relativeTime,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
