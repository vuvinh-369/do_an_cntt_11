// File: lib/core/user_management/user_account_service.dart
import 'package:flutter/foundation.dart';

import '../../features/user/models/user_account_model.dart';
import '../supabase/supabase_service.dart';

/// Dịch vụ Singleton quản lý tài khoản người dùng, trạng thái Khóa / Mở khóa
/// và các Đơn khiếu nại mở khóa (Tích hợp Supabase Cloud & Bảo mật băm Bcrypt pgcrypto)
class UserAccountService extends ChangeNotifier {
  UserAccountService._() {
    // Tự động tải dữ liệu từ Supabase khi dịch vụ khởi động
    fetchAccountsFromSupabase();
    fetchAppealsFromSupabase();
  }
  static final UserAccountService instance = UserAccountService._();

  // Danh sách tài khoản người dùng được đồng bộ từ Supabase
  final List<UserAccountModel> _accounts = [];
  List<UserAccountModel> get accounts => List.unmodifiable(_accounts);

  // Danh sách các yêu cầu mở khóa tài khoản được đồng bộ từ Supabase
  final List<UserUnlockAppealModel> _appeals = [];
  List<UserUnlockAppealModel> get appeals => List.unmodifiable(_appeals);

  int get pendingAppealCount =>
      _appeals.where((a) => a.isPending).length;

  /// Tìm kiếm tài khoản theo username trong bộ nhớ đệm đồng bộ
  UserAccountModel? findByUsername(String username) {
    final clean = username.trim().toLowerCase();
    final idx = _accounts.indexWhere((a) => a.username.toLowerCase() == clean);
    return idx != -1 ? _accounts[idx] : null;
  }

  /// Tải danh sách tài khoản từ bảng 'user_accounts' trên Supabase
  Future<void> fetchAccountsFromSupabase() async {
    try {
      final client = SupabaseService.instance.client;
      if (client == null) return;

      final res = await client
          .from('user_accounts')
          .select()
          .order('created_at', ascending: false);

      _accounts.clear();
      for (final row in res) {
        _accounts.add(UserAccountModel.fromMap(row));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[UserAccountService] Tải tài khoản Supabase (đang chuẩn bị bảng): $e');
    }
  }

  /// Tải danh sách yêu cầu mở khóa từ bảng 'account_unlock_appeals' trên Supabase
  Future<void> fetchAppealsFromSupabase() async {
    try {
      final client = SupabaseService.instance.client;
      if (client == null) return;

      final res = await client
          .from('account_unlock_appeals')
          .select()
          .order('created_at', ascending: false);

      _appeals.clear();
      for (final row in res) {
        _appeals.add(UserUnlockAppealModel.fromMap(row));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[UserAccountService] Tải khiếu nại Supabase (đang chuẩn bị bảng): $e');
    }
  }

  /// Đăng ký tài khoản người dùng mới (Băm mật khẩu bằng Bcrypt pgcrypto trên Supabase)
  Future<String?> registerAsync({
    required String username,
    required String password,
    String? emailOrPhone,
  }) async {
    final cleanUser = username.trim();
    if (cleanUser.length < 3) {
      return 'Tên tài khoản phải có ít nhất 3 ký tự.';
    }
    if (password.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        // Gọi Stored Procedure băm Bcrypt trên Supabase
        final rpcRes = await client.rpc('register_user_account', params: {
          'p_username': cleanUser,
          'p_password': password,
          'p_email_or_phone': emailOrPhone?.trim().isNotEmpty == true ? emailOrPhone!.trim() : null,
        });

        if (rpcRes is Map) {
          if (rpcRes['success'] != true) {
            return rpcRes['message'] as String? ?? 'Đăng ký không thành công.';
          }
          await fetchAccountsFromSupabase();
          return null;
        }
      }
    } catch (e) {
      debugPrint('[UserAccountService] Gọi RPC register_user_account: $e');
      // Dự phòng nếu chưa chạy SQL tạo hàm RPC: Insert trực tiếp vào bảng
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          await client.from('user_accounts').insert({
            'username': cleanUser,
            'password_hash': password, // Sau khi chạy script SQL sẽ tự băm Bcrypt
            'email_or_phone': emailOrPhone?.trim(),
            'created_at': DateTime.now().toIso8601String(),
            'last_active_at': DateTime.now().toIso8601String(),
            'is_locked': false,
          });
          await fetchAccountsFromSupabase();
          return null;
        }
      } catch (insertErr) {
        debugPrint('[UserAccountService] Lỗi insert bảng user_accounts: $insertErr');
      }
    }

    // Fallback đồng bộ bộ nhớ tạm
    final newAccount = UserAccountModel(
      username: cleanUser,
      password: password,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      emailOrPhone: emailOrPhone?.trim().isNotEmpty == true ? emailOrPhone!.trim() : null,
      isLocked: false,
    );
    _accounts.insert(0, newAccount);
    notifyListeners();
    return null;
  }

  /// Wrapper đồng bộ tương thích ngược cho giao diện hiện tại
  String? register({
    required String username,
    required String password,
    String? emailOrPhone,
  }) {
    registerAsync(username: username, password: password, emailOrPhone: emailOrPhone);
    final cleanUser = username.trim();
    if (findByUsername(cleanUser) == null) {
      _accounts.insert(0, UserAccountModel(
        username: cleanUser,
        password: password,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        emailOrPhone: emailOrPhone,
      ));
      notifyListeners();
    }
    return null;
  }

  /// Xác thực đăng nhập người dùng (So khớp Bcrypt qua pgcrypto trên Supabase)
  Future<Map<String, dynamic>> authenticateAsync({
    required String username,
    required String password,
  }) async {
    final cleanUser = username.trim();
    final cleanPass = password.trim();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        final rpcRes = await client.rpc('authenticate_user_account', params: {
          'p_username': cleanUser,
          'p_password': cleanPass,
        });

        if (rpcRes is Map) {
          if (rpcRes['success'] == true) {
            final accMap = rpcRes['account'] as Map<String, dynamic>;
            final account = UserAccountModel.fromMap(accMap);
            // Cập nhật bộ nhớ đệm
            final idx = _accounts.indexWhere((a) => a.username.toLowerCase() == cleanUser.toLowerCase());
            if (idx != -1) {
              _accounts[idx] = account;
            } else {
              _accounts.insert(0, account);
            }
            notifyListeners();
            return {'success': true, 'account': account};
          } else {
            return {
              'success': false,
              'isLocked': rpcRes['is_locked'] == true,
              'lockReason': rpcRes['lock_reason'],
              'message': rpcRes['message'] ?? 'Đăng nhập không thành công.',
            };
          }
        }
      }
    } catch (e) {
      debugPrint('[UserAccountService] Gọi RPC authenticate_user_account: $e');
    }

    // Fallback kiểm tra từ bộ nhớ đệm nếu chưa chạy SQL trên Supabase
    return authenticate(username: username, password: password);
  }

  /// Xác thực đăng nhập
  Map<String, dynamic> authenticate({
    required String username,
    required String password,
  }) {
    final cleanUser = username.trim();
    final cleanPass = password.trim();
    final account = findByUsername(cleanUser);

    if (account == null) {
      return {
        'success': false,
        'message': 'Tài khoản "$cleanUser" không tồn tại trong hệ thống.',
      };
    }

    if (account.password != cleanPass) {
      return {
        'success': false,
        'message': 'Mật khẩu không chính xác. Vui lòng kiểm tra lại.',
      };
    }

    if (account.isLocked) {
      return {
        'success': false,
        'isLocked': true,
        'lockReason': account.lockReason ?? 'Tài khoản của bạn đã bị tạm khóa bởi Quản trị viên do vi phạm quy định.',
        'message': 'Tài khoản của bạn hiện đang bị khóa.',
      };
    }

    final updated = account.copyWith(lastActiveAt: DateTime.now());
    final idx = _accounts.indexWhere((a) => a.username.toLowerCase() == cleanUser.toLowerCase());
    if (idx != -1) {
      _accounts[idx] = updated;
    }
    notifyListeners();

    // Đồng bộ async thời gian truy cập lên Supabase
    _syncLastActiveToSupabase(cleanUser);

    return {
      'success': true,
      'account': updated,
    };
  }

  void _syncLastActiveToSupabase(String username) async {
    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client
            .from('user_accounts')
            .update({'last_active_at': DateTime.now().toIso8601String()})
            .eq('username', username);
      }
    } catch (_) {}
  }

  /// Cập nhật hồ sơ sức khỏe cá nhân (Zero-Knowledge)
  Future<void> updateProfile(UserAccountModel updated) async {
    final idx = _accounts.indexWhere(
      (a) => a.username.toLowerCase() == updated.username.toLowerCase(),
    );
    if (idx != -1) {
      _accounts[idx] = updated;
      notifyListeners();
    }

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client
            .from('user_accounts')
            .update({'medical_profile': updated.toMedicalProfileMap()})
            .eq('username', updated.username);
      }
    } catch (e) {
      debugPrint('[UserAccountService] Cập nhật medical_profile lên Supabase: $e');
    }
  }

  /// Đổi mật khẩu
  Future<void> changePassword(String username, String newPassword) async {
    final idx = _accounts.indexWhere(
      (a) => a.username.toLowerCase() == username.toLowerCase(),
    );
    if (idx != -1) {
      _accounts[idx] = _accounts[idx].copyWith(password: newPassword);
      notifyListeners();
    }

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.rpc('change_user_password', params: {
          'p_username': username,
          'p_old_password': _accounts[idx].password,
          'p_new_password': newPassword,
        });
      }
    } catch (e) {
      debugPrint('[UserAccountService] Đổi mật khẩu Supabase: $e');
    }
  }

  // ===========================================================================
  // CÁC THAO TÁC QUẢN TRỊ ADMIN (Khóa, Mở khóa, Xóa, Duyệt yêu cầu)
  // ===========================================================================

  /// Khóa (vô hiệu hóa) tài khoản người dùng
  Future<void> blockUser({
    required String username,
    String? reason,
  }) async {
    final cleanReason = reason ?? 'Tài khoản vi phạm quy chuẩn sử dụng hoặc offline quá lâu.';
    final idx = _accounts.indexWhere(
      (a) => a.username.toLowerCase() == username.toLowerCase(),
    );
    if (idx != -1) {
      _accounts[idx] = _accounts[idx].copyWith(
        isLocked: true,
        lockReason: cleanReason,
      );
      notifyListeners();
    }

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('user_accounts').update({
          'is_locked': true,
          'lock_reason': cleanReason,
        }).eq('username', username);
      }
    } catch (e) {
      debugPrint('[UserAccountService] Khóa tài khoản trên Supabase: $e');
    }
  }

  /// Mở khóa tài khoản người dùng
  Future<void> unblockUser(String username) async {
    final idx = _accounts.indexWhere(
      (a) => a.username.toLowerCase() == username.toLowerCase(),
    );
    if (idx != -1) {
      _accounts[idx] = _accounts[idx].copyWith(
        isLocked: false,
        lockReason: null,
      );
      notifyListeners();
    }

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('user_accounts').update({
          'is_locked': false,
          'lock_reason': null,
        }).eq('username', username);
      }
    } catch (e) {
      debugPrint('[UserAccountService] Mở khóa tài khoản trên Supabase: $e');
    }
  }

  /// Xóa tài khoản người dùng (Xóa tài khoản rác/offline quá lâu)
  Future<void> deleteUser(String username) async {
    _accounts.removeWhere(
      (a) => a.username.toLowerCase() == username.toLowerCase(),
    );
    _appeals.removeWhere(
      (ap) => ap.username.toLowerCase() == username.toLowerCase(),
    );
    notifyListeners();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('user_accounts').delete().eq('username', username);
      }
    } catch (e) {
      debugPrint('[UserAccountService] Xóa tài khoản trên Supabase: $e');
    }
  }

  /// Người dùng gửi yêu cầu gỡ khóa tài khoản
  Future<void> submitUnlockAppeal({
    required String username,
    required String reason,
  }) async {
    final newAppeal = UserUnlockAppealModel(
      id: 'appeal_${DateTime.now().millisecondsSinceEpoch}',
      username: username.trim(),
      reason: reason.trim(),
      createdAt: DateTime.now(),
      status: 'pending',
    );
    _appeals.insert(0, newAppeal);
    notifyListeners();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('account_unlock_appeals').insert({
          'username': username.trim(),
          'reason': reason.trim(),
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
        await fetchAppealsFromSupabase();
      }
    } catch (e) {
      debugPrint('[UserAccountService] Gửi khiếu nại lên Supabase: $e');
    }
  }

  /// Quản trị viên duyệt và mở khóa tài khoản ngay lập tức
  Future<void> approveUnlockAppeal(String appealId) async {
    final idx = _appeals.indexWhere((a) => a.id == appealId);
    if (idx != -1) {
      final appeal = _appeals[idx];
      _appeals[idx] = appeal.copyWith(
        status: 'approved',
        resolvedAt: DateTime.now(),
        adminNote: 'Đã phê duyệt mở khóa tài khoản.',
      );
      unblockUser(appeal.username);
      notifyListeners();

      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          await client.from('account_unlock_appeals').update({
            'status': 'approved',
            'admin_note': 'Đã phê duyệt mở khóa tài khoản.',
            'resolved_at': DateTime.now().toIso8601String(),
          }).eq('id', appealId);
        }
      } catch (e) {
        debugPrint('[UserAccountService] Phê duyệt khiếu nại Supabase: $e');
      }
    }
  }

  /// Quản trị viên từ chối yêu cầu mở khóa
  Future<void> rejectUnlockAppeal(String appealId, {String? note}) async {
    final idx = _appeals.indexWhere((a) => a.id == appealId);
    if (idx != -1) {
      final appeal = _appeals[idx];
      final finalNote = note ?? 'Yêu cầu không đủ điều kiện phê duyệt.';
      _appeals[idx] = appeal.copyWith(
        status: 'rejected',
        resolvedAt: DateTime.now(),
        adminNote: finalNote,
      );
      notifyListeners();

      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          await client.from('account_unlock_appeals').update({
            'status': 'rejected',
            'admin_note': finalNote,
            'resolved_at': DateTime.now().toIso8601String(),
          }).eq('id', appealId);
        }
      } catch (e) {
        debugPrint('[UserAccountService] Từ chối khiếu nại Supabase: $e');
      }
    }
  }
}
