import '../models/admin_login_models.dart';
import 'admin_navigation_viewmodel.dart';

mixin DangNhapQuanTriViewModel on DieuHuongQuanTriViewModel {
  // Cấu hình văn bản chuẩn xác theo ảnh thiết kế Màn hình 9
  final AdminLoginSpecModel loginSpec = const AdminLoginSpecModel(
    brandTitle: 'Trợ lý Cứu hộ AI',
    brandSubtitle: 'Quản trị hệ thống',
    formTitle: 'Đăng nhập quản trị',
    usernameLabel: 'Tài khoản',
    usernameHint: 'Nhập tài khoản',
    passwordLabel: 'Mật khẩu',
    passwordHint: 'Nhập mật khẩu',
    rememberMeLabel: 'Ghi nhớ đăng nhập',
    loginButtonLabel: 'Đăng nhập',
    rightPanelTitle: 'Khu vực quản trị',
    rightPanelSubtitle: 'Chỉ dành cho người có thẩm quyền',
  );

  String _usernameInput = '';
  String get usernameInput => _usernameInput;

  String _passwordInput = '';
  String get passwordInput => _passwordInput;

  // Mặc định tích chọn "Ghi nhớ đăng nhập" đúng như ảnh thiết kế Màn hình 9
  bool _rememberMe = true;
  bool get rememberMe => _rememberMe;

  // Trạng thái ẩn/hiện mật khẩu khi nhấn vào icon con mắt
  bool _isPasswordObscured = true;
  bool get isPasswordObscured => _isPasswordObscured;

  // Thông báo lỗi kiểm tra hợp lệ hoặc thông báo trạng thái đăng nhập
  String? _loginFeedbackMessage;
  String? get loginFeedbackMessage => _loginFeedbackMessage;

  bool _isLoginError = false;
  bool get isLoginError => _isLoginError;

  AdminSessionModel _currentAdminSession = const AdminSessionModel(
    username: 'admin',
    displayName: 'Quản trị viên',
  );
  AdminSessionModel get currentAdminSession => _currentAdminSession;

  void updateUsername(String value) {
    _usernameInput = value;
    if (_loginFeedbackMessage != null) {
      _loginFeedbackMessage = null;
      notifyListeners();
    }
  }

  void updatePassword(String value) {
    _passwordInput = value;
    if (_loginFeedbackMessage != null) {
      _loginFeedbackMessage = null;
      notifyListeners();
    }
  }

  void toggleRememberMe(bool? value) {
    _rememberMe = value ?? false;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _isPasswordObscured = !_isPasswordObscured;
    notifyListeners();
  }

  /// Xử lý khi bấm nút "Đăng nhập" trên Màn hình 9
  bool submitAdminLogin() {
    final trimmedUser = _usernameInput.trim();
    final trimmedPass = _passwordInput.trim();

    if (trimmedUser.isEmpty || trimmedPass.isEmpty) {
      _isLoginError = true;
      _loginFeedbackMessage =
          'Vui lòng nhập đầy đủ Tài khoản và Mật khẩu quản trị.';
      notifyListeners();
      return false;
    }

    // Chấp nhận tài khoản demo (ví dụ: admin / 123456 hoặc bất kỳ tài khoản hợp lệ >= 3 ký tự)
    if (trimmedPass.length < 3) {
      _isLoginError = true;
      _loginFeedbackMessage = 'Mật khẩu quản trị phải có ít nhất 3 ký tự.';
      notifyListeners();
      return false;
    }

    _isLoginError = false;
    _loginFeedbackMessage = 'Đăng nhập quản trị thành công!';
    _currentAdminSession = AdminSessionModel(
      username: trimmedUser,
      displayName: trimmedUser == 'admin' ? 'Quản trị viên AI' : trimmedUser,
      loginTime: DateTime.now(),
    );
    completeAdminAuthentication();
    return true;
  }
}
