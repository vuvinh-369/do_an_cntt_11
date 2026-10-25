/// Mô hình dữ liệu cấu hình văn bản hiển thị cho màn hình "9. Đăng nhập quản trị" (Màn hình 9)
class AdminLoginSpecModel {
  final String brandTitle;
  final String brandSubtitle;
  final String formTitle;
  final String usernameLabel;
  final String usernameHint;
  final String passwordLabel;
  final String passwordHint;
  final String rememberMeLabel;
  final String loginButtonLabel;
  final String rightPanelTitle;
  final String rightPanelSubtitle;

  const AdminLoginSpecModel({
    required this.brandTitle,
    required this.brandSubtitle,
    required this.formTitle,
    required this.usernameLabel,
    required this.usernameHint,
    required this.passwordLabel,
    required this.passwordHint,
    required this.rememberMeLabel,
    required this.loginButtonLabel,
    required this.rightPanelTitle,
    required this.rightPanelSubtitle,
  });
}

/// Mô hình thông tin phiên đăng nhập của Quản trị viên
class AdminSessionModel {
  final String username;
  final String displayName;
  final String roleLabel;
  final DateTime? loginTime;

  const AdminSessionModel({
    required this.username,
    required this.displayName,
    this.roleLabel = 'Quản trị hệ thống',
    this.loginTime,
  });
}
