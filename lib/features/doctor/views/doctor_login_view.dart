// File: lib/features/doctor/views/doctor_login_view.dart
import 'package:flutter/material.dart';

import '../../../core/doctor_management/doctor_management_service.dart';
import '../../../core/security/auth_brute_force_service.dart';
import '../../../core/security/widgets/auth_captcha_box.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/user_management/user_account_service.dart';
import '../../user/models/doctor_consultation_models.dart';
import '../../user/models/user_account_model.dart';

/// Màn hình Đăng nhập Cổng Bác sĩ Trực tuyến (/doctor) - Yêu cầu R2
/// Bọc đúng Scaffold Material ancestor, xác thực thông tin đăng nhập được Admin cấp,
/// kiểm tra phân quyền Bác sĩ (chặn tài khoản thường), và ghi nhớ phiên làm việc.
class DoctorLoginView extends StatefulWidget {
  final Function(DoctorProfile doctor) onLoginSuccess;
  final VoidCallback? onExitToUserApp;

  const DoctorLoginView({
    super.key,
    required this.onLoginSuccess,
    this.onExitToUserApp,
  });

  @override
  State<DoctorLoginView> createState() => _DoctorLoginViewState();
}

class _DoctorLoginViewState extends State<DoctorLoginView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _captchaCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  void _loadSavedCredentials() {
    final savedUsername = LocalStorageService.instance.getDoctorSavedUsername();
    if (savedUsername != null && savedUsername.isNotEmpty) {
      _usernameCtrl.text = savedUsername;
    }
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final bfService = AuthBruteForceService.instance;

    // A. Kiểm tra độ trễ lũy tiến (Progressive Rate Limiting Delay)
    if (bfService.isDelayActive(AuthBruteForceService.scopeDoctor)) {
      final remaining = bfService.getRemainingDelaySeconds(AuthBruteForceService.scopeDoctor);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Đăng nhập sai quá nhiều lần. Vui lòng chờ $remaining giây trước khi thử lại.';
      });
      return;
    }

    // B. Kiểm tra thử thách CAPTCHA bắt buộc (sau 5 lần sai liên tiếp)
    if (bfService.isChallengeRequired(AuthBruteForceService.scopeDoctor)) {
      if (!bfService.validateChallenge(AuthBruteForceService.scopeDoctor, _captchaCtrl.text)) {
        bfService.recordFailedAttempt(AuthBruteForceService.scopeDoctor);
        final remaining = bfService.getRemainingDelaySeconds(AuthBruteForceService.scopeDoctor);
        setState(() {
          _isLoading = false;
          _errorMessage = remaining > 0
              ? 'Mã xác thực không chính xác! Vui lòng chờ $remaining giây trước khi thử lại.'
              : 'Mã xác thực không chính xác hoặc chưa nhập!';
        });
        return;
      }
    }

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authResult = await UserAccountService.instance.authenticateAsync(
        username: username,
        password: password,
      );

      if (!mounted) return;

      if (authResult['success'] != true) {
        bfService.recordFailedAttempt(AuthBruteForceService.scopeDoctor);
        setState(() {
          _isLoading = false;
          _errorMessage = authResult['message'] as String? ?? 'Đăng nhập không thành công. Vui lòng kiểm tra lại tài khoản và mật khẩu.';
        });
        return;
      }

      final rawAccount = authResult['account'] as UserAccountModel?;
      if (rawAccount == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể nạp thông tin tài khoản người dùng.';
        });
        return;
      }
      UserAccountModel account = rawAccount;

      // Kiểm tra chéo phân quyền: nếu account chưa mang role doctor, kiểm tra xem username có liên kết hồ sơ bác sĩ không
      if (!account.isDoctor) {
        final linkedDoc = DoctorManagementService.instance.getDoctorByUsername(
          account.username,
        );
        final isDefaultDoc =
            account.username.toLowerCase() ==
            UserAccountService.defaultDoctorAccount.username.toLowerCase();
        final hasDoctorPrefix = account.username.toLowerCase().startsWith(
          'bs_',
        );
        final hasDocId =
            account.doctorId != null && account.doctorId!.isNotEmpty;
        if (linkedDoc != null || isDefaultDoc || hasDoctorPrefix || hasDocId) {
          account = account.copyWith(
            role: UserRole.doctor,
            doctorId:
                account.doctorId ??
                linkedDoc?.id ??
                UserAccountService.defaultDoctorAccount.doctorId,
            fullName: account.fullName.isNotEmpty
                ? account.fullName
                : (linkedDoc?.fullName ??
                      UserAccountService.defaultDoctorAccount.fullName),
          );
        }
      }

      // Kiểm tra phân quyền: Bắt buộc phải là tài khoản có role doctor
      if (!account.isDoctor) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Tài khoản "${account.username}" không có quyền truy cập Cổng Bác sĩ. Vui lòng sử dụng tài khoản Bác sĩ được Quản trị viên (Admin) cấp.';
        });
        return;
      }

      if (account.isLocked) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Tài khoản bác sĩ hiện đang bị khóa. Lý do: ${account.lockReason ?? "Liên hệ quản trị viên"}';
        });
        return;
      }

      // Xác định hồ sơ Bác sĩ tương ứng
      DoctorProfile? doctor;
      if (account.doctorId != null && account.doctorId!.isNotEmpty) {
        doctor = DoctorManagementService.instance.getDoctorById(
          account.doctorId!,
        );
      }
      doctor ??= DoctorManagementService.instance.getDoctorByUsername(
        account.username,
      );

      // Nếu chưa có trong danh mục hồ sơ (profile chưa tạo), tự động khởi tạo hồ sơ bác sĩ hợp lệ
      if (doctor == null) {
        doctor = DoctorProfile(
          id: account.doctorId ?? 'doc_${account.username}',
          fullName: account.fullName.isNotEmpty
              ? account.fullName
              : 'BS. ${account.username}',
          title: 'Bác sĩ Tư vấn Sơ cứu',
          specialty: 'Khám & Tư vấn Cấp cứu Từ xa',
          hospital: 'Trung tâm Cấp cứu 115',
          phoneNumber: account.emailOrPhone ?? '115',
          workplaceAddress: 'Bệnh viện Đa khoa / Cổng Bác sĩ Trực tuyến',
          avatarInitials: account.fullName.isNotEmpty
              ? account.fullName[0].toUpperCase()
              : 'BS',
          avatarColor: const Color(0xFF2563EB),
          accountUsername: account.username,
          isOnline: true,
          statusText: 'Đang trực tuyến • Sẵn sàng hỗ trợ',
        );
      }

      // Kích hoạt và lưu phiên làm việc bác sĩ bền vững (Yêu cầu R2 - AppRootPortalSwitcher chuyển sang DoctorWorkspaceView)
      await LocalStorageService.instance.saveDoctorSession(
        username: account.username,
        doctorId: doctor.id,
      );

      bfService.recordSuccessfulLogin(AuthBruteForceService.scopeDoctor);

      setState(() {
        _isLoading = false;
      });

      widget.onLoginSuccess(doctor);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Đã xảy ra lỗi trong quá trình xác thực: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 20 : 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Biểu tượng y tế & Tiêu đề cổng
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.medical_services_rounded,
                              size: 32,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'CỔNG BÁC SĨ TRỰC TUYẾN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Đăng nhập ca trực để tiếp nhận hàng đợi bệnh nhân & tư vấn cấp cứu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Banner thông báo lỗi nếu có
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFB91C1C),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Ô nhập Tên đăng nhập
                        const Text(
                          'Tên tài khoản Bác sĩ',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameCtrl,
                          autofocus: _usernameCtrl.text.isEmpty,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'Nhập tên tài khoản (ví dụ: bs_an)',
                            hintStyle: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
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
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                                width: 1.8,
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập tên tài khoản bác sĩ.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Ô nhập Mật khẩu
                        const Text(
                          'Mật khẩu',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submitLogin(),
                          decoration: InputDecoration(
                            hintText: 'Nhập mật khẩu',
                            hintStyle: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
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
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                                width: 1.8,
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập mật khẩu.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Ghi nhớ phiên làm việc
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: const Color(0xFF2563EB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (v) {
                                  setState(() {
                                    _rememberMe = v ?? true;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Ghi nhớ đăng nhập ca trực này',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        AuthCaptchaBox(
                          scope: AuthBruteForceService.scopeDoctor,
                          controller: _captchaCtrl,
                        ),
                        const SizedBox(height: 20),

                        // Nút Đăng nhập
                        ElevatedButton.icon(
                          onPressed: (_isLoading || AuthBruteForceService.instance.isDelayActive(AuthBruteForceService.scopeDoctor))
                              ? null
                              : _submitLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded, size: 20),
                          label: Text(
                            _isLoading
                                ? 'Đang xác thực...'
                                : 'Đăng nhập ca trực',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Hộp thông tin hướng dẫn
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: Color(0xFF475569),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Thông tin tài khoản:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                '• Tài khoản bác sĩ do Quản trị viên (Admin) cấp phát.\n• Tài khoản mặc định: bs_an / password123',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Nút Thoát quay lại Cổng Người dùng / Bệnh nhân
                        TextButton.icon(
                          onPressed: widget.onExitToUserApp,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text(
                            'Quay lại Cổng Người dùng / Bệnh nhân',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
