import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/admin_dashboard_models.dart';

/// Vẽ họa tiết sóng nền mềm mại cho khung thẻ Đăng nhập quản trị (Màn hình 9)
class AdminLoginWaveBackgroundPainter extends CustomPainter {
  const AdminLoginWaveBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bottomWavePaint = Paint()
      ..color = const Color(0xFFE9F0FA).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final bottomPath = Path()
      ..moveTo(size.width * 0.22, size.height)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.80,
        size.width * 0.56,
        size.height * 0.86,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.93,
        size.width,
        size.height * 0.78,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(bottomPath, bottomWavePaint);

    final topCornerPaint = Paint()
      ..color = const Color(0xFFDCE8FC).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final topCornerPath = Path()
      ..moveTo(size.width * 0.84, 0)
      ..quadraticBezierTo(
        size.width * 0.86,
        size.height * 0.16,
        size.width,
        size.height * 0.14,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(topCornerPath, topCornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vẽ hình minh họa Laptop và Khiên bảo mật có dấu tích trắng (Cột phải Màn hình 9)
class AdminSecurityIllustrationPainter extends CustomPainter {
  const AdminSecurityIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.52;

    final stemPaint = Paint()
      ..color = const Color(0xFFA5B8D8)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafFillPaint = Paint()
      ..color = const Color(0xFFC5D6F2)
      ..style = PaintingStyle.fill;

    final leftStem = Path()
      ..moveTo(cx - 64, cy + 44)
      ..quadraticBezierTo(cx - 86, cy + 5, cx - 80, cy - 36);
    canvas.drawPath(leftStem, stemPaint);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 88, cy - 52), width: 22, height: 14),
      leafFillPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 102, cy - 10), width: 18, height: 11),
      leafFillPaint,
    );

    canvas.drawCircle(
      Offset(cx + 88, cy - 16),
      4,
      Paint()..color = const Color(0xFFB8CCF0),
    );
    canvas.drawCircle(
      Offset(cx + 76, cy + 12),
      6,
      Paint()
        ..color = const Color(0xFFA3BBE6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final baseShadowPaint = Paint()
      ..color = const Color(0xFFCBD9F2)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 58), width: 210, height: 14),
      baseShadowPaint,
    );

    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 8), width: 138, height: 90),
      const Radius.circular(8),
    );

    final screenOuterPaint = Paint()
      ..color = const Color(0xFFB8CBEB)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(screenRect, screenOuterPaint);

    final screenInnerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 8), width: 126, height: 78),
      const Radius.circular(5),
    );
    final screenInnerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE1ECFF), Color(0xFFC7DAFA)],
      ).createShader(screenInnerRect.outerRect);
    canvas.drawRRect(screenInnerRect, screenInnerPaint);

    final screenHighlightPath = Path()
      ..moveTo(cx - 50, cy - 30)
      ..lineTo(cx - 15, cy - 30)
      ..lineTo(cx - 45, cy + 46)
      ..lineTo(cx - 62, cy + 46)
      ..close();
    canvas.drawPath(
      screenHighlightPath,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    final laptopBasePath = Path()
      ..moveTo(cx - 82, cy + 50)
      ..lineTo(cx + 82, cy + 50)
      ..lineTo(cx + 92, cy + 58)
      ..lineTo(cx - 92, cy + 58)
      ..close();
    canvas.drawPath(laptopBasePath, Paint()..color = const Color(0xFF9EB6E0));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 52), width: 28, height: 3),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF7B97C9),
    );

    final shieldCenterX = cx + 4;
    final shieldTopY = cy - 68;
    const shieldWidth = 76.0;
    const shieldHeight = 88.0;

    Path buildShieldPath(double cxShield, double topY, double w, double h) {
      final halfW = w / 2;
      return Path()
        ..moveTo(cxShield, topY)
        ..quadraticBezierTo(
          cxShield + halfW * 0.45,
          topY + h * 0.08,
          cxShield + halfW,
          topY + h * 0.14,
        )
        ..quadraticBezierTo(
          cxShield + halfW,
          topY + h * 0.62,
          cxShield,
          topY + h,
        )
        ..quadraticBezierTo(
          cxShield - halfW,
          topY + h * 0.62,
          cxShield - halfW,
          topY + h * 0.14,
        )
        ..quadraticBezierTo(
          cxShield - halfW * 0.45,
          topY + h * 0.08,
          cxShield,
          topY,
        )
        ..close();
    }

    final shieldShadowPath = buildShieldPath(
      shieldCenterX + 2,
      shieldTopY + 5,
      shieldWidth + 4,
      shieldHeight + 4,
    );
    canvas.drawPath(
      shieldShadowPath,
      Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.18),
    );

    final outerShieldPath = buildShieldPath(
      shieldCenterX,
      shieldTopY,
      shieldWidth,
      shieldHeight,
    );
    final outerShieldPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF93BBFB), Color(0xFF609AF8)],
          ).createShader(
            Rect.fromLTWH(
              shieldCenterX - shieldWidth / 2,
              shieldTopY,
              shieldWidth,
              shieldHeight,
            ),
          );
    canvas.drawPath(outerShieldPath, outerShieldPaint);

    final innerShieldPath = buildShieldPath(
      shieldCenterX,
      shieldTopY + 7,
      shieldWidth - 14,
      shieldHeight - 14,
    );
    final innerShieldPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF609AFA), Color(0xFF3B76E6)],
          ).createShader(
            Rect.fromLTWH(
              shieldCenterX - (shieldWidth - 14) / 2,
              shieldTopY + 7,
              shieldWidth - 14,
              shieldHeight - 14,
            ),
          );
    canvas.drawPath(innerShieldPath, innerShieldPaint);

    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(shieldCenterX - 13, shieldTopY + 45)
      ..lineTo(shieldCenterX - 3, shieldTopY + 55)
      ..lineTo(shieldCenterX + 15, shieldTopY + 33);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vẽ Biểu đồ vòng (Donut Chart) cho thẻ "Thống kê loại tổn thương" (Màn hình 10)
class AdminInjuryDonutChartPainter extends CustomPainter {
  final List<AdminInjuryStatItemModel> segments;
  final double strokeWidth;

  const AdminInjuryDonutChartPainter({
    required this.segments,
    this.strokeWidth = 34.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = segments.fold<int>(0, (sum, item) => sum + item.percentage);
    if (total <= 0) return;

    // Bắt đầu vẽ từ góc -110 độ (phía trên hơi lệch trái giống hệt ảnh thiết kế Màn hình 10)
    double startAngle = -110 * (math.pi / 180.0);
    const double gapRadians =
        0.035; // Khe trắng mảnh phân tách giữa các cung màu

    for (final segment in segments) {
      final sweepAngle = (segment.percentage / total) * (2 * math.pi);
      final adjustedSweep = math.max(0.01, sweepAngle - gapRadians);

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect,
        startAngle + (gapRadians / 2),
        adjustedSweep,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant AdminInjuryDonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
