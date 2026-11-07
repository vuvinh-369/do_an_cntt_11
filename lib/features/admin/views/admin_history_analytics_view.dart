import 'package:flutter/material.dart';

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


