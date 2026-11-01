import '../models/admin_login_models.dart';
import 'admin_navigation_viewmodel.dart';

mixin DangNhapQuanTriViewModel on DieuHuongQuanTriViewModel {
  // Cấu hình văn bản chuẩn xác theo ảnh thiết kế Màn hình 9
  final AdminLoginSpecModel loginSpec = const AdminLoginSpecModel(
    brandTitle: 'Trợ lý Cứu hộ AI',
    brandSubtitle: 'Quản trị hệ thống',
    formTitle: 'Đăng nhập quản trị',
    usernameLabel: 'Tài khoản',
    usernameHint: 'Nhập tài khoản (test: 1)',
    passwordLabel: 'Mật khẩu',
    passwordHint: 'Nhập mật khẩu (test: 1)',
    rememberMeLabel: 'Ghi nhớ đăng nhập',
    loginButtonLabel: 'Đăng nhập',
    rightPanelTitle: 'Khu vực quản trị',
    rightPanelSubtitle: 'Chỉ dành cho người có thẩm quyền',
  );

  // Khởi tạo sẵn giá trị '1' cho cả tài khoản và mật khẩu để test nhanh
  String _usernameInput = '1';
  String get usernameInput => _usernameInput;

  String _passwordInput = '1';
  String get passwordInput => _passwordInput;

  // Mặc định tích chọn "Ghi nhớ đăng nhập"
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
  /// Đã code cứng tài khoản và mật khẩu là 1 và 1 để test chức năng
  bool submitAdminLogin() {
    final trimmedUser = _usernameInput.trim();
    final trimmedPass = _passwordInput.trim();

    if (trimmedUser.isEmpty || trimmedPass.isEmpty) {
      _isLoginError = true;
      _loginFeedbackMessage =
          'Vui lòng nhập đầy đủ Tài khoản và Mật khẩu';
      notifyListeners();
      return false;
    }

    // Code cứng tài khoản admin và mật khẩu là 1 và 1 (hỗ trợ thêm admin / 1 / 123456)
    final bool isAuthorized = (trimmedUser == '1' && trimmedPass == '1') ||
        (trimmedUser == 'admin' &&
            (trimmedPass == '1' ||
                trimmedPass == 'admin' ||
                trimmedPass == '123456'));

    if (!isAuthorized) {
      _isLoginError = true;
      _loginFeedbackMessage =
          'Tài khoản hoặc mật khẩu không chính xác!';
      notifyListeners();
      return false;
    }

    _isLoginError = false;
    _loginFeedbackMessage = 'Đăng nhập quản trị thành công!';
    _currentAdminSession = AdminSessionModel(
      username: trimmedUser,
      displayName: 'Quản trị viên AI',
      loginTime: DateTime.now(),
    );
    completeAdminAuthentication();
    return true;
  }
}
