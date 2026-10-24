import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../viewmodels/user_viewmodel.dart';

class UserView extends StatelessWidget {
  const UserView({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe dữ liệu và trạng thái từ UserViewModel
    final viewModel = context.watch<UserViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1240),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F0D2B6B),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Thanh điều hướng trên cùng dùng chung cho toàn ứng dụng
                _buildTopNavigationBar(context, viewModel),

                // Đường kẻ phân tách mảnh dưới Header khi ở màn hình Phân tích ảnh AI
                if (viewModel.currentScreenIndex == 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE8EEF5),
                  ),

                // 2. Chuyển đổi mượt mà giữa Trang chủ (0) và Phân tích ảnh AI (1)
                if (viewModel.currentScreenIndex == 0)
                  _buildHomeScreenBody(context, viewModel)
                else
                  _buildAiAnalysisScreenBody(context, viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PHẦN DÙNG CHUNG: THANH ĐIỀU HƯỚNG TRÊN CÙNG (TOP NAVIGATION BAR)
  // ===========================================================================

  Widget _buildTopNavigationBar(BuildContext context, UserViewModel viewModel) {
    final isHomeScreen = viewModel.currentScreenIndex == 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;

          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              // Bên trái: Logo trái tim xanh dương có dấu cộng trắng + Tên thương hiệu
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.read<UserViewModel>().navigateToHome(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: Stack(
                        alignment: Alignment.center,
                        children: const [
                          Icon(
                            Icons.favorite,
                            color: Color(0xFF2563EB),
                            size: 38,
                          ),
                          Icon(Icons.add, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Trợ lý Cứu hộ AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2B6B),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Ở giữa: Hiển thị 4 mục menu ngang khi ở Trang chủ
              if (isHomeScreen)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(viewModel.navItems.length, (index) {
                      final isSelected = viewModel.selectedNavIndex == index;
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 8 : 16,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => context
                              .read<UserViewModel>()
                              .selectNavIndex(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              viewModel.navItems[index],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

              // Bên phải: Nút tìm kiếm (ở Trang chủ) + Ảnh đại diện & Tên "Nguyễn Văn A" (ở Màn hình 2)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHomeScreen) ...[
                    IconButton(
                      onPressed: () =>
                          context.read<UserViewModel>().onSearchPressed(),
                      icon: const Icon(
                        Icons.search,
                        color: Color(0xFF475569),
                        size: 22,
                      ),
                      tooltip: 'Tìm kiếm',
                    ),
                    const SizedBox(width: 8),
                  ],
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () =>
                        context.read<UserViewModel>().onProfileAvatarPressed(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFFE2E8F0),
                            child: Icon(
                              Icons.person,
                              color: Color(0xFF0F2942),
                              size: 22,
                            ),
                          ),
                          if (!isHomeScreen) ...[
                            const SizedBox(width: 10),
                            Text(
                              viewModel.currentUserName,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // MÀN HÌNH 1: NỘI DUNG TRANG CHỦ (GIỮ NGUYÊN 100% TỪ BƯỚC TRƯỚC)
  // ===========================================================================

  Widget _buildHomeScreenBody(BuildContext context, UserViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroSection(context, viewModel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeatureCardsSection(context, viewModel),
              const SizedBox(height: 36),
              _buildCommonSituationsSection(context, viewModel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection(BuildContext context, UserViewModel viewModel) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBF4FF), Color(0xFFDCEBFE)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: _buildHeroLeftColumn(context)),
                const SizedBox(width: 32),
                Expanded(flex: 5, child: _buildHeroRightIllustration()),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroLeftColumn(context),
                const SizedBox(height: 28),
                Center(child: _buildHeroRightIllustration()),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildHeroLeftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sơ cứu đúng cách\nBảo vệ sức khỏe\nVì một cộng đồng an toàn hơn',
          style: TextStyle(
            fontSize: 32,
            height: 1.32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D2B6B),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ứng dụng AI giúp nhận diện tổn thương, cung cấp hướng dẫn\nsơ cứu nhanh chóng và chính xác.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: () =>
                  context.read<UserViewModel>().onAnalyzeImageNowPressed(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Phân tích hình ảnh ngay'),
            ),
            OutlinedButton(
              onPressed: () =>
                  context.read<UserViewModel>().onLookupKnowledgePressed(),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D2B6B),
                side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Tra cứu kiến thức'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroRightIllustration() {
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 14,
            child: Container(
              width: 280,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0x221E3A8A),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          Positioned(
            right: 28,
            top: 24,
            child: Transform.rotate(
              angle: 0.35,
              child: const Icon(Icons.eco, size: 84, color: Color(0xFF6EE7B7)),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF93C5FD), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140D2B6B),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                size: 46,
                color: Color(0xFF1E40AF),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 16,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1D4ED8), width: 6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
              ),
              Container(
                width: 190,
                height: 145,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x331E3A8A),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 52),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 36,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x190D2B6B),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.healing, color: Color(0xFFD97706), size: 24),
                  SizedBox(width: 6),
                  Text(
                    'AI First-Aid',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCardsSection(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        int crossAxisCount = 4;
        if (maxWidth < 560) {
          crossAxisCount = 1;
        } else if (maxWidth < 920) {
          crossAxisCount = 2;
        }

        const double spacing = 20;
        final double cardWidth =
            (maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: viewModel.featureCards.map((card) {
            return SizedBox(
              width: cardWidth,
              child: _buildSingleFeatureCard(context, card),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSingleFeatureCard(BuildContext context, FeatureCardModel card) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.read<UserViewModel>().onFeatureCardTapped(card),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEFF4FB), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0D2B6B),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: card.iconBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(card.icon, color: card.iconColor, size: 26),
              ),
              const SizedBox(height: 18),
              Text(
                card.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D2B6B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                card.description,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommonSituationsSection(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tình huống thường gặp',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D2B6B),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            int columns = 5;
            if (maxWidth < 500) {
              columns = 1;
            } else if (maxWidth < 760) {
              columns = 2;
            } else if (maxWidth < 1024) {
              columns = 3;
            }

            const double spacing = 16;
            final double itemWidth =
                (maxWidth - (spacing * (columns - 1))) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: viewModel.commonSituations.map((situation) {
                return SizedBox(
                  width: itemWidth,
                  child: _buildSituationCard(context, situation),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSituationCard(
    BuildContext context,
    CommonSituationModel situation,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.read<UserViewModel>().onSituationCardTapped(situation),
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEFF4FB), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0D2B6B),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10.5),
                ),
                child: SizedBox(
                  height: 100,
                  child: _buildSafeSituationImage(situation),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Center(
                    child: Text(
                      situation.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D2B6B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeSituationImage(CommonSituationModel situation) {
    if (situation.imageUrl != null && situation.imageUrl!.isNotEmpty) {
      return Image.network(
        situation.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderWoundGraphic(situation);
        },
      );
    }
    return _buildPlaceholderWoundGraphic(situation);
  }

  Widget _buildPlaceholderWoundGraphic(CommonSituationModel situation) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            situation.baseSkinColor,
            situation.baseSkinColor.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  situation.woundAccentColor.withValues(alpha: 0.75),
                  situation.woundAccentColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Icon(
            situation.medicalIcon,
            color: Colors.white.withValues(alpha: 0.9),
            size: 22,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MÀN HÌNH 2: PHÂN TÍCH ẢNH AI (NGƯỜI DÙNG) THEO ẢNH THIẾT KẾ MỚI
  // ===========================================================================

  Widget _buildAiAnalysisScreenBody(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 780;

        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cột trái: Sidebar điều hướng 6 mục (Cố định 250px)
                SizedBox(
                  width: 250,
                  child: _buildLeftSidebar(context, viewModel, isWide: true),
                ),

                // Đường kẻ dọc phân tách Sidebar và Nội dung chính
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFE8EEF5),
                ),

                // Cột phải: Nội dung Phân tích hình ảnh tổn thương
                Expanded(
                  child: _buildAiAnalysisMainContent(context, viewModel),
                ),
              ],
            ),
          );
        } else {
          // Trên màn hình hẹp (< 780px): Xếp dọc để chống lỗi RenderFlex overflowed
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLeftSidebar(context, viewModel, isWide: false),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE8EEF5)),
              _buildAiAnalysisMainContent(context, viewModel),
            ],
          );
        }
      },
    );
  }

  /// Xây dựng thanh Sidebar bên trái gồm 6 mục menu có icon
  Widget _buildLeftSidebar(
    BuildContext context,
    UserViewModel viewModel, {
    required bool isWide,
  }) {
    return Container(
      color: const Color(0xFFFAFBFD),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isWide ? 24 : 14),
      child: isWide
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(
                viewModel.sidebarMenuItems.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildSidebarMenuItem(context, viewModel, index),
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  viewModel.sidebarMenuItems.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildSidebarMenuItem(context, viewModel, index),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSidebarMenuItem(
    BuildContext context,
    UserViewModel viewModel,
    int index,
  ) {
    final item = viewModel.sidebarMenuItems[index];
    final isSelected = viewModel.selectedSidebarIndex == index;

    return Material(
      color: isSelected ? const Color(0xFFE8F1FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.read<UserViewModel>().selectSidebarIndex(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 21,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF475569),
              ),
              const SizedBox(width: 12),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Xây dựng khu vực nội dung chính bên phải: "Phân tích hình ảnh tổn thương"
  Widget _buildAiAnalysisMainContent(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final spec = viewModel.uploadSpec;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tiêu đề chính: "Phân tích hình ảnh tổn thương"
          Text(
            spec.screenTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),

          // 2. Khung viền nét đứt Kéo thả hoặc Chọn ảnh
          _buildDashedUploadArea(context, spec),
          const SizedBox(height: 28),

          // 3. Dòng phân cách "Hoặc chụp ảnh"
          _buildOrCaptureDivider(spec.dividerText),
          const SizedBox(height: 24),

          // 4. Nút "Chụp ảnh bằng camera" căn giữa
          Center(
            child: _buildCameraCaptureButton(context, spec.cameraButtonLabel),
          ),
          const SizedBox(height: 32),

          // 5. Hộp lưu ý màu xanh nhạt ở dưới cùng
          _buildBottomWarningNotice(spec),
        ],
      ),
    );
  }

  /// Khung tải ảnh có viền nét đứt (Dashed Border) chuẩn theo ảnh thiết kế
  Widget _buildDashedUploadArea(BuildContext context, AiUploadSpecModel spec) {
    return CustomPaint(
      painter: const _DashedBorderPainter(
        color: Color(0xFFBFDBFE),
        strokeWidth: 1.8,
        dashLength: 7.0,
        gapLength: 5.0,
        borderRadius: 14.0,
      ),
      child: Material(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () =>
              context.read<UserViewModel>().onSelectImageFromFilePressed(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon đám mây xanh dương ở giữa
                SizedBox(
                  width: 68,
                  height: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: const [
                      Icon(
                        Icons.cloud_outlined,
                        size: 64,
                        color: Color(0xFF2563EB),
                      ),
                      Positioned(
                        bottom: 10,
                        child: Icon(
                          Icons.add,
                          size: 26,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dòng chữ: "Kéo thả ảnh vào đây hoặc chọn ảnh"
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D2B6B),
                    ),
                    children: [
                      TextSpan(text: spec.dropzonePrefixText),
                      TextSpan(
                        text: spec.dropzoneActionText,
                        style: const TextStyle(color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Dòng phụ: "Hỗ trợ: JPG, PNG, WEBP (tối đa 10MB)"
                Text(
                  spec.supportedFormatsText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 22),

                // Nút bấm "Chọn ảnh" màu xanh dương
                ElevatedButton(
                  onPressed: () => context
                      .read<UserViewModel>()
                      .onSelectImageFromFilePressed(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 38,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(spec.selectButtonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dòng kẻ ngang kèm chữ "Hoặc chụp ảnh" ở chính giữa
  Widget _buildOrCaptureDivider(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
      ],
    );
  }

  /// Nút "Chụp ảnh bằng camera" có viền sáng, bo góc và icon máy ảnh nền xanh nhạt
  Widget _buildCameraCaptureButton(BuildContext context, String label) {
    return OutlinedButton(
      onPressed: () =>
          context.read<UserViewModel>().onCaptureFromCameraPressed(),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D2B6B),
        side: const BorderSide(color: Color(0xFFD8E3F2), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEBF2FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D2B6B),
            ),
          ),
        ],
      ),
    );
  }

  /// Hộp thông báo lưu ý màu xanh nhạt ở dưới cùng
  Widget _buildBottomWarningNotice(AiUploadSpecModel spec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF2563EB),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.noticeBoldText,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D2B6B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.noticeDetailText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF334155),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter vẽ đường viền nét đứt bo góc (Dashed Rounded Border)
/// Sử dụng 100% thư viện chuẩn của Flutter mà không cần cài thêm package ngoài.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLength = 6.0,
    this.gapLength = 4.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final r = math.min(borderRadius, math.min(size.width, size.height) / 2);

    // Vẽ 4 cạnh thẳng nét đứt
    _drawDashedLine(canvas, paint, Offset(r, 0), Offset(size.width - r, 0));
    _drawDashedLine(
      canvas,
      paint,
      Offset(size.width, r),
      Offset(size.width, size.height - r),
    );
    _drawDashedLine(
      canvas,
      paint,
      Offset(size.width - r, size.height),
      Offset(r, size.height),
    );
    _drawDashedLine(canvas, paint, Offset(0, size.height - r), Offset(0, r));

    // Vẽ 4 góc bo tròn
    if (r > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(r, r), radius: r),
        math.pi,
        math.pi / 2,
        false,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width - r, r), radius: r),
        -math.pi / 2,
        math.pi / 2,
        false,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width - r, size.height - r),
          radius: r,
        ),
        0,
        math.pi / 2,
        false,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(r, size.height - r), radius: r),
        math.pi / 2,
        math.pi / 2,
        false,
        paint,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    final totalDistance = (end - start).distance;
    if (totalDistance <= 0) return;

    final direction = (end - start) / totalDistance;
    double currentDistance = 0;

    while (currentDistance < totalDistance) {
      final nextDistance = math.min(
        currentDistance + dashLength,
        totalDistance,
      );
      canvas.drawLine(
        start + direction * currentDistance,
        start + direction * nextDistance,
        paint,
      );
      currentDistance += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength ||
        oldDelegate.borderRadius != borderRadius;
  }
}
