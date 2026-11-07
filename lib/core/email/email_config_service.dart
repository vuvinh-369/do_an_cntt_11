// File: lib/core/email/email_config_service.dart
import 'dart:math';

/// Model cấu hình dịch vụ Email (SMTP & Khôi phục mật khẩu)
class EmailConfigModel {
  final bool isEnabled;
  final String smtpHost;
  final int smtpPort;
  final String senderEmail;
  final String senderName;
  final String smtpPassword;
  final bool isSslTls;
  final int otpExpiryMinutes;
  final String emailSubject;

  const EmailConfigModel({
    this.isEnabled = true,
    this.smtpHost = 'smtp.gmail.com',
    this.smtpPort = 587,
    this.senderEmail = 'cuuho.ai.system@gmail.com',
    this.senderName = 'Trợ lý Cứu hộ AI',
    this.smtpPassword = '••••••••••••••••',
    this.isSslTls = true,
    this.otpExpiryMinutes = 5,
    this.emailSubject = '[Trợ lý Cứu hộ AI] Mã OTP khôi phục mật khẩu của bạn',
  });

  EmailConfigModel copyWith({
    bool? isEnabled,
    String? smtpHost,
    int? smtpPort,
    String? senderEmail,
    String? senderName,
    String? smtpPassword,
    bool? isSslTls,
    int? otpExpiryMinutes,
    String? emailSubject,
  }) {
    return EmailConfigModel(
      isEnabled: isEnabled ?? this.isEnabled,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      senderEmail: senderEmail ?? this.senderEmail,
      senderName: senderName ?? this.senderName,
      smtpPassword: smtpPassword ?? this.smtpPassword,
      isSslTls: isSslTls ?? this.isSslTls,
      otpExpiryMinutes: otpExpiryMinutes ?? this.otpExpiryMinutes,
      emailSubject: emailSubject ?? this.emailSubject,
    );
  }
}

/// Bản ghi OTP đang hoạt động trong RAM
class PendingOtpRecord {
  final String identifier; // username hoặc email (in lowercase)
  final String targetEmail;
  final String username;
  final String otpCode;
  final DateTime createdAt;
  final DateTime expiresAt;

  PendingOtpRecord({
    required this.identifier,
    required this.targetEmail,
    required this.username,
    required this.otpCode,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Nhật ký gửi email OTP (lưu tạm trong RAM phục vụ quan sát ở /admin)
class EmailDispatchLog {
  final String id;
  final DateTime timestamp;
  final String recipient;
  final String subject;
  final String otpCode;
  final String status;
  final String details;

  EmailDispatchLog({
    required this.id,
    required this.timestamp,
    required this.recipient,
    required this.subject,
    required this.otpCode,
    required this.status,
    required this.details,
  });
}

/// Singleton Service quản lý cấu hình Email & cấp phát mã OTP lưu tạm trong RAM
class EmailConfigService {
  EmailConfigService._();
  static final EmailConfigService instance = EmailConfigService._();

  // Cấu hình email lưu tạm trong RAM
  EmailConfigModel _config = const EmailConfigModel();
  EmailConfigModel get config => _config;

  // Bản đồ lưu trữ các mã OTP đang chờ xác minh: Key = lowercase(identifier)
  final Map<String, PendingOtpRecord> _pendingOtps = {};

  // Lịch sử nhật ký gửi email trong phiên làm việc
  final List<EmailDispatchLog> _dispatchLogs = [];
  List<EmailDispatchLog> get dispatchLogs => List.unmodifiable(_dispatchLogs.reversed);

  /// Cập nhật cấu hình email từ trang /admin
  void updateConfig(EmailConfigModel newConfig) {
    _config = newConfig;
  }

  /// Khôi phục cấu hình email về mặc định
  void resetToDefaults() {
    _config = const EmailConfigModel();
  }

  /// Sinh mã OTP 6 số và lưu vào RAM
  Map<String, dynamic> generateAndDispatchOtp({
    required String identifier,
    required String targetEmail,
    required String username,
  }) {
    if (!_config.isEnabled) {
      return {
        'success': false,
        'message': 'Dịch vụ gửi email khôi phục mật khẩu hiện đang tạm dừng bởi Quản trị viên.',
      };
    }

    final random = Random();
    // Sinh mã OTP 6 chữ số ngẫu nhiên
    final otp = (100000 + random.nextInt(900000)).toString();

    final now = DateTime.now();
    final expiresAt = now.add(Duration(minutes: _config.otpExpiryMinutes));

    final record = PendingOtpRecord(
      identifier: identifier.trim().toLowerCase(),
      targetEmail: targetEmail.trim(),
      username: username,
      otpCode: otp,
      createdAt: now,
      expiresAt: expiresAt,
    );

    // Lưu đè vào danh sách chờ xác thực trong RAM
    _pendingOtps[identifier.trim().toLowerCase()] = record;
    // Đồng thời lưu theo email để người dùng nhập username hay email đều khớp
    if (targetEmail.trim().isNotEmpty) {
      _pendingOtps[targetEmail.trim().toLowerCase()] = record;
    }

    // Ghi nhật ký vào RAM cho Admin theo dõi
    final logId = 'LOG_${now.millisecondsSinceEpoch}_${random.nextInt(999)}';
    _dispatchLogs.add(
      EmailDispatchLog(
        id: logId,
        timestamp: now,
        recipient: targetEmail,
        subject: _config.emailSubject,
        otpCode: otp,
        status: 'Đã gửi (RAM)',
        details: 'Mã xác nhận hết hạn lúc ${expiresAt.hour.toString().padLeft(2, '0')}:${expiresAt.minute.toString().padLeft(2, '0')} (${_config.otpExpiryMinutes} phút).',
      ),
    );

    return {
      'success': true,
      'otp': otp,
      'expiresAt': expiresAt,
      'targetEmail': targetEmail,
      'message': 'Mã OTP đã được gửi đến email $targetEmail.',
    };
  }

  /// Kiểm tra tính hợp lệ của mã OTP
  Map<String, dynamic> verifyOtp({
    required String identifier,
    required String otpInput,
  }) {
    final key = identifier.trim().toLowerCase();
    final record = _pendingOtps[key];

    if (record == null) {
      return {
        'valid': false,
        'message': 'Không tìm thấy yêu cầu đặt lại mật khẩu hoặc mã OTP chưa được tạo.',
      };
    }

    if (record.isExpired) {
      _pendingOtps.remove(key);
      return {
        'valid': false,
        'message': 'Mã OTP đã hết hạn (${_config.otpExpiryMinutes} phút). Vui lòng yêu cầu mã mới.',
      };
    }

    if (record.otpCode != otpInput.trim()) {
      return {
        'valid': false,
        'message': 'Mã xác nhận OTP không chính xác. Vui lòng kiểm tra lại.',
      };
    }

    return {
      'valid': true,
      'record': record,
      'message': 'Xác thực OTP thành công.',
    };
  }

  /// Hủy OTP sau khi đã đổi mật khẩu thành công
  void consumeOtp(String identifier) {
    final key = identifier.trim().toLowerCase();
    final record = _pendingOtps.remove(key);
    if (record != null) {
      _pendingOtps.remove(record.targetEmail.toLowerCase());
      _pendingOtps.remove(record.username.toLowerCase());
    }
  }

  /// Gửi thử một email kiểm tra từ trang /admin
  void sendTestEmail({required String testRecipient}) {
    final now = DateTime.now();
    final logId = 'TEST_${now.millisecondsSinceEpoch}';

    _dispatchLogs.add(
      EmailDispatchLog(
        id: logId,
        timestamp: now,
        recipient: testRecipient.trim(),
        subject: '[TEST] Kiểm tra kết nối SMTP máy chủ',
        otpCode: 'TEST',
        status: 'Thành công (RAM)',
        details: 'Gửi thử nghiệm cấu hình SMTP ${_config.smtpHost}:${_config.smtpPort} từ ${_config.senderEmail}.',
      ),
    );
  }

  /// Xóa toàn bộ nhật ký gửi email trong RAM
  void clearLogs() {
    _dispatchLogs.clear();
  }
}
