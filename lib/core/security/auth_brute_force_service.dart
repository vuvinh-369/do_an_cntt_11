// File: lib/core/security/auth_brute_force_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:do_an_cntt_11/core/storage/local_storage_service.dart';

/// Đại diện cho một thử thách CAPTCHA tự sinh nội bộ (Self-contained Challenge)
class AuthCaptchaChallenge {
  final String id;
  final String question; // ví dụ: "18 + 27 = ?"
  final String answer; // "45"
  final DateTime createdAt;
  final DateTime expiresAt;

  AuthCaptchaChallenge({
    required this.id,
    required this.question,
    required this.answer,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Dịch vụ phòng thủ chống tấn công vét cạn (Brute-Force & Credential Spam Protection)
///
/// Yêu cầu R2 & R3:
/// 1. Theo dõi số lần đăng nhập sai theo từng cổng: Admin ('admin'), Bác sĩ ('doctor'), Người dùng ('user').
/// 2. Bắt buộc giải CAPTCHA tự sinh sau 5 lần đăng nhập sai liên tiếp (failedAttempts >= 5).
/// 3. Trì hoãn lũy tiến (Progressive Delays) trên các lần sai liên tiếp:
///    - Lần sai thứ 5 (chuẩn bị lần 6): phạt hoãn tối thiểu 5 giây.
///    - Lần sai thứ 6 (chuẩn bị lần 7): phạt hoãn 10 giây.
///    - Lần sai thứ 7: phạt hoãn 15 giây...
///    Công thức: Delay(N) = 5 + (N - 5) * 5 giây với N >= 5.
/// 4. Từ chối sớm (Early Rejection) nếu đang trong thời gian chờ hoặc thiếu/sai mã CAPTCHA.
/// 5. Đăng nhập đúng + CAPTCHA đúng -> Khôi phục truy cập, xóa bộ đếm thất bại về 0.
/// 6. Bền vững qua reload trình duyệt qua LocalStorageService.
class AuthBruteForceService extends ChangeNotifier {
  AuthBruteForceService._() {
    _initStorage();
  }

  static final AuthBruteForceService instance = AuthBruteForceService._();

  static const String scopeAdmin = 'admin';
  static const String scopeDoctor = 'doctor';
  static const String scopeUser = 'user';

  final Map<String, int> _failedAttempts = {};
  final Map<String, DateTime> _lockedUntil = {};
  final Map<String, AuthCaptchaChallenge> _activeChallenges = {};
  final math.Random _random = math.Random();

  bool _initialized = false;

  Future<void> _initStorage() async {
    if (_initialized) return;
    for (final scope in [scopeAdmin, scopeDoctor, scopeUser]) {
      final data = await LocalStorageService.instance.loadFailedLoginAttempts(scope);
      final count = data['count'] as int? ?? 0;
      final locked = data['lockedUntil'] as DateTime?;
      if (count > 0) {
        _failedAttempts[scope] = count;
      }
      if (locked != null && DateTime.now().isBefore(locked)) {
        _lockedUntil[scope] = locked;
      }
    }
    _initialized = true;
    notifyListeners();
  }

  /// Lấy số lần đăng nhập sai liên tiếp của một cổng
  int getFailedAttempts(String scope) {
    return _failedAttempts[scope] ?? 0;
  }

  /// Kiểm tra cổng có yêu cầu mã xác thực CAPTCHA không (khi failedAttempts >= 5)
  bool isChallengeRequired(String scope) {
    return getFailedAttempts(scope) >= 5;
  }

  /// Tính toán thời gian phạt trì hoãn (giây) theo số lần thất bại liên tiếp
  /// - Dưới 5 lần: 0 giây
  /// - Lần 5: 5 giây
  /// - Lần 6: 10 giây
  /// - Lần 7: 15 giây
  /// - Lần 8: 20 giây...
  int calculateDelaySeconds(int consecutiveFailures) {
    if (consecutiveFailures < 5) return 0;
    return 5 + (consecutiveFailures - 5) * 5;
  }

  /// Kiểm tra có đang bị khóa bởi thời gian trì hoãn lũy tiến không
  bool isDelayActive(String scope) {
    final lockedUntil = _lockedUntil[scope];
    if (lockedUntil == null) return false;
    if (DateTime.now().isBefore(lockedUntil)) {
      return true;
    } else {
      _lockedUntil.remove(scope);
      return false;
    }
  }

  /// Lấy số giây còn lại cần phải chờ
  int getRemainingDelaySeconds(String scope) {
    final lockedUntil = _lockedUntil[scope];
    if (lockedUntil == null) return 0;
    final now = DateTime.now();
    if (now.isBefore(lockedUntil)) {
      final remaining = lockedUntil.difference(now).inSeconds;
      return remaining > 0 ? remaining : 1;
    }
    return 0;
  }

  /// Lấy hoặc tạo mới thử thách CAPTCHA đang hoạt động cho cổng
  AuthCaptchaChallenge getOrGenerateChallenge(String scope) {
    final existing = _activeChallenges[scope];
    if (existing != null && !existing.isExpired) {
      return existing;
    }
    return generateNewChallenge(scope);
  }

  /// Tự sinh một thử thách CAPTCHA toán học mới hoàn toàn nội bộ
  AuthCaptchaChallenge generateNewChallenge(String scope) {
    final isAddition = _random.nextBool();
    int a = 10 + _random.nextInt(41); // 10..50
    int b = 1 + _random.nextInt(30);  // 1..30
    if (!isAddition && a < b) {
      final t = a;
      a = b;
      b = t;
    }
    final op = isAddition ? '+' : '-';
    final ans = isAddition ? (a + b) : (a - b);
    final question = '$a $op $b = ?';

    final challenge = AuthCaptchaChallenge(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}',
      question: question,
      answer: ans.toString(),
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    _activeChallenges[scope] = challenge;
    notifyListeners();
    return challenge;
  }

  /// Xác minh lời giải CAPTCHA của người dùng
  bool validateChallenge(String scope, String? answerInput) {
    if (!isChallengeRequired(scope)) {
      return true; // Chưa đến ngưỡng 5 lần thì không bắt buộc
    }
    if (answerInput == null || answerInput.trim().isEmpty) {
      return false;
    }
    final challenge = _activeChallenges[scope];
    if (challenge == null || challenge.isExpired) {
      return false;
    }
    return answerInput.trim() == challenge.answer.trim();
  }

  /// Ghi nhận 1 lần đăng nhập thất bại
  void recordFailedAttempt(String scope) {
    final current = getFailedAttempts(scope);
    final next = current + 1;
    _failedAttempts[scope] = next;

    DateTime? lockTime;
    if (next >= 5) {
      final delaySeconds = calculateDelaySeconds(next);
      lockTime = DateTime.now().add(Duration(seconds: delaySeconds));
      _lockedUntil[scope] = lockTime;
      // Sinh mới thử thách nếu chưa có hoặc làm mới
      generateNewChallenge(scope);
    }

    LocalStorageService.instance.saveFailedLoginAttempts(scope, next, lockTime);
    notifyListeners();
  }

  /// Ghi nhận đăng nhập thành công: xóa toàn bộ vi phạm và khôi phục trạng thái
  void recordSuccessfulLogin(String scope) {
    _failedAttempts[scope] = 0;
    _lockedUntil.remove(scope);
    _activeChallenges.remove(scope);
    LocalStorageService.instance.clearFailedLoginAttempts(scope);
    notifyListeners();
  }

  /// Phục vụ cho kiểm thử tự động (Unit Test / Automated Runner)
  void resetForTest([String? scope]) {
    if (scope != null) {
      _failedAttempts.remove(scope);
      _lockedUntil.remove(scope);
      _activeChallenges.remove(scope);
      LocalStorageService.instance.clearFailedLoginAttempts(scope);
    } else {
      _failedAttempts.clear();
      _lockedUntil.clear();
      _activeChallenges.clear();
      for (final s in [scopeAdmin, scopeDoctor, scopeUser]) {
        LocalStorageService.instance.clearFailedLoginAttempts(s);
      }
    }
    notifyListeners();
  }
}
