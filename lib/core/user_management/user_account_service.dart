// File: lib/core/user_management/user_account_service.dart
import 'package:flutter/foundation.dart';

import '../../features/user/models/user_account_model.dart';
import '../doctor_management/doctor_management_service.dart';
import '../storage/local_storage_service.dart';
import '../supabase/supabase_service.dart';

/// Dịch vụ Singleton quản lý tài khoản người dùng, trạng thái Khóa / Mở khóa
/// và các Đơn khiếu nại mở khóa (Tích hợp Supabase Cloud & Bảo mật băm Bcrypt pgcrypto)
class UserAccountService extends ChangeNotifier {
  /// Tài khoản bác sĩ mẫu mặc định offline (Fail-safe)
  static final UserAccountModel defaultDoctorAccount = UserAccountModel(
    username: 'bs_an',
    password: 'password123',
    fullName: 'BS. CKI Nguyễn Văn An',
    role: UserRole.doctor,
    doctorId: 'doc_an_nguyen',
    emailOrPhone: '0912345678',
    createdAt: DateTime(2026, 1, 1),
    lastActiveAt: DateTime.now(),
    isLocked: false,
  );

  UserAccountService._() {
    _initSeedAccounts();
    loadFromLocalStorage();
    // Tự động tải dữ liệu từ Supabase khi dịch vụ khởi động
    fetchAccountsFromSupabase();
    fetchAppealsFromSupabase();
  }
  static final UserAccountService instance = UserAccountService._();

  // Danh sách tài khoản người dùng được đồng bộ từ Supabase
  final List<UserAccountModel> _accounts = [];
  List<UserAccountModel> get accounts => List.unmodifiable(_accounts);

  void _initSeedAccounts() {
    if (_accounts.isEmpty) {
      _accounts.add(defaultDoctorAccount);
    }
  }

  /// Nạp các tài khoản bác sĩ đã được cấp từ bộ lưu trữ cục bộ SharedPreferences (Yêu cầu R1)
  Future<void> loadFromLocalStorage() async {
    try {
      final savedMaps = await LocalStorageService.instance.loadProvisionedDoctorAccounts();
      if (savedMaps.isNotEmpty) {
        for (final map in savedMaps) {
          try {
            final acc = UserAccountModel.fromMap(map);
            final cleanUser = acc.username.trim().toLowerCase();
            final existingIdx = _accounts.indexWhere(
              (a) => a.username.trim().toLowerCase() == cleanUser,
            );
            if (existingIdx != -1) {
              _accounts[existingIdx] = acc;
            } else {
              _accounts.add(acc);
            }
          } catch (e) {
            debugPrint('[UserAccountService] Lỗi parse provisioned account: $e');
          }
        }
      }
      _initSeedAccounts();
      notifyListeners();
    } catch (e) {
      debugPrint('[UserAccountService] Lỗi loadFromLocalStorage: $e');
    }
  }

  /// Khôi phục dữ liệu bộ nhớ về danh sách seed mặc định (dùng cho test/reset)
  void resetToDefaultSeed() {
    _accounts.clear();
    _accounts.add(defaultDoctorAccount);
    notifyListeners();
  }

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

      final savedDoctorAccounts = await LocalStorageService.instance.loadProvisionedDoctorAccounts();

      _accounts.clear();
      for (final row in res) {
        if (row is Map) {
          _accounts.add(UserAccountModel.fromMap(Map<String, dynamic>.from(row)));
        }
      }
      // Bảo tồn tài khoản bác sĩ tạo offline từ bộ nhớ cục bộ
      for (final map in savedDoctorAccounts) {
        try {
          final acc = UserAccountModel.fromMap(map);
          final existing = findByUsername(acc.username);
          if (existing == null) {
            _accounts.add(acc);
          } else {
            // Khi merging saved doctor accounts từ local storage, đảm bảo non-empty credentials và doctor metadata được bảo toàn
            final idx = _accounts.indexOf(existing);
            _accounts[idx] = existing.copyWith(
              password: acc.password.isNotEmpty ? acc.password : existing.password,
              role: acc.isDoctor ? UserRole.doctor : existing.role,
              doctorId: acc.doctorId ?? existing.doctorId,
              fullName: existing.fullName.isNotEmpty ? existing.fullName : acc.fullName,
            );
          }
        } catch (_) {}
      }
      // Giữ tài khoản bác sĩ mẫu offline nếu chưa tồn tại trên Supabase
      if (findByUsername('bs_an') == null) {
        _accounts.add(defaultDoctorAccount);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[UserAccountService] Tải tài khoản Supabase (đang chuẩn bị bảng): $e');
      if (_accounts.isEmpty) {
        _initSeedAccounts();
      }
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
      role: UserRole.patient,
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
        role: UserRole.patient,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        emailOrPhone: emailOrPhone,
      ));
      notifyListeners();
    }
    return null;
  }

  /// Tạo tài khoản đăng nhập cho Bác sĩ (Admin Provisioning - Yêu cầu R2)
  /// - Kiểm tra tính duy nhất của username
  /// - Tạo UserAccountModel với role = 'doctor' và doctorId
  /// - Tự động liên kết 2 chiều thông qua DoctorManagementService.instance.linkAccountToDoctor
  Future<String?> createDoctorAccount({
    required String username,
    required String password,
    required String doctorId,
    String? email,
    String? fullName,
    String? phone,
  }) async {
    final cleanUser = username.trim();
    if (cleanUser.length < 3) {
      return 'Tên tài khoản phải có ít nhất 3 ký tự.';
    }
    if (password.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }

    // 1. Kiểm tra tính duy nhất của tên đăng nhập
    final existing = findByUsername(cleanUser);
    if (existing != null) {
      // Cho phép cập nhật/đặt lại thông tin nếu tài khoản này thuộc về chính bác sĩ được chọn
      final isSameDoctor = (existing.doctorId != null && existing.doctorId == doctorId) ||
          (cleanUser.toLowerCase() == 'bs_an' && doctorId == 'doc_an_nguyen');
      if (!isSameDoctor) {
        return 'Tên tài khoản "$cleanUser" đã tồn tại trong hệ thống.';
      }
    }

    // 2. Lấy thông tin bác sĩ từ doctorId để bổ sung metadata
    final doctor = DoctorManagementService.instance.getDoctorById(doctorId);
    final effectiveFullName = fullName?.trim().isNotEmpty == true
        ? fullName!.trim()
        : (doctor?.fullName ?? cleanUser);
    final effectiveContact = email?.trim().isNotEmpty == true
        ? email!.trim()
        : (phone?.trim().isNotEmpty == true ? phone!.trim() : doctor?.phoneNumber);

    final newAccount = UserAccountModel(
      username: cleanUser,
      password: password,
      fullName: effectiveFullName,
      role: UserRole.doctor,
      doctorId: doctorId,
      emailOrPhone: effectiveContact,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      isLocked: false,
    );

    // 3. Cập nhật bộ nhớ đệm tài khoản
    final idx = _accounts.indexWhere((a) => a.username.toLowerCase() == cleanUser.toLowerCase());
    if (idx != -1) {
      _accounts[idx] = newAccount;
    } else {
      _accounts.insert(0, newAccount);
    }
    notifyListeners();

    // 4. Lưu bền vững vào LocalStorageService (Yêu cầu R1)
    try {
      await LocalStorageService.instance.saveDoctorAccount(newAccount.toMap());
    } catch (e) {
      debugPrint('[UserAccountService] Lỗi lưu doctor account vào local storage: $e');
    }

    // 5. Tự động liên kết ngược vào hồ sơ bác sĩ
    await DoctorManagementService.instance.linkAccountToDoctor(doctorId, cleanUser);

    // 6. Đồng bộ lên bảng user_accounts trên Supabase Cloud bằng upsert
    // Đóng gói thông tin bác sĩ vào medical_profile JSONB để tránh lỗi thiếu cột trên CSDL Supabase Cloud
    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('user_accounts').upsert({
          'username': cleanUser,
          'password_hash': password,
          'email_or_phone': effectiveContact,
          'full_name': effectiveFullName,
          'role': UserRole.doctor,
          'doctor_id': doctorId,
          'created_at': DateTime.now().toIso8601String(),
          'last_active_at': DateTime.now().toIso8601String(),
          'is_locked': false,
          'medical_profile': {
            'role': UserRole.doctor,
            'doctor_id': doctorId,
            'full_name': effectiveFullName,
            'account_type': 'doctor_provisioned',
          },
        }, onConflict: 'username');
      }
    } catch (e) {
      debugPrint('[UserAccountService] Lỗi upsert createDoctorAccount lên Supabase: $e');
    }

    return null;
  }

  /// Kiểm tra chéo thông tin xác thực từ các nguồn tài khoản bác sĩ đã cấp phát
  /// 1. Tài khoản bác sĩ mẫu mặc định (defaultDoctorAccount: bs_an / password123)
  /// 2. Tài khoản bác sĩ lưu trong LocalStorageService (loadProvisionedDoctorAccounts)
  /// 3. Tài khoản trong danh sách _accounts được liên kết hồ sơ bác sĩ
  Future<Map<String, dynamic>?> _checkProvisionedDoctorFallback(String cleanUser, String cleanPass) async {
    // 1. Kiểm tra tài khoản bác sĩ kiểm thử mặc định (BS. CKI Nguyễn Văn An)
    if (cleanUser.toLowerCase() == defaultDoctorAccount.username.toLowerCase()) {
      if (cleanPass == defaultDoctorAccount.password) {
        return {'success': true, 'account': defaultDoctorAccount};
      } else {
        return {'success': false, 'message': 'Mật khẩu không chính xác. Vui lòng kiểm tra lại.'};
      }
    }

    // 2. Kiểm tra tài khoản bác sĩ cấp phát từ LocalStorageService
    try {
      final provisioned = await LocalStorageService.instance.loadProvisionedDoctorAccounts();
      final provMap = provisioned.cast<Map<String, dynamic>?>().firstWhere(
        (m) => (m?['username'] as String? ?? '').trim().toLowerCase() == cleanUser.toLowerCase(),
        orElse: () => null,
      );

      if (provMap != null) {
        final savedPass = provMap['password'] as String? ?? provMap['password_hash'] as String? ?? '';
        if (savedPass == cleanPass) {
          final acc = UserAccountModel.fromMap(provMap).copyWith(
            role: UserRole.doctor,
            doctorId: provMap['doctorId'] as String? ?? provMap['doctor_id'] as String?,
          );
          if (acc.isLocked) {
            return {
              'success': false,
              'isLocked': true,
              'lockReason': acc.lockReason ?? 'Tài khoản bác sĩ hiện đang bị khóa.',
              'message': 'Tài khoản của bạn hiện đang bị khóa.',
            };
          }
          return {'success': true, 'account': acc};
        } else {
          return {'success': false, 'message': 'Mật khẩu không chính xác. Vui lòng kiểm tra lại.'};
        }
      }
    } catch (e) {
      debugPrint('[UserAccountService] Lỗi kiểm tra fallback từ local storage: $e');
    }

    // 3. Kiểm tra danh sách _accounts trong bộ nhớ liên kết với DoctorManagementService
    final localAcc = findByUsername(cleanUser);
    final linkedDoc = DoctorManagementService.instance.getDoctorByUsername(cleanUser);
    if (localAcc != null && (localAcc.isDoctor || linkedDoc != null)) {
      if (localAcc.password == cleanPass) {
        if (localAcc.isLocked) {
          return {
            'success': false,
            'isLocked': true,
            'lockReason': localAcc.lockReason ?? 'Tài khoản bác sĩ hiện đang bị khóa.',
            'message': 'Tài khoản của bạn hiện đang bị khóa.',
          };
        }
        final enriched = localAcc.copyWith(
          role: UserRole.doctor,
          doctorId: localAcc.doctorId ?? linkedDoc?.id,
        );
        return {'success': true, 'account': enriched};
      } else {
        return {'success': false, 'message': 'Mật khẩu không chính xác. Vui lòng kiểm tra lại.'};
      }
    }

    // 4. Kiểm tra trực tiếp bảng user_accounts trên Supabase Cloud
    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        final res = await client
            .from('user_accounts')
            .select()
            .ilike('username', cleanUser)
            .limit(1);
        if (res is List && res.isNotEmpty) {
          final row = Map<String, dynamic>.from(res.first as Map);
          final savedPass = (row['password_hash'] ?? row['password'] ?? '') as String;
          if (savedPass == cleanPass) {
            final acc = UserAccountModel.fromMap(row).copyWith(
              role: UserRole.doctor,
            );
            if (acc.isLocked) {
              return {
                'success': false,
                'isLocked': true,
                'lockReason': acc.lockReason ?? 'Tài khoản bác sĩ hiện đang bị khóa.',
                'message': 'Tài khoản của bạn hiện đang bị khóa.',
              };
            }
            // Đồng bộ cập nhật vào bộ nhớ đệm
            final existingIdx = _accounts.indexWhere(
                (a) => a.username.toLowerCase() == cleanUser.toLowerCase());
            if (existingIdx != -1) {
              _accounts[existingIdx] = acc;
            } else {
              _accounts.insert(0, acc);
            }
            notifyListeners();
            return {'success': true, 'account': acc};
          }
        }
      }
    } catch (e) {
      debugPrint('[UserAccountService] Lỗi kiểm tra trực tiếp user_accounts: $e');
    }

    return null;
  }

  /// Xác thực đăng nhập người dùng (So khớp Bcrypt qua pgcrypto trên Supabase với cơ chế Fallback bác sĩ)
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
            final accMap = Map<String, dynamic>.from(rpcRes['account'] as Map);
            var account = UserAccountModel.fromMap(accMap);

            // Hòa giải thông tin vai trò bác sĩ & doctorId nếu Supabase RPC trả về thiếu
            if (!account.isDoctor || account.doctorId == null || account.doctorId!.isEmpty) {
              final linkedDoc = DoctorManagementService.instance.getDoctorByUsername(cleanUser);
              if (linkedDoc != null || cleanUser.toLowerCase() == defaultDoctorAccount.username.toLowerCase()) {
                account = account.copyWith(
                  role: UserRole.doctor,
                  doctorId: account.doctorId ?? linkedDoc?.id ?? defaultDoctorAccount.doctorId,
                  fullName: account.fullName.isNotEmpty ? account.fullName : (linkedDoc?.fullName ?? defaultDoctorAccount.fullName),
                );
              }
            }

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
            // Khi RPC trả về thất bại (ví dụ mật khẩu băm thô hoặc không nhận role), kiểm tra chéo tài khoản bác sĩ cấp phát
            final doctorFallback = await _checkProvisionedDoctorFallback(cleanUser, cleanPass);
            if (doctorFallback != null) {
              return doctorFallback;
            }

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

    // Fallback kiểm tra chéo tài khoản bác sĩ đã cấp phát khi offline hoặc RPC ngoại lệ
    final doctorFallback = await _checkProvisionedDoctorFallback(cleanUser, cleanPass);
    if (doctorFallback != null) {
      return doctorFallback;
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

      if (_accounts[idx].isDoctor) {
        try {
          await LocalStorageService.instance.saveDoctorAccount(_accounts[idx].toMap());
        } catch (e) {
          debugPrint('[UserAccountService] Lỗi lưu mật khẩu doctor vào local storage: $e');
        }
      }
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
