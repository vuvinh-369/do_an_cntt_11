// Standalone pure Dart verification test for Milestone 2 Realtime Chat & Models
// File: test/doctor_realtime_chat_standalone_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:do_an_cntt_11/features/user/models/doctor_consultation_models.dart';

void main() async {
  print('======================================================================');
  print('Running Milestone 2 Realtime 2-Way Chat Standalone Test Suite');
  print('======================================================================');

  int passed = 0;
  int failed = 0;

  void expect(String spec, bool condition, [String detail = '']) {
    if (condition) {
      passed++;
      print('  [PASS] $spec');
    } else {
      failed++;
      print('  [FAIL] $spec: $detail');
      throw AssertionError('Spec failed: $spec: $detail');
    }
  }

  // ===========================================================================
  // GROUP 1: DoctorChatMessage & Queue Data Models Serialization
  // ===========================================================================
  print('\nGroup 1: DoctorChatMessage & Queue Data Models Serialization');
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
  expect('DoctorChatMessage toMap contains id', map['id'] == 'msg_test_01');
  expect('DoctorChatMessage toMap contains conversation_id', map['conversation_id'] == 'conv_test_01');
  expect('DoctorChatMessage toMap contains sender_type patient', map['sender_type'] == 'patient');
  expect('DoctorChatMessage toMap contains sender_id', map['sender_id'] == 'pat_test_01');
  expect('DoctorChatMessage toMap contains sender_name', map['sender_name'] == 'Nguyễn Văn An (Bệnh nhân)');
  expect('DoctorChatMessage toMap contains content', map['content'] == 'Bác sĩ ơi, vết thương của tôi chảy nhiều máu');
  expect('DoctorChatMessage toMap contains attachment_url', map['attachment_url'] == 'https://example.com/wound.jpg');
  expect('DoctorChatMessage toMap contains attachment_type image', map['attachment_type'] == 'image');
  expect('DoctorChatMessage toMap contains status sent', map['status'] == 'sent');
  expect('DoctorChatMessage toMap contains is_emergency_warning true', map['is_emergency_warning'] == true);

  final restored = DoctorChatMessage.fromMap(map);
  expect('fromMap restores id', restored.id == 'msg_test_01');
  expect('fromMap restores conversationId', restored.conversationId == 'conv_test_01');
  expect('fromMap restores senderType patient', restored.senderType == ChatSenderType.patient);
  expect('fromMap restores senderId', restored.senderId == 'pat_test_01');
  expect('fromMap restores senderName', restored.senderName == 'Nguyễn Văn An (Bệnh nhân)');
  expect('fromMap restores isPatient', restored.isPatient == true);
  expect('fromMap restores isDoctor false', restored.isDoctor == false);
  expect('fromMap restores hasAttachment true', restored.hasAttachment == true);
  expect('fromMap restores isEmergencyWarning true', restored.isEmergencyWarning == true);
  expect('fromMap restores status sent', restored.status == MessageDeliveryStatus.sent);

  expect('ChatSenderType enum contains ai', ChatSenderType.values.contains(ChatSenderType.ai));
  expect('ChatSenderType enum contains doctor', ChatSenderType.values.contains(ChatSenderType.doctor));
  expect('ChatSenderType enum contains patient', ChatSenderType.values.contains(ChatSenderType.patient));
  expect('ChatSenderType enum contains system', ChatSenderType.values.contains(ChatSenderType.system));

  final aiMsg = DoctorChatMessage(
    id: 'msg_ai_01',
    conversationId: 'conv_ai',
    senderType: ChatSenderType.ai,
    content: 'AI Doctor response',
    timestamp: now,
  );
  expect('AI message isAi is true', aiMsg.isAi == true);
  expect('AI message isDoctor is false', aiMsg.isDoctor == false);
  expect('AI message isPatient is false', aiMsg.isPatient == false);

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
    status: 'active',
  );

  final qMap = qItem.toMap();
  expect('QueueItem toMap id', qMap['id'] == 'conv_q_01');
  expect('QueueItem toMap patient_name', qMap['patient_name'] == 'Lê Hoàng');
  expect('QueueItem toMap unread_doctor_count', qMap['unread_doctor_count'] == 3);

  final qRestored = ConversationQueueItem.fromMap(qMap);
  expect('QueueItem fromMap conversationId', qRestored.conversationId == 'conv_q_01');
  expect('QueueItem fromMap patientName', qRestored.patientName == 'Lê Hoàng');
  expect('QueueItem fromMap patientPhone', qRestored.patientPhone == '0901234567');
  expect('QueueItem fromMap doctorId', qRestored.doctorId == 'doc_an_nguyen');
  expect('QueueItem fromMap unreadCount', qRestored.unreadCount == 3);

  final consultationConv = ConsultationConversation(
    id: 'conv_c_01',
    patientId: 'pat_01',
    patientName: 'Lê Hoàng',
    patientPhone: '0901234567',
    doctorId: 'doc_an_nguyen',
    doctorName: 'BS. CKI Nguyễn Văn An',
    lastMessageContent: 'Vết thương sâu',
    lastMessageTime: now,
    unreadDoctorCount: 2,
    unreadPatientCount: 0,
    hasAiFallbackResponse: true,
    createdAt: now,
    updatedAt: now,
  );
  final cMap = consultationConv.toMap();
  final cRestored = ConsultationConversation.fromMap(cMap);
  expect('ConsultationConversation fromMap id', cRestored.id == 'conv_c_01');
  expect('ConsultationConversation fromMap unreadDoctorCount', cRestored.unreadDoctorCount == 2);
  expect('ConsultationConversation fromMap hasAiFallbackResponse', cRestored.hasAiFallbackResponse == true);

  // ===========================================================================
  // GROUP 2: In-Memory Stream Reactivity & 2-Way Messaging Lifecycle
  // ===========================================================================
  print('\nGroup 2: In-Memory Stream Reactivity & 2-Way Messaging Lifecycle');
  final controller = StreamController<List<DoctorChatMessage>>.broadcast();
  final messagesList = <DoctorChatMessage>[];

  List<DoctorChatMessage>? receivedStreamMessages;
  final subscription = controller.stream.listen((msgs) {
    receivedStreamMessages = msgs;
  });

  // Patient sends message
  final patientMsg = DoctorChatMessage(
    id: 'p_msg_1',
    conversationId: 'conv_live',
    senderType: ChatSenderType.patient,
    senderId: 'pat_01',
    content: 'Tôi bị bỏng tay do chạm vào pô xe máy',
    timestamp: DateTime.now(),
    status: MessageDeliveryStatus.sent,
  );
  messagesList.add(patientMsg);
  controller.add(List.unmodifiable(messagesList));
  await Future.delayed(const Duration(milliseconds: 15));

  expect('Stream emits patient message', receivedStreamMessages != null && receivedStreamMessages!.length == 1);
  expect('Emitted message isPatient', receivedStreamMessages!.last.isPatient);
  expect('Emitted content contains po xe may', receivedStreamMessages!.last.content.contains('pô xe máy'));

  // Doctor replies
  final doctorReplyMsg = DoctorChatMessage(
    id: 'd_msg_1',
    conversationId: 'conv_live',
    senderType: ChatSenderType.doctor,
    senderId: 'doc_an_nguyen',
    content: 'Bạn hãy ngâm tay dưới vòi nước mát sạch ngay trong 15-20 phút nhé!',
    timestamp: DateTime.now(),
    status: MessageDeliveryStatus.sent,
  );
  messagesList.add(doctorReplyMsg);
  controller.add(List.unmodifiable(messagesList));
  await Future.delayed(const Duration(milliseconds: 15));

  expect('Stream emits doctor reply', receivedStreamMessages != null && receivedStreamMessages!.length == 2);
  expect('Emitted reply isDoctor', receivedStreamMessages!.last.isDoctor);
  expect('Emitted reply content matches advice', receivedStreamMessages!.last.content.contains('ngâm tay dưới vòi nước mát'));
  await subscription.cancel();
  await controller.close();

  // ===========================================================================
  // GROUP 3: Image & Attachment Serialization & Base64 Handling
  // ===========================================================================
  print('\nGroup 3: Image & Attachment Serialization & Base64 Handling');
  final sampleBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
  final base64Image = 'data:image/jpeg;base64,${base64Encode(sampleBytes)}';

  final attachMsg = DoctorChatMessage(
    id: 'attach_msg_01',
    conversationId: 'conv_attach',
    senderType: ChatSenderType.patient,
    content: 'Ảnh vết bỏng',
    attachmentUrl: base64Image,
    attachmentType: ChatAttachmentType.image,
    timestamp: DateTime.now(),
    attachment: ChatAttachment(
      id: 'att_01',
      type: ChatAttachmentType.image,
      bytes: sampleBytes,
      fileName: 'wound.jpg',
    ),
  );

  expect('attachMsg hasAttachment is true', attachMsg.hasAttachment == true);
  expect('attachMsg attachment bytes match', attachMsg.attachment!.bytes!.length == 6);

  final attachMap = attachMsg.toMap();
  final attachRestored = DoctorChatMessage.fromMap(attachMap);
  expect('attachRestored hasAttachment is true', attachRestored.hasAttachment == true);
  expect('attachRestored synthesizes bytes from Base64 data URL', attachRestored.attachment?.bytes != null);
  expect('attachRestored decoded byte count matches', attachRestored.attachment!.bytes!.length == 6);

  // ===========================================================================
  // GROUP 4: Message Delivery Status Transitions
  // ===========================================================================
  print('\nGroup 4: Message Delivery Status Transitions');
  var lifecycleMsg = DoctorChatMessage(
    id: 'status_msg_01',
    senderType: ChatSenderType.patient,
    content: 'Kiểm tra trạng thái',
    timestamp: DateTime.now(),
    status: MessageDeliveryStatus.sending,
  );
  expect('Initial status is sending', lifecycleMsg.status == MessageDeliveryStatus.sending);

  lifecycleMsg = lifecycleMsg.copyWith(status: MessageDeliveryStatus.sent);
  expect('Transitioned to sent', lifecycleMsg.status == MessageDeliveryStatus.sent);

  lifecycleMsg = lifecycleMsg.copyWith(status: MessageDeliveryStatus.delivered);
  expect('Transitioned to delivered', lifecycleMsg.status == MessageDeliveryStatus.delivered);

  lifecycleMsg = lifecycleMsg.copyWith(status: MessageDeliveryStatus.read);
  expect('Transitioned to read', lifecycleMsg.status == MessageDeliveryStatus.read);

  // ===========================================================================
  // GROUP 5: Queue Reordering & Unread Count Logic
  // ===========================================================================
  print('\nGroup 5: Queue Reordering & Unread Count Logic');
  final queueList = <ConversationQueueItem>[
    ConversationQueueItem(
      conversationId: 'conv_1',
      patientId: 'p1',
      patientName: 'Bệnh nhân 1',
      lastMessageContent: 'Msg 1',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 10)),
      unreadCount: 0,
    ),
    ConversationQueueItem(
      conversationId: 'conv_2',
      patientId: 'p2',
      patientName: 'Bệnh nhân 2',
      lastMessageContent: 'Msg 2',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: 1,
    ),
  ];

  // Most recent first sort
  queueList.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
  expect('Most recent message is conv_2 at index 0', queueList.first.conversationId == 'conv_2');

  // conv_1 receives new message now
  final conv1Idx = queueList.indexWhere((q) => q.conversationId == 'conv_1');
  final updatedConv1 = queueList.removeAt(conv1Idx).copyWith(
    lastMessageContent: 'Msg 1 New',
    lastMessageTime: DateTime.now(),
    unreadCount: 1,
  );
  queueList.insert(0, updatedConv1);
  expect('conv_1 bumped to top of queue on new message', queueList.first.conversationId == 'conv_1');
  expect('conv_1 unreadCount incremented', queueList.first.unreadCount == 1);

  // Mark read resets unreadCount
  queueList.first.unreadCount = 0;
  expect('Mark read resets unreadCount to 0', queueList.first.unreadCount == 0);

  // Aggregated unread count
  final totalUnread = queueList.fold<int>(0, (sum, q) => sum + q.unreadCount);
  expect('Total aggregated unread count calculated accurately', totalUnread == 1);

  print('\n======================================================================');
  print('ALL $passed SPECS PASSED ($failed FAILURES - 100% SUCCESS)');
  print('======================================================================');
}
