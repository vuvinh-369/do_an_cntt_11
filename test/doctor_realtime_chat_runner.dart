// Standalone verification runner for Milestone 2 Doctor Realtime Chat
// File: test/doctor_realtime_chat_runner.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:do_an_cntt_11/features/user/models/doctor_consultation_models.dart';
import 'package:do_an_cntt_11/features/user/services/doctor_consultation_service.dart';

void main() async {
  print('===============================================================');
  print('Running Milestone 2 Realtime Chat & Portal Verification Runner');
  print('===============================================================');

  final service = DoctorConsultationService.instance;
  int testsPassed = 0;
  int totalTests = 0;

  void assertCheck(String testName, bool condition, [String detail = '']) {
    totalTests++;
    if (condition) {
      testsPassed++;
      print('  [PASS] Spec $totalTests: $testName');
    } else {
      print('  [FAIL] Spec $totalTests: $testName - $detail');
      throw AssertionError('Test failed: $testName - $detail');
    }
  }

  // ---------------------------------------------------------------------------
  // GROUP 1: Models & Serialization
  // ---------------------------------------------------------------------------
  print('\nGroup 1: DoctorChatMessage & Queue Data Models Serialization');
  service.resetToDefaultSeed();
  service.currentViewingConversationId = null;

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
  assertCheck('DoctorChatMessage toMap contains conversation_id', map['conversation_id'] == 'conv_test_01');
  assertCheck('DoctorChatMessage toMap contains sender_type patient', map['sender_type'] == 'patient');
  assertCheck('DoctorChatMessage toMap contains attachment_url', map['attachment_url'] == 'https://example.com/wound.jpg');
  assertCheck('DoctorChatMessage toMap contains is_emergency_warning', map['is_emergency_warning'] == true);

  final restored = DoctorChatMessage.fromMap(map);
  assertCheck('DoctorChatMessage fromMap restores id', restored.id == msg.id);
  assertCheck('DoctorChatMessage fromMap restores conversationId', restored.conversationId == msg.conversationId);
  assertCheck('DoctorChatMessage fromMap restores isPatient', restored.isPatient == true);
  assertCheck('DoctorChatMessage fromMap restores hasAttachment', restored.hasAttachment == true);
  assertCheck('DoctorChatMessage fromMap restores isEmergencyWarning', restored.isEmergencyWarning == true);

  assertCheck('ChatSenderType contains ai', ChatSenderType.values.contains(ChatSenderType.ai));
  final aiMsg = DoctorChatMessage(
    id: 'msg_ai_01',
    senderType: ChatSenderType.ai,
    content: 'AI Doctor response',
    timestamp: DateTime.now(),
  );
  assertCheck('DoctorChatMessage isAi getter works', aiMsg.isAi && !aiMsg.isDoctor);

  final qItem = ConversationQueueItem(
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
  final qMap = qItem.toMap();
  final qRestored = ConversationQueueItem.fromMap(qMap);
  assertCheck('ConversationQueueItem restores unreadCount', qRestored.unreadCount == 3);
  assertCheck('ConversationQueueItem restores patientName', qRestored.patientName == 'Lê Hoàng');

  // ---------------------------------------------------------------------------
  // GROUP 2: In-Memory Stream Reactivity & 2-Way Messaging
  // ---------------------------------------------------------------------------
  print('\nGroup 2: In-Memory Stream Reactivity & 2-Way Messaging');
  service.resetToDefaultSeed();

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
  assertCheck('Patient message emitted on stream', streamData != null && streamData!.last.isPatient);
  assertCheck('Patient message content matches', streamData!.last.content.contains('chạm vào pô xe máy'));

  await service.sendMessage(
    conversationId: 'conv_test_2way',
    senderType: 'doctor',
    senderId: 'doc_an_nguyen',
    senderName: 'BS. CKI Nguyễn Văn An',
    content: 'Bạn hãy ngâm tay dưới vòi nước mát sạch ngay trong 15-20 phút nhé!',
  );
  await Future.delayed(const Duration(milliseconds: 20));
  assertCheck('Doctor message emitted on stream', streamData != null && streamData!.last.isDoctor);
  assertCheck('Doctor message content matches', streamData!.last.content.contains('ngâm tay dưới vòi nước mát'));
  await sub.cancel();

  // ---------------------------------------------------------------------------
  // GROUP 3: Image & Attachment Handling
  // ---------------------------------------------------------------------------
  print('\nGroup 3: Image & Attachment Handling');
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
  final storedAttach = service.getStoredMessages('conv_attach_test');
  assertCheck('Attachment stored with bytes', storedAttach.last.attachment != null);
  assertCheck('Attachment hasImage is true', storedAttach.last.hasAttachment);

  await service.sendMessage(
    conversationId: 'conv_url_test',
    senderType: 'patient',
    senderId: 'pat_03',
    content: 'Ảnh vết rách',
    attachmentUrl: 'https://supabase.co/storage/v1/object/public/wounds/cut.jpg',
    attachmentType: 'image',
  );
  final storedUrl = service.getStoredMessages('conv_url_test');
  assertCheck('AttachmentUrl stored accurately', storedUrl.last.attachmentUrl!.contains('cut.jpg'));

  // ---------------------------------------------------------------------------
  // GROUP 4: Message Delivery Status Transitions
  // ---------------------------------------------------------------------------
  print('\nGroup 4: Message Delivery Status Transitions');
  final msgStatus = await service.sendMessage(
    conversationId: 'conv_status_progression',
    senderType: 'patient',
    senderId: 'pat_04',
    content: 'Kiểm tra trạng thái',
  );
  assertCheck('Initial status is sent', msgStatus.status == MessageDeliveryStatus.sent);

  service.updateDeliveryStatus('conv_status_progression', msgStatus.id, MessageDeliveryStatus.delivered);
  assertCheck('Updated to delivered', service.getStoredMessages('conv_status_progression').last.status == MessageDeliveryStatus.delivered);

  service.updateDeliveryStatus('conv_status_progression', msgStatus.id, MessageDeliveryStatus.read);
  assertCheck('Updated to read', service.getStoredMessages('conv_status_progression').last.status == MessageDeliveryStatus.read);

  // ---------------------------------------------------------------------------
  // GROUP 5: Doctor Portal Queue & Unread Notification System
  // ---------------------------------------------------------------------------
  print('\nGroup 5: Doctor Portal Queue & Unread Notification System');
  service.currentViewingConversationId = 'other_conv';
  await service.sendMessage(
    conversationId: 'conv_unread_test',
    senderType: 'patient',
    senderId: 'pat_05',
    content: 'Bác sĩ kiểm tra giúp tôi với',
  );
  assertCheck('Unread increments for inactive conversation', service.getUnreadCount('conv_unread_test') == 1);

  service.currentViewingConversationId = 'conv_active_view';
  await service.sendMessage(
    conversationId: 'conv_active_view',
    senderType: 'patient',
    senderId: 'pat_06',
    content: 'Đang xem trực tiếp',
  );
  assertCheck('Unread silenced for active viewing conversation', service.getUnreadCount('conv_active_view') == 0);

  service.currentViewingConversationId = 'conv_viewing_a';
  String? alertReceived;
  final alertSub = service.bannerAlertStream.listen((alert) => alertReceived = alert);

  await service.sendMessage(
    conversationId: 'conv_viewing_b',
    senderType: 'patient',
    senderId: 'pat_alert',
    patientName: 'Bệnh nhân Mai',
    content: 'Khẩn cấp bác sĩ ơi!',
  );
  await Future.delayed(const Duration(milliseconds: 20));
  assertCheck('Banner alert received for inactive conversation', alertReceived != null && alertReceived!.contains('Bệnh nhân Mai'));
  await alertSub.cancel();

  service.currentViewingConversationId = 'none';
  await service.sendMessage(
    conversationId: 'conv_mark_read_test',
    senderType: 'patient',
    senderId: 'pat_07',
    content: 'Tin nhắn chưa đọc',
  );
  assertCheck('Unread count is 1 before mark read', service.getUnreadCount('conv_mark_read_test') == 1);
  await service.markMessagesAsRead('conv_mark_read_test');
  assertCheck('Unread count resets to 0 after mark read', service.getUnreadCount('conv_mark_read_test') == 0);
  assertCheck('Messages marked as read', service.getStoredMessages('conv_mark_read_test').last.status == MessageDeliveryStatus.read);

  await service.sendMessage(conversationId: 'conv_order_1', senderType: 'patient', senderId: 'p1', content: 'Msg 1');
  await service.sendMessage(conversationId: 'conv_order_2', senderType: 'patient', senderId: 'p2', content: 'Msg 2');
  assertCheck('Queue orders most recent at top', service.queue.first.conversationId == 'conv_order_2');
  await service.sendMessage(conversationId: 'conv_order_1', senderType: 'patient', senderId: 'p1', content: 'Msg 1 New');
  assertCheck('Queue re-orders on new message', service.queue.first.conversationId == 'conv_order_1');

  // ---------------------------------------------------------------------------
  // GROUP 6: Dual-Mode Fail-Safe Offline Resilience
  // ---------------------------------------------------------------------------
  print('\nGroup 6: Dual-Mode Fail-Safe Offline Resilience');
  assertCheck('Seed conversations exist offline', service.getStoredMessages('conv_an_nguyen_01').isNotEmpty);
  final offlineMsg = await service.sendMessage(
    conversationId: 'conv_offline_test',
    senderType: 'patient',
    senderId: 'pat_offline',
    content: 'Hoàn toàn offline nhưng mượt mà',
  );
  assertCheck('Offline message sent smoothly', offlineMsg.content.contains('offline nhưng mượt mà'));
  final doctorConvs = await service.getDoctorConversations('doc_an_nguyen');
  assertCheck('Doctor conversations retrieved offline', doctorConvs.isNotEmpty);

  print('\n===============================================================');
  print('ALL $testsPassed OF $totalTests SPECS PASSED (100% SUCCESS)');
  print('===============================================================');
}
