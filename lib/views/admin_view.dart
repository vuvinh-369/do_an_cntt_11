import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/admin_viewmodel.dart';
import 'adminview/dang_nhap_quan_tri_view.dart';
import 'adminview/dashboard_quan_tri_view.dart';

class AdminView extends StatelessWidget {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context) {
    final adminViewModel = context.watch<AdminViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: adminViewModel.currentAdminScreenIndex == 0
          ? const DangNhapQuanTriView()
          : _buildAdminWorkspaceShell(context, adminViewModel),
    );
  }

  // ===========================================================================
  // KHUNG KHÔNG GIAN LÀM VIỆC QUẢN TRỊ (MÀN HÌNH 10+)
  // ===========================================================================

  Widget _buildAdminWorkspaceShell(
    BuildContext context,
    AdminViewModel viewModel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;
        final minShellHeight = (constraints.maxHeight - 32).clamp(
          600.0,
          2000.0,
        );

        // Bố cục chính cho màn hình rộng (Desktop / Web)
        if (isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 1240,
                  minHeight: minShellHeight,
                ),
                decoration: BoxDecoration(
                  // Đặt màu nền cột trái làm nền mặc định để Sidebar luôn cao hết khung
                  color: const Color(0xFFFAFBFD),
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
                // ĐÃ XÓA IntrinsicHeight ĐỂ TRÁNH LỖI CRASH RENDERBOX VỚI LAYOUTBUILDER/LISTVIEW CON
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột trái: Thanh Sidebar Quản trị (Rộng cố định 245px)
                    Container(
                      width: 245,
                      constraints: BoxConstraints(minHeight: minShellHeight),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAFBFD),
                        border: Border(
                          right: BorderSide(color: Color(0xFFE8EEF5), width: 1),
                        ),
                      ),
                      child: _buildAdminLeftSidebar(
                        context,
                        viewModel,
                        isWide: true,
                      ),
                    ),

                    // Cột phải: Thanh Header + Nội dung động theo Sidebar
                    Expanded(
                      child: Container(
                        constraints: BoxConstraints(minHeight: minShellHeight),
                        color: Colors.white,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildAdminTopHeaderBar(context, viewModel),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFE8EEF5),
                            ),
                            // Hiển thị trực tiếp nội dung mà không dùng Flexible trong chiều dọc không giới hạn
                            _buildSelectedAdminContent(viewModel),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Bố cục thu gọn cho màn hình nhỏ (Responsive / Mobile)
        return SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1240),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAdminTopHeaderBar(context, viewModel),
                  const Divider(height: 1, color: Color(0xFFE8EEF5)),
                  _buildAdminLeftSidebar(context, viewModel, isWide: false),
                  const Divider(height: 1, color: Color(0xFFE8EEF5)),
                  _buildSelectedAdminContent(viewModel),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // THANH SIDEBAR BÊN TRÁI CỦA QUẢN TRỊ (LOGO "QUẢN TRỊ" + 7 MỤC MENU)
  // ===========================================================================

  Widget _buildAdminLeftSidebar(
    BuildContext context,
    AdminViewModel viewModel, {
    required bool isWide,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isWide ? 22 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cụm Logo Trái tim có dấu '+' + chữ "Quản trị" ở góc trên bên trái
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 24),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => viewModel.selectAdminSidebarIndex(0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: const [
                        Icon(
                          Icons.favorite,
                          color: Color(0xFF2563EB),
                          size: 36,
                        ),
                        Icon(Icons.add, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Quản trị',
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
          ),

          // Danh sách các mục menu Quản trị
          if (isWide)
            ...List.generate(viewModel.adminSidebarItems.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildAdminSidebarMenuItem(viewModel, index),
              );
            })
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  viewModel.adminSidebarItems.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildAdminSidebarMenuItem(viewModel, index),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminSidebarMenuItem(AdminViewModel viewModel, int index) {
    final item = viewModel.adminSidebarItems[index];
    final isSelected = viewModel.selectedAdminSidebarIndex == index;

    return Material(
      color: isSelected ? const Color(0xFFE8F1FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => viewModel.selectAdminSidebarIndex(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF475569),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.hasTrailingChevron) ...[
                const Spacer(),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF94A3B8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // THANH HEADER PHÍA TRÊN BÊN PHẢI (AVATAR + "admin ⌄")
  // ===========================================================================

  Widget _buildAdminTopHeaderBar(
    BuildContext context,
    AdminViewModel viewModel,
  ) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      color: Colors.white,
      alignment: Alignment.centerRight,
      child: PopupMenuButton<String>(
        offset: const Offset(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          if (value == 'user_app') {
            viewModel.exitAdminPortalToUserApp();
          } else if (value == 'logout') {
            viewModel.logoutAdmin();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'user_app',
            child: Row(
              children: [
                Icon(Icons.home_outlined, size: 18, color: Color(0xFF475569)),
                SizedBox(width: 10),
                Text('Về giao diện Người dùng'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                SizedBox(width: 10),
                Text(
                  'Đăng xuất Quản trị',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
              ],
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.person, size: 20, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(width: 10),
              Text(
                viewModel.currentAdminSession.username.isNotEmpty
                    ? viewModel.currentAdminSession.username
                    : 'admin',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ĐIỀU PHỐI NỘI DUNG MÀN HÌNH QUẢN TRỊ BÊN PHẢI (AN TOÀN CHỈ MỤC)
  // ===========================================================================

  Widget _buildSelectedAdminContent(AdminViewModel viewModel) {
    final items = viewModel.adminSidebarItems;
    final selectedIndex = viewModel.selectedAdminSidebarIndex;

    // Kiểm tra nếu mục đầu tiên (index 0) hoặc mục được chọn có tên là "Dashboard"
    // hoặc nếu bạn đang quy ước index == 0 / index == 1 cho Dashboard:
    if (items.isEmpty) {
      return const DashboardQuanTriView();
    }

    final safeIndex = selectedIndex.clamp(0, items.length - 1);
    final selectedItem = items[safeIndex];

    // Hiển thị Dashboard nếu người dùng chọn mục đầu tiên (index 0)
    // hoặc mục có tiêu đề chứa "Dashboard"
    if (safeIndex == 0 ||
        selectedItem.title.toLowerCase().contains('dashboard')) {
      return const DashboardQuanTriView();
    }

    // Khung chờ an toàn cho các màn hình Quản trị tiếp theo
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selectedItem.icon, size: 48, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 14),
            Text(
              'Màn hình "${selectedItem.title}" đang chờ tích hợp thiết kế tiếp theo.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => viewModel.selectAdminSidebarIndex(0),
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: const Text('Quay lại Dashboard (Màn hình 10)'),
            ),
          ],
        ),
      ),
    );
  }
}
