// File: lib/core/doctor_management/doctor_management_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/user/models/doctor_consultation_models.dart';
import '../storage/local_storage_service.dart';
import '../supabase/supabase_service.dart';

/// Dịch vụ Singleton quản lý hồ sơ Bác sĩ (CRUD), bộ nhớ đệm cục bộ Fail-safe
/// và đồng bộ thời gian thực 2 chiều (Supabase Realtime) cho Admin & Bệnh nhân.
class DoctorManagementService extends ChangeNotifier {
  DoctorManagementService._() {
    _initDefaultSeedDoctors();
    loadFromLocalStorage();
    // Tự động tải danh sách bác sĩ từ Supabase khi khởi chạy
    fetchDoctors();
  }

  /// Singleton Instance truy cập toàn cục
  static final DoctorManagementService instance = DoctorManagementService._();

  // Danh sách bác sĩ trong bộ nhớ đệm
  final List<DoctorProfile> _doctors = [];
  List<DoctorProfile> get doctors => List.unmodifiable(_doctors);
  int get onlineDoctorCount => _doctors.where((d) => d.isOnline).length;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isRealtimeSubscribed = false;
  bool get isRealtimeSubscribed => _isRealtimeSubscribed;

  RealtimeChannel? _realtimeChannel;

  /// Nạp các liên kết tài khoản bác sĩ từ SharedPreferences (Yêu cầu R1)
  Future<void> loadFromLocalStorage() async {
    try {
      final links = await LocalStorageService.instance.loadDoctorAccountLinks();
      if (links.isNotEmpty) {
        for (final entry in links.entries) {
          final idx = _doctors.indexWhere((d) => d.id == entry.key);
          if (idx != -1) {
            _doctors[idx] = _doctors[idx].copyWith(accountUsername: entry.value);
          }
        }
      }

      // Đối chiếu bổ sung từ các tài khoản đã cấp trong LocalStorage
      final provisionedAccounts =
          await LocalStorageService.instance.loadProvisionedDoctorAccounts();
      for (final accMap in provisionedAccounts) {
        final doctorId = (accMap['doctorId'] ?? accMap['doctor_id']) as String?;
        final username = accMap['username'] as String?;
        if (doctorId != null && username != null && username.isNotEmpty) {
          final idx = _doctors.indexWhere((d) => d.id == doctorId);
          if (idx != -1 &&
              (_doctors[idx].accountUsername == null ||
                  _doctors[idx].accountUsername!.isEmpty)) {
            _doctors[idx] = _doctors[idx].copyWith(accountUsername: username);
          }
        }
      }

      // Đảm bảo bác sĩ mặc định Nguyễn Văn An luôn giữ tài khoản bs_an
      final defaultIdx = _doctors.indexWhere((d) =>
          d.id == DoctorProfile.defaultDoctor.id ||
          d.fullName.contains('Nguyễn Văn An'));
      if (defaultIdx != -1 &&
          (_doctors[defaultIdx].accountUsername == null ||
              _doctors[defaultIdx].accountUsername!.isEmpty)) {
        _doctors[defaultIdx] = _doctors[defaultIdx].copyWith(
            accountUsername: DoctorProfile.defaultDoctor.accountUsername);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[DoctorManagementService] Lỗi loadFromLocalStorage: $e');
    }
  }

  /// Regex kiểm tra số điện thoại di động Việt Nam chuẩn: 10 chữ số bắt đầu bằng 0 hoặc 11 ký tự bắt đầu bằng +84
  static final RegExp _vietnamesePhoneRegex = RegExp(r'^(0|\+84)[0-9]{9}$');

  // ===========================================================================
  // KHỞI TẠO BỘ DỮ LIỆU BÁC SĨ MẪU DỰ PHÒNG (SEED DOCTORS FALLBACK)
  // ===========================================================================

  void _initDefaultSeedDoctors() {
    if (_doctors.isNotEmpty) return;

    _doctors.addAll([
      // 1. Bác sĩ trực cấp cứu mặc định
      DoctorProfile.defaultDoctor,

      // 2. ThS. BS Trần Mai Hương - Bỏng & Tạo hình
      const DoctorProfile(
        id: 'doc_mai_huong',
        fullName: 'ThS. BS Trần Mai Hương',
        title: 'Thạc sĩ Bác sĩ',
        specialty: 'Bỏng & Tạo hình Thẩm mỹ Vết thương',
        hospital: 'Viện Bỏng Quốc gia',
        phoneNumber: '0983124567',
        workplaceAddress: 'Trung tâm Bỏng & Liền vết thương, 263 Phùng Hưng, Hà Đông, Hà Nội',
        avatarInitials: 'MH',
        avatarColor: Color(0xFF059669),
        rating: 4.92,
        consultationCount: 1640,
        isOnline: true,
        statusText: 'Đang trực tuyến • Chuyên xử trí bỏng nhiệt & hóa chất',
        isVerified: true,
        experienceYears: 10,
        consultationFee: 'Miễn phí tư vấn sơ cứu ban đầu',
      ),

      // 3. BS. CKII Lê Quốc Bảo - Chấn thương Chỉnh hình
      const DoctorProfile(
        id: 'doc_quoc_bao',
        fullName: 'BS. CKII Lê Quốc Bảo',
        title: 'Bác sĩ Chuyên khoa II',
        specialty: 'Chấn thương Chỉnh hình & Cơ Xương Khớp',
        hospital: 'Bệnh viện Chấn thương Chỉnh hình TP.HCM',
        phoneNumber: '0908765432',
        workplaceAddress: '929 Trần Hưng Đạo, Phường 1, Quận 5, TP.HCM',
        avatarInitials: 'QB',
        avatarColor: Color(0xFF7C3AED),
        rating: 4.88,
        consultationCount: 1950,
        isOnline: false,
        statusText: 'Tạm vắng • Trực ca mổ cấp cứu',
        isVerified: true,
        experienceYears: 18,
        consultationFee: 'Tư vấn theo tiêu chuẩn bệnh viện',
      ),

      // 4. BS. Hoàng Thu Trang - Hồi sức Cấp cứu & Nhiễm trùng
      const DoctorProfile(
        id: 'doc_thu_trang',
        fullName: 'BS. Hoàng Thu Trang',
        title: 'Bác sĩ Đa khoa',
        specialty: 'Hồi sức Cấp cứu & Nhiễm trùng Vết thương',
        hospital: 'Bệnh viện Bạch Mai',
        phoneNumber: '0978901234',
        workplaceAddress: 'Khoa Cấp cứu A9, 78 Giải Phóng, Phương Mai, Đống Đa, Hà Nội',
        avatarInitials: 'TT',
        avatarColor: Color(0xFFEA580C),
        rating: 4.85,
        consultationCount: 1120,
        isOnline: true,
        statusText: 'Đang trực tuyến • Hướng dẫn ngừa uốn ván & kháng sinh',
        isVerified: true,
        experienceYears: 8,
        consultationFee: 'Tư vấn miễn phí qua tổng đài AI',
      ),
    ]);
  }

  /// Khôi phục dữ liệu bộ nhớ về danh sách seed mặc định (dùng cho test/reset)
  void resetToDefaultSeed() {
    _doctors.clear();
    _initDefaultSeedDoctors();
    notifyListeners();
  }

  // ===========================================================================
  // VALIDATION LOGIC
  // ===========================================================================

  /// Xác thực thông tin bác sĩ theo yêu cầu R1
  static String? validateDoctor(DoctorProfile doctor) {
    final name = doctor.fullName.trim();
    if (name.length < 3) {
      return 'Họ tên bác sĩ phải có ít nhất 3 ký tự.';
    }

    final phone = doctor.phoneNumber.trim();
    if (phone.isEmpty) {
      return 'Số điện thoại không được để trống.';
    }
    if (!_vietnamesePhoneRegex.hasMatch(phone)) {
      return 'Số điện thoại không đúng định dạng Việt Nam (10 số bắt đầu bằng 0 hoặc 11 ký tự bắt đầu bằng +84).';
    }

    final address = doctor.workplaceAddress.trim();
    if (address.length < 5) {
      return 'Địa chỉ nơi công tác phải có ít nhất 5 ký tự.';
    }

    return null;
  }

  // ===========================================================================
  // TRUY VẤN VÀ ĐỒNG BỘ DỮ LIỆU (FETCH & QUERY)
  // ===========================================================================

  /// Tìm kiếm bác sĩ theo ID
  DoctorProfile? getDoctorById(String id) {
    final index = _doctors.indexWhere((d) => d.id == id);
    return index != -1 ? _doctors[index] : null;
  }

  /// Tìm kiếm bác sĩ theo username tài khoản đăng nhập
  DoctorProfile? getDoctorByUsername(String username) {
    final clean = username.trim().toLowerCase();
    final index = _doctors.indexWhere(
      (d) => d.accountUsername?.trim().toLowerCase() == clean,
    );
    return index != -1 ? _doctors[index] : null;
  }

  /// Liên kết tài khoản người dùng với hồ sơ bác sĩ (Cập nhật cache, LocalStorage & Supabase)
  Future<void> linkAccountToDoctor(String doctorId, String username) async {
    final cleanUser = username.trim();
    final idx = _doctors.indexWhere((d) => d.id == doctorId);
    if (idx != -1) {
      _doctors[idx] = _doctors[idx].copyWith(accountUsername: cleanUser);
      notifyListeners();
    }

    // Lưu bền vững vào LocalStorageService (Yêu cầu R1)
    try {
      await LocalStorageService.instance.saveDoctorAccountLink(doctorId, cleanUser);
    } catch (e) {
      debugPrint('[DoctorManagementService] Lỗi lưu doctor account link vào local storage: $e');
    }

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        if (idx != -1) {
          await client.from('doctor_profiles').upsert(
            _doctors[idx].toSupabaseMap(),
            onConflict: 'id',
          );
        } else {
          await client.from('doctor_profiles').update({
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', doctorId);
        }
      }
    } catch (e) {
      debugPrint('[DoctorManagementService] Lỗi linkAccountToDoctor lên Supabase: $e');
    }
  }

  /// Bí danh tương thích ngược cho fetchDoctorsFromSupabase
  Future<List<DoctorProfile>> fetchDoctors({bool forceRefresh = false}) =>
      fetchDoctorsFromSupabase(forceRefresh: forceRefresh);

  /// Tải danh sách bác sĩ từ Supabase Cloud với cơ chế Cross-Table Synchronization (Yêu cầu R1)
  /// - Truy vấn đồng thời doctor_profiles và user_accounts từ Supabase
  /// - Trích xuất mapping doctorId -> username từ cột medical_profile (JSONB) của user_accounts
  /// - Tự động tái kích hoạt / bù đắp bộ nhớ cache local storage của origin (port) hiện tại
  /// - Áp dụng thứ tự ưu tiên gộp tài khoản phi hủy diệt (Non-destructive username merge):
  ///   (1) Ánh xạ đám mây từ user_accounts.medical_profile
  ///   (2) Bộ nhớ đệm cục bộ LocalStorageService của port hiện tại
  ///   (3) Dữ liệu sẵn có trong RAM (_doctors in-memory)
  ///   (4) Fallback mặc định cho Bác sĩ Nguyễn Văn An (doc_an_nguyen -> bs_an)
  /// - Tuyệt đối không xóa trắng tài khoản đã được cấp ('Chưa cấp TK')
  Future<List<DoctorProfile>> fetchDoctorsFromSupabase({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        // Truy vấn đồng thời doctor_profiles và user_accounts từ Supabase Cloud
        dynamic docProfilesResponse;
        dynamic userAccountsResponse;

        try {
          final results = await Future.wait([
            client.from('doctor_profiles').select().order('consultation_count', ascending: false),
            client.from('user_accounts').select('username, medical_profile'),
          ]);
          docProfilesResponse = results[0];
          userAccountsResponse = results[1];
        } catch (queryErr) {
          debugPrint('[DoctorManagementService] Lỗi truy vấn song song Supabase: $queryErr');
          // Thử lại riêng doctor_profiles nếu user_accounts lỗi
          docProfilesResponse = await client
              .from('doctor_profiles')
              .select()
              .order('consultation_count', ascending: false);
        }

        // Trích xuất doctorId -> username từ user_accounts.medical_profile
        final Map<String, String> cloudDoctorAccounts = {};
        if (userAccountsResponse is List) {
          for (final row in userAccountsResponse) {
            try {
              if (row is Map) {
                final uName = row['username'] as String?;
                Map<String, dynamic>? medProf;
                if (row['medical_profile'] is Map) {
                  try {
                    medProf = Map<String, dynamic>.from(row['medical_profile'] as Map);
                  } catch (_) {}
                }
                if (uName != null && uName.isNotEmpty && medProf != null) {
                  final docId = (medProf['doctor_id'] ?? medProf['doctorId']) as String?;
                  final role = medProf['role'] as String?;
                  final accType = medProf['account_type'] as String?;
                  final isDoc = role == 'doctor' ||
                      role == 'UserRole.doctor' ||
                      accType == 'doctor_provisioned';
                  if (docId != null && docId.isNotEmpty && isDoc) {
                    cloudDoctorAccounts[docId] = uName;
                    // Hydrate cache LocalStorageService cho port/origin hiện tại
                    try {
                      await LocalStorageService.instance.saveDoctorAccountLink(docId, uName);
                    } catch (_) {}
                  }
                }
              }
            } catch (_) {}
          }
        }

        if (docProfilesResponse is List && docProfilesResponse.isNotEmpty) {
          final List<DoctorProfile> fetched = [];
          for (final item in docProfilesResponse) {
            try {
              if (item is Map) {
                fetched.add(DoctorProfile.fromMap(Map<String, dynamic>.from(item)));
              }
            } catch (parseError) {
              debugPrint('[DoctorManagementService] Lỗi parse doctor row: $parseError');
            }
          }

          if (fetched.isNotEmpty) {
            // Nạp liên kết offline hiện có trong LocalStorageService
            final localLinks = await LocalStorageService.instance.loadDoctorAccountLinks();
            final oldDoctors = Map<String, DoctorProfile>.fromEntries(
              _doctors.map((d) => MapEntry(d.id, d)),
            );

            _doctors.clear();
            for (var doc in fetched) {
              // Thứ tự ưu tiên Non-Destructive Merge:
              // 1. Cloud user_accounts mapping
              // 2. Local storage link cache
              // 3. UserAccountService account in-memory list
              // 4. Existing in-memory doctor profile
              // 5. Default seed fallback (doc_an_nguyen -> bs_an)
              String? resolvedUsername = doc.accountUsername;
              if (resolvedUsername == null || resolvedUsername.trim().isEmpty) {
                resolvedUsername = cloudDoctorAccounts[doc.id];
              }
              if (resolvedUsername == null || resolvedUsername.trim().isEmpty) {
                resolvedUsername = localLinks[doc.id];
              }
              if (resolvedUsername == null || resolvedUsername.trim().isEmpty) {
                resolvedUsername = oldDoctors[doc.id]?.accountUsername;
              }
              if ((resolvedUsername == null || resolvedUsername.trim().isEmpty) &&
                  (doc.id == DoctorProfile.defaultDoctor.id ||
                      doc.fullName.contains('Nguyễn Văn An'))) {
                resolvedUsername = DoctorProfile.defaultDoctor.accountUsername;
              }

              if (resolvedUsername != null && resolvedUsername.trim().isNotEmpty) {
                doc = doc.copyWith(accountUsername: resolvedUsername);
                // Đồng bộ lưu liên kết vào LocalStorageService
                try {
                  LocalStorageService.instance.saveDoctorAccountLink(doc.id, resolvedUsername);
                } catch (_) {}
              }
              _doctors.add(doc);
            }
            _errorMessage = null;
            debugPrint('[DoctorManagementService] Đồng bộ ${_doctors.length} bác sĩ từ Supabase Cloud.');
          }
        } else if (docProfilesResponse is List && docProfilesResponse.isEmpty && _doctors.isEmpty) {
          // Bảng trống trên cloud: giữ seed mặc định
          _initDefaultSeedDoctors();
        }
      } else {
        // Supabase client chưa sẵn sàng, giữ nguyên danh sách seed dự phòng
        if (_doctors.isEmpty) {
          _initDefaultSeedDoctors();
        }
      }
    } catch (e) {
      debugPrint('[DoctorManagementService] Ngoại lệ fetchDoctorsFromSupabase (sử dụng in-memory fallback): $e');
      _errorMessage = e.toString();
      if (_doctors.isEmpty) {
        _initDefaultSeedDoctors();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return List<DoctorProfile>.from(_doctors);
  }

  // ===========================================================================
  // CÁC THAO TÁC CRUD (ADD, UPDATE, DELETE)
  // ===========================================================================

  /// Thêm bác sĩ mới (Admin CRUD)
  Future<DoctorProfile> addDoctor(DoctorProfile doctor) async {
    final validationError = validateDoctor(doctor);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final effectiveDoctor = doctor.id.isEmpty
        ? doctor.copyWith(id: 'doc_${DateTime.now().millisecondsSinceEpoch}')
        : doctor;

    // 1. Cập nhật lạc quan vào bộ nhớ đệm
    _doctors.insert(0, effectiveDoctor);
    notifyListeners();

    // 2. Đồng bộ lên Supabase Cloud
    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        final res = await client
            .from('doctor_profiles')
            .insert(effectiveDoctor.toSupabaseMap())
            .select()
            .maybeSingle();

        if (res != null) {
          var serverDoctor = DoctorProfile.fromMap(res);
          if (effectiveDoctor.accountUsername != null &&
              effectiveDoctor.accountUsername!.isNotEmpty &&
              (serverDoctor.accountUsername == null || serverDoctor.accountUsername!.isEmpty)) {
            serverDoctor = serverDoctor.copyWith(accountUsername: effectiveDoctor.accountUsername);
          }
          final idx = _doctors.indexWhere((d) => d.id == effectiveDoctor.id);
          if (idx != -1) {
            _doctors[idx] = serverDoctor;
            notifyListeners();
          }
          return serverDoctor;
        }
      }
    } catch (e) {
      debugPrint('[DoctorManagementService] Lỗi insert doctor_profiles lên Supabase: $e');
      // Dữ liệu vẫn được giữ trong in-memory cache để không làm gián đoạn UI
    }

    return effectiveDoctor;
  }

  /// Cập nhật thông tin bác sĩ (Admin CRUD)
  Future<DoctorProfile> updateDoctor(DoctorProfile doctor) async {
    final validationError = validateDoctor(doctor);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    // 1. Cập nhật vào bộ nhớ đệm
    final index = _doctors.indexWhere((d) => d.id == doctor.id);
    if (index != -1) {
      _doctors[index] = doctor;
      notifyListeners();
    } else {
      _doctors.insert(0, doctor);
      notifyListeners();
    }

    // 2. Đồng bộ lên Supabase Cloud
    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        final res = await client
            .from('doctor_profiles')
            .update(doctor.toSupabaseMap())
            .eq('id', doctor.id)
            .select()
            .maybeSingle();

        if (res != null) {
          var serverDoctor = DoctorProfile.fromMap(res);
          if (doctor.accountUsername != null &&
              doctor.accountUsername!.isNotEmpty &&
              (serverDoctor.accountUsername == null || serverDoctor.accountUsername!.isEmpty)) {
            serverDoctor = serverDoctor.copyWith(accountUsername: doctor.accountUsername);
          }
          final idx = _doctors.indexWhere((d) => d.id == doctor.id);
          if (idx != -1) {
            _doctors[idx] = serverDoctor;
            notifyListeners();
          }
          return serverDoctor;
        }
      }
    } catch (e) {
      debugPrint('[DoctorManagementService] Lỗi update doctor_profiles lên Supabase: $e');
    }

    return doctor;
  }

  /// Xóa bác sĩ khỏi hệ thống (Admin CRUD)
  Future<void> deleteDoctor(String id) async {
    // 1. Xóa khỏi bộ nhớ đệm
    _doctors.removeWhere((d) => d.id == id);
    notifyListeners();

    // 2. Đồng bộ lệnh xóa lên Supabase Cloud
    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('doctor_profiles').delete().eq('id', id);
      }
    } catch (e) {
      debugPrint('[DoctorManagementService] Lỗi delete doctor_profiles trên Supabase: $e');
    }
  }

  /// Cập nhật trạng thái trực tuyến của bác sĩ (Online / Offline Toggle)
  Future<void> updateDoctorOnlineStatus(String doctorId, bool isOnline) async {
    final idx = _doctors.indexWhere((d) => d.id == doctorId);
    if (idx != -1) {
      final old = _doctors[idx];
      final updated = old.copyWith(
        isOnline: isOnline,
        statusText: isOnline
            ? 'Đang trực tuyến • Sẵn sàng hỗ trợ'
            : 'Tạm vắng • AI Bác sĩ hỗ trợ thay',
      );
      _doctors[idx] = updated;
      notifyListeners();

      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          await client.from('doctor_profiles').update({
            'is_online': isOnline,
            'status_text': updated.statusText,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', doctorId);
        }
      } catch (e) {
        debugPrint('[DoctorManagementService] Lỗi updateDoctorOnlineStatus lên Supabase: $e');
      }
    }
  }

  // ===========================================================================
  // SUPABASE REALTIME SUBSCRIPTION
  // ===========================================================================

  /// Lắng nghe các thay đổi thời gian thực trên bảng 'doctor_profiles'
  void subscribeRealtime() {
    if (_isRealtimeSubscribed) return;

    try {
      final client = SupabaseService.instance.client;
      if (client == null) return;

      _realtimeChannel = client.channel('public:doctor_profiles');
      _realtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'doctor_profiles',
            callback: (PostgresChangePayload payload) {
              _handleRealtimePayload(payload);
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              _isRealtimeSubscribed = true;
              debugPrint('[DoctorManagementService] Realtime channel connected for doctor_profiles');
            } else if (error != null) {
              debugPrint('[DoctorManagementService] Realtime status: $status, error: $error');
            }
          });
    } catch (e) {
      debugPrint('[DoctorManagementService] Lỗi khởi tạo Realtime: $e');
    }
  }

  /// Xử lý các sự kiện thay đổi dữ liệu từ Realtime Channel
  void _handleRealtimePayload(PostgresChangePayload payload) {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          final newRecord = payload.newRecord;
          if (newRecord.isNotEmpty) {
            final doctor = DoctorProfile.fromMap(newRecord);
            final index = _doctors.indexWhere((d) => d.id == doctor.id);
            if (index == -1) {
              _doctors.insert(0, doctor);
              notifyListeners();
            }
          }
          break;

        case PostgresChangeEvent.update:
          final newRecord = payload.newRecord;
          if (newRecord.isNotEmpty) {
            final doctor = DoctorProfile.fromMap(newRecord);
            final index = _doctors.indexWhere((d) => d.id == doctor.id);
            if (index != -1) {
              _doctors[index] = doctor;
            } else {
              _doctors.insert(0, doctor);
            }
            notifyListeners();
          }
          break;

        case PostgresChangeEvent.delete:
          final oldRecord = payload.oldRecord;
          final deletedId = oldRecord['id']?.toString();
          if (deletedId != null && deletedId.isNotEmpty) {
            _doctors.removeWhere((d) => d.id == deletedId);
            notifyListeners();
          }
          break;

        default:
          break;
      }
    } catch (e) {
      debugPrint('[DoctorManagementService] Lỗi xử lý sự kiện Realtime: $e');
    }
  }

  /// Hủy đăng ký lắng nghe Realtime khi thoát hoặc dừng dịch vụ
  void unsubscribeRealtime() {
    if (_realtimeChannel != null) {
      final client = SupabaseService.instance.client;
      client?.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
      _isRealtimeSubscribed = false;
    }
  }

  @override
  void dispose() {
    unsubscribeRealtime();
    super.dispose();
  }
}
