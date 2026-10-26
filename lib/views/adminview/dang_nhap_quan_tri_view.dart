// File: lib/views/adminview/dang_nhap_quan_tri_view.dart
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
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 20,
          vertical: isMobile ? 16 : 24,
        ),
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
                        Expanded(
                          flex: 5,
                          child: _buildLeftLoginForm(
                            context,
                            adminViewModel,
                            spec,
                            isMobile: false,
                          ),
                        ),
                        Container(width: 1, color: const Color(0xFFE8EEF7)),
                        Expanded(
                          flex: 5,
                          child: _buildRightIllustrationPanel(
                            spec,
                            isMobile: false,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLeftLoginForm(
                      context,
                      adminViewModel,
                      spec,
                      isMobile: true,
                    ),
                    const Divider(height: 1, color: Color(0xFFE8EEF7)),
                    _buildRightIllustrationPanel(spec, isMobile: true),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftLoginForm(
    BuildContext context,
    AdminViewModel viewModel,
    dynamic spec, {
    required bool isMobile,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 44,
        vertical: isMobile ? 26 : 42,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: const [
                    Icon(Icons.favorite, color: Color(0xFF2563EB), size: 32),
                    Icon(Icons.add, color: Colors.white, size: 16),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.brandTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2B6B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.brandSubtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
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
          SizedBox(height: isMobile ? 22 : 32),
          Text(
            spec.formTitle,
            style: TextStyle(
              fontSize: isMobile ? 21 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 20),
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

  Widget _buildRightIllustrationPanel(dynamic spec, {required bool isMobile}) {
    return Container(
      color: const Color(0xFFF0F5FF).withValues(alpha: 0.75),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 36,
        vertical: isMobile ? 24 : 44,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: isMobile ? 210 : 260,
            height: isMobile ? 150 : 190,
            child: const CustomPaint(
              painter: AdminSecurityIllustrationPainter(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            spec.rightPanelTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.rightPanelSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
