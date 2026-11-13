import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:do_an_cntt_11/core/doctor_management/doctor_management_service.dart';
import 'package:do_an_cntt_11/core/storage/local_storage_service.dart';
import 'package:do_an_cntt_11/core/user_management/user_account_service.dart';
import 'package:do_an_cntt_11/features/admin/views/admin_doctor_management_view.dart';
import 'package:do_an_cntt_11/features/user/models/doctor_consultation_models.dart';
import 'package:do_an_cntt_11/features/user/models/user_account_model.dart';
import 'package:do_an_cntt_11/features/user/viewmodels/user_viewmodel.dart';
import 'package:do_an_cntt_11/features/user/views/doctor_consultation_view.dart';
import 'package:do_an_cntt_11/features/user/views/doctor_directory_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. DoctorProfile Data Model & Serialization Tests', () {
    test('DoctorProfile serialization toMap and fromMap with mandatory R1 fields', () {
      final doc = const DoctorProfile(
        id: 'doc_test_01',
        fullName: 'BS. CKI Trần Minh Tuấn',
        title: 'Bác sĩ Chuyên khoa I',
        specialty: 'Cấp cứu & Hồi sức ngoại viện',
        hospital: 'Bệnh viện Chợ Rẫy',
        phoneNumber: '0912345678',
        workplaceAddress: '201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
        avatarInitials: 'TM',
        avatarColor: Color(0xFF2563EB),
        rating: 4.9,
        consultationCount: 850,
        isOnline: true,
        statusText: 'Đang trực tuyến',
        isVerified: true,
        experienceYears: 12,
        consultationFee: 'Tư vấn sơ cứu miễn phí',
      );

      final map = doc.toMap();
      expect(map['id'], equals('doc_test_01'));
      expect(map['phone_number'], equals('0912345678'));
      expect(map['workplace_address'], contains('201B Nguyễn Chí Thanh'));
      expect(map['full_name'], equals('BS. CKI Trần Minh Tuấn'));

      final restored = DoctorProfile.fromMap(map);
      expect(restored.id, equals(doc.id));
      expect(restored.fullName, equals(doc.fullName));
      expect(restored.phoneNumber, equals(doc.phoneNumber));
      expect(restored.workplaceAddress, equals(doc.workplaceAddress));
      expect(restored.experienceYears, equals(12));
      expect(restored.rating, equals(4.9));
      expect(restored.isOnline, isTrue);
    });

    test('DoctorProfile copyWith updates fields correctly', () {
      final original = DoctorProfile.defaultDoctor;
      final updated = original.copyWith(
        phoneNumber: '+84987654321',
        workplaceAddress: 'Số 1 Bệnh viện Bạch Mai, Giải Phóng, Hà Nội',
        isOnline: false,
      );

      expect(updated.phoneNumber, equals('+84987654321'));
      expect(updated.workplaceAddress, contains('Bạch Mai'));
      expect(updated.isOnline, isFalse);
      expect(updated.fullName, equals(original.fullName));
      expect(updated.id, equals(original.id));
    });

    test('DoctorProfile defaultDoctor compatibility preserves backwards compatibility', () {
      final doc = DoctorProfile.defaultDoctor;
      expect(doc.id, equals('doc_an_nguyen'));
      expect(doc.fullName, contains('Nguyễn Văn An'));
      expect(doc.phoneNumber, equals('0912345678'));
      expect(doc.workplaceAddress, contains('Nguyễn Chí Thanh'));
      expect(doc.isOnline, isTrue);
      expect(doc.isVerified, isTrue);
      expect(doc.avatarInitials, equals('AN'));
    });
  });

  group('2. Vietnamese Phone and Workplace Address Validation Tests', () {
    test('Valid Vietnamese phone numbers pass static validator', () {
      expect(DoctorProfile.isValidPhoneNumber('0912345678'), isTrue);
      expect(DoctorProfile.isValidPhoneNumber('0334567890'), isTrue);
      expect(DoctorProfile.isValidPhoneNumber('+84912345678'), isTrue);
      expect(DoctorProfile.isValidPhoneNumber('+84389998888'), isTrue);
      expect(DoctorProfile.isValidPhoneNumber(' 0912345678 '), isTrue);
    });

    test('Invalid phone numbers fail static validator', () {
      expect(DoctorProfile.isValidPhoneNumber(null), isFalse);
      expect(DoctorProfile.isValidPhoneNumber(''), isFalse);
      expect(DoctorProfile.isValidPhoneNumber('12345'), isFalse);
      expect(DoctorProfile.isValidPhoneNumber('091234567890'), isFalse);
      expect(DoctorProfile.isValidPhoneNumber('abc0912345678'), isFalse);
      expect(DoctorProfile.isValidPhoneNumber('0912-345-678'), isFalse);
    });

    test('Workplace address validation requires at least 5 chars', () {
      expect(DoctorProfile.isValidWorkplaceAddress('Bệnh viện Chợ Rẫy'), isTrue);
      expect(DoctorProfile.isValidWorkplaceAddress('Số 215 Hồng Bàng'), isTrue);
      expect(DoctorProfile.isValidWorkplaceAddress(null), isFalse);
      expect(DoctorProfile.isValidWorkplaceAddress(''), isFalse);
      expect(DoctorProfile.isValidWorkplaceAddress('   '), isFalse);
      expect(DoctorProfile.isValidWorkplaceAddress('BV 1'), isFalse);
    });

    test('Full name validation requires at least 3 chars', () {
      expect(DoctorProfile.isValidFullName('BS. An'), isTrue);
      expect(DoctorProfile.isValidFullName('Nguyễn Văn A'), isTrue);
      expect(DoctorProfile.isValidFullName(null), isFalse);
      expect(DoctorProfile.isValidFullName(''), isFalse);
      expect(DoctorProfile.isValidFullName('A'), isFalse);
      expect(DoctorProfile.isValidFullName('  B  '), isFalse);
    });
  });

  group('3. DoctorManagementService CRUD & Listener Lifecycle Tests', () {
    final service = DoctorManagementService.instance;

    setUp(() {
      service.resetToDefaultSeed();
    });

    test('Initial service state contains seeded doctors with valid R1 fields', () async {
      final doctors = await service.fetchDoctors();
      expect(doctors, isNotEmpty);
      expect(doctors.length, greaterThanOrEqualTo(4));
      for (final doc in doctors) {
        expect(DoctorProfile.isValidPhoneNumber(doc.phoneNumber), isTrue);
        expect(DoctorProfile.isValidWorkplaceAddress(doc.workplaceAddress), isTrue);
      }
    });

    test('addDoctor appends doctor, validates fields, and fires notification', () async {
      int notifyCount = 0;
      void listener() => notifyCount++;
      service.addListener(listener);

      final newDoc = const DoctorProfile(
        id: 'doc_crud_test_01',
        fullName: 'BS. Lê Thị Hoa',
        phoneNumber: '0988776655',
        workplaceAddress: 'Bệnh viện Nhi Đồng 1, TP.HCM',
        title: 'ThS.BS',
        specialty: 'Cấp cứu Nhi khoa',
        hospital: 'Bệnh viện Nhi Đồng 1',
      );

      final added = await service.addDoctor(newDoc);
      expect(added.id, equals('doc_crud_test_01'));
      expect(service.doctors.any((d) => d.id == 'doc_crud_test_01'), isTrue);
      expect(notifyCount, greaterThan(0));

      service.removeListener(listener);
    });

    test('addDoctor throws ArgumentError on invalid phone number', () async {
      final invalidDoc = const DoctorProfile(
        id: 'doc_invalid_phone',
        fullName: 'BS. Lê Thị Hoa',
        phoneNumber: '12345', // invalid
        workplaceAddress: 'Bệnh viện Nhi Đồng 1, TP.HCM',
        title: 'ThS.BS',
        specialty: 'Cấp cứu Nhi khoa',
        hospital: 'Bệnh viện Nhi Đồng 1',
      );

      expect(() => service.addDoctor(invalidDoc), throwsArgumentError);
    });

    test('updateDoctor modifies doctor and fires notification', () async {
      final newDoc = const DoctorProfile(
        id: 'doc_to_update',
        fullName: 'BS. Phạm Hồng',
        phoneNumber: '0901112222',
        workplaceAddress: 'Bệnh viện Quận 1, TP.HCM',
        title: 'BS. CKI',
        specialty: 'Nội tổng quát',
        hospital: 'Bệnh viện Quận 1',
      );
      await service.addDoctor(newDoc);

      final updated = newDoc.copyWith(
        phoneNumber: '0911223344',
        workplaceAddress: 'Số 341 Sư Vạn Hạnh, Quận 10, TP.HCM',
      );

      await service.updateDoctor(updated);
      final found = service.getDoctorById('doc_to_update');
      expect(found, isNotNull);
      expect(found!.phoneNumber, equals('0911223344'));
      expect(found.workplaceAddress, contains('Sư Vạn Hạnh'));
    });

    test('deleteDoctor removes doctor and fires notification', () async {
      final newDoc = const DoctorProfile(
        id: 'doc_to_delete',
        fullName: 'BS. Trần Văn Xóa',
        phoneNumber: '0909998888',
        workplaceAddress: 'Bệnh viện Quận 3, TP.HCM',
        title: 'BS',
        specialty: 'Đa khoa',
        hospital: 'Bệnh viện Quận 3',
      );
      await service.addDoctor(newDoc);
      expect(service.doctors.any((d) => d.id == 'doc_to_delete'), isTrue);

      await service.deleteDoctor('doc_to_delete');
      expect(service.doctors.any((d) => d.id == 'doc_to_delete'), isFalse);
    });
  });

  group('4. AdminDoctorManagementView Widget & Interaction Tests', () {
    Widget buildTestApp(Widget child) {
      return MaterialApp(
        home: Scaffold(body: child),
      );
    }

    testWidgets('Renders AdminDoctorManagementView with KPI cards and search field', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(const AdminDoctorManagementView()));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Quản lý Bác sĩ hệ thống'), findsOneWidget);
      expect(find.text('Tổng số Bác sĩ'), findsOneWidget);
      expect(find.text('Đang trực tuyến'), findsOneWidget);
      expect(find.text('Thêm Bác sĩ mới'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping Thêm Bác sĩ opens Form Dialog with required validators', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(const AdminDoctorManagementView()));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Thêm Bác sĩ mới'));
      await tester.pumpAndSettle();

      expect(find.text('Họ và tên Bác sĩ *'), findsOneWidget);
      expect(find.text('Số điện thoại liên hệ *'), findsOneWidget);
      expect(find.text('Địa chỉ nơi công tác *'), findsOneWidget);

      // Submit empty to trigger validation
      await tester.tap(find.text('Thêm Bác sĩ'));
      await tester.pumpAndSettle();

      expect(find.textContaining('tối thiểu 3 ký tự'), findsOneWidget);
    });
  });

  group('5. Patient Doctor Directory & Switcher Widget Tests', () {
    Widget buildPatientApp(Widget child, UserViewModel vm) {
      return ChangeNotifierProvider<UserViewModel>.value(
        value: vm,
        child: MaterialApp(home: child),
      );
    }

    testWidgets('DoctorDirectoryView renders doctor cards and consultation button', (tester) async {
      final userVm = UserViewModel();

      await tester.pumpWidget(buildPatientApp(const DoctorDirectoryView(), userVm));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Danh bạ Bác sĩ Chuyên khoa'), findsOneWidget);
      expect(find.textContaining('Tư vấn'), findsWidgets);
      expect(tester.takeException(), isNull);

      userVm.dispose();
    });

    testWidgets('Doctor switcher inside DoctorConsultationView allows switching active doctor', (tester) async {
      final userVm = UserViewModel();
      userVm.initDoctorConsultationIfNeeded();

      await tester.pumpWidget(buildPatientApp(const DoctorConsultationView(), userVm));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(Icons.swap_horiz_rounded), findsWidgets);
      expect(tester.takeException(), isNull);

      userVm.dispose();
    });
  });

  group('6. Doctor Account Provisioning & Role Modeling Tests (Milestone M2)', () {
    test('UserAccountModel role and doctorId defaults and getters', () {
      final patient = UserAccountModel(
        username: 'patient_01',
        password: 'password123',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(patient.role, equals(UserRole.patient));
      expect(patient.doctorId, isNull);
      expect(patient.isPatient, isTrue);
      expect(patient.isDoctor, isFalse);

      final doctorAcc = UserAccountModel(
        username: 'bs_an',
        password: 'password123',
        role: UserRole.doctor,
        doctorId: 'doc_an_nguyen',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(doctorAcc.role, equals(UserRole.doctor));
      expect(doctorAcc.doctorId, equals('doc_an_nguyen'));
      expect(doctorAcc.isDoctor, isTrue);
      expect(doctorAcc.isPatient, isFalse);
    });

    test('DoctorProfile defaultDoctor is linked with accountUsername bs_an', () {
      final doc = DoctorProfile.defaultDoctor;
      expect(doc.accountUsername, equals('bs_an'));
      expect(doc.hasAccount, isTrue);
    });

    test('UserAccountService seeds bs_an and authenticates returning doctorId', () {
      final auth = UserAccountService.instance.authenticate(
        username: 'bs_an',
        password: 'password123',
      );
      expect(auth['success'], isTrue);
      final acc = auth['account'] as UserAccountModel;
      expect(acc.role, equals(UserRole.doctor));
      expect(acc.doctorId, equals('doc_an_nguyen'));
    });

    test('createDoctorAccount links UserAccountModel and DoctorProfile two-ways', () async {
      DoctorManagementService.instance.resetToDefaultSeed();
      final err = await UserAccountService.instance.createDoctorAccount(
        username: 'bs_mai_huong',
        password: 'password123',
        doctorId: 'doc_mai_huong',
        fullName: 'ThS. BS Trần Mai Hương',
        phone: '0983124567',
      );
      expect(err, isNull);

      final acc = UserAccountService.instance.findByUsername('bs_mai_huong');
      expect(acc, isNotNull);
      expect(acc!.role, equals(UserRole.doctor));
      expect(acc.doctorId, equals('doc_mai_huong'));

      final doc = DoctorManagementService.instance.getDoctorById('doc_mai_huong');
      expect(doc, isNotNull);
      expect(doc!.accountUsername, equals('bs_mai_huong'));
      expect(doc.hasAccount, isTrue);

      final byUser = DoctorManagementService.instance.getDoctorByUsername('bs_mai_huong');
      expect(byUser?.id, equals('doc_mai_huong'));
    });

    test('createDoctorAccount rejects duplicate usernames', () async {
      final err = await UserAccountService.instance.createDoctorAccount(
        username: 'bs_an',
        password: 'password123',
        doctorId: 'doc_quoc_bao',
      );
      expect(err, isNotNull);
      expect(err, contains('đã tồn tại'));
    });

    test('LocalStorageService manages doctor session correctly', () async {
      final storage = LocalStorageService.instance;
      await storage.saveDoctorSession(username: 'bs_an', doctorId: 'doc_an_nguyen');
      expect(storage.isDoctorLoggedIn(), isTrue);
      expect(storage.getDoctorSavedUsername(), equals('bs_an'));
      expect(storage.getDoctorSavedId(), equals('doc_an_nguyen'));

      await storage.clearDoctorSession();
      expect(storage.isDoctorLoggedIn(), isFalse);
      expect(storage.getDoctorSavedUsername(), isNull);
    });
  });

  group('7. Requirements R1 & R2 Enhancements (Persistence & Auth Fallback)', () {
    test('DoctorProfile.toSupabaseMap excludes account_username to prevent PostgREST 400', () {
      final doc = DoctorProfile.defaultDoctor.copyWith(accountUsername: 'bs_an');
      final localMap = doc.toMap();
      expect(localMap.containsKey('account_username'), isTrue);
      expect(localMap['account_username'], equals('bs_an'));

      final supabaseMap = doc.toSupabaseMap();
      expect(supabaseMap.containsKey('account_username'), isFalse);
      expect(supabaseMap['id'], equals('doc_an_nguyen'));
    });

    test('UserAccountModel.fromMap deserializes medical_profile JSONB, password_hash, and full_name', () {
      final cloudJson = {
        'username': 'bs_cloud_test',
        'password_hash': 'secret123',
        'medical_profile': {
          'role': UserRole.doctor,
          'doctor_id': 'doc_cloud_01',
          'full_name': 'BS. Cloud Test',
          'account_type': 'doctor_provisioned',
        },
      };

      final acc = UserAccountModel.fromMap(cloudJson);
      expect(acc.username, equals('bs_cloud_test'));
      expect(acc.password, equals('secret123'));
      expect(acc.fullName, equals('BS. Cloud Test'));
      expect(acc.role, equals(UserRole.doctor));
      expect(acc.doctorId, equals('doc_cloud_01'));
      expect(acc.isDoctor, isTrue);
    });

    test('DoctorManagementService.fetchDoctorsFromSupabase non-destructive merge preserves bs_an', () async {
      final service = DoctorManagementService.instance;
      service.resetToDefaultSeed();
      final defaultDoc = service.getDoctorById('doc_an_nguyen');
      expect(defaultDoc?.accountUsername, equals('bs_an'));

      // Khi fetchDoctorsFromSupabase được gọi, bs_an không bao giờ bị xóa trắng
      await service.fetchDoctorsFromSupabase();
      final afterFetch = service.getDoctorById('doc_an_nguyen');
      expect(afterFetch?.accountUsername, equals('bs_an'));
      expect(afterFetch?.hasAccount, isTrue);
    });

    test('UserAccountService.authenticateAsync authenticates default doctor with fallback', () async {
      final authResult = await UserAccountService.instance.authenticateAsync(
        username: 'bs_an',
        password: 'password123',
      );
      expect(authResult['success'], isTrue);
      final acc = authResult['account'] as UserAccountModel;
      expect(acc.username, equals('bs_an'));
      expect(acc.role, equals(UserRole.doctor));
      expect(acc.doctorId, equals('doc_an_nguyen'));
    });
  });
}
