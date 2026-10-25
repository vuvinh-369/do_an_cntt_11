import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/admin_viewmodel.dart';
import 've_do_hoa_quan_tri_view.dart';

class DangNhapQuanTriView extends StatelessWidget {
  const DangNhapQuanTriView({super.key});

  @override
  Widget build(BuildContext context) {
    final adminViewModel = context.watch<AdminViewModel>();
    final spec = adminViewModel.loginSpec;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 980),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120D2B6B),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: const AdminLoginWaveBackgroundPainter(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 740;

                if (isWide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cột trái: Biểu mẫu Đăng nhập quản trị
                        Expanded(
                          flex: 5,
                          child: _buildLeftLoginForm(
                            context,
                            adminViewModel,
                            spec,
                          ),
                        ),
                        // Đường kẻ dọc phân tách nhẹ giữa 2 cột
                        Container(width: 1, color: const Color(0xFFE8EEF7)),
                        // Cột phải: Minh họa Khiên bảo mật & Khu vực quản trị
                        Expanded(
                          flex: 5,
                          child: _buildRightIllustrationPanel(spec),
                        ),
                      ],
                    ),
                  );
                }

                // Bố cục xếp dọc trên màn hình nhỏ (Responsive)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLeftLoginForm(context, adminViewModel, spec),
                    const Divider(height: 1, color: Color(0xFFE8EEF7)),
                    _buildRightIllustrationPanel(spec),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // CỘT TRÁI: BIỂU MẪU ĐĂNG NHẬP QUẢN TRỊ
  // ===========================================================================

  Widget _buildLeftLoginForm(
    BuildContext context,
    AdminViewModel viewModel,
    dynamic spec,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Cụm Logo trái tim xanh dương có dấu '+' trắng & Tên hệ thống
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: const [
                    Icon(Icons.favorite, color: Color(0xFF2563EB), size: 36),
                    Icon(Icons.add, color: Colors.white, size: 18),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.brandTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2B6B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.brandSubtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Nút nhỏ giúp quay về giao diện Người dùng bất cứ lúc nào
              TextButton.icon(
                onPressed: () => viewModel.exitAdminPortalToUserApp(),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text(
                  'Người dùng',
                  style: TextStyle(fontSize: 12.5),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 2. Tiêu đề "Đăng nhập quản trị"
          Text(
            spec.formTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),

          // 3. Nhãn & Ô nhập "Tài khoản"
          Text(
            spec.usernameLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: viewModel.updateUsername,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: spec.usernameHint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFD8E2EE),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 4. Nhãn & Ô nhập "Mật khẩu" (Có icon con mắt ẩn/hiện)
          Text(
            spec.passwordLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: viewModel.updatePassword,
            obscureText: viewModel.isPasswordObscured,
            onSubmitted: (_) => viewModel.submitAdminLogin(),
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: spec.passwordHint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              suffixIcon: IconButton(
                onPressed: viewModel.togglePasswordVisibility,
                icon: Icon(
                  viewModel.isPasswordObscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: const Color(0xFF475569),
                ),
                tooltip: viewModel.isPasswordObscured
                    ? 'Hiện mật khẩu'
                    : 'Ẩn mật khẩu',
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFD8E2EE),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 5. Checkbox "Ghi nhớ đăng nhập"
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => viewModel.toggleRememberMe(!viewModel.rememberMe),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: viewModel.rememberMe,
                    onChanged: viewModel.toggleRememberMe,
                    activeColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: const BorderSide(
                      color: Color(0xFF94A3B8),
                      width: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  spec.rememberMeLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

          // Hiển thị thông báo lỗi nếu người dùng bấm Đăng nhập khi chưa điền thông tin
          if (viewModel.loginFeedbackMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: viewModel.isLoginError
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: viewModel.isLoginError
                      ? const Color(0xFFFECACA)
                      : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    viewModel.isLoginError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: viewModel.isLoginError
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      viewModel.loginFeedbackMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: viewModel.isLoginError
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          // 6. Nút bấm "Đăng nhập" màu xanh dương toàn chiều rộng cột
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => viewModel.submitAdminLogin(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                spec.loginButtonLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CỘT PHẢI: HÌNH MINH HỌA KHIÊN BẢO MẬT & "KHU VỰC QUẢN TRỊ"
  // ===========================================================================

  Widget _buildRightIllustrationPanel(dynamic spec) {
    return Container(
      color: const Color(0xFFF0F5FF).withValues(alpha: 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 44),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hình vẽ Laptop + Khiên bảo mật xanh dương có dấu tích trắng
          const SizedBox(
            width: 260,
            height: 190,
            child: CustomPaint(painter: AdminSecurityIllustrationPainter()),
          ),
          const SizedBox(height: 18),

          // Tiêu đề "Khu vực quản trị"
          Text(
            spec.rightPanelTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
            ),
          ),
          const SizedBox(height: 6),

          // Phụ đề "Chỉ dành cho người có thẩm quyền"
          Text(
            spec.rightPanelSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
