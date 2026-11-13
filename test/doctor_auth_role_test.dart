// File: test/doctor_auth_role_test.dart
// Unit tests verifying Milestone M2: Admin Create Doctor Login Account & Role Modeling

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:do_an_cntt_11/core/doctor_management/doctor_management_service.dart';
import 'package:do_an_cntt_11/core/storage/local_storage_service.dart';
import 'package:do_an_cntt_11/core/user_management/user_account_service.dart';
import 'package:do_an_cntt_11/features/user/models/doctor_consultation_models.dart';
import 'package:do_an_cntt_11/features/user/models/user_account_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. UserAccountModel Role Modeling', () {
    test('1.1 UserAccountModel mặc định role là patient và doctorId null', () {
      final user = UserAccountModel(
        username: 'benhnhan_01',
        password: 'password123',
        createdAt: DateTime.now(),
      );
      expect(user.role, equals(UserRole.patient));
      expect(user.doctorId, isNull);
      expect(user.isPatient, isTrue);
      expect(user.isDoctor, isFalse);
      expect(user.isAdmin, isFalse);
    });

    test('1.2 UserAccountModel khởi tạo với role doctor và doctorId', () {
      final docUser = UserAccountModel(
        username: 'bs_tuan',
        password: 'password123',
        role: UserRole.doctor,
        doctorId: 'doc_tuan_01',
        createdAt: DateTime.now(),
      );
      expect(docUser.role, equals(UserRole.doctor));
      expect(docUser.doctorId, equals('doc_tuan_01'));
      expect(docUser.isDoctor, isTrue);
      expect(docUser.isPatient, isFalse);
      expect(docUser.isAdmin, isFalse);
    });

    test('1.3 UserAccountModel tương thích ngược 100% với JSON cũ thiếu role/doctorId', () {
      final legacyMap = {
        'username': 'legacy_user',
        'password': 'secret_password',
        'created_at': DateTime.now().toIso8601String(),
      };
      final user = UserAccountModel.fromMap(legacyMap);
      expect(user.role, equals('patient'));
      expect(user.doctorId, isNull);
    });

    test('1.4 UserAccountModel toMap và fromMap duy trì role và doctorId 2 chiều', () {
      final original = UserAccountModel(
        username: 'bs_huong',
        password: 'password123',
        role: UserRole.doctor,
        doctorId: 'doc_mai_huong',
        createdAt: DateTime.now(),
      );
      final map = original.toMap();
      expect(map['role'], equals(UserRole.doctor));
      expect(map['doctorId'], equals('doc_mai_huong'));
      expect(map['doctor_id'], equals('doc_mai_huong'));

      final restored = UserAccountModel.fromMap(map);
      expect(restored.role, equals(UserRole.doctor));
      expect(restored.doctorId, equals('doc_mai_huong'));
      expect(restored.isDoctor, isTrue);
    });
  });

  group('2. DoctorProfile accountUsername', () {
    test('2.1 DoctorProfile defaultDoctor đã được liên kết với bs_an', () {
      final doc = DoctorProfile.defaultDoctor;
      expect(doc.accountUsername, equals('bs_an'));
      expect(doc.hasAccount, isTrue);
    });

    test('2.2 DoctorProfile toMap và fromMap duy trì account_username', () {
      final doc = DoctorProfile.defaultDoctor.copyWith(accountUsername: 'bs_nguyen_van_an');
      final map = doc.toMap();
      expect(map['account_username'], equals('bs_nguyen_van_an'));

      final restored = DoctorProfile.fromMap(map);
      expect(restored.accountUsername, equals('bs_nguyen_van_an'));
      expect(restored.hasAccount, isTrue);
    });
  });

  group('3. UserAccountService & DoctorManagementService', () {
    test('3.1 UserAccountService đã seed tài khoản bs_an mặc định và xác thực thành công', () {
      final authRes = UserAccountService.instance.authenticate(
        username: 'bs_an',
        password: 'password123',
      );
      expect(authRes['success'], isTrue);
      final acc = authRes['account'] as UserAccountModel;
      expect(acc.role, equals(UserRole.doctor));
      expect(acc.doctorId, equals('doc_an_nguyen'));
    });

    test('3.2 createDoctorAccount tạo tài khoản bác sĩ mới và liên kết 2 chiều với DoctorProfile', () async {
      DoctorManagementService.instance.resetToDefaultSeed();
      final docId = 'doc_mai_huong';

      final err = await UserAccountService.instance.createDoctorAccount(
        username: 'bs_huong_test',
        password: 'password123',
        doctorId: docId,
        fullName: 'ThS. BS Trần Mai Hương',
        phone: '0983124567',
      );
      expect(err, isNull);

      final acc = UserAccountService.instance.findByUsername('bs_huong_test');
      expect(acc, isNotNull);
      expect(acc!.role, equals(UserRole.doctor));
      expect(acc.doctorId, equals(docId));

      final doc = DoctorManagementService.instance.getDoctorById(docId);
      expect(doc, isNotNull);
      expect(doc!.accountUsername, equals('bs_huong_test'));
      expect(doc.hasAccount, isTrue);

      final foundByUsername = DoctorManagementService.instance.getDoctorByUsername('bs_huong_test');
      expect(foundByUsername, isNotNull);
      expect(foundByUsername!.id, equals(docId));
    });

    test('3.3 createDoctorAccount từ chối tên đăng nhập trùng lặp', () async {
      final err = await UserAccountService.instance.createDoctorAccount(
        username: 'bs_an',
        password: 'password123',
        doctorId: 'doc_quoc_bao',
      );
      expect(err, isNotNull);
      expect(err, contains('đã tồn tại'));
    });

    test('3.4 createDoctorAccount từ chối mật khẩu quá ngắn', () async {
      final err = await UserAccountService.instance.createDoctorAccount(
        username: 'bs_quoc_bao',
        password: '123',
        doctorId: 'doc_quoc_bao',
      );
      expect(err, isNotNull);
      expect(err, contains('ít nhất 6 ký tự'));
    });
  });

  group('4. LocalStorageService Doctor Session Helpers', () {
    test('4.1 LocalStorageService lưu và đọc phiên làm việc của Bác sĩ', () async {
      final storage = LocalStorageService.instance;
      await storage.saveDoctorSession(username: 'bs_an', doctorId: 'doc_an_nguyen');

      expect(storage.isDoctorLoggedIn(), isTrue);
      expect(storage.getDoctorSavedUsername(), equals('bs_an'));
      expect(storage.getDoctorSavedId(), equals('doc_an_nguyen'));

      await storage.clearDoctorSession();
      expect(storage.isDoctorLoggedIn(), isFalse);
      expect(storage.getDoctorSavedUsername(), isNull);
      expect(storage.getDoctorSavedId(), isNull);
    });
  });
}
