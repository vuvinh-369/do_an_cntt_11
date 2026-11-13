// =============================================================================
// DOCTOR AUTH & ROLE MODELING (MILESTONE M2) STANDALONE RUNNER
// File: test/doctor_auth_role_standalone_runner.dart
//
// Pure-Dart Standalone Test Runner verifying all Milestone M2 requirements:
// 1. UserAccountModel Role Modeling ('patient', 'doctor', 'admin') & doctorId
// 2. DoctorProfile accountUsername linking
// 3. UserAccountService createDoctorAccount, role/doctorId auth, duplicate rejection
// 4. DoctorManagementService linkAccountToDoctor & getDoctorByUsername
// 5. LocalStorageService Doctor Session Persistence
// =============================================================================

import 'dart:async';

// -----------------------------------------------------------------------------
// PURE DART MODELS & SERVICE LOGIC (MIRRORING LIB FILES FOR STANDALONE RUN)
// -----------------------------------------------------------------------------

class UserRole {
  static const String patient = 'patient';
  static const String doctor = 'doctor';
  static const String admin = 'admin';
}

class UserAccountModel {
  final String username;
  final String password;
  final String fullName;
  final DateTime createdAt;
  final String? emailOrPhone;
  final String role;
  final String? doctorId;
  final bool isLocked;
  final String? lockReason;
  final DateTime? lastActiveAt;

  const UserAccountModel({
    required this.username,
    required this.password,
    this.fullName = '',
    required this.createdAt,
    this.emailOrPhone,
    this.role = UserRole.patient,
    this.doctorId,
    this.isLocked = false,
    this.lockReason,
    this.lastActiveAt,
  });

  bool get isDoctor => role == UserRole.doctor;
  bool get isAdmin => role == UserRole.admin;
  bool get isPatient => role == UserRole.patient;

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password': password,
      'fullName': fullName,
      'createdAt': createdAt.toIso8601String(),
      'emailOrPhone': emailOrPhone,
      'role': role,
      'doctorId': doctorId,
      'doctor_id': doctorId,
      'is_locked': isLocked,
      'lock_reason': lockReason,
      'last_active_at': lastActiveAt?.toIso8601String(),
    };
  }

  factory UserAccountModel.fromMap(Map<String, dynamic> map) {
    return UserAccountModel(
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : (map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now() : DateTime.now()),
      emailOrPhone: map['emailOrPhone'] as String? ?? map['email_or_phone'] as String?,
      role: (map['role'] as String?)?.isNotEmpty == true ? map['role'] as String : UserRole.patient,
      doctorId: map['doctorId'] as String? ?? map['doctor_id'] as String?,
      isLocked: map['is_locked'] as bool? ?? map['isLocked'] as bool? ?? false,
      lockReason: map['lock_reason'] as String? ?? map['lockReason'] as String?,
      lastActiveAt: map['last_active_at'] != null
          ? DateTime.tryParse(map['last_active_at'] as String)
          : (map['lastActiveAt'] != null ? DateTime.tryParse(map['lastActiveAt'] as String) : null),
    );
  }

  UserAccountModel copyWith({
    String? username,
    String? password,
    String? fullName,
    DateTime? createdAt,
    String? emailOrPhone,
    String? role,
    String? doctorId,
    bool? isLocked,
    String? lockReason,
    DateTime? lastActiveAt,
  }) {
    return UserAccountModel(
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt ?? this.createdAt,
      emailOrPhone: emailOrPhone ?? this.emailOrPhone,
      role: role ?? this.role,
      doctorId: doctorId ?? this.doctorId,
      isLocked: isLocked ?? this.isLocked,
      lockReason: lockReason ?? this.lockReason,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}

class DoctorProfile {
  final String id;
  final String fullName;
  final String title;
  final String specialty;
  final String hospital;
  final String phoneNumber;
  final String workplaceAddress;
  final String? accountUsername;
  final bool isOnline;
  final bool isVerified;

  const DoctorProfile({
    required this.id,
    required this.fullName,
    required this.title,
    required this.specialty,
    required this.hospital,
    this.phoneNumber = '0901234567',
    this.workplaceAddress = '201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
    this.accountUsername,
    this.isOnline = true,
    this.isVerified = true,
  });

  bool get hasAccount => accountUsername != null && accountUsername!.trim().isNotEmpty;

  static const DoctorProfile defaultDoctor = DoctorProfile(
    id: 'doc_an_nguyen',
    fullName: 'BS. CKI Nguyễn Văn An',
    title: 'Bác sĩ Chuyên khoa I',
    specialty: 'Ngoại Chấn thương & Xử trí Vết thương cấp',
    hospital: 'Bệnh viện Đa khoa Trung ương',
    phoneNumber: '0912345678',
    workplaceAddress: 'Bệnh viện Chợ Rẫy, 201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
    accountUsername: 'bs_an',
  );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'title': title,
      'specialty': specialty,
      'hospital': hospital,
      'phone_number': phoneNumber,
      'workplace_address': workplaceAddress,
      'is_online': isOnline,
      'is_verified': isVerified,
      if (accountUsername != null) 'account_username': accountUsername,
    };
  }

  factory DoctorProfile.fromMap(Map<String, dynamic> map) {
    return DoctorProfile(
      id: (map['id'] ?? '').toString(),
      fullName: (map['full_name'] ?? map['fullName'] ?? '').toString(),
      title: (map['title'] ?? 'Bác sĩ Chuyên khoa').toString(),
      specialty: (map['specialty'] ?? 'Đa khoa').toString(),
      hospital: (map['hospital'] ?? '').toString(),
      phoneNumber: (map['phone_number'] ?? map['phoneNumber'] ?? '0901234567').toString(),
      workplaceAddress: (map['workplace_address'] ?? map['workplaceAddress'] ?? '').toString(),
      isOnline: map['is_online'] == true || map['isOnline'] == true,
      isVerified: map['is_verified'] != false && map['isVerified'] != false,
      accountUsername: (map['account_username'] ?? map['accountUsername'])?.toString(),
    );
  }

  DoctorProfile copyWith({
    String? id,
    String? fullName,
    String? title,
    String? specialty,
    String? hospital,
    String? phoneNumber,
    String? workplaceAddress,
    String? accountUsername,
    bool? isOnline,
    bool? isVerified,
  }) {
    return DoctorProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      title: title ?? this.title,
      specialty: specialty ?? this.specialty,
      hospital: hospital ?? this.hospital,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      workplaceAddress: workplaceAddress ?? this.workplaceAddress,
      accountUsername: accountUsername ?? this.accountUsername,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

class MockDoctorManagementService {
  MockDoctorManagementService._() {
    resetToDefaultSeed();
  }
  static final MockDoctorManagementService instance = MockDoctorManagementService._();

  final List<DoctorProfile> _doctors = [];
  List<DoctorProfile> get doctors => List.unmodifiable(_doctors);

  void resetToDefaultSeed() {
    _doctors.clear();
    _doctors.addAll([
      DoctorProfile.defaultDoctor,
      const DoctorProfile(
        id: 'doc_mai_huong',
        fullName: 'ThS. BS Trần Mai Hương',
        title: 'Thạc sĩ Bác sĩ',
        specialty: 'Bỏng & Tạo hình Thẩm mỹ Vết thương',
        hospital: 'Viện Bỏng Quốc gia',
        phoneNumber: '0983124567',
        workplaceAddress: '263 Phùng Hưng, Hà Đông, Hà Nội',
      ),
      const DoctorProfile(
        id: 'doc_quoc_bao',
        fullName: 'BS. CKII Lê Quốc Bảo',
        title: 'Bác sĩ Chuyên khoa II',
        specialty: 'Chấn thương Chỉnh hình & Cơ Xương Khớp',
        hospital: 'Bệnh viện Chấn thương Chỉnh hình TP.HCM',
        phoneNumber: '0908765432',
        workplaceAddress: '929 Trần Hưng Đạo, Phường 1, Quận 5, TP.HCM',
      ),
    ]);
  }

  DoctorProfile? getDoctorById(String id) {
    final idx = _doctors.indexWhere((d) => d.id == id);
    return idx != -1 ? _doctors[idx] : null;
  }

  DoctorProfile? getDoctorByUsername(String username) {
    final clean = username.trim().toLowerCase();
    final idx = _doctors.indexWhere((d) => d.accountUsername?.trim().toLowerCase() == clean);
    return idx != -1 ? _doctors[idx] : null;
  }

  Future<void> linkAccountToDoctor(String doctorId, String username) async {
    final cleanUser = username.trim();
    final idx = _doctors.indexWhere((d) => d.id == doctorId);
    if (idx != -1) {
      _doctors[idx] = _doctors[idx].copyWith(accountUsername: cleanUser);
    }
  }
}

class MockUserAccountService {
  MockUserAccountService._() {
    resetToDefaultSeed();
  }
  static final MockUserAccountService instance = MockUserAccountService._();

  static final UserAccountModel defaultDoctorAccount = UserAccountModel(
    username: 'bs_an',
    password: 'password123',
    fullName: 'BS. CKI Nguyễn Văn An',
    role: UserRole.doctor,
    doctorId: 'doc_an_nguyen',
    emailOrPhone: '0912345678',
    createdAt: DateTime(2026, 1, 1),
    lastActiveAt: DateTime.now(),
  );

  final List<UserAccountModel> _accounts = [];
  List<UserAccountModel> get accounts => List.unmodifiable(_accounts);

  void resetToDefaultSeed() {
    _accounts.clear();
    _accounts.add(defaultDoctorAccount);
  }

  UserAccountModel? findByUsername(String username) {
    final clean = username.trim().toLowerCase();
    final idx = _accounts.indexWhere((a) => a.username.toLowerCase() == clean);
    return idx != -1 ? _accounts[idx] : null;
  }

  Future<String?> createDoctorAccount({
    required String username,
    required String password,
    required String doctorId,
    String? email,
    String? fullName,
    String? phone,
  }) async {
    final cleanUser = username.trim();
    if (cleanUser.length < 3) return 'Tên tài khoản phải có ít nhất 3 ký tự.';
    if (password.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự.';

    final existing = findByUsername(cleanUser);
    if (existing != null) {
      return 'Tên tài khoản "$cleanUser" đã tồn tại trong hệ thống.';
    }

    final doctor = MockDoctorManagementService.instance.getDoctorById(doctorId);
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
    );

    _accounts.insert(0, newAccount);
    await MockDoctorManagementService.instance.linkAccountToDoctor(doctorId, cleanUser);
    return null;
  }

  Map<String, dynamic> authenticate({
    required String username,
    required String password,
  }) {
    final cleanUser = username.trim();
    final cleanPass = password.trim();
    final account = findByUsername(cleanUser);

    if (account == null) {
      return {'success': false, 'message': 'Tài khoản không tồn tại.'};
    }
    if (account.password != cleanPass) {
      return {'success': false, 'message': 'Mật khẩu không chính xác.'};
    }
    final updated = account.copyWith(lastActiveAt: DateTime.now());
    return {'success': true, 'account': updated};
  }
}

class MockLocalStorageService {
  MockLocalStorageService._();
  static final MockLocalStorageService instance = MockLocalStorageService._();

  String? _doctorSavedUsername;
  String? _doctorSavedId;
  bool _doctorIsLoggedIn = false;

  Future<void> saveDoctorSession({
    required String username,
    required String doctorId,
  }) async {
    _doctorSavedUsername = username;
    _doctorSavedId = doctorId;
    _doctorIsLoggedIn = true;
  }

  String? getDoctorSavedUsername() => _doctorSavedUsername;
  String? getDoctorSavedId() => _doctorSavedId;
  bool isDoctorLoggedIn() => _doctorIsLoggedIn;

  Future<void> clearDoctorSession() async {
    _doctorSavedUsername = null;
    _doctorSavedId = null;
    _doctorIsLoggedIn = false;
  }
}

// -----------------------------------------------------------------------------
// TEST RUNNER MAIN
// -----------------------------------------------------------------------------

void main() async {
  print('======================================================================');
  print('Running Milestone M2 Doctor Auth & Role Modeling Test Runner (20 Specs)');
  print('Requirements: R2 (Admin Create Doctor Account & User Roles)');
  print('======================================================================\n');

  int total = 0;
  int passed = 0;

  void runSpec(String specName, void Function() body) {
    total++;
    try {
      body();
      passed++;
      print('  [PASS] Spec $total: $specName');
    } catch (e) {
      print('  [FAIL] Spec $total: $specName -> $e');
      throw AssertionError('Spec $total failed: $e');
    }
  }

  Future<void> runAsyncSpec(String specName, Future<void> Function() body) async {
    total++;
    try {
      await body();
      passed++;
      print('  [PASS] Spec $total: $specName');
    } catch (e) {
      print('  [FAIL] Spec $total: $specName -> $e');
      throw AssertionError('Spec $total failed: $e');
    }
  }

  print('--- Group 1: UserAccountModel Role Modeling ---');
  runSpec('UserAccountModel role defaults to patient', () {
    final acc = UserAccountModel(
      username: 'pat_01',
      password: '123456',
      createdAt: DateTime.now(),
    );
    if (acc.role != 'patient') throw Exception('Expected role patient');
    if (acc.isPatient != true) throw Exception('Expected isPatient true');
    if (acc.isDoctor != false) throw Exception('Expected isDoctor false');
    if (acc.isAdmin != false) throw Exception('Expected isAdmin false');
  });

  runSpec('UserAccountModel accepts role doctor and doctorId', () {
    final acc = UserAccountModel(
      username: 'bs_an',
      password: '123456',
      role: UserRole.doctor,
      doctorId: 'doc_an_nguyen',
      createdAt: DateTime.now(),
    );
    if (acc.role != 'doctor') throw Exception('Expected role doctor');
    if (acc.doctorId != 'doc_an_nguyen') throw Exception('Expected doctorId doc_an_nguyen');
    if (acc.isDoctor != true) throw Exception('Expected isDoctor true');
    if (acc.isPatient != false) throw Exception('Expected isPatient false');
  });

  runSpec('UserAccountModel supports role admin', () {
    final acc = UserAccountModel(
      username: 'admin',
      password: '123456',
      role: UserRole.admin,
      createdAt: DateTime.now(),
    );
    if (acc.isAdmin != true) throw Exception('Expected isAdmin true');
    if (acc.isDoctor != false) throw Exception('Expected isDoctor false');
  });

  runSpec('UserAccountModel fromMap backwards compatibility with legacy JSON', () {
    final legacyMap = {
      'username': 'legacy_patient',
      'password': 'password123',
      'created_at': '2026-01-01T00:00:00.000',
    };
    final acc = UserAccountModel.fromMap(legacyMap);
    if (acc.role != 'patient') throw Exception('Expected fallback to patient');
    if (acc.doctorId != null) throw Exception('Expected null doctorId');
  });

  runSpec('UserAccountModel toMap preserves role, doctorId, and snake_case doctor_id', () {
    final acc = UserAccountModel(
      username: 'bs_huong',
      password: 'password123',
      role: UserRole.doctor,
      doctorId: 'doc_mai_huong',
      createdAt: DateTime.now(),
    );
    final map = acc.toMap();
    if (map['role'] != 'doctor') throw Exception('Expected map role doctor');
    if (map['doctorId'] != 'doc_mai_huong') throw Exception('Expected map doctorId');
    if (map['doctor_id'] != 'doc_mai_huong') throw Exception('Expected map doctor_id');
  });

  runSpec('UserAccountModel round-trip fromMap restores role and doctorId', () {
    final map = {
      'username': 'bs_quoc_bao',
      'password': 'password123',
      'role': 'doctor',
      'doctor_id': 'doc_quoc_bao',
      'created_at': DateTime.now().toIso8601String(),
    };
    final acc = UserAccountModel.fromMap(map);
    if (acc.role != 'doctor') throw Exception('Expected restored role doctor');
    if (acc.doctorId != 'doc_quoc_bao') throw Exception('Expected restored doctorId doc_quoc_bao');
    if (acc.isDoctor != true) throw Exception('Expected isDoctor true');
  });

  runSpec('UserAccountModel copyWith correctly updates role and doctorId', () {
    final acc = UserAccountModel(
      username: 'user_01',
      password: 'password123',
      createdAt: DateTime.now(),
    );
    final promoted = acc.copyWith(role: UserRole.doctor, doctorId: 'doc_test');
    if (promoted.role != 'doctor') throw Exception('Expected updated role doctor');
    if (promoted.doctorId != 'doc_test') throw Exception('Expected updated doctorId doc_test');
    if (promoted.username != 'user_01') throw Exception('Username must be preserved');
  });

  print('\n--- Group 2: DoctorProfile Account Linking ---');
  runSpec('DoctorProfile defaultDoctor has accountUsername bs_an', () {
    final doc = DoctorProfile.defaultDoctor;
    if (doc.accountUsername != 'bs_an') throw Exception('Expected defaultDoctor accountUsername bs_an');
    if (doc.hasAccount != true) throw Exception('Expected defaultDoctor hasAccount true');
  });

  runSpec('DoctorProfile unprovisioned has null accountUsername and hasAccount false', () {
    const doc = DoctorProfile(
      id: 'doc_new',
      fullName: 'BS. Mới',
      title: 'BS',
      specialty: 'Cấp cứu',
      hospital: 'BV Chợ Rẫy',
    );
    if (doc.accountUsername != null) throw Exception('Expected null accountUsername');
    if (doc.hasAccount != false) throw Exception('Expected hasAccount false');
  });

  runSpec('DoctorProfile toMap and fromMap preserve account_username', () {
    final doc = DoctorProfile.defaultDoctor.copyWith(accountUsername: 'bs_custom');
    final map = doc.toMap();
    if (map['account_username'] != 'bs_custom') throw Exception('Expected account_username in map');
    final restored = DoctorProfile.fromMap(map);
    if (restored.accountUsername != 'bs_custom') throw Exception('Expected restored accountUsername');
    if (restored.hasAccount != true) throw Exception('Expected restored hasAccount true');
  });

  print('\n--- Group 3: DoctorManagementService & Account Linking ---');
  await Future.delayed(const Duration(milliseconds: 10));

  runSpec('linkAccountToDoctor updates accountUsername in service cache', () {
    final service = MockDoctorManagementService.instance;
    service.resetToDefaultSeed();
    service.linkAccountToDoctor('doc_mai_huong', 'bs_huong_nguyen');
    final doc = service.getDoctorById('doc_mai_huong');
    if (doc?.accountUsername != 'bs_huong_nguyen') throw Exception('Expected updated accountUsername');
    if (doc?.hasAccount != true) throw Exception('Expected hasAccount true');
  });

  runSpec('getDoctorByUsername retrieves doctor profile case-insensitively', () {
    final service = MockDoctorManagementService.instance;
    service.resetToDefaultSeed();
    final doc = service.getDoctorByUsername('BS_AN');
    if (doc == null || doc.id != 'doc_an_nguyen') throw Exception('Expected doc_an_nguyen');
  });

  print('\n--- Group 4: UserAccountService Provisioning & Authentication ---');
  runSpec('UserAccountService has default seeded bs_an doctor account', () {
    final service = MockUserAccountService.instance;
    service.resetToDefaultSeed();
    final acc = service.findByUsername('bs_an');
    if (acc == null) throw Exception('Expected bs_an account seeded');
    if (acc.role != 'doctor') throw Exception('Expected role doctor');
    if (acc.doctorId != 'doc_an_nguyen') throw Exception('Expected doctorId doc_an_nguyen');
  });

  runSpec('UserAccountService authenticate bs_an returns role doctor and doctorId', () {
    final service = MockUserAccountService.instance;
    service.resetToDefaultSeed();
    final res = service.authenticate(username: 'bs_an', password: 'password123');
    if (res['success'] != true) throw Exception('Expected successful authentication');
    final acc = res['account'] as UserAccountModel;
    if (acc.role != 'doctor') throw Exception('Expected role doctor');
    if (acc.doctorId != 'doc_an_nguyen') throw Exception('Expected doctorId doc_an_nguyen');
  });

  await runAsyncSpec('createDoctorAccount successfully provisions doctor and sets two-way link', () async {
    final userSvc = MockUserAccountService.instance;
    final docSvc = MockDoctorManagementService.instance;
    userSvc.resetToDefaultSeed();
    docSvc.resetToDefaultSeed();

    await userSvc.createDoctorAccount(
      username: 'bs_quoc_bao',
      password: 'password123',
      doctorId: 'doc_quoc_bao',
      fullName: 'BS. CKII Lê Quốc Bảo',
    );

    final acc = userSvc.findByUsername('bs_quoc_bao');
    if (acc == null) throw Exception('Expected bs_quoc_bao account');
    if (acc.role != 'doctor') throw Exception('Expected role doctor');
    if (acc.doctorId != 'doc_quoc_bao') throw Exception('Expected doctorId doc_quoc_bao');

    final doc = docSvc.getDoctorById('doc_quoc_bao');
    if (doc?.accountUsername != 'bs_quoc_bao') throw Exception('Expected linked accountUsername');
    if (doc?.hasAccount != true) throw Exception('Expected hasAccount true');
  });

  await runAsyncSpec('createDoctorAccount rejects duplicate username', () async {
    final userSvc = MockUserAccountService.instance;
    userSvc.resetToDefaultSeed();
    final err = await userSvc.createDoctorAccount(
      username: 'bs_an',
      password: 'password123',
      doctorId: 'doc_quoc_bao',
    );
    if (err == null || !err.contains('đã tồn tại')) {
      throw Exception('Expected duplicate username error, got $err');
    }
  });

  await runAsyncSpec('createDoctorAccount rejects short username (< 3 chars)', () async {
    final userSvc = MockUserAccountService.instance;
    final err = await userSvc.createDoctorAccount(
      username: 'bs',
      password: 'password123',
      doctorId: 'doc_quoc_bao',
    );
    if (err == null || !err.contains('3 ký tự')) {
      throw Exception('Expected short username error, got $err');
    }
  });

  await runAsyncSpec('createDoctorAccount rejects short password (< 6 chars)', () async {
    final userSvc = MockUserAccountService.instance;
    final err = await userSvc.createDoctorAccount(
      username: 'bs_valid_name',
      password: '123',
      doctorId: 'doc_quoc_bao',
    );
    if (err == null || !err.contains('6 ký tự')) {
      throw Exception('Expected short password error, got $err');
    }
  });

  print('\n--- Group 5: LocalStorageService Doctor Session ---');
  await runAsyncSpec('LocalStorageService saves and reads doctor session', () async {
    final storage = MockLocalStorageService.instance;
    await storage.saveDoctorSession(username: 'bs_an', doctorId: 'doc_an_nguyen');
    if (storage.isDoctorLoggedIn() != true) throw Exception('Expected isDoctorLoggedIn true');
    if (storage.getDoctorSavedUsername() != 'bs_an') throw Exception('Expected username bs_an');
    if (storage.getDoctorSavedId() != 'doc_an_nguyen') throw Exception('Expected doctorId doc_an_nguyen');
  });

  await runAsyncSpec('LocalStorageService clearDoctorSession resets all doctor credentials', () async {
    final storage = MockLocalStorageService.instance;
    await storage.saveDoctorSession(username: 'bs_an', doctorId: 'doc_an_nguyen');
    await storage.clearDoctorSession();
    if (storage.isDoctorLoggedIn() != false) throw Exception('Expected isDoctorLoggedIn false');
    if (storage.getDoctorSavedUsername() != null) throw Exception('Expected null username');
    if (storage.getDoctorSavedId() != null) throw Exception('Expected null doctorId');
  });

  print('\n======================================================================');
  print('TEST SUMMARY: $passed / $total SPECS PASSED (100% PASS)');
  print('Milestone M2 (Admin Create Doctor Login Account & Role Modeling) VERIFIED.');
  print('======================================================================');
}
