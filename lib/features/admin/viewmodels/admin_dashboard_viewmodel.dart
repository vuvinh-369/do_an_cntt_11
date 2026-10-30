import 'package:flutter/material.dart';

import '../models/admin_dashboard_models.dart';
import 'admin_navigation_viewmodel.dart';

mixin DashboardQuanTriViewModel on DieuHuongQuanTriViewModel {
  // Tiêu đề chính trên Màn hình 10
  final String dashboardScreenTitle = 'Dashboard';

  // Tiêu đề của 2 thẻ lớn ở hàng dưới
  final String injuryStatsCardTitle = 'Thống kê loại tổn thương';
  final String recentActivitiesCardTitle = 'Hoạt động gần đây';

  // Số liệu trung tâm biểu đồ Donut
  final String donutCenterCountText = '1,248';
  final String donutCenterUnitText = 'lượt';

  // Danh sách 3 Thẻ chỉ số KPI ở hàng trên cùng của Màn hình 10
  final List<AdminKpiCardModel> kpiCards = const [
    AdminKpiCardModel(
      id: 'total_analyses',
      title: 'Tổng lượt phân tích',
      mainValue: '1,248',
      growthHighlight: '+12%',
      growthComparisonText: 'so với tuần trước',
      icon: Icons.center_focus_strong_outlined,
      iconColor: Color(0xFF2563EB),
      iconBackgroundColor: Color(0xFFE8F1FF),
      valueColor: Color(0xFF2563EB),
    ),
    AdminKpiCardModel(
      id: 'total_documents',
      title: 'Tổng tài liệu',
      mainValue: '85',
      growthHighlight: '+5%',
      growthComparisonText: 'so với tuần trước',
      icon: Icons.description_outlined,
      iconColor: Color(0xFF2563EB),
      iconBackgroundColor: Color(0xFFE8F1FF),
      valueColor: Color(0xFF0F172A),
    ),
    AdminKpiCardModel(
      id: 'total_users',
      title: 'Người dùng',
      mainValue: '2,341',
      growthHighlight: '+18%',
      growthComparisonText: 'so với tuần trước',
      icon: Icons.people_alt_outlined,
      iconColor: Color(0xFF0EA5E9),
      iconBackgroundColor: Color(0xFFE0F2FE),
      valueColor: Color(0xFF2563EB),
    ),
  ];

  // Danh sách 5 phân khúc trong "Thống kê loại tổn thương" (Tổng: 32 + 21 + 18 + 15 + 14 = 100%)
  final List<AdminInjuryStatItemModel> injuryDistributionStats = const [
    AdminInjuryStatItemModel(
      id: 'abrasion',
      label: 'Trầy xước',
      percentage: 32,
      color: Color(0xFF3B66F5),
    ),
    AdminInjuryStatItemModel(
      id: 'cut_laceration',
      label: 'Vết cắt / Vết rách',
      percentage: 21,
      color: Color(0xFF5B8DEF),
    ),
    AdminInjuryStatItemModel(
      id: 'burn',
      label: 'Bỏng',
      percentage: 18,
      color: Color(0xFFEC629A),
    ),
    AdminInjuryStatItemModel(
      id: 'bruise',
      label: 'Bầm',
      percentage: 15,
      color: Color(0xFFF5A623),
    ),
    AdminInjuryStatItemModel(
      id: 'other',
      label: 'Khác',
      percentage: 14,
      color: Color(0xFF48B89F),
    ),
  ];

  // Danh sách 4 mục trong thẻ "Hoạt động gần đây" trên Màn hình 10
  final List<AdminRecentActivityModel> recentActivities = const [
    AdminRecentActivityModel(
      id: 'act_1',
      title: 'Thêm kiến thức mới',
      relativeTime: '2 giờ trước',
      icon: Icons.add_box_outlined,
    ),
    AdminRecentActivityModel(
      id: 'act_2',
      title: 'Cập nhật rule engine',
      relativeTime: '4 giờ trước',
      icon: Icons.rule_outlined,
    ),
    AdminRecentActivityModel(
      id: 'act_3',
      title: 'Thêm tài liệu y tế',
      relativeTime: '6 giờ trước',
      icon: Icons.note_add_outlined,
    ),
    AdminRecentActivityModel(
      id: 'act_4',
      title: 'Phân tích ảnh mới',
      relativeTime: '8 giờ trước',
      icon: Icons.center_focus_strong_outlined,
    ),
  ];
}
