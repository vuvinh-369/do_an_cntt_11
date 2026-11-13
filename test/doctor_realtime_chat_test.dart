// File: test/doctor_realtime_chat_test.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:do_an_cntt_11/features/user/models/doctor_consultation_models.dart';
import 'package:do_an_cntt_11/features/user/services/doctor_consultation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = DoctorConsultationService.instance;

  setUp(() {
    service.resetToDefaultSeed();
    service.currentViewingConversationId = null;
  });

  // ===========================================================================
  // GROUP 1: DATA MODEL SERIALIZATION & ENUMS
  // ===========================================================================
  group('1. DoctorChatMessage & Queue Data Models Serialization', () {
    test('DoctorChatMessage serialization toMap and fromMap with new M2 fields', () {
      final now = DateTime.now();
      final msg = DoctorChatMessage(
        id: 'msg_test_01',
        conversationId: 'conv_test_01',
        senderType: ChatSenderType.patient,
        senderId: 'pat_test_01',
        senderName: 'Nguyễn Văn An (Bệnh nhân)',
        content: 'Bác sĩ ơi, vết thương của tôi chảy nhiều máu',
        attachmentUrl: 'https://example.com/wound.jpg',
        attachmentType: ChatAttachmentType.image,
        timestamp: now,
        status: MessageDeliveryStatus.sent,
        isEmergencyWarning: true,
      );

      final map = msg.toMap();
      expect(map['id'], equals('msg_test_01'));
      expect(map['conversation_id'], equals('conv_test_01'));
      expect(map['sender_type'], equals('patient'));
      expect(map['sender_id'], equals('pat_test_01'));
      expect(map['sender_name'], contains('Nguyễn Văn An'));
      expect(map['attachment_url'], equals('https://example.com/wound.jpg'));
      expect(map['attachment_type'], equals('image'));
      expect(map['is_emergency_warning'], isTrue);

      final restored = DoctorChatMessage.fromMap(map);
      expect(restored.id, equals(msg.id));
      expect(restored.conversationId, equals(msg.conversationId));
      expect(restored.senderType, equals(ChatSenderType.patient));
      expect(restored.isPatient, isTrue);
      expect(restored.isDoctor, isFalse);
      expect(restored.hasAttachment, isTrue);
      expect(restored.isEmergencyWarning, isTrue);
    });

    test('ChatSenderType enum includes ai, doctor, patient, and system', () {
      expect(ChatSenderType.values, contains(ChatSenderType.ai));
      expect(ChatSenderType.values, contains(ChatSenderType.doctor));
      expect(ChatSenderType.values, contains(ChatSenderType.patient));
      expect(ChatSenderType.values, contains(ChatSenderType.system));

      final aiMsg = DoctorChatMessage(
        id: 'msg_ai_01',
        senderType: ChatSenderType.ai,
        content: 'AI Doctor response',
        timestamp: DateTime.now(),
      );
      expect(aiMsg.isAi, isTrue);
      expect(aiMsg.isDoctor, isFalse);
    });

    test('ConversationQueueItem serialization toMap and fromMap', () {
      final now = DateTime.now();
      final item = ConversationQueueItem(
        conversationId: 'conv_q_01',
        patientId: 'pat_01',
        patientName: 'Lê Hoàng',
        patientPhone: '0901234567',
        doctorId: 'doc_an_nguyen',
        doctorName: 'BS. CKI Nguyễn Văn An',
        lastMessageContent: 'Vết khâu bị bục',
        lastMessageTime: now,
        unreadCount: 3,
        hasAiFallbackResponse: false,
      );

      final map = item.toMap();
      expect(map['id'], equals('conv_q_01'));
      expect(map['patient_name'], equals('Lê Hoàng'));
      expect(map['unread_doctor_count'], equals(3));

      final restored = ConversationQueueItem.fromMap(map);
      expect(restored.conversationId, equals(item.conversationId));
      expect(restored.patientName, equals('Lê Hoàng'));
      expect(restored.unreadCount, equals(3));
    });
  });

  // ===========================================================================
  // GROUP 2: IN-MEMORY STREAM REACTIVITY & 2-WAY MESSAGING
  // ===========================================================================
  group('2. In-Memory Stream Reactivity & 2-Way Messaging', () {
    test('getMessagesStream emits stored messages immediately upon listen', () async {
      final stream = service.getMessagesStream('conv_an_nguyen_01');
      List<DoctorChatMessage>? received;
      final sub = stream.listen((data) => received = data);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(received, isNotNull);
      expect(received!.length, greaterThanOrEqualTo(2));
      await sub.cancel();
    });

    test('Patient sends message and receives live update on stream', () async {
      final stream = service.getMessagesStream('conv_test_2way');
      List<DoctorChatMessage>? streamData;
      final sub = stream.listen((data) => streamData = data);

      await service.sendMessage(
        conversationId: 'conv_test_2way',
        senderType: 'patient',
        senderId: 'pat_01',
        patientName: 'Bệnh nhân Thắng',
        content: 'Tôi bị bỏng tay do chạm vào pô xe máy',
      );

      await Future.delayed(const Duration(milliseconds: 20));
      expect(streamData, isNotNull);
      expect(streamData!.last.isPatient, isTrue);
      expect(streamData!.last.content, contains('chạm vào pô xe máy'));
      await sub.cancel();
    });

    test('Doctor replies and patient sees message immediately on stream', () async {
      final stream = service.getMessagesStream('conv_test_2way');
      List<DoctorChatMessage>? streamData;
      final sub = stream.listen((data) => streamData = data);

      await service.sendMessage(
        conversationId: 'conv_test_2way',
        senderType: 'doctor',
        senderId: 'doc_an_nguyen',
        senderName: 'BS. CKI Nguyễn Văn An',
        content: 'Bạn hãy ngâm tay dưới vòi nước mát sạch ngay trong 15-20 phút nhé!',
      );

      await Future.delayed(const Duration(milliseconds: 20));
      expect(streamData, isNotNull);
      expect(streamData!.last.isDoctor, isTrue);
      expect(streamData!.last.content, contains('ngâm tay dưới vòi nước mát'));
      await sub.cancel();
    });
  });

  // ===========================================================================
  // GROUP 3: IMAGE ATTACHMENTS HANDLING
  // ===========================================================================
  group('3. Image & Attachment Handling', () {
    test('Patient sends image attachment with caption', () async {
      final attachment = ChatAttachment(
        id: 'att_wound_01',
        type: ChatAttachmentType.image,
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        fileName: 'wound_burn.jpg',
      );

      await service.sendMessage(
        conversationId: 'conv_attach_test',
        senderType: 'patient',
        senderId: 'pat_02',
        content: 'Gửi bác sĩ ảnh vết bỏng',
        attachment: attachment,
        attachmentType: 'image',
      );

      final stored = service.getStoredMessages('conv_attach_test');
      expect(stored.last.attachment, isNotNull);
      expect(stored.last.attachment!.fileName, equals('wound_burn.jpg'));
      expect(stored.last.hasAttachment, isTrue);
    });

    test('URL attachment without bytes is supported', () async {
      await service.sendMessage(
        conversationId: 'conv_url_test',
        senderType: 'patient',
        senderId: 'pat_03',
        content: 'Ảnh vết rách',
        attachmentUrl: 'https://supabase.co/storage/v1/object/public/wounds/cut.jpg',
        attachmentType: 'image',
      );

      final stored = service.getStoredMessages('conv_url_test');
      expect(stored.last.attachmentUrl, contains('cut.jpg'));
      expect(stored.last.hasAttachment, isTrue);
    });
  });

  // ===========================================================================
  // GROUP 4: MESSAGE DELIVERY STATUS TRANSITIONS
  // ===========================================================================
  group('4. Message Delivery Status Transitions', () {
    test('Delivery status transitions from sent to delivered to read', () async {
      final msg = await service.sendMessage(
        conversationId: 'conv_status_progression',
        senderType: 'patient',
        senderId: 'pat_04',
        content: 'Kiểm tra trạng thái',
      );
      expect(msg.status, equals(MessageDeliveryStatus.sent));

      service.updateDeliveryStatus('conv_status_progression', msg.id, MessageDeliveryStatus.delivered);
      expect(service.getStoredMessages('conv_status_progression').last.status, equals(MessageDeliveryStatus.delivered));

      service.updateDeliveryStatus('conv_status_progression', msg.id, MessageDeliveryStatus.read);
      expect(service.getStoredMessages('conv_status_progression').last.status, equals(MessageDeliveryStatus.read));
    });
  });

  // ===========================================================================
  // GROUP 5: DOCTOR PORTAL QUEUE & UNREAD NOTIFICATIONS
  // ===========================================================================
  group('5. Doctor Portal Queue & Unread Notification System', () {
    test('Patient sending message to inactive chat increments unread count', () async {
      service.currentViewingConversationId = 'other_conv';

      await service.sendMessage(
        conversationId: 'conv_unread_test',
        senderType: 'patient',
        senderId: 'pat_05',
        content: 'Bác sĩ kiểm tra giúp tôi với',
      );

      final unread = service.getUnreadCount('conv_unread_test');
      expect(unread, equals(1));
    });

    test('Doctor viewing conversation does NOT increment unread badge', () async {
      service.currentViewingConversationId = 'conv_active_view';

      await service.sendMessage(
        conversationId: 'conv_active_view',
        senderType: 'patient',
        senderId: 'pat_06',
        content: 'Đang xem trực tiếp',
      );

      final unread = service.getUnreadCount('conv_active_view');
      expect(unread, equals(0));
    });

    test('Doctor receives in-app banner alert for incoming message on inactive chat', () async {
      service.currentViewingConversationId = 'conv_viewing_a';
      String? alertReceived;
      final sub = service.bannerAlertStream.listen((alert) => alertReceived = alert);

      await service.sendMessage(
        conversationId: 'conv_viewing_b',
        senderType: 'patient',
        senderId: 'pat_alert',
        patientName: 'Bệnh nhân Mai',
        content: 'Khẩn cấp bác sĩ ơi!',
      );

      await Future.delayed(const Duration(milliseconds: 20));
      expect(alertReceived, isNotNull);
      expect(alertReceived, contains('Bệnh nhân Mai'));
      expect(alertReceived, contains('Khẩn cấp'));
      await sub.cancel();
    });

    test('markMessagesAsRead resets unread count and marks messages as read', () async {
      service.currentViewingConversationId = 'none';

      await service.sendMessage(
        conversationId: 'conv_mark_read_test',
        senderType: 'patient',
        senderId: 'pat_07',
        content: 'Tin nhắn chưa đọc',
      );
      expect(service.getUnreadCount('conv_mark_read_test'), equals(1));

      await service.markMessagesAsRead('conv_mark_read_test');
      expect(service.getUnreadCount('conv_mark_read_test'), equals(0));
      expect(service.getStoredMessages('conv_mark_read_test').last.status, equals(MessageDeliveryStatus.read));
    });

    test('Conversation queue re-orders with most recent message at top', () async {
      await service.sendMessage(
        conversationId: 'conv_order_1',
        senderType: 'patient',
        senderId: 'pat_1',
        content: 'Msg 1',
      );

      await service.sendMessage(
        conversationId: 'conv_order_2',
        senderType: 'patient',
        senderId: 'pat_2',
        content: 'Msg 2',
      );

      expect(service.queue.first.conversationId, equals('conv_order_2'));

      // Bump conv_order_1
      await service.sendMessage(
        conversationId: 'conv_order_1',
        senderType: 'patient',
        senderId: 'pat_1',
        content: 'Msg 1 New',
      );
      expect(service.queue.first.conversationId, equals('conv_order_1'));
    });
  });

  // ===========================================================================
  // GROUP 6: FAIL-SAFE OFFLINE RESILIENCE
  // ===========================================================================
  group('6. Dual-Mode Fail-Safe Offline Resilience', () {
    test('Service operations succeed with 0 crashes when Supabase is uninitialized', () async {
      expect(service.getStoredMessages('conv_an_nguyen_01'), isNotEmpty);

      final msg = await service.sendMessage(
        conversationId: 'conv_offline_test',
        senderType: 'patient',
        senderId: 'pat_offline',
        content: 'Hoàn toàn offline nhưng mượt mà',
      );

      expect(msg.content, contains('offline nhưng mượt mà'));
      final convs = await service.getDoctorConversations('doc_an_nguyen');
      expect(convs, isNotEmpty);
    });
  });

  // ===========================================================================
  // GROUP 7: STREAM RE-ENTRANCY PREVENTION & SEEDING TESTS (MILESTONE 1 FIX)
  // ===========================================================================
  group('7. Stream Loop Prevention & Seeding Verification (M1 Fix)', () {
    test('markMessagesAsRead does NOT emit into stream if no messages change status', () async {
      const convId = 'conv_no_loop_test';
      // 1. Seed already-read messages
      final welcomeMsg = DoctorChatMessage(
        id: 'welcome_01',
        conversationId: convId,
        senderType: ChatSenderType.doctor,
        senderId: 'doc_test',
        senderName: 'BS Test',
        content: 'Xin chào',
        timestamp: DateTime.now(),
        status: MessageDeliveryStatus.read,
      );
      service.seedInitialConversationMessages(convId, [welcomeMsg]);

      int streamEmitCount = 0;
      final sub = service.getMessagesStream(convId).listen((_) {
        streamEmitCount++;
      });
      // Allow initial microtask to fire
      await Future.delayed(const Duration(milliseconds: 20));
      final initialCount = streamEmitCount;

      // 2. Call markMessagesAsRead when messages are already read
      await service.markMessagesAsRead(convId, 'patient');
      await Future.delayed(const Duration(milliseconds: 20));

      // Stream should NOT have emitted any new event because hasStatusChanged was false
      expect(streamEmitCount, equals(initialCount));

      // 3. Add an unread message from doctor
      await service.sendMessage(
        conversationId: convId,
        senderType: 'doctor',
        senderId: 'doc_test',
        content: 'Tin nhắn mới từ bác sĩ',
      );
      await Future.delayed(const Duration(milliseconds: 20));
      expect(streamEmitCount, greaterThan(initialCount));
      final countAfterNewMsg = streamEmitCount;

      // 4. Now call markMessagesAsRead('patient') -> this time status changes!
      await service.markMessagesAsRead(convId, 'patient');
      await Future.delayed(const Duration(milliseconds: 20));
      expect(streamEmitCount, greaterThan(countAfterNewMsg));

      // 5. Subsequent call without new messages does NOT emit again
      final countAfterRead = streamEmitCount;
      await service.markMessagesAsRead(convId, 'patient');
      await Future.delayed(const Duration(milliseconds: 20));
      expect(streamEmitCount, equals(countAfterRead));

      await sub.cancel();
    });

    test('seedInitialConversationMessages preserves initial quick reply chips', () {
      const convId = 'conv_seed_test_unique';
      final welcomeMsg = DoctorChatMessage(
        id: 'seed_msg_01',
        conversationId: convId,
        senderType: ChatSenderType.doctor,
        senderId: 'doc_01',
        senderName: 'BS A',
        content: 'Tin nhắn chào ban đầu',
        timestamp: DateTime.now(),
        status: MessageDeliveryStatus.read,
        quickReplies: const [
          DoctorQuickActionOption(
            id: 'chip_1',
            title: 'Vết rách',
            defaultText: 'Vết rách da',
            icon: Icons.cut,
          ),
        ],
      );

      service.seedInitialConversationMessages(convId, [welcomeMsg]);
      final stored = service.getStoredMessages(convId);
      expect(stored.length, equals(1));
      expect(stored.first.quickReplies.length, equals(1));
      expect(stored.first.quickReplies.first.id, equals('chip_1'));
    });

    test('markMessagesAsRead only marks messages from opposite senderType', () async {
      const convId = 'conv_opposite_sender_test';
      final patMsg = DoctorChatMessage(
        id: 'pat_msg_01',
        conversationId: convId,
        senderType: ChatSenderType.patient,
        senderId: 'pat_01',
        content: 'Bệnh nhân hỏi',
        timestamp: DateTime.now(),
        status: MessageDeliveryStatus.delivered,
      );
      final docMsg = DoctorChatMessage(
        id: 'doc_msg_01',
        conversationId: convId,
        senderType: ChatSenderType.doctor,
        senderId: 'doc_01',
        content: 'Bác sĩ trả lời',
        timestamp: DateTime.now(),
        status: MessageDeliveryStatus.delivered,
      );

      service.seedInitialConversationMessages(convId, [patMsg, docMsg]);

      // Patient marks as read -> only doctor's message should become read
      await service.markMessagesAsRead(convId, 'patient');
      var stored = service.getStoredMessages(convId);
      expect(stored[0].status, equals(MessageDeliveryStatus.delivered)); // patient's own msg unchanged
      expect(stored[1].status, equals(MessageDeliveryStatus.read)); // doctor's msg marked read

      // Doctor marks as read -> now patient's message should become read
      await service.markMessagesAsRead(convId, 'doctor');
      stored = service.getStoredMessages(convId);
      expect(stored[0].status, equals(MessageDeliveryStatus.read)); // patient's msg now marked read
      expect(stored[1].status, equals(MessageDeliveryStatus.read));
    });
  });
}
