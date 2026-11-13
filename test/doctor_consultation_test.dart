import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:do_an_cntt_11/features/user/models/doctor_consultation_models.dart';
import 'package:do_an_cntt_11/features/user/services/doctor_response_simulator.dart';
import 'package:do_an_cntt_11/features/user/viewmodels/user_viewmodel.dart';
import 'package:do_an_cntt_11/features/user/views/doctor_consultation_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Doctor Consultation Data Models Tests', () {
    test('DoctorProfile default constructor and values', () {
      final doc = DoctorProfile.defaultDoctor;
      expect(doc.id, equals('doc_an_nguyen'));
      expect(doc.fullName, contains('Nguyễn Văn An'));
      expect(doc.avatarInitials, equals('AN'));
      expect(doc.isOnline, isTrue);
      expect(doc.isVerified, isTrue);
      expect(doc.rating, greaterThanOrEqualTo(4.9));
      expect(doc.consultationCount, greaterThan(2000));
    });

    test('DoctorChatMessage getters, status and copyWith', () {
      final now = DateTime.now();
      final message = DoctorChatMessage(
        id: 'msg_01',
        senderType: ChatSenderType.patient,
        content: 'Tôi bị bỏng nước sôi ở cánh tay',
        timestamp: now,
        status: MessageDeliveryStatus.sending,
      );

      expect(message.isPatient, isTrue);
      expect(message.isDoctor, isFalse);
      expect(message.isSystem, isFalse);
      expect(message.formattedTime, isNotEmpty);

      final updated = message.copyWith(status: MessageDeliveryStatus.read);
      expect(updated.status, equals(MessageDeliveryStatus.read));
      expect(updated.content, equals(message.content));
    });

    test('ChatAttachment and hasImage validation', () {
      final attachmentNoImage = const ChatAttachment(
        id: 'att_01',
        type: ChatAttachmentType.none,
      );
      expect(attachmentNoImage.hasImage, isFalse);

      final attachmentWithImage = ChatAttachment(
        id: 'att_02',
        type: ChatAttachmentType.image,
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        fileName: 'wound.jpg',
      );
      expect(attachmentWithImage.hasImage, isTrue);
      expect(attachmentWithImage.fileName, equals('wound.jpg'));
    });
  });

  group('2. Medical Simulation Engine (DoctorResponseSimulator) Tests', () {
    const simulator = DoctorResponseSimulator(fastMode: true);
    final doctor = DoctorProfile.defaultDoctor;

    test('Triage Decision Tree: Bleeding Emergency Warning', () async {
      final reply = await simulator.generateDoctorResponse(
        patientMessage: 'Tôi bị chảy máu nhiều, không cầm được máu',
        doctor: doctor,
      );

      expect(reply.isDoctor, isTrue);
      expect(reply.isEmergencyWarning, isTrue);
      expect(reply.content, contains('CẤP CỨU'));
      expect(reply.content, contains('ép TRỰC TIẾP'));
      expect(reply.quickReplies.any((q) => q.id.contains('bleeding')), isTrue);
    });

    test('Triage Decision Tree: Burn Injury Protocol', () async {
      final reply = await simulator.generateDoctorResponse(
        patientMessage: 'Tôi vừa bị bỏng nước sôi ở bàn tay',
        doctor: doctor,
      );

      expect(reply.isEmergencyWarning, isFalse);
      expect(reply.content, contains('vòi nước sạch'));
      expect(reply.content, contains('15 - 20 phút'));
      expect(reply.content, contains('TUYỆT ĐỐI KHÔNG'));
      expect(reply.quickReplies.any((q) => q.id.contains('burn')), isTrue);
    });

    test('Triage Decision Tree: Infection Signs Protocol', () async {
      final reply = await simulator.generateDoctorResponse(
        patientMessage: 'Vết thương của tôi đang sưng đỏ và chảy mủ, sốt nhẹ',
        doctor: doctor,
      );

      expect(reply.isEmergencyWarning, isTrue);
      expect(reply.content, contains('NHIỄM TRÙNG'));
      expect(reply.content, contains('kháng sinh'));
    });

    test('Triage Decision Tree: Wound Scan Handover Protocol', () async {
      final attachment = ChatAttachment(
        id: 'scan_att_01',
        type: ChatAttachmentType.woundScanSummary,
        bytes: Uint8List.fromList([10, 20, 30]),
      );

      final reply = await simulator.generateDoctorResponse(
        patientMessage: 'Chào bác sĩ, tôi gửi kết quả phân tích vết thương',
        doctor: doctor,
        attachment: attachment,
        clinicalContext: {
          'injuryType': 'Vết cắt / rách da',
          'confidence': 95,
          'location': 'Cẳng tay',
          'isBleeding': true,
        },
      );

      expect(reply.content, contains('Vết cắt / rách da'));
      expect(reply.content, contains('95%'));
      expect(reply.content, contains('Cẳng tay'));
      expect(reply.content, contains('CHẢY MÁU'));
    });

    test('Triage Decision Tree: Defensive parsing of confidence (double/string/null)', () async {
      // Test double confidence
      final replyDouble = await simulator.generateDoctorResponse(
        patientMessage: 'kết quả phân tích vết thương',
        doctor: doctor,
        clinicalContext: {
          'injuryType': 'Vết xước',
          'confidence': 92.5,
          'location': 'Khuỷu tay',
        },
      );
      expect(replyDouble.content, contains('92%'));

      // Test String percentage confidence
      final replyString = await simulator.generateDoctorResponse(
        patientMessage: 'kết quả phân tích vết thương',
        doctor: doctor,
        clinicalContext: {
          'injuryType': 'Bỏng nhiệt',
          'confidence': '88%',
          'location': 'Bàn chân',
        },
      );
      expect(replyString.content, contains('88%'));

      // Test null confidence and types
      final replyNull = await simulator.generateDoctorResponse(
        patientMessage: 'kết quả phân tích vết thương',
        doctor: doctor,
        clinicalContext: null,
      );
      expect(replyNull.content, contains('90%'));
    });

    test('Message Delivery Lifecycle transitions through sent, delivered, read', () async {
      final message = DoctorChatMessage(
        id: 'test_pat_msg',
        senderType: ChatSenderType.patient,
        content: 'Xin chào bác sĩ',
        timestamp: DateTime.now(),
        status: MessageDeliveryStatus.sending,
      );

      final transitions = <MessageDeliveryStatus>[];
      bool typingStarted = false;

      await simulator.simulateMessageDeliveryLifecycle(
        message: message,
        onStatusChanged: (status) => transitions.add(status),
        onStartTyping: () => typingStarted = true,
      );

      expect(transitions, containsAllInOrder([
        MessageDeliveryStatus.sent,
        MessageDeliveryStatus.delivered,
        MessageDeliveryStatus.read,
      ]));
      expect(typingStarted, isTrue);
    });
  });

  group('3. ViewModel Mixin (BacSiTuVanViewModel) Integration Tests', () {
    late UserViewModel vm;

    setUp(() {
      vm = UserViewModel();
      vm.setSimulatorForTesting(const DoctorResponseSimulator(fastMode: true));
      vm.initDoctorConsultationIfNeeded();
    });

    tearDown(() {
      vm.dispose();
    });

    test('Initial consultation state has default welcome message from doctor', () {
      expect(vm.doctorChatMessages, isNotEmpty);
      expect(vm.doctorChatMessages.first.isDoctor, isTrue);
      expect(vm.doctorChatMessages.first.content, contains('Nguyễn Văn An'));
      expect(vm.isDoctorTyping, isFalse);
      expect(vm.pendingAttachment, isNull);
    });

    test('Sending patient message triggers full lifecycle and appends doctor reply', () async {
      expect(vm.doctorChatMessages.length, equals(1));

      final sendFuture = vm.sendDoctorChatMessage(text: 'Tôi bị đứt tay đang chảy máu');
      expect(vm.doctorChatMessages.length, equals(2));
      expect(vm.doctorChatMessages.last.isPatient, isTrue);
      expect(vm.doctorChatMessages.last.content, equals('Tôi bị đứt tay đang chảy máu'));

      await sendFuture;

      expect(vm.doctorChatMessages.length, equals(3));
      expect(vm.doctorChatMessages.last.isDoctor, isTrue);
      expect(vm.isDoctorTyping, isFalse);
    });

    test('Selecting a quick reply triggers patient message dispatch', () async {
      const option = DoctorQuickActionOption(
        id: 'test_opt_01',
        title: 'Hỏi về bỏng',
        defaultText: 'Tôi vừa bị bỏng nhiệt cần tư vấn ngay',
      );

      final initialCount = vm.doctorChatMessages.length;
      vm.selectDoctorQuickReply(option);

      expect(vm.doctorChatMessages.length, equals(initialCount + 1));
      expect(vm.doctorChatMessages.last.content, equals(option.defaultText));

      await Future.delayed(const Duration(milliseconds: 250));
      expect(vm.doctorChatMessages.last.isDoctor, isTrue);
    });

    test('Clear chat history resets to initial doctor welcome', () async {
      await vm.sendDoctorChatMessage(text: 'Tin nhắn thử nghiệm 1');
      expect(vm.doctorChatMessages.length, greaterThan(1));

      vm.clearDoctorChatHistory();
      expect(vm.doctorChatMessages.length, equals(1));
      expect(vm.doctorChatMessages.first.isDoctor, isTrue);
    });

    test('Navigation to Doctor Consultation sets currentScreenIndex to 8', () {
      expect(vm.currentScreenIndex, equals(0));
      vm.navigateToDoctorConsultation();
      expect(vm.currentScreenIndex, equals(8));
      expect(vm.selectedSidebarIndex, equals(6));
    });

    test('Disposing ViewModel mid-flight does not throw Bad state or ScrollController errors', () async {
      final localVm = UserViewModel();
      localVm.setSimulatorForTesting(const DoctorResponseSimulator(fastMode: true));
      localVm.initDoctorConsultationIfNeeded();

      // Dispatch message and immediately dispose
      final future = localVm.sendDoctorChatMessage(text: 'Tin nhắn trước khi rời phòng tư vấn');
      localVm.dispose();

      // Wait for simulator timers to fire and ensure no exceptions occur
      await expectLater(future, completes);
    });

    test('Rapid sequential dispatches generate unique microsecond monotonic message IDs', () async {
      final futures = <Future<void>>[];
      for (int i = 0; i < 5; i++) {
        futures.add(vm.sendDoctorChatMessage(text: 'Tin nhắn nhanh thứ $i'));
      }
      await Future.wait(futures);

      final ids = vm.doctorChatMessages.map((m) => m.id).toList();
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, equals(ids.length));
    });
  });

  group('4. Responsive Widget & Zalo UI Tests', () {
    Widget buildTestableWidget(UserViewModel vm, {required Size size}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: ChangeNotifierProvider<UserViewModel>.value(
            value: vm,
            child: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: const DoctorConsultationView(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Doctor Consultation UI renders doctor header, bubbles, and input bar', (WidgetTester tester) async {
      final vm = UserViewModel();
      vm.setSimulatorForTesting(const DoctorResponseSimulator(fastMode: true));
      vm.initDoctorConsultationIfNeeded();

      await tester.pumpWidget(buildTestableWidget(vm, size: const Size(390, 844)));
      await tester.pump(const Duration(milliseconds: 200));

      // Kiểm tra Header
      expect(find.text(DoctorProfile.defaultDoctor.fullName), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

      // Kiểm tra tin nhắn chào ban đầu của Bác sĩ
      expect(find.textContaining('Tôi đang trực tiếp tiếp nhận phòng khám'), findsOneWidget);

      // Kiểm tra thanh nhập liệu và các nút
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);

      // Gõ tin nhắn và gửi
      await tester.enterText(find.byType(TextField), 'Xin chào bác sĩ, tôi cần tư vấn');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      // Kiểm tra bong bóng bệnh nhân xuất hiện ngay lập tức
      expect(find.text('Xin chào bác sĩ, tôi cần tư vấn'), findsOneWidget);

      // Chờ hoàn thành phản hồi của bác sĩ
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(vm.doctorChatMessages.length, greaterThanOrEqualTo(3));

      // Đảm bảo không có exception
      expect(tester.takeException(), isNull);

      vm.dispose();
    });

    testWidgets('Responsive Desktop viewport (1280x800) renders without layout overflow', (WidgetTester tester) async {
      final vm = UserViewModel();
      vm.setSimulatorForTesting(const DoctorResponseSimulator(fastMode: true));
      vm.initDoctorConsultationIfNeeded();

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(vm, size: const Size(1280, 800)));
      await tester.pump(const Duration(milliseconds: 200));

      // Cột hồ sơ Bác sĩ bên phải trên Desktop
      expect(find.text('Đánh giá'), findsOneWidget);
      expect(find.text('Lượt tư vấn'), findsOneWidget);
      expect(find.text('Kinh nghiệm'), findsOneWidget);
      expect(find.text('Cấp cứu SOS 115'), findsOneWidget);

      // Xác nhận không có lỗi tràn khung giao diện (zero overflow exceptions)
      expect(tester.takeException(), isNull);

      vm.dispose();
    });

    testWidgets('Responsive Mobile viewport (360x640) renders cleanly without layout overflow', (WidgetTester tester) async {
      final vm = UserViewModel();
      vm.setSimulatorForTesting(const DoctorResponseSimulator(fastMode: true));
      vm.initDoctorConsultationIfNeeded();

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(vm, size: const Size(360, 640)));
      await tester.pump(const Duration(milliseconds: 200));

      // Nút Back trên Mobile
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      // Xác nhận không có lỗi tràn khung giao diện (zero overflow exceptions)
      expect(tester.takeException(), isNull);

      vm.dispose();
    });

    testWidgets('Responsive Ultra-narrow Mobile viewport (320x568) renders cleanly without layout overflow', (WidgetTester tester) async {
      final vm = UserViewModel();
      vm.setSimulatorForTesting(const DoctorResponseSimulator(fastMode: true));
      vm.initDoctorConsultationIfNeeded();

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(vm, size: const Size(320, 568)));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(DoctorProfile.defaultDoctor.fullName), findsOneWidget);
      expect(tester.takeException(), isNull);

      vm.dispose();
    });

    testWidgets('Image attachment with corrupt bytes displays fallback broken image icon without crashing', (WidgetTester tester) async {
      final vm = UserViewModel();
      vm.setSimulatorForTesting(const DoctorResponseSimulator(fastMode: true));
      vm.initDoctorConsultationIfNeeded();

      // Dispatch a message with broken attachment bytes
      await vm.sendDoctorChatMessage(
        text: 'Ảnh vết thương hỏng',
        attachment: ChatAttachment(
          id: 'corrupt_img_test',
          type: ChatAttachmentType.image,
          bytes: Uint8List.fromList([0, 1, 2, 3]), // Non-decodable bytes
        ),
      );

      await tester.pumpWidget(buildTestableWidget(vm, size: const Size(390, 844)));
      await tester.pump(const Duration(milliseconds: 200));

      // Broken image icon from errorBuilder should be rendered without throwing
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);

      vm.dispose();
    });

    testWidgets('DoctorTypingBubble animates cleanly without build mutations', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorTypingBubble(
              doctor: DoctorProfile.defaultDoctor,
              isDesktop: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('${DoctorProfile.defaultDoctor.fullName} đang phản hồi...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
