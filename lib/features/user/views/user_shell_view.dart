// File: lib/views/user_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../admin/viewmodels/admin_viewmodel.dart';
import '../viewmodels/user_viewmodel.dart';
import 'chat_view.dart';
import 'first_aid_view.dart';
import 'analysis_result_view.dart';
import 'document_view.dart';
import 'history_view.dart';
import 'image_analysis_view.dart';
import 'knowledge_view.dart';
import 'home_view.dart';
import 'widgets/user_painters.dart';

class UserShellView extends StatelessWidget {
  const UserShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      return _buildMobileUserScaffold(context, viewModel);
    }

    // =========================================================================
    // GIAO DIỆN PC / DESKTOP (GIỮ NGUYÊN 100% BỐ CỤC HIỆN TẠI)
    // =========================================================================
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
                _buildTopNavigationBar(context, viewModel),
                if (viewModel.currentScreenIndex != 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE8EEF5),
                  ),
                if (viewModel.currentScreenIndex == 0)
                  const TrangChuView()
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
  // GIAO DIỆN MOBILE WEB (< 768PX) ĐỒNG BỘ THEO ẢNH MẪU MINH HỌA
  // ===========================================================================

  Widget _buildMobileUserScaffold(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final isHome = viewModel.currentScreenIndex == 0;
    final isChatScreen = viewModel.currentScreenIndex == 5;

    return Scaffold(
      backgroundColor: isHome ? const Color(0xFFF6F9FC) : Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: isHome
            ? _buildMobileHomeHeader(context, viewModel)
            : _buildMobileInnerAppBar(context, viewModel),
      ),
      body: isChatScreen
          ? const ChatBoxAiView()
          : SingleChildScrollView(
              child: _buildSelectedMobileBodyContent(viewModel),
            ),
      bottomNavigationBar: isChatScreen
          ? _buildMobileChatSupportBottomBar(context, viewModel)
          : _buildMobileStandardBottomNavBar(context, viewModel),
    );
  }

  /// Header Mobile ở Trang chủ (Màn hình 1): Logo trái tim + "Trợ lý Cứu hộ AI" & Nút icon Chat góc phải
  Widget _buildMobileHomeHeader(BuildContext context, UserViewModel viewModel) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EEF5), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => viewModel.navigateToHome(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: const [
                          Icon(
                            Icons.favorite,
                            color: Color(0xFF2563EB),
                            size: 32,
                          ),
                          Icon(Icons.add, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Trợ lý Cứu hộ AI',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2B6B),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => viewModel.navigateToChatBoxAi(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header Mobile cho các màn hình con (Màn hình 2 - 8): Nút '<' + Icon Khiên xanh + Tiêu đề màn hình
  Widget _buildMobileInnerAppBar(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final String title = _getMobileScreenTitle(viewModel.currentScreenIndex);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EEF5), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => viewModel.navigateBack(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 19,
                  color: Color(0xFF1E293B),
                ),
                tooltip: 'Quay lại',
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
                child: const CustomPaint(painter: AiShieldBadgePainter()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D2B6B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => viewModel.onSearchPressed(),
                icon: const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: Color(0xFF64748B),
                ),
                tooltip: 'Tra cứu',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMobileScreenTitle(int screenIndex) {
    switch (screenIndex) {
      case 1:
        return 'Phân tích ảnh AI';
      case 2:
        return 'Kết quả phân tích';
      case 3:
        return 'Chi tiết sơ cứu';
      case 4:
        return 'Kiến thức sơ cứu';
      case 5:
        return 'ChatBox AI';
      case 6:
        return 'Kho tài liệu y tế';
      case 7:
        return 'Lịch sử phân tích';
      default:
        return 'Trợ lý Cứu hộ AI';
    }
  }

  Widget _buildSelectedMobileBodyContent(UserViewModel viewModel) {
    switch (viewModel.currentScreenIndex) {
      case 0:
        return const TrangChuView();
      case 1:
        return const PhanTichAnhView();
      case 2:
        return const KetQuaPhanTichView();
      case 3:
        return const HuongDanSoCuuView();
      case 4:
        return const TraCuuKienThucView();
      case 5:
        return const ChatBoxAiView();
      case 6:
        return const KhoTaiLieuView();
      case 7:
        return const LichSuPhanTichView();
      default:
        return const TrangChuView();
    }
  }

  /// Thanh điều hướng đáy 4 mục trên Mobile (Trang chủ, Kiến thức, Tài liệu, Cá nhân)
  Widget _buildMobileStandardBottomNavBar(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    int activeTab = 0;
    if (viewModel.currentScreenIndex == 4 || viewModel.currentScreenIndex == 3) {
      activeTab = 1;
    } else if (viewModel.currentScreenIndex == 6) {
      activeTab = 2;
    } else if (viewModel.currentScreenIndex == 7) {
      activeTab = 3;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0D2B6B),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _buildMobileBottomNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Trang chủ',
                isSelected: activeTab == 0 && viewModel.currentScreenIndex == 0,
                onTap: () => viewModel.navigateToHome(),
              ),
              _buildMobileBottomNavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book_rounded,
                label: 'Kiến thức',
                isSelected: activeTab == 1,
                onTap: () => viewModel.navigateToKnowledgeLookup(),
              ),
              _buildMobileBottomNavItem(
                icon: Icons.description_outlined,
                activeIcon: Icons.description_rounded,
                label: 'Tài liệu',
                isSelected: activeTab == 2,
                onTap: () => viewModel.navigateToMedicalDocuments(),
              ),
              _buildMobileBottomNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Cá nhân',
                isSelected: activeTab == 3,
                onTap: () => _showMobilePersonalMenuSheet(context, viewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = isSelected
        ? const Color(0xFF2563EB)
        : const Color(0xFF64748B);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Thanh đáy đặc trưng của màn hình ChatBox AI trên Mobile (Chuông | Hỗ trợ | Cá nhân) theo Ảnh 1
  Widget _buildMobileChatSupportBottomBar(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EEF5), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () => viewModel.navigateToAnalysisHistory(),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
                tooltip: 'Lịch sử phân tích',
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Hỗ trợ',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    _showMobilePersonalMenuSheet(context, viewModel),
                icon: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
                tooltip: 'Cá nhân & Quản trị',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menu nhanh khi nhấn vào tab "Cá nhân" trên Mobile: Xem Lịch sử phân tích hoặc vào Quản trị hệ thống
  void _showMobilePersonalMenuSheet(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFFDBEAFE),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF1E3A8A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            viewModel.currentUserName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0D2B6B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tài khoản Người dùng • Trợ lý Cứu hộ AI',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE8EEF5)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF2563EB),
                  ),
                  title: const Text(
                    'Lịch sử phân tích ảnh',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: const Text(
                    'Xem lại các lần chụp và phân tích sơ cứu',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    viewModel.navigateToAnalysisHistory();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Color(0xFF0D2B6B),
                  ),
                  title: const Text(
                    'Khu vực Quản trị hệ thống (/admin)',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: const Text(
                    'Đăng nhập quản trị & xem Dashboard thống kê',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.read<AdminViewModel>().openAdminPortal();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // PHẦN DÙNG CHUNG TRÊN PC: TOP NAVIGATION BAR & LEFT SIDEBAR
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isHomeScreen) ...[
                    IconButton(
                      onPressed: () =>
                          context.read<UserViewModel>().navigateBack(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF0D2B6B),
                        size: 21,
                      ),
                      tooltip: 'Quay lại',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        hoverColor: const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
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
                ],
              ),
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
                    onTap: () => _showUserAccountMenu(context, viewModel),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: viewModel.isUserLoggedIn
                                ? const Color(0xFFDBEAFE)
                                : const Color(0xFFE2E8F0),
                            child: Icon(
                              viewModel.isUserLoggedIn
                                  ? Icons.person
                                  : Icons.person_outline,
                              color: viewModel.isUserLoggedIn
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF64748B),
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

  Widget _buildAiWorkspaceBody(BuildContext context, UserViewModel viewModel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 780;

        final Widget rightContent;
        if (viewModel.currentScreenIndex == 7) {
          rightContent = const LichSuPhanTichView();
        } else if (viewModel.currentScreenIndex == 6) {
          rightContent = const KhoTaiLieuView();
        } else if (viewModel.currentScreenIndex == 5) {
          rightContent = const ChatBoxAiView();
        } else if (viewModel.currentScreenIndex == 4) {
          rightContent = const TraCuuKienThucView();
        } else if (viewModel.currentScreenIndex == 3) {
          rightContent = const HuongDanSoCuuView();
        } else if (viewModel.currentScreenIndex == 2) {
          rightContent = const KetQuaPhanTichView();
        } else {
          rightContent = const PhanTichAnhView();
        }

        if (isWide) {
          return CustomPaint(
            painter: const WorkspaceSidebarBackgroundPainter(
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

  /// Menu quản lý tài khoản người dùng và điều hướng cổng Quản trị riêng biệt
  void _showUserAccountMenu(BuildContext context, UserViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: viewModel.isUserLoggedIn
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFF1F5F9),
                      child: Icon(
                        viewModel.isUserLoggedIn
                            ? Icons.person
                            : Icons.person_outline,
                        color: viewModel.isUserLoggedIn
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            viewModel.currentUserName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D2B6B),
                            ),
                          ),
                          Text(
                            viewModel.isUserLoggedIn
                                ? 'Dữ liệu được lưu trữ theo tài khoản'
                                : 'Chế độ khách:',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                if (!viewModel.isUserLoggedIn)
                  ListTile(
                    leading: const Icon(Icons.person_add_rounded, color: Color(0xFF2563EB)),
                    title: const Text('Đăng nhập / Đăng ký tài khoản'),
                    subtitle: const Text('Lưu dữ liệu cá nhân khi đổi thiết bị (Không bắt buộc)'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAuthModal(context, viewModel);
                    },
                  )
                else ...[
                  ListTile(
                    leading: const Icon(Icons.account_circle_rounded, color: Color(0xFF16A34A)),
                    title: Text(viewModel.currentUserName),
                    subtitle: Text('Tài khoản: @${viewModel.currentUsername ?? 'nguoidung'} • Đã đồng bộ dữ liệu'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                    title: const Text('Đăng xuất tài khoản'),
                    subtitle: const Text('Trở về chế độ Khách'),
                    onTap: () {
                      viewModel.logoutUser();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã đăng xuất. Bạn đang sử dụng với chế độ Khách.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.history_rounded, color: Color(0xFF0D2B6B)),
                  title: const Text('Lịch sử phân tích'),
                  onTap: () {
                    Navigator.pop(ctx);
                    viewModel.navigateToAnalysisHistory();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFD97706)),
                  title: const Text('Cổng Quản trị hệ thống'),
                  subtitle: const Text('Trang dành cho quản trị viên'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.read<AdminViewModel>().openAdminPortal();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAuthModal(BuildContext context, UserViewModel viewModel) {
    showDialog(
      context: context,
      builder: (ctx) => _UserAuthModalDialog(viewModel: viewModel),
    );
  }
}

class _UserAuthModalDialog extends StatefulWidget {
  final UserViewModel viewModel;

  const _UserAuthModalDialog({required this.viewModel});

  @override
  State<_UserAuthModalDialog> createState() => _UserAuthModalDialogState();
}

class _UserAuthModalDialogState extends State<_UserAuthModalDialog> {
  int _activeTab = 0; // 0 = Đăng nhập, 1 = Đăng ký

  // Controllers cho Đăng nhập
  final _loginUserCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  bool _obscureLoginPass = true;

  // Controllers cho Đăng ký
  final _regNameCtrl = TextEditingController();
  final _regUserCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regConfirmPassCtrl = TextEditingController();
  bool _obscureRegPass = true;
  bool _obscureRegConfirm = true;

  String? _errorMessage;

  @override
  void dispose() {
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regUserCtrl.dispose();
    _regPassCtrl.dispose();
    _regConfirmPassCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() {
    setState(() => _errorMessage = null);
    final user = _loginUserCtrl.text.trim();
    final pass = _loginPassCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng điền đầy đủ tài khoản và mật khẩu.');
      return;
    }

    final error = widget.viewModel.loginWithCredentials(username: user, password: pass);
    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Đăng nhập thành công! Chào mừng ${widget.viewModel.currentUserName}.'),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleRegister() {
    setState(() => _errorMessage = null);
    final name = _regNameCtrl.text.trim();
    final user = _regUserCtrl.text.trim();
    final pass = _regPassCtrl.text.trim();
    final confirm = _regConfirmPassCtrl.text.trim();

    if (name.isEmpty || user.isEmpty || pass.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng điền đầy đủ tất cả các trường.');
      return;
    }

    if (pass != confirm) {
      setState(() => _errorMessage = 'Mật khẩu xác nhận không trùng khớp.');
      return;
    }

    final error = widget.viewModel.registerUser(
      username: user,
      password: pass,
      fullName: name,
    );

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Đăng ký tài khoản thành công! Dữ liệu cá nhân đã được liên kết.'),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tiêu đề & nút đóng
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_circle_rounded, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeTab == 0 ? 'Đăng nhập người dùng' : 'Đăng ký tài khoản mới',
                          style: const TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D2B6B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Lưu trữ dữ liệu lịch sử phân tích khi đổi thiết bị',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ℹ️ BẢNG LƯU Ý QUAN TRỌNG: KHÔNG BẮT BUỘC ĐĂNG KÝ
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đăng ký tài khoản nếu muốn lưu dữ liệu cá nhân',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF166534),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab chuyển đổi Đăng nhập / Đăng ký
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _activeTab = 0;
                          _errorMessage = null;
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _activeTab == 0
                                ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: _activeTab == 0 ? FontWeight.w800 : FontWeight.w600,
                              color: _activeTab == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _activeTab = 1;
                          _errorMessage = null;
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _activeTab == 1
                                ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Đăng ký mới',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: _activeTab == 1 ? FontWeight.w800 : FontWeight.w600,
                              color: _activeTab == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Báo lỗi nếu có
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // NỘI DUNG TAB ĐĂNG NHẬP
              if (_activeTab == 0) ...[
                TextField(
                  controller: _loginUserCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tên tài khoản',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _loginPassCtrl,
                  obscureText: _obscureLoginPass,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureLoginPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () => setState(() => _obscureLoginPass = !_obscureLoginPass),
                    ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                // Gợi ý tài khoản demo
                InkWell(
                  onTap: () {
                    _loginUserCtrl.text = 'user123';
                    _loginPassCtrl.text = '123456';
                    setState(() => _errorMessage = null);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text(
                          'Tài khoản có sẵn: user123 / 123456 (Bấm để điền nhanh)',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Đăng nhập', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => setState(() {
                    _activeTab = 1;
                    _errorMessage = null;
                  }),
                  child: const Text(
                    'Chưa có tài khoản? Bấm vào đây để đăng ký',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF2563EB)),
                  ),
                ),
              ],

              // NỘI DUNG TAB ĐĂNG KÝ
              if (_activeTab == 1) ...[
                TextField(
                  controller: _regNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Họ và tên của bạn',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _regUserCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tên tài khoản (ít nhất 3 ký tự)',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _regPassCtrl,
                  obscureText: _obscureRegPass,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu (ít nhất 6 ký tự)',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureRegPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () => setState(() => _obscureRegPass = !_obscureRegPass),
                    ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _regConfirmPassCtrl,
                  obscureText: _obscureRegConfirm,
                  decoration: InputDecoration(
                    labelText: 'Nhập lại mật khẩu',
                    prefixIcon: const Icon(Icons.lock_reset_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureRegConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () => setState(() => _obscureRegConfirm = !_obscureRegConfirm),
                    ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Tạo tài khoản & Đăng nhập ngay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => setState(() {
                    _activeTab = 0;
                    _errorMessage = null;
                  }),
                  child: const Text(
                    'Đã có tài khoản? Bấm vào đây để đăng nhập',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF2563EB)),
                  ),
                ),
              ],

              const Divider(height: 24),
              // Nút tiếp tục với vai trò khách
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tiếp tục với vai trò Khách (Không đăng nhập)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
