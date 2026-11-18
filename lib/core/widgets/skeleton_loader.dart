// File: lib/core/widgets/skeleton_loader.dart
import 'package:flutter/material.dart';

/// Widget tạo hiệu ứng lượn sóng (Shimmer Effect) mượt mà cho các trạng thái tải dữ liệu
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Duration period;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Khung chữ nhật Skeleton giả lập dòng văn bản hoặc card
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Card mẫu Skeleton cho danh sách Bác sĩ, Lịch sử hoặc Bài học
class SkeletonCardItem extends StatelessWidget {
  const SkeletonCardItem({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 56, height: 56, borderRadius: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: MediaQuery.of(context).size.width * 0.45, height: 16),
                  const SizedBox(height: 8),
                  SkeletonBox(width: MediaQuery.of(context).size.width * 0.65, height: 12),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      SkeletonBox(width: 70, height: 22, borderRadius: 11),
                      SizedBox(width: 8),
                      SkeletonBox(width: 90, height: 22, borderRadius: 11),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
