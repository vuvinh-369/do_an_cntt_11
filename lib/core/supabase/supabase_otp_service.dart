// File: lib/core/supabase/supabase_otp_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/services/user_account_service.dart';
import 'supabase_service.dart';

/// Dịch vụ gửi & xác thực mã OTP qua Email bằng cơ chế có sẵn của Supabase Auth
/// Thay thế toàn bộ hệ thống SMTP thủ công, quản lý email và OTP tập trung trên Supabase Cloud
class SupabaseOtpService {
  SupabaseOtpService._();
  static final SupabaseOtpService instance = SupabaseOtpService._();

  /// Gửi mã OTP khôi phục mật khẩu đến Email người dùng qua Supabase Auth
  Future<Map<String, dynamic>> sendPasswordResetOtp({
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return {
        'success': false,
        'message': 'Vui lòng nhập địa chỉ email hợp lệ để nhận mã OTP.',
      };
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      return {
        'success': false,
        'message': 'Chưa kết nối máy chủ Supabase. Vui lòng kiểm tra lại kết nối mạng.',
      };
    }

    try {
      // 1. Sử dụng signInWithOtp với shouldCreateUser: true.
      // Giải pháp cốt lõi: Nếu email chưa từng có trong auth.users (do hệ thống cũ chỉ lưu ở user_accounts),
      // hàm resetPasswordForEmail mặc định của Supabase sẽ âm thầm KHÔNG gửi mail (chống user enumeration).
      // Gọi signInWithOtp(shouldCreateUser: true) đảm bảo Supabase LUÔN LUÔN tạo tài khoản auth và GỬI MÃ OTP về email 100%!
      try {
        await client.auth.signInWithOtp(
          email: cleanEmail,
          shouldCreateUser: true,
        );
      } catch (signInErr) {
        // Fallback: Nếu signInWithOtp gặp lỗi hạn chế cấu hình, thử lại với resetPasswordForEmail
        await client.auth.resetPasswordForEmail(cleanEmail);
      }

      return {
        'success': true,
        'email': cleanEmail,
        'message': 'Mã OTP đã được gửi đến email $cleanEmail từ Supabase. Vui lòng kiểm tra hộp thư (kể cả mục Spam/Thư rác).',
      };
    } on AuthException catch (e) {
      debugPrint('[SupabaseOtpService] AuthException: ${e.message} (code: ${e.statusCode})');
      String msg = e.message;
      if (e.statusCode == '429' || msg.toLowerCase().contains('rate limit')) {
        msg = 'Bạn đã gửi yêu cầu quá nhiều lần. Supabase đang tạm khóa gửi email (Rate Limit). Vui lòng chờ ít phút hoặc cấu hình Custom SMTP trên Supabase Dashboard.';
      } else if (msg.toLowerCase().contains('not found') || msg.toLowerCase().contains('invalid user')) {
        msg = 'Không tìm thấy tài khoản tương ứng với email $cleanEmail trên máy chủ.';
      } else if (msg.toLowerCase().contains('disabled')) {
        msg = 'Tính năng gửi email xác thực hiện đang tạm dừng trong cấu hình Supabase Auth -> Providers -> Email.';
      }
      return {
        'success': false,
        'message': msg,
      };
    } catch (e) {
      debugPrint('[SupabaseOtpService] Lỗi gửi OTP: $e');
      return {
        'success': false,
        'message': 'Không thể gửi email OTP qua Supabase: $e',
      };
    }
  }

  /// Gửi mã OTP đăng nhập nhanh qua Email (Sign in with OTP)
  Future<Map<String, dynamic>> sendSignInOtp({
    required String email,
    bool shouldCreateUser = false,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final client = SupabaseService.instance.client;
    if (client == null) {
      return {
        'success': false,
        'message': 'Chưa kết nối máy chủ Supabase.',
      };
    }

    try {
      await client.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: shouldCreateUser,
      );
      return {
        'success': true,
        'email': cleanEmail,
        'message': 'Mã xác thực OTP đã được gửi tới $cleanEmail qua hệ thống Supabase Auth.',
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi gửi mã xác thực: $e',
      };
    }
  }

  /// Xác thực mã OTP và cập nhật mật khẩu mới trên Supabase Auth & user_accounts
  Future<String?> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
    String? username,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();
    final cleanPass = newPassword.trim();

    if (cleanOtp.isEmpty) {
      return 'Vui lòng nhập mã OTP xác thực.';
    }
    if (cleanPass.length < 6) {
      return 'Mật khẩu mới phải có ít nhất 6 ký tự.';
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      return 'Chưa kết nối máy chủ Supabase. Vui lòng kiểm tra mạng.';
    }

    try {
      // 1. Xác thực mã OTP thông qua Supabase Auth SDK (hỗ trợ cả OtpType.recovery và OtpType.email)
      AuthResponse? authRes;
      try {
        authRes = await client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanOtp,
          type: OtpType.recovery,
        );
      } catch (err) {
        // Thử lại với OtpType.email nếu cấu hình mẫu Supabase dùng OTP Email thường
        authRes = await client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanOtp,
          type: OtpType.email,
        );
      }

      // 2. Cập nhật mật khẩu mới trên Supabase Auth nếu đã xác thực phiên thành công
      if (authRes.session != null || authRes.user != null) {
        await client.auth.updateUser(
          UserAttributes(password: cleanPass),
        );
      }

      // 3. Đồng bộ mật khẩu mới vào bảng user_accounts của ứng dụng
      final targetUsername = username ?? cleanEmail;
      final localUser = UserAccountService.instance.findByUsername(targetUsername);
      if (localUser != null) {
        await UserAccountService.instance.changePassword(localUser.username, cleanPass);
      } else {
        // Thử tìm theo email nếu username không khớp trực tiếp
        for (final acc in UserAccountService.instance.accounts) {
          if (acc.emailOrPhone?.trim().toLowerCase() == cleanEmail) {
            await UserAccountService.instance.changePassword(acc.username, cleanPass);
            break;
          }
        }
      }

      return null; // Thành công
    } on AuthException catch (e) {
      debugPrint('[SupabaseOtpService] AuthException verifyOTP: ${e.message}');
      String msg = e.message;
      if (msg.toLowerCase().contains('expired') || msg.toLowerCase().contains('invalid token')) {
        msg = 'Mã OTP không chính xác hoặc đã hết hiệu lực. Vui lòng yêu cầu mã mới.';
      }
      return msg;
    } catch (e) {
      debugPrint('[SupabaseOtpService] Lỗi verifyOtp: $e');
      return 'Xác thực OTP thất bại: $e';
    }
  }
}
