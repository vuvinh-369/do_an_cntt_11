import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../viewmodels/user_viewmodel.dart';

class UserView extends StatelessWidget {
  const UserView({super.key});

  @override
  Widget build(BuildContext context) {
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

                // Đường kẻ phân tách mảnh dưới Header khi ở các màn hình có Sidebar
                if (viewModel.currentScreenIndex != 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE8EEF5),
                  ),

                // 2. Chuyển đổi giữa Trang chủ (0) và Không gian làm việc có Sidebar (1..6)
                if (viewModel.currentScreenIndex == 0)
                  _buildHomeScreenBody(context, viewModel)
                else
                  _buildAiWorkspaceBody(context, viewModel),
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

              // Bên phải: Nút tìm kiếm (ở Trang chủ) + Ảnh đại diện & Tên "Nguyễn Văn A"
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
  // MÀN HÌNH 1: NỘI DUNG TRANG CHỦ
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
  // KHUNG BỐ CỤC CHUNG CHO MÀN HÌNH 2, 3, 4, 5, 6 & 7 (CÓ SIDEBAR BÊN TRÁI)
  // ===========================================================================

  Widget _buildAiWorkspaceBody(BuildContext context, UserViewModel viewModel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 780;

        final Widget rightContent;
        if (viewModel.currentScreenIndex == 6) {
          rightContent = _buildMedicalDocumentsMainContent(context, viewModel);
        } else if (viewModel.currentScreenIndex == 5) {
          rightContent = _buildChatBoxAiMainContent(context, viewModel);
        } else if (viewModel.currentScreenIndex == 4) {
          rightContent = _buildKnowledgeLookupMainContent(context, viewModel);
        } else if (viewModel.currentScreenIndex == 3) {
          rightContent = _buildFirstAidGuideMainContent(context, viewModel);
        } else if (viewModel.currentScreenIndex == 2) {
          rightContent = _buildAnalysisResultMainContent(context, viewModel);
        } else {
          rightContent = _buildAiAnalysisMainContent(context, viewModel);
        }

        if (isWide) {
          return CustomPaint(
            painter: const _WorkspaceSidebarBackgroundPainter(
              sidebarWidth: 250,
              backgroundColor: Color(0xFFFAFBFD),
              dividerColor: Color(0xFFE8EEF5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 250,
                  child: _buildLeftSidebar(context, viewModel, isWide: true),
                ),
                const SizedBox(width: 1),
                Expanded(child: rightContent),
              ],
            ),
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLeftSidebar(context, viewModel, isWide: false),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE8EEF5)),
              rightContent,
            ],
          );
        }
      },
    );
  }

  Widget _buildLeftSidebar(
    BuildContext context,
    UserViewModel viewModel, {
    required bool isWide,
  }) {
    return Container(
      color: isWide ? Colors.transparent : const Color(0xFFFAFBFD),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isWide ? 24 : 14),
      child: isWide
          ? Column(
              mainAxisSize: MainAxisSize.min,
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

  // ===========================================================================
  // MÀN HÌNH 2: TẢI ẢNH / CHỤP ẢNH PHÂN TÍCH AI
  // ===========================================================================

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
          _buildDashedUploadArea(context, spec),
          const SizedBox(height: 28),
          _buildOrCaptureDivider(spec.dividerText),
          const SizedBox(height: 24),
          Center(
            child: _buildCameraCaptureButton(context, spec.cameraButtonLabel),
          ),
          const SizedBox(height: 32),
          _buildBottomWarningNotice(spec),
        ],
      ),
    );
  }

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

  // ===========================================================================
  // MÀN HÌNH 3: KẾT QUẢ PHÂN TÍCH (NGƯỜI DÙNG)
  // ===========================================================================

  Widget _buildAnalysisResultMainContent(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final result = viewModel.analysisResult;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopConfidenceBanner(result),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoColumn = constraints.maxWidth >= 660;

              if (isTwoColumn) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 46,
                      child: _buildAnalyzedWoundImageCard(result),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      flex: 54,
                      child: _buildRightIdentificationColumn(
                        context,
                        viewModel,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAnalyzedWoundImageCard(result),
                    const SizedBox(height: 24),
                    _buildRightIdentificationColumn(context, viewModel),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 26),
          _buildResultBottomInfoNotice(result.bottomNoticeText),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: _buildViewFirstAidGuideButton(
              context,
              result.primaryActionLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopConfidenceBanner(AiAnalysisResultModel result) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981), width: 1.8),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF059669),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.bannerTitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  result.bannerConfidenceText,
                  style: const TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzedWoundImageCard(AiAnalysisResultModel result) {
    return Container(
      height: 336,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140D2B6B),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (result.analyzedImageUrl != null &&
              result.analyzedImageUrl!.isNotEmpty)
            Image.network(
              result.analyzedImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const CustomPaint(painter: _ForearmAbrasionPainter());
              },
            )
          else
            const CustomPaint(painter: _ForearmAbrasionPainter()),
          Center(
            child: SizedBox(
              width: 196,
              height: 196,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                    child: Text(
                      result.boundingBoxLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF22C55E),
                          width: 2.5,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(6),
                        ),
                      ),
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

  Widget _buildRightIdentificationColumn(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final result = viewModel.analysisResult;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.infoCardTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D2B6B),
                ),
              ),
              const SizedBox(height: 18),
              _buildIdentificationInfoRow(
                label: result.injuryTypeLabel,
                value: result.injuryType,
              ),
              const SizedBox(height: 14),
              _buildIdentificationInfoRow(
                label: result.confidenceRowLabel,
                value: result.formattedConfidence,
              ),
              const SizedBox(height: 14),
              _buildIdentificationInfoRow(
                label: result.locationRowLabel,
                value: viewModel.selectedLocationLabel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          result.locationSectionTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D2B6B),
          ),
        ),
        const SizedBox(height: 14),
        _buildLocationSelectorRow(context, viewModel),
      ],
    );
  }

  Widget _buildIdentificationInfoRow({
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSelectorRow(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const double spacing = 10;
        final int count = viewModel.injuryLocations.length;

        int columns = count;
        if (maxWidth < 280) {
          columns = 2;
        } else if (maxWidth < 390) {
          columns = 3;
        }

        final double cardWidth =
            (maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: viewModel.injuryLocations.map((option) {
            final isSelected = viewModel.selectedLocationId == option.id;
            return SizedBox(
              width: cardWidth,
              child: _buildSingleLocationOptionCard(
                context,
                option: option,
                isSelected: isSelected,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSingleLocationOptionCard(
    BuildContext context, {
    required InjuryLocationOptionModel option,
    required bool isSelected,
  }) {
    final Color strokeAndTextColor = isSelected
        ? const Color(0xFF2563EB)
        : const Color(0xFF64748B);
    final Color iconStrokeColor = isSelected
        ? const Color(0xFF2563EB)
        : const Color(0xFF94A3B8);

    return Material(
      color: isSelected ? const Color(0xFFEBF2FE) : const Color(0xFFFAFBFD),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            context.read<UserViewModel>().selectInjuryLocation(option.id),
        child: Container(
          height: 98,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CustomPaint(
                  painter: _BodyPartIconPainter(
                    partId: option.id,
                    color: iconStrokeColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                option.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: strokeAndTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBottomInfoNotice(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF2563EB),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewFirstAidGuideButton(BuildContext context, String label) {
    return ElevatedButton(
      onPressed: () =>
          context.read<UserViewModel>().onViewFirstAidGuidePressed(),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward_rounded, size: 19),
        ],
      ),
    );
  }

  // ===========================================================================
  // MÀN HÌNH 4: HƯỚNG DẪN SƠ CỨU (NGƯỜI DÙNG)
  // ===========================================================================

  Widget _buildFirstAidGuideMainContent(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final guide = viewModel.firstAidGuide;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            guide.screenTitle,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          _buildInjuryStatusYellowBox(guide),
          const SizedBox(height: 24),
          Text(
            guide.stepsSectionTitle,
            style: const TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
            ),
          ),
          const SizedBox(height: 14),
          _buildFirstAidStepsTimelineCard(guide.steps),
          const SizedBox(height: 24),
          _buildWhenToSeeDoctorRedBox(guide),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: _buildBackToImageAnalysisButton(
              context,
              guide.backButtonLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInjuryStatusYellowBox(FirstAidGuideModel guide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CustomPaint(painter: _SoftAmberWarningTrianglePainter()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.statusBoxTitle,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  guide.severityText,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  guide.safetyNoteText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstAidStepsTimelineCard(List<FirstAidStepModel> steps) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050D2B6B),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(steps.length, (index) {
          final isLast = index == steps.length - 1;
          return _buildSingleFirstAidTimelineStep(
            step: steps[index],
            isLast: isLast,
          );
        }),
      ),
    );
  }

  Widget _buildSingleFirstAidTimelineStep({
    required FirstAidStepModel step,
    required bool isLast,
  }) {
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 13.25,
            top: 28,
            bottom: 0,
            width: 1.5,
            child: Container(color: const Color(0xFFCBD5E1)),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${step.stepNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(9),
                ),
                padding: const EdgeInsets.all(7),
                child: CustomPaint(
                  painter: _FirstAidStepIconPainter(stepId: step.id),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D2B6B),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhenToSeeDoctorRedBox(FirstAidGuideModel guide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  guide.redWarningTitle,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...guide.redWarningBullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF991B1B),
                      height: 1.45,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF991B1B),
                        height: 1.45,
                      ),
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

  Widget _buildBackToImageAnalysisButton(BuildContext context, String label) {
    return ElevatedButton(
      onPressed: () =>
          context.read<UserViewModel>().onBackToImageAnalysisPressed(),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ===========================================================================
  // MÀN HÌNH 5: TRA CỨU KIẾN THỨC (NGƯỜI DÙNG)
  // ===========================================================================

  Widget _buildKnowledgeLookupMainContent(
    BuildContext context,
    UserViewModel viewModel,
  ) {
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
            painter: _KnowledgeTopicThumbnailPainter(topicId: topic.id),
          );
        },
      );
    }
    return CustomPaint(
      painter: _KnowledgeTopicThumbnailPainter(topicId: topic.id),
    );
  }

  // ===========================================================================
  // MÀN HÌNH 6: CHATBOX AI (NGƯỜI DÙNG) - CUỘN TIN NHẮN & CỐ ĐỊNH THANH NHẬP
  // ===========================================================================

  Widget _buildChatBoxAiMainContent(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final double fixedChatViewportHeight = math.max(540.0, screenHeight - 135);

    return SizedBox(
      height: fixedChatViewportHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ChatBox AI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D2B6B),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hỏi đáp nhanh về các tình huống sơ cứu',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: viewModel.chatMessages.isEmpty
                  ? _buildEmptyChatWelcomeState(context, viewModel)
                  : Scrollbar(
                      controller: viewModel.chatScrollController,
                      thumbVisibility: true,
                      child: ListView.separated(
                        controller: viewModel.chatScrollController,
                        padding: const EdgeInsets.only(
                          top: 4,
                          bottom: 16,
                          right: 8,
                        ),
                        itemCount: viewModel.chatMessages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 22),
                        itemBuilder: (context, index) {
                          final message = viewModel.chatMessages[index];
                          return message.isUser
                              ? _buildUserChatMessageRow(message)
                              : _buildAiChatMessageRow(context, message);
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            _buildChatBottomInputBar(context, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatWelcomeState(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Color(0xFF2563EB),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Bắt đầu cuộc trò chuyện với Trợ lý Cứu hộ AI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D2B6B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nhập câu hỏi của bạn vào ô bên dưới hoặc chọn nhanh một tình huống gợi ý:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: viewModel.quickSuggestedQuestions.map((question) {
                return ActionChip(
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFDBEAFE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  label: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  onPressed: () =>
                      context.read<UserViewModel>().sendChatMessage(question),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserChatMessageRow(ChatMessageModel message) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Text(
                  message.messageText,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  message.timestamp,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: const CustomPaint(painter: _ChatUserPortraitAvatarPainter()),
        ),
      ],
    );
  }

  Widget _buildAiChatMessageRow(
    BuildContext context,
    ChatMessageModel message,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF93C5FD).withValues(alpha: 0.55),
              width: 2.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F2563EB),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8.5),
          child: const CustomPaint(painter: _AiShieldBadgePainter()),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.messageText,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                    height: 1.45,
                  ),
                ),
                if (message.numberedSteps.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...List.generate(message.numberedSteps.length, (index) {
                    final stepNumber = index + 1;
                    final stepContent = message.numberedSteps[index];
                    final isLastStep =
                        index == message.numberedSteps.length - 1;

                    return Padding(
                      padding: EdgeInsets.only(bottom: isLastStep ? 0 : 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              '$stepNumber.',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                                height: 1.42,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              stepContent,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF1E293B),
                                height: 1.42,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 10),
                Text(
                  message.timestamp,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatBottomInputBar(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return Container(
      height: 54,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D2B6B),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: viewModel.chatInputController,
              onChanged: (value) =>
                  context.read<UserViewModel>().updateChatInput(value),
              onSubmitted: (value) =>
                  context.read<UserViewModel>().sendChatMessage(value),
              style: const TextStyle(
                fontSize: 14.5,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Nhập câu hỏi của bạn...',
                hintStyle: TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: const Color(0xFF2563EB),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.read<UserViewModel>().sendChatMessage(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CustomPaint(painter: _PaperPlaneSendIconPainter()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MÀN HÌNH 7: KHO TÀI LIỆU Y TẾ (QUẢN LÝ TÀI LIỆU CỤC BỘ TRÊN THIẾT BỊ)
  // Đầy đủ 6 chức năng: Thêm tài liệu, Mở tài liệu, Tìm kiếm, Phân loại, Quản lý, Lưu cục bộ
  // ===========================================================================

  Widget _buildMedicalDocumentsMainContent(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hàng Tiêu đề "Kho tài liệu y tế" (Trái) + Nút "+ Thêm tài liệu" (Phải) chuẩn theo ảnh thiết kế
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Text(
                'Kho tài liệu y tế',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D2B6B),
                  letterSpacing: -0.3,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _showAddLocalDocumentDialog(context, viewModel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Thêm tài liệu',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // 2. Hàng Thanh tìm kiếm "Tìm kiếm tài liệu..." + Dropdown "Tất cả danh mục"
          _buildDocumentsSearchAndDropdownRow(context, viewModel),
          const SizedBox(height: 22),

          // 3. Khu vực chính: Cột danh mục tài liệu bên trái + Bảng danh sách tài liệu bên phải
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideContent = constraints.maxWidth >= 680;

              if (isWideContent) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột danh mục con bên trái (Tất cả (24), Sơ cứu cơ bản, Vết thương (6), Bỏng, Dị vật, Khác)
                    SizedBox(
                      width: 200,
                      child: _buildDocumentCategorySubMenu(
                        context,
                        viewModel,
                        isVertical: true,
                      ),
                    ),
                    const SizedBox(width: 22),

                    // Bảng danh sách tài liệu bên phải
                    Expanded(
                      child: _buildMedicalDocumentsTableCard(
                        context,
                        viewModel,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDocumentCategorySubMenu(
                      context,
                      viewModel,
                      isVertical: false,
                    ),
                    const SizedBox(height: 16),
                    _buildMedicalDocumentsTableCard(context, viewModel),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // 4. Thanh phân trang (< 1 2 3 >) ở góc dưới bên phải
          Align(
            alignment: Alignment.centerRight,
            child: _buildDocumentsPaginationBar(context, viewModel),
          ),
        ],
      ),
    );
  }

  /// Hàng Tìm kiếm tài liệu và Dropdown chọn danh mục
  Widget _buildDocumentsSearchAndDropdownRow(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;

        // Ô nhập tìm kiếm "Tìm kiếm tài liệu..."
        final searchBox = Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD8E3F2), width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: TextField(
            controller: viewModel.documentSearchController,
            onChanged: (value) =>
                context.read<UserViewModel>().updateDocumentSearchQuery(value),
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
                size: 20,
              ),
              hintText: 'Tìm kiếm tài liệu...',
              hintStyle: TextStyle(
                fontSize: 14.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        );

        // Hộp Dropdown "Tất cả danh mục"
        final categoryDropdown = Container(
          height: 46,
          width: isCompact ? double.infinity : 210,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD8E3F2), width: 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: viewModel.selectedDocumentCategoryId,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF475569),
                size: 22,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              items: viewModel.documentCategories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat.id,
                  child: Text(
                    cat.dropdownLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (selectedId) {
                if (selectedId != null) {
                  context.read<UserViewModel>().selectDocumentCategory(
                    selectedId,
                  );
                }
              },
            ),
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [searchBox, const SizedBox(height: 10), categoryDropdown],
          );
        }

        return Row(
          children: [
            Expanded(child: searchBox),
            const SizedBox(width: 14),
            categoryDropdown,
          ],
        );
      },
    );
  }

  /// Menu danh mục bên trái của Kho tài liệu y tế:
  /// Tất cả (24), Sơ cứu cơ bản, Vết thương (6), Bỏng, Dị vật, Khác
  Widget _buildDocumentCategorySubMenu(
    BuildContext context,
    UserViewModel viewModel, {
    required bool isVertical,
  }) {
    if (!isVertical) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: viewModel.documentCategories.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildSingleDocumentCategoryItem(context, viewModel, cat),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: viewModel.documentCategories.map((cat) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildSingleDocumentCategoryItem(context, viewModel, cat),
        );
      }).toList(),
    );
  }

  Widget _buildSingleDocumentCategoryItem(
    BuildContext context,
    UserViewModel viewModel,
    MedicalDocumentCategoryModel category,
  ) {
    final isSelected = viewModel.selectedDocumentCategoryId == category.id;
    final displayLabel = viewModel.getDocumentCategorySidebarLabel(category);

    return Material(
      color: isSelected ? const Color(0xFFE8F1FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            context.read<UserViewModel>().selectDocumentCategory(category.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CustomPaint(
                  painter: _DocumentSubCategoryIconPainter(
                    categoryId: category.id,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  displayLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bảng danh sách tài liệu y tế gồm 3 cột chuẩn thiết kế: Tên tài liệu | Danh mục | Ngày thêm
  Widget _buildMedicalDocumentsTableCard(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final docs = viewModel.filteredMedicalDocuments;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050D2B6B),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header của bảng: Tên tài liệu | Danh mục | Ngày thêm
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: const [
                Expanded(
                  flex: 52,
                  child: Text(
                    'Tên tài liệu',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                Expanded(
                  flex: 28,
                  child: Text(
                    'Danh mục',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Text(
                    'Ngày thêm',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8EEF5)),

          // Danh sách các hàng tài liệu
          if (docs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42, horizontal: 20),
              child: Center(
                child: Text(
                  'Không tìm thấy tài liệu y tế phù hợp.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ...List.generate(docs.length, (index) {
              final doc = docs[index];
              final isLast = index == docs.length - 1;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSingleMedicalDocumentRow(context, viewModel, doc),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  /// Từng dòng tài liệu trong bảng (Click vào để Mở tài liệu & Quản lý tài liệu cục bộ)
  Widget _buildSingleMedicalDocumentRow(
    BuildContext context,
    UserViewModel viewModel,
    MedicalDocumentModel doc,
  ) {
    final isHighlightedBadge = doc.categoryId == 'basic_first_aid';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _showOpenAndManageDocumentDialog(context, viewModel, doc),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cột 1: Icon tài liệu y tế nền xanh nhạt + Tên tài liệu
              Expanded(
                flex: 52,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF2FE),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const CustomPaint(
                        painter: _MedicalDocumentRowIconPainter(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            doc.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D2B6B),
                              height: 1.3,
                            ),
                          ),
                          if (doc.isUserAdded) ...[
                            const SizedBox(height: 3),
                            Text(
                              '${doc.fileName} (${doc.fileSize})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Cột 2: Nhãn Danh mục
              Expanded(
                flex: 28,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isHighlightedBadge ? 10 : 0,
                      vertical: isHighlightedBadge ? 5 : 0,
                    ),
                    decoration: isHighlightedBadge
                        ? BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          )
                        : null,
                    child: Text(
                      doc.categoryLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),

              // Cột 3: Ngày thêm
              Expanded(
                flex: 20,
                child: Text(
                  doc.dateAdded,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hộp thoại "+ Thêm tài liệu": Cho phép chọn tệp trên thiết bị, phân loại danh mục và lưu cục bộ
  void _showAddLocalDocumentDialog(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final titleController = TextEditingController();
    final fileNameController = TextEditingController(
      text: viewModel.sampleDeviceFiles.first['fileName'],
    );
    final localPathController = TextEditingController(
      text: viewModel.sampleDeviceFiles.first['localFilePath'],
    );
    final summaryController = TextEditingController();

    String selectedCategoryId = 'basic_first_aid';
    String selectedExtension =
        viewModel.sampleDeviceFiles.first['fileExtension']!;
    String selectedFileSize = viewModel.sampleDeviceFiles.first['fileSize']!;

    final selectableCategories = viewModel.documentCategories
        .where((c) => c.id != 'all')
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.upload_file_rounded,
                              color: Color(0xFF2563EB),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thêm tài liệu y tế vào thiết bị',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0D2B6B),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Lưu trữ, phân loại và mở tệp tài liệu cục bộ trên thiết bị',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),

                      // Chọn nhanh tệp từ bộ nhớ thiết bị
                      const Text(
                        '1. Chọn tệp trên thiết bị:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: viewModel.sampleDeviceFiles.map((fileInfo) {
                          final isCurrentFile =
                              fileNameController.text == fileInfo['fileName'];
                          return ActionChip(
                            backgroundColor: isCurrentFile
                                ? const Color(0xFFE8F1FF)
                                : const Color(0xFFF8FAFC),
                            side: BorderSide(
                              color: isCurrentFile
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFE2E8F0),
                            ),
                            avatar: Icon(
                              Icons.insert_drive_file_outlined,
                              size: 16,
                              color: isCurrentFile
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF64748B),
                            ),
                            label: Text(
                              fileInfo['fileName']!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isCurrentFile
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCurrentFile
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF334155),
                              ),
                            ),
                            onPressed: () {
                              setModalState(() {
                                fileNameController.text = fileInfo['fileName']!;
                                localPathController.text =
                                    fileInfo['localFilePath']!;
                                selectedExtension = fileInfo['fileExtension']!;
                                selectedFileSize = fileInfo['fileSize']!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Tên tài liệu hiển thị
                      const Text(
                        '2. Tên tài liệu y tế (*):',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'Nhập tên tài liệu (ví dụ: Sổ tay sơ cứu gia đình)',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF94A3B8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Phân loại danh mục
                      const Text(
                        '3. Phân loại danh mục:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategoryId,
                            isExpanded: true,
                            items: selectableCategories.map((cat) {
                              return DropdownMenuItem<String>(
                                value: cat.id,
                                child: Text(cat.dropdownLabel),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedCategoryId = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Đường dẫn tệp cục bộ trên thiết bị
                      const Text(
                        '4. Đường dẫn tệp lưu trữ cục bộ trên thiết bị:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: localPathController,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.folder_outlined,
                            size: 19,
                            color: Color(0xFF2563EB),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Nội dung tóm tắt / Ghi chú
                      const Text(
                        '5. Tóm tắt nội dung tài liệu:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: summaryController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'Mô tả ngắn gọn nội dung tệp tài liệu y tế...',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF94A3B8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text(
                              'Hủy',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              final enteredTitle = titleController.text.trim();
                              final finalTitle = enteredTitle.isNotEmpty
                                  ? enteredTitle
                                  : fileNameController.text
                                        .replaceAll('.pdf', '')
                                        .replaceAll('.docx', '')
                                        .replaceAll('.txt', '')
                                        .replaceAll('_', ' ');

                              viewModel.addLocalMedicalDocument(
                                title: finalTitle,
                                categoryId: selectedCategoryId,
                                fileName: fileNameController.text,
                                fileExtension: selectedExtension,
                                fileSize: selectedFileSize,
                                localFilePath: localPathController.text,
                                summary: summaryController.text,
                              );
                              Navigator.of(dialogContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text(
                              'Lưu tài liệu vào thiết bị',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Hộp thoại Mở Tài liệu & Quản lý Tài liệu Cục bộ (Xem tệp, Đổi danh mục, Sửa tên, Xóa tài liệu)
  void _showOpenAndManageDocumentDialog(
    BuildContext context,
    UserViewModel viewModel,
    MedicalDocumentModel doc,
  ) {
    bool isEditing = false;
    final editTitleController = TextEditingController(text: doc.title);
    final editSummaryController = TextEditingController(text: doc.summary);
    String editCategoryId = doc.categoryId;

    final selectableCategories = viewModel.documentCategories
        .where((c) => c.id != 'all')
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header hộp thoại mở tài liệu
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.all(9),
                            child: const CustomPaint(
                              painter: _MedicalDocumentRowIconPainter(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Quản lý & Phân loại tài liệu'
                                      : doc.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0D2B6B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F1FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        viewModel.getCategoryLabelById(
                                          editCategoryId,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Ngày thêm: ${doc.dateAdded}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Khung thông tin Tệp lưu trữ cục bộ trên thiết bị
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.sd_storage_outlined,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tệp cục bộ: ${doc.fileName} (${doc.fileExtension} • ${doc.fileSize})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Đường dẫn thiết bị: ${doc.localFilePath}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (isEditing) ...[
                        // Chế độ Quản lý & Phân loại lại tài liệu
                        const Text(
                          'Tên tài liệu:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D2B6B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: editTitleController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Phân loại danh mục:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D2B6B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: editCategoryId,
                              isExpanded: true,
                              items: selectableCategories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat.id,
                                  child: Text(cat.dropdownLabel),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    editCategoryId = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tóm tắt nội dung:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D2B6B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: editSummaryController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Chế độ Mở xem nội dung tài liệu
                        Text(
                          doc.summary,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF334155),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...doc.contentPoints.map(
                          (point) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              point,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Hàng nút chức năng: Xóa tài liệu | Sửa/Phân loại | Mở hướng dẫn sơ cứu | Đóng/Lưu
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          // Nút Xóa tài liệu khỏi thiết bị
                          TextButton.icon(
                            onPressed: () {
                              viewModel.deleteMedicalDocument(doc.id);
                              Navigator.of(dialogContext).pop();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                            ),
                            label: const Text(
                              'Xóa tài liệu',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nút Chuyển đổi giữa Xem và Sửa/Phân loại
                              OutlinedButton.icon(
                                onPressed: () {
                                  if (isEditing) {
                                    viewModel.updateMedicalDocument(
                                      id: doc.id,
                                      newTitle: editTitleController.text,
                                      newCategoryId: editCategoryId,
                                      newSummary: editSummaryController.text,
                                    );
                                    Navigator.of(dialogContext).pop();
                                  } else {
                                    setModalState(() {
                                      isEditing = true;
                                    });
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0D2B6B),
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: Icon(
                                  isEditing
                                      ? Icons.check_rounded
                                      : Icons.edit_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  isEditing
                                      ? 'Lưu thay đổi'
                                      : 'Phân loại / Sửa',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              if (!isEditing &&
                                  doc.relatedGuideTopicId != null) ...[
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    viewModel.navigateToFirstAidGuide(
                                      topicId: doc.relatedGuideTopicId,
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF2563EB),
                                    side: const BorderSide(
                                      color: Color(0xFFBFDBFE),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Hướng dẫn sơ cứu',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],

                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Đóng',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Thanh phân trang (< 1 2 3 >) ở góc dưới bên phải của Kho tài liệu y tế
  Widget _buildDocumentsPaginationBar(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPaginationArrowButton(
          icon: Icons.chevron_left_rounded,
          onTap: () => context.read<UserViewModel>().goToPreviousDocumentPage(),
        ),
        const SizedBox(width: 6),
        ...[1, 2, 3].map((page) {
          final isSelected = viewModel.currentDocumentPage == page;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Material(
              color: isSelected ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    context.read<UserViewModel>().selectDocumentPage(page),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
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
                    '$page',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 6),
        _buildPaginationArrowButton(
          icon: Icons.chevron_right_rounded,
          onTap: () => context.read<UserViewModel>().goToNextDocumentPage(),
        ),
      ],
    );
  }

  Widget _buildPaginationArrowButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }
}

// =============================================================================
// CÁC LỚP CUSTOM PAINTER VẼ ĐỒ HỌA THUẦN FLUTTER (KHÔNG PHỤ THUỘC ASSET NGOÀI)
// =============================================================================

class _MedicalDocumentRowIconPainter extends CustomPainter {
  const _MedicalDocumentRowIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 1.9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final docPath = Path()
      ..moveTo(w * 0.20, h * 0.08)
      ..lineTo(w * 0.62, h * 0.08)
      ..lineTo(w * 0.84, h * 0.30)
      ..lineTo(w * 0.84, h * 0.88)
      ..quadraticBezierTo(w * 0.84, h * 0.94, w * 0.76, h * 0.94)
      ..lineTo(w * 0.24, h * 0.94)
      ..quadraticBezierTo(w * 0.16, h * 0.94, w * 0.16, h * 0.88)
      ..lineTo(w * 0.16, h * 0.14)
      ..quadraticBezierTo(w * 0.16, h * 0.08, w * 0.20, h * 0.08)
      ..close();
    canvas.drawPath(docPath, paint);

    final foldPath = Path()
      ..moveTo(w * 0.60, h * 0.08)
      ..lineTo(w * 0.60, h * 0.30)
      ..lineTo(w * 0.84, h * 0.30);
    canvas.drawPath(foldPath, paint);

    canvas.drawLine(
      Offset(w * 0.50, h * 0.45),
      Offset(w * 0.50, h * 0.71),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.37, h * 0.58),
      Offset(w * 0.63, h * 0.58),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DocumentSubCategoryIconPainter extends CustomPainter {
  final String categoryId;
  final Color color;

  const _DocumentSubCategoryIconPainter({
    required this.categoryId,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (categoryId == 'other') {
      canvas.drawCircle(Offset(w * 0.50, h * 0.32), w * 0.18, paint);
      final bodyPath = Path()
        ..moveTo(w * 0.20, h * 0.86)
        ..quadraticBezierTo(w * 0.24, h * 0.58, w * 0.50, h * 0.58)
        ..quadraticBezierTo(w * 0.76, h * 0.58, w * 0.80, h * 0.86);
      canvas.drawPath(bodyPath, paint);
      return;
    }

    if (categoryId == 'all') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.14, h * 0.22, w * 0.72, h * 0.64),
          const Radius.circular(3.5),
        ),
        paint,
      );
      canvas.drawLine(
        Offset(w * 0.32, h * 0.44),
        Offset(w * 0.68, h * 0.44),
        paint,
      );
      canvas.drawLine(
        Offset(w * 0.32, h * 0.64),
        Offset(w * 0.58, h * 0.64),
        paint,
      );
      return;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.12, w * 0.64, h * 0.76),
        const Radius.circular(3.5),
      ),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.50, h * 0.36),
      Offset(w * 0.50, h * 0.64),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.36, h * 0.50),
      Offset(w * 0.64, h * 0.50),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DocumentSubCategoryIconPainter oldDelegate) {
    return oldDelegate.categoryId != categoryId || oldDelegate.color != color;
  }
}

class _AiShieldBadgePainter extends CustomPainter {
  const _AiShieldBadgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shieldStrokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shieldPath = Path()
      ..moveTo(w * 0.50, h * 0.08)
      ..lineTo(w * 0.86, h * 0.22)
      ..lineTo(w * 0.86, h * 0.50)
      ..quadraticBezierTo(w * 0.86, h * 0.78, w * 0.50, h * 0.92)
      ..quadraticBezierTo(w * 0.14, h * 0.78, w * 0.14, h * 0.50)
      ..lineTo(w * 0.14, h * 0.22)
      ..close();

    canvas.drawPath(shieldPath, shieldStrokePaint);

    final checkPath = Path()
      ..moveTo(w * 0.35, h * 0.51)
      ..lineTo(w * 0.46, h * 0.62)
      ..lineTo(w * 0.67, h * 0.39);
    canvas.drawPath(checkPath, shieldStrokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChatUserPortraitAvatarPainter extends CustomPainter {
  const _ChatUserPortraitAvatarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    canvas.drawRect(rect, Paint()..color = const Color(0xFFDCEBFE));

    final suitPath = Path()
      ..moveTo(w * 0.12, h)
      ..quadraticBezierTo(w * 0.20, h * 0.64, w * 0.50, h * 0.64)
      ..quadraticBezierTo(w * 0.80, h * 0.64, w * 0.88, h)
      ..close();
    canvas.drawPath(suitPath, Paint()..color = const Color(0xFF1E3A8A));

    final collarPath = Path()
      ..moveTo(w * 0.38, h * 0.66)
      ..lineTo(w * 0.50, h * 0.86)
      ..lineTo(w * 0.62, h * 0.66)
      ..close();
    canvas.drawPath(collarPath, Paint()..color = Colors.white);

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.61),
        width: w * 0.16,
        height: h * 0.14,
      ),
      Paint()..color = const Color(0xFFEAC0A2),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.40),
        width: w * 0.38,
        height: h * 0.42,
      ),
      Paint()..color = const Color(0xFFF3CFB6),
    );

    final hairPath = Path()
      ..moveTo(w * 0.31, h * 0.40)
      ..quadraticBezierTo(w * 0.32, h * 0.16, w * 0.52, h * 0.17)
      ..quadraticBezierTo(w * 0.70, h * 0.18, w * 0.69, h * 0.39)
      ..quadraticBezierTo(w * 0.54, h * 0.28, w * 0.31, h * 0.40)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = const Color(0xFF1E293B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PaperPlaneSendIconPainter extends CustomPainter {
  const _PaperPlaneSendIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final planePath = Path()
      ..moveTo(w * 0.88, h * 0.12)
      ..lineTo(w * 0.10, h * 0.46)
      ..lineTo(w * 0.44, h * 0.56)
      ..lineTo(w * 0.56, h * 0.90)
      ..close();

    canvas.drawPath(planePath, paint);
    canvas.drawLine(
      Offset(w * 0.88, h * 0.12),
      Offset(w * 0.44, h * 0.56),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KnowledgeTopicThumbnailPainter extends CustomPainter {
  final String topicId;

  const _KnowledgeTopicThumbnailPainter({required this.topicId});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    switch (topicId) {
      case 'abrasion':
        final skinPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3D5C1), Color(0xFFE5B89B), Color(0xFFD6A080)],
          ).createShader(rect);
        canvas.drawRect(rect, skinPaint);

        final center = Offset(w * 0.50, h * 0.50);
        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFDC2626).withValues(alpha: 0.45),
              const Color(0xFFDC2626).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: 24));
        canvas.drawCircle(center, 24, glowPaint);

        final patchPaint = Paint()
          ..color = const Color(0xFFC84B31).withValues(alpha: 0.78)
          ..style = PaintingStyle.fill;
        canvas.drawOval(
          Rect.fromCenter(center: center, width: 18, height: 26),
          patchPaint,
        );
        break;

      case 'cut_laceration':
        final skinPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFECC7B0), Color(0xFFD8A486), Color(0xFFC58C6D)],
          ).createShader(rect);
        canvas.drawRect(rect, skinPaint);

        final cutGlowPaint = Paint()
          ..color = const Color(0xFFDC2626).withValues(alpha: 0.28)
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(w * 0.34, h * 0.18),
          Offset(w * 0.62, h * 0.80),
          cutGlowPaint,
        );

        final cutLinePaint = Paint()
          ..color = const Color(0xFF991B1B)
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(w * 0.34, h * 0.18),
          Offset(w * 0.62, h * 0.80),
          cutLinePaint,
        );

        canvas.drawCircle(
          Offset(w * 0.49, h * 0.52),
          3.2,
          Paint()..color = const Color(0xFFFEE2E2),
        );
        break;

      case 'burn':
        final bgPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF64748B), Color(0xFF475569)],
          ).createShader(rect);
        canvas.drawRect(rect, bgPaint);

        final handPath = Path()
          ..moveTo(w * 0.15, h)
          ..quadraticBezierTo(w * 0.22, h * 0.25, w * 0.58, h * 0.18)
          ..quadraticBezierTo(w * 0.88, h * 0.24, w * 0.86, h)
          ..close();

        final handSkinPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEABFA4), Color(0xFFD79C7A)],
          ).createShader(rect);
        canvas.drawPath(handPath, handSkinPaint);

        final burnCenter = Offset(w * 0.54, h * 0.55);
        final burnPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFDC2626).withValues(alpha: 0.72),
              const Color(0xFFEA580C).withValues(alpha: 0.35),
              const Color(0xFFEA580C).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: burnCenter, radius: 24));
        canvas.drawCircle(burnCenter, 24, burnPaint);
        break;

      case 'bruise':
        final skinPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1D4C2), Color(0xFFE0B8A0)],
          ).createShader(rect);
        canvas.drawRect(rect, skinPaint);

        final bruiseCenter = Offset(w * 0.48, h * 0.52);
        final bruisePaint = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF4C1D95).withValues(alpha: 0.65),
              const Color(0xFF6D28D9).withValues(alpha: 0.38),
              const Color(0xFF7C3AED).withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: bruiseCenter, radius: 28));
        canvas.drawCircle(bruiseCenter, 28, bruisePaint);
        break;

      case 'foreign_body':
        final darkBgPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF64748B), Color(0xFF334155), Color(0xFF1E293B)],
          ).createShader(rect);
        canvas.drawRect(rect, darkBgPaint);

        final strapPaint = Paint()
          ..color = const Color(0xFF0F172A)
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(w * 0.20, h * 0.88),
          Offset(w * 0.78, h * 0.22),
          strapPaint,
        );

        final objCenter = Offset(w * 0.48, h * 0.50);
        canvas.drawCircle(
          objCenter,
          17,
          Paint()..color = const Color(0xFF1E293B),
        );
        canvas.drawCircle(
          objCenter,
          14,
          Paint()
            ..color = const Color(0xFFD97706)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0,
        );
        canvas.drawCircle(
          objCenter,
          8,
          Paint()..color = const Color(0xFF78350F),
        );
        break;

      case 'poisoning':
      default:
        final tablePaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5E1DA), Color(0xFFE5C4B8)],
          ).createShader(rect);
        canvas.drawRect(rect, tablePaint);

        canvas.drawCircle(
          Offset(w * 0.36, h * 0.44),
          16,
          Paint()..color = const Color(0xFFDC2626).withValues(alpha: 0.75),
        );

        final moldCenter = Offset(w * 0.54, h * 0.54);
        canvas.drawCircle(
          moldCenter,
          19,
          Paint()..color = const Color(0xFF4D7C0F),
        );
        canvas.drawCircle(
          Offset(w * 0.52, h * 0.50),
          13,
          Paint()..color = const Color(0xFF84CC16),
        );
        canvas.drawCircle(
          Offset(w * 0.60, h * 0.58),
          8,
          Paint()..color = const Color(0xFFBEF264),
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _KnowledgeTopicThumbnailPainter oldDelegate) {
    return oldDelegate.topicId != topicId;
  }
}

class _WorkspaceSidebarBackgroundPainter extends CustomPainter {
  final double sidebarWidth;
  final Color backgroundColor;
  final Color dividerColor;

  const _WorkspaceSidebarBackgroundPainter({
    required this.sidebarWidth,
    required this.backgroundColor,
    required this.dividerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, sidebarWidth, size.height), bgPaint);

    final dividerPaint = Paint()
      ..color = dividerColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(sidebarWidth + 0.5, 0),
      Offset(sidebarWidth + 0.5, size.height),
      dividerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WorkspaceSidebarBackgroundPainter oldDelegate) {
    return oldDelegate.sidebarWidth != sidebarWidth ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dividerColor != dividerColor;
  }
}

class _SoftAmberWarningTrianglePainter extends CustomPainter {
  const _SoftAmberWarningTrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final trianglePath = Path()
      ..moveTo(w * 0.50, h * 0.10)
      ..quadraticBezierTo(w * 0.55, h * 0.10, w * 0.59, h * 0.18)
      ..lineTo(w * 0.90, h * 0.76)
      ..quadraticBezierTo(w * 0.95, h * 0.86, w * 0.84, h * 0.88)
      ..lineTo(w * 0.16, h * 0.88)
      ..quadraticBezierTo(w * 0.05, h * 0.86, w * 0.10, h * 0.76)
      ..lineTo(w * 0.41, h * 0.18)
      ..quadraticBezierTo(w * 0.45, h * 0.10, w * 0.50, h * 0.10)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0xFFFDE68A).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawPath(trianglePath, fillPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(trianglePath, borderPaint);

    final exclamationPaint = Paint()
      ..color = const Color(0xFFD97706)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.50, h * 0.36),
      Offset(w * 0.50, h * 0.60),
      exclamationPaint,
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.73),
      1.6,
      Paint()..color = const Color(0xFFD97706),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FirstAidStepIconPainter extends CustomPainter {
  final String stepId;

  const _FirstAidStepIconPainter({required this.stepId});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (stepId) {
      case 'wash_hands':
      case 'clean_wound':
      case 'antiseptic':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.24, h * 0.34, w * 0.52, h * 0.58),
            const Radius.circular(3.5),
          ),
          strokePaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.38, h * 0.20, w * 0.24, h * 0.14),
          strokePaint,
        );
        canvas.drawLine(
          Offset(w * 0.50, h * 0.20),
          Offset(w * 0.50, h * 0.10),
          strokePaint,
        );
        canvas.drawLine(
          Offset(w * 0.36, h * 0.10),
          Offset(w * 0.68, h * 0.10),
          strokePaint,
        );
        canvas.drawLine(
          Offset(w * 0.50, h * 0.52),
          Offset(w * 0.50, h * 0.72),
          strokePaint,
        );
        canvas.drawLine(
          Offset(w * 0.40, h * 0.62),
          Offset(w * 0.60, h * 0.62),
          strokePaint,
        );
        break;

      case 'bandage_wound':
      default:
        final dropPath = Path()
          ..moveTo(w * 0.50, h * 0.14)
          ..quadraticBezierTo(w * 0.80, h * 0.48, w * 0.76, h * 0.68)
          ..arcToPoint(
            Offset(w * 0.24, h * 0.68),
            radius: Radius.circular(w * 0.26),
            clockwise: true,
          )
          ..quadraticBezierTo(w * 0.20, h * 0.48, w * 0.50, h * 0.14)
          ..close();
        canvas.drawPath(dropPath, strokePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FirstAidStepIconPainter oldDelegate) {
    return oldDelegate.stepId != stepId;
  }
}

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

class _ForearmAbrasionPainter extends CustomPainter {
  const _ForearmAbrasionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF475569), Color(0xFF1E293B), Color(0xFF0F172A)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final armPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.62, 0)
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.48,
        size.width,
        size.height * 0.88,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.14, size.height)
      ..quadraticBezierTo(
        size.width * 0.04,
        size.height * 0.62,
        0,
        size.height * 0.42,
      )
      ..close();

    final skinPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE5B899),
          Color(0xFFD9A17C),
          Color(0xFFC68863),
          Color(0xFFA86B47),
        ],
        stops: [0.0, 0.38, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawPath(armPath, skinPaint);

    final highlightCenter = Offset(size.width * 0.46, size.height * 0.50);
    final skinHighlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.65,
        colors: [
          const Color(0xFFF7D7C0).withValues(alpha: 0.48),
          const Color(0xFFE5B899).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: highlightCenter, radius: 130));
    canvas.drawPath(armPath, skinHighlightPaint);

    final woundCenter = Offset(size.width * 0.50, size.height * 0.52);
    final inflammationPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFB91C1C).withValues(alpha: 0.42),
          const Color(0xFFDC2626).withValues(alpha: 0.18),
          const Color(0xFFDC2626).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: woundCenter, radius: 54));
    canvas.drawCircle(woundCenter, 54, inflammationPaint);

    canvas.save();
    canvas.translate(woundCenter.dx, woundCenter.dy);
    canvas.rotate(-0.25);

    final abrasionOuterPath = Path()
      ..moveTo(-18, -32)
      ..cubicTo(-4, -38, 18, -30, 24, -14)
      ..cubicTo(30, 4, 26, 26, 10, 34)
      ..cubicTo(-8, 40, -24, 28, -28, 10)
      ..cubicTo(-32, -8, -28, -24, -18, -32)
      ..close();

    final abrasionBasePaint = Paint()
      ..color = const Color(0xFFC24136).withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;
    canvas.drawPath(abrasionOuterPath, abrasionBasePaint);

    final scratchPaint = Paint()
      ..color = const Color(0xFF991B1B).withValues(alpha: 0.82)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(-12, -20), const Offset(8, 18), scratchPaint);
    canvas.drawLine(const Offset(-4, -24), const Offset(14, 10), scratchPaint);
    canvas.drawLine(const Offset(-18, -8), const Offset(2, 24), scratchPaint);

    final spotPaint = Paint()
      ..color = const Color(0xFF7F1D1D).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    const List<Offset> spots = [
      Offset(-8, -14),
      Offset(6, -16),
      Offset(-14, 2),
      Offset(0, -2),
      Offset(12, 4),
      Offset(-6, 16),
      Offset(8, 18),
      Offset(-12, -6),
      Offset(4, 10),
    ];
    for (final pt in spots) {
      canvas.drawCircle(pt, 2.6, spotPaint);
    }

    final lightTissuePaint = Paint()
      ..color = const Color(0xFFFCA5A5).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-2, -6), width: 14, height: 8),
      lightTissuePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(4, 12), width: 12, height: 7),
      lightTissuePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BodyPartIconPainter extends CustomPainter {
  final String partId;
  final Color color;

  const _BodyPartIconPainter({required this.partId, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    switch (partId) {
      case 'arm':
        final path = Path()
          ..moveTo(w * 0.24, h * 0.62)
          ..quadraticBezierTo(w * 0.16, h * 0.84, w * 0.42, h * 0.84)
          ..lineTo(w * 0.72, h * 0.78)
          ..quadraticBezierTo(w * 0.86, h * 0.72, w * 0.78, h * 0.56)
          ..quadraticBezierTo(w * 0.66, h * 0.46, w * 0.52, h * 0.56)
          ..lineTo(w * 0.56, h * 0.26)
          ..quadraticBezierTo(w * 0.56, h * 0.14, w * 0.44, h * 0.16)
          ..quadraticBezierTo(w * 0.34, h * 0.18, w * 0.36, h * 0.32)
          ..lineTo(w * 0.34, h * 0.56);
        canvas.drawPath(path, paint);
        break;

      case 'leg':
        final legPath = Path()
          ..moveTo(w * 0.36, h * 0.16)
          ..lineTo(w * 0.36, h * 0.68)
          ..quadraticBezierTo(w * 0.22, h * 0.74, w * 0.22, h * 0.82)
          ..lineTo(w * 0.68, h * 0.82)
          ..quadraticBezierTo(w * 0.76, h * 0.82, w * 0.74, h * 0.72)
          ..lineTo(w * 0.58, h * 0.66)
          ..lineTo(w * 0.58, h * 0.16);
        canvas.drawPath(legPath, paint);
        break;

      case 'head':
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.42),
            width: w * 0.52,
            height: h * 0.56,
          ),
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(w * 0.23, h * 0.44),
            width: w * 0.1,
            height: h * 0.16,
          ),
          math.pi / 2,
          math.pi,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(w * 0.77, h * 0.44),
            width: w * 0.1,
            height: h * 0.16,
          ),
          -math.pi / 2,
          math.pi,
          false,
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.40, h * 0.68),
          Offset(w * 0.36, h * 0.84),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.60, h * 0.68),
          Offset(w * 0.64, h * 0.84),
          paint,
        );
        break;

      case 'back':
        final torsoPath = Path()
          ..moveTo(w * 0.22, h * 0.26)
          ..quadraticBezierTo(w * 0.50, h * 0.18, w * 0.78, h * 0.26)
          ..lineTo(w * 0.72, h * 0.82)
          ..lineTo(w * 0.28, h * 0.82)
          ..close();
        canvas.drawPath(torsoPath, paint);
        canvas.drawLine(
          Offset(w * 0.50, h * 0.24),
          Offset(w * 0.50, h * 0.80),
          paint,
        );
        break;

      case 'other':
      default:
        canvas.drawLine(
          Offset(w * 0.42, h * 0.42),
          Offset(w * 0.20, h * 0.20),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.20, h * 0.20),
          Offset(w * 0.36, h * 0.20),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.20, h * 0.20),
          Offset(w * 0.20, h * 0.36),
          paint,
        );

        canvas.drawLine(
          Offset(w * 0.58, h * 0.42),
          Offset(w * 0.80, h * 0.20),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.80, h * 0.20),
          Offset(w * 0.64, h * 0.20),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.80, h * 0.20),
          Offset(w * 0.80, h * 0.36),
          paint,
        );

        canvas.drawLine(
          Offset(w * 0.42, h * 0.58),
          Offset(w * 0.20, h * 0.80),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.20, h * 0.80),
          Offset(w * 0.36, h * 0.80),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.20, h * 0.80),
          Offset(w * 0.20, h * 0.64),
          paint,
        );

        canvas.drawLine(
          Offset(w * 0.58, h * 0.58),
          Offset(w * 0.80, h * 0.80),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.80, h * 0.80),
          Offset(w * 0.64, h * 0.80),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.80, h * 0.80),
          Offset(w * 0.80, h * 0.64),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPartIconPainter oldDelegate) {
    return oldDelegate.partId != partId || oldDelegate.color != color;
  }
}
