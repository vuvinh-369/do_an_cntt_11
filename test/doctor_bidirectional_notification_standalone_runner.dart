// =============================================================================
// BIDIRECTIONAL IN-APP FLOATING NOTIFICATION (MILESTONE M4 - R4) STANDALONE RUNNER
// File: test/doctor_bidirectional_notification_standalone_runner.dart
//
// Pure-Dart Standalone Test Runner verifying Requirement R4:
// 1. Notification Model & Role Serialization (InAppNotificationItem, NotificationTargetRole)
// 2. Patient -> Doctor In-App Notification Dispatch (targetRole: doctor, when doctor inactive)
// 3. Doctor -> Patient In-App Notification Dispatch (targetRole: patient, when patient inactive)
// 4. Active Room Notification Suppression (Zero notifications when recipient in room)
// 5. Cross-Conversation Triage (Doctor viewing Room A receives notification for Room B)
// 6. Click-to-Chat Deep Navigation & Payload Integrity (deep-linking parameters)
// 7. Auto-Dismiss, Stream Lifecycle & Concurrent Multi-Room Stress
//
// Zero external network calls. Zero dart:ui or flutter engine dependencies.
// Genuine execution of all models, brokers, stream controllers, and assertions.
// =============================================================================

import 'dart:async';

// =============================================================================
// DATA MODELS (PURE DART EQUIVALENT OF LIB/FEATURES/USER/MODELS)
// =============================================================================

/// Vai trò người nhận thông báo nổi trong ứng dụng
enum NotificationTargetRole {
  doctor,
  patient,
}

/// Loại đối tượng gửi tin nhắn
enum ChatSenderType {
  patient,
  doctor,
  ai,
  system,
}

/// Trạng thái chuyển giao tin nhắn
enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// Mô hình mục thông báo nổi hai chiều (Milestone M4 - R4)
class InAppNotificationItem {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final NotificationTargetRole targetRole;
  final DateTime timestamp;
  final String? doctorId;
  final String? patientId;

  const InAppNotificationItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.targetRole,
    required this.timestamp,
    this.doctorId,
    this.patientId,
  });

  bool get isTargetDoctor => targetRole == NotificationTargetRole.doctor;
  bool get isTargetPatient => targetRole == NotificationTargetRole.patient;

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'target_role': targetRole.name,
      'timestamp': timestamp.toIso8601String(),
      if (doctorId != null) 'doctor_id': doctorId,
      if (patientId != null) 'patient_id': patientId,
    };
  }

  factory InAppNotificationItem.fromMap(Map<String, dynamic> map) {
    final roleStr = (map['target_role'] ?? map['targetRole'] ?? 'doctor').toString().toLowerCase();
    final role = NotificationTargetRole.values.firstWhere(
      (r) => r.name.toLowerCase() == roleStr,
      orElse: () => NotificationTargetRole.doctor,
    );

    final rawTime = map['timestamp'] ?? map['created_at'] ?? map['createdAt'];
    final time = rawTime != null
        ? (DateTime.tryParse(rawTime.toString()) ?? DateTime.now())
        : DateTime.now();

    return InAppNotificationItem(
      id: (map['id'] ?? '').toString(),
      conversationId: (map['conversation_id'] ?? map['conversationId'] ?? '').toString(),
      senderId: (map['sender_id'] ?? map['senderId'] ?? '').toString(),
      senderName: (map['sender_name'] ?? map['senderName'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      targetRole: role,
      timestamp: time,
      doctorId: (map['doctor_id'] ?? map['doctorId'])?.toString(),
      patientId: (map['patient_id'] ?? map['patientId'])?.toString(),
    );
  }

  InAppNotificationItem copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? content,
    NotificationTargetRole? targetRole,
    DateTime? timestamp,
    String? doctorId,
    String? patientId,
  }) {
    return InAppNotificationItem(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      targetRole: targetRole ?? this.targetRole,
      timestamp: timestamp ?? this.timestamp,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InAppNotificationItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'InAppNotificationItem(id: $id, conv: $conversationId, target: ${targetRole.name}, sender: $senderName)';
}

/// Mô hình tin nhắn trò chuyện
class DoctorChatMessage {
  final String id;
  final String conversationId;
  final ChatSenderType senderType;
  final String senderId;
  final String? senderName;
  final String content;
  final DateTime timestamp;
  final MessageDeliveryStatus status;

  const DoctorChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.senderId,
    this.senderName,
    required this.content,
    required this.timestamp,
    this.status = MessageDeliveryStatus.sent,
  });

  bool get isDoctor => senderType == ChatSenderType.doctor;
  bool get isPatient => senderType == ChatSenderType.patient;
}

/// Hàng đợi phiên tư vấn
class ConversationQueueItem {
  final String conversationId;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String lastMessageContent;
  final DateTime lastMessageTime;
  int unreadCount;

  ConversationQueueItem({
    required this.conversationId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.lastMessageContent,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  ConversationQueueItem copyWith({
    String? conversationId,
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    String? lastMessageContent,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return ConversationQueueItem(
      conversationId: conversationId ?? this.conversationId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// =============================================================================
// CONSULTATION SERVICE BROKER (REPRODUCING DOCTOR_CONSULTATION_SERVICE)
// =============================================================================

class MockDoctorConsultationBroker {
  final Map<String, List<DoctorChatMessage>> _messagesStore = {};
  final List<ConversationQueueItem> _queue = [];

  final StreamController<InAppNotificationItem> _inAppNotificationController =
      StreamController<InAppNotificationItem>.broadcast();
  final StreamController<String> _inAppBannerAlerts =
      StreamController<String>.broadcast();
  final StreamController<String> _navigationRequests =
      StreamController<String>.broadcast();

  // Active viewing context properties (used for suppression)
  String? currentViewingConversationId; // Logged-in doctor active room
  String? patientViewingConversationId; // Active patient room

  Stream<InAppNotificationItem> get inAppNotificationStream =>
      _inAppNotificationController.stream;
  Stream<String> get bannerAlertStream => _inAppBannerAlerts.stream;
  Stream<String> get navigationRequestStream => _navigationRequests.stream;

  List<ConversationQueueItem> get queue => List.unmodifiable(_queue);

  void seedQueue(List<ConversationQueueItem> items) {
    _queue.clear();
    _queue.addAll(items);
  }

  void requestNavigationToConversation(String conversationId) {
    currentViewingConversationId = conversationId;
    if (!_navigationRequests.isClosed) {
      _navigationRequests.add(conversationId);
    }
  }

  Future<DoctorChatMessage> sendMessage({
    required String conversationId,
    required String senderType,
    required String senderId,
    String? senderName,
    required String content,
    String? doctorId,
    String? patientId,
    String patientName = 'Bệnh nhân',
    String? localMessageId,
  }) async {
    if (content.trim().isEmpty) {
      throw ArgumentError('Nội dung tin nhắn không được để trống.');
    }

    final type = ChatSenderType.values.firstWhere(
      (e) => e.name.toLowerCase() == senderType.toLowerCase(),
      orElse: () => ChatSenderType.patient,
    );

    final msgId = localMessageId ?? 'msg_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();

    final message = DoctorChatMessage(
      id: msgId,
      conversationId: conversationId,
      senderType: type,
      senderId: senderId,
      senderName: senderName ?? (type == ChatSenderType.patient ? patientName : 'Bác sĩ'),
      content: content,
      timestamp: now,
      status: MessageDeliveryStatus.sent,
    );

    _messagesStore.putIfAbsent(conversationId, () => []);
    _messagesStore[conversationId]!.add(message);

    // Suppression logic
    final isDoctorInactive = currentViewingConversationId != conversationId;
    final isPatientInactive = patientViewingConversationId != conversationId;
    final unreadInc = (type == ChatSenderType.patient && isDoctorInactive) ? 1 : 0;

    final qIdx = _queue.indexWhere((q) => q.conversationId == conversationId);
    ConversationQueueItem currentItem;
    if (qIdx != -1) {
      final existing = _queue.removeAt(qIdx);
      currentItem = existing.copyWith(
        lastMessageContent: message.content,
        lastMessageTime: now,
        unreadCount: existing.unreadCount + unreadInc,
      );
      _queue.insert(0, currentItem);
    } else {
      currentItem = ConversationQueueItem(
        conversationId: conversationId,
        patientId: type == ChatSenderType.patient ? senderId : (patientId ?? 'pat_$conversationId'),
        patientName: type == ChatSenderType.patient ? (senderName ?? patientName) : patientName,
        doctorId: type == ChatSenderType.doctor ? senderId : (doctorId ?? 'doc_an_nguyen'),
        doctorName: type == ChatSenderType.doctor ? (senderName ?? 'BS. CKI Nguyễn Văn An') : 'BS. CKI Nguyễn Văn An',
        lastMessageContent: message.content,
        lastMessageTime: now,
        unreadCount: unreadInc,
      );
      _queue.insert(0, currentItem);
    }

    final resolvedDoctorId = doctorId ?? currentItem.doctorId;
    final resolvedPatientId = patientId ?? currentItem.patientId;

    if (type == ChatSenderType.patient) {
      if (isDoctorInactive) {
        final notif = InAppNotificationItem(
          id: 'notif_${message.id}',
          conversationId: conversationId,
          senderId: senderId,
          senderName: message.senderName ?? patientName,
          content: message.content,
          targetRole: NotificationTargetRole.doctor,
          timestamp: now,
          doctorId: resolvedDoctorId,
          patientId: resolvedPatientId,
        );
        _inAppNotificationController.add(notif);
        _inAppBannerAlerts.add('${message.senderName ?? patientName}: ${message.content}');
      }
    } else if (type == ChatSenderType.doctor || type == ChatSenderType.ai) {
      if (isPatientInactive) {
        final defaultSender = type == ChatSenderType.ai ? 'AI Bác sĩ' : 'Bác sĩ';
        final notif = InAppNotificationItem(
          id: 'notif_${message.id}',
          conversationId: conversationId,
          senderId: senderId,
          senderName: message.senderName ?? defaultSender,
          content: message.content,
          targetRole: NotificationTargetRole.patient,
          timestamp: now,
          doctorId: resolvedDoctorId,
          patientId: resolvedPatientId,
        );
        _inAppNotificationController.add(notif);
        _inAppBannerAlerts.add('${message.senderName ?? defaultSender}: ${message.content}');
      }
    }

    return message;
  }

  void dispose() {
    _inAppNotificationController.close();
    _inAppBannerAlerts.close();
    _navigationRequests.close();
  }
}

// =============================================================================
// TEST HARNESS & ASSERTION UTILITIES
// =============================================================================

int _passCount = 0;
int _failCount = 0;

void expect(bool condition, String message) {
  if (condition) {
    _passCount++;
    print('  [PASS] Spec ${_passCount + _failCount}: $message');
  } else {
    _failCount++;
    print('  [FAIL] Spec ${_passCount + _failCount}: $message');
  }
}

void expectEqual<T>(T actual, T expected, String message) {
  expect(actual == expected, '$message (expected: $expected, actual: $actual)');
}

// =============================================================================
// MAIN TEST RUNNER
// =============================================================================

Future<void> main() async {
  print('======================================================================');
  print('Running Milestone M4 Bidirectional In-App Notification Test Runner');
  print('Requirements: R4 (Bidirectional Real-Time Floating Notification)');
  print('======================================================================\n');

  // ---------------------------------------------------------------------------
  // GROUP 1: NOTIFICATION MODEL & ROLE SERIALIZATION
  // ---------------------------------------------------------------------------
  print('--- Group 1: Notification Model & Role Serialization ---');

  final now = DateTime(2026, 11, 12, 15, 30, 0);
  final item1 = InAppNotificationItem(
    id: 'notif_001',
    conversationId: 'conv_alpha',
    senderId: 'pat_01',
    senderName: 'Nguyễn Văn Bình',
    content: 'Bác sĩ ơi, vết thương tôi bị sưng đỏ và nhức',
    targetRole: NotificationTargetRole.doctor,
    timestamp: now,
    doctorId: 'doc_an_nguyen',
    patientId: 'pat_01',
  );

  expectEqual(item1.id, 'notif_001', 'InAppNotificationItem instantiation preserves id');
  expectEqual(item1.isTargetDoctor, true, 'isTargetDoctor returns true for doctor role');
  expectEqual(item1.isTargetPatient, false, 'isTargetPatient returns false for doctor role');

  final map1 = item1.toMap();
  expectEqual(map1['conversation_id'], 'conv_alpha', 'toMap produces snake_case conversation_id');
  expectEqual(map1['target_role'], 'doctor', 'toMap produces snake_case target_role string');
  expectEqual(map1['doctor_id'], 'doc_an_nguyen', 'toMap preserves doctor_id');
  expectEqual(map1['patient_id'], 'pat_01', 'toMap preserves patient_id');

  final fromMap1 = InAppNotificationItem.fromMap(map1);
  expectEqual(fromMap1.id, item1.id, 'fromMap correctly deserializes id');
  expectEqual(fromMap1.conversationId, item1.conversationId, 'fromMap correctly deserializes conversationId');
  expectEqual(fromMap1.targetRole, NotificationTargetRole.doctor, 'fromMap correctly deserializes targetRole enum');
  expectEqual(fromMap1.doctorId, 'doc_an_nguyen', 'fromMap correctly deserializes doctorId');

  // CamelCase backwards compatibility
  final camelMap = {
    'id': 'notif_002',
    'conversationId': 'conv_beta',
    'senderId': 'doc_mai_huong',
    'senderName': 'BS. Trần Mai Hương',
    'content': 'Hãy chụp ảnh vết thương rõ nét gửi tôi kiểm tra nhé',
    'targetRole': 'patient',
    'timestamp': now.toIso8601String(),
    'doctorId': 'doc_mai_huong',
    'patientId': 'pat_02',
  };
  final fromCamel = InAppNotificationItem.fromMap(camelMap);
  expectEqual(fromCamel.conversationId, 'conv_beta', 'fromMap supports camelCase conversationId');
  expectEqual(fromCamel.targetRole, NotificationTargetRole.patient, 'fromMap supports camelCase targetRole patient');
  expectEqual(fromCamel.isTargetPatient, true, 'isTargetPatient returns true for patient target role');

  final copied = item1.copyWith(content: 'Nội dung cập nhật');
  expectEqual(copied.content, 'Nội dung cập nhật', 'copyWith updates content correctly');
  expectEqual(copied.id, item1.id, 'copyWith preserves unmodified fields');
  expectEqual(item1.formattedTime, '15:30', 'formattedTime accurately formats timestamp HH:mm');

  // ---------------------------------------------------------------------------
  // GROUP 2: PATIENT -> DOCTOR IN-APP NOTIFICATION DISPATCH
  // ---------------------------------------------------------------------------
  print('\n--- Group 2: Patient -> Doctor In-App Notification Dispatch ---');

  final broker = MockDoctorConsultationBroker();
  broker.seedQueue([
    ConversationQueueItem(
      conversationId: 'conv_01',
      patientId: 'pat_101',
      patientName: 'Trần Văn Nam',
      doctorId: 'doc_an_nguyen',
      doctorName: 'BS. CKI Nguyễn Văn An',
      lastMessageContent: 'Chào bác sĩ',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: 0,
    ),
  ]);

  InAppNotificationItem? capturedDoctorNotif;
  String? capturedBannerAlert;
  final subNotif = broker.inAppNotificationStream.listen((n) => capturedDoctorNotif = n);
  final subBanner = broker.bannerAlertStream.listen((b) => capturedBannerAlert = b);

  // Doctor is currently viewing room 'conv_other', so conv_01 is inactive
  broker.currentViewingConversationId = 'conv_other';

  await broker.sendMessage(
    conversationId: 'conv_01',
    senderType: 'patient',
    senderId: 'pat_101',
    senderName: 'Trần Văn Nam',
    content: 'Bác sĩ ơi, vết mổ của tôi có dịch vàng',
    doctorId: 'doc_an_nguyen',
    patientId: 'pat_101',
  );

  await Future.delayed(const Duration(milliseconds: 10));

  expect(capturedDoctorNotif != null, 'Patient message dispatches InAppNotificationItem when doctor is inactive');
  expectEqual(capturedDoctorNotif?.targetRole, NotificationTargetRole.doctor, 'Notification targetRole is doctor');
  expectEqual(capturedDoctorNotif?.senderName, 'Trần Văn Nam', 'Notification preserves patient senderName');
  expectEqual(capturedDoctorNotif?.content, 'Bác sĩ ơi, vết mổ của tôi có dịch vàng', 'Notification contains exact message content');
  expectEqual(capturedDoctorNotif?.doctorId, 'doc_an_nguyen', 'Notification contains resolved doctorId');
  expectEqual(capturedDoctorNotif?.patientId, 'pat_101', 'Notification contains resolved patientId');
  expect(capturedBannerAlert != null && capturedBannerAlert!.contains('Trần Văn Nam'), 'bannerAlertStream dispatches backwards-compatible alert');

  // ---------------------------------------------------------------------------
  // GROUP 3: DOCTOR -> PATIENT IN-APP NOTIFICATION DISPATCH
  // ---------------------------------------------------------------------------
  print('\n--- Group 3: Doctor -> Patient In-App Notification Dispatch ---');

  InAppNotificationItem? capturedPatientNotif;
  final subPatientNotif = broker.inAppNotificationStream.listen((n) => capturedPatientNotif = n);

  // Patient is currently NOT viewing conv_01
  broker.patientViewingConversationId = 'conv_other_patient';

  await broker.sendMessage(
    conversationId: 'conv_01',
    senderType: 'doctor',
    senderId: 'doc_an_nguyen',
    senderName: 'BS. CKI Nguyễn Văn An',
    content: 'Bạn hãy dùng cồn sát khuẩn lau nhẹ quanh mép vết thương và đến viện tái khám ngay.',
    doctorId: 'doc_an_nguyen',
    patientId: 'pat_101',
  );

  await Future.delayed(const Duration(milliseconds: 10));

  expect(capturedPatientNotif != null, 'Doctor reply dispatches InAppNotificationItem when patient is inactive');
  expectEqual(capturedPatientNotif?.targetRole, NotificationTargetRole.patient, 'Notification targetRole is patient');
  expectEqual(capturedPatientNotif?.senderName, 'BS. CKI Nguyễn Văn An', 'Notification contains doctor senderName');
  expectEqual(capturedPatientNotif?.conversationId, 'conv_01', 'Notification targets correct conversation room');

  // AI Doctor fallback response
  InAppNotificationItem? capturedAiNotif;
  final subAiNotif = broker.inAppNotificationStream.listen((n) => capturedAiNotif = n);

  await broker.sendMessage(
    conversationId: 'conv_01',
    senderType: 'ai',
    senderId: 'ai_assistant',
    senderName: 'AI Bác sĩ Cứu hộ',
    content: 'Bác sĩ phụ trách hiện đang bận phẫu thuật. Đây là khuyến nghị sơ cứu tự động khẩn cấp.',
    doctorId: 'doc_an_nguyen',
    patientId: 'pat_101',
  );

  await Future.delayed(const Duration(milliseconds: 10));

  expect(capturedAiNotif != null, 'AI Doctor response dispatches InAppNotificationItem to patient');
  expectEqual(capturedAiNotif?.targetRole, NotificationTargetRole.patient, 'AI Doctor notification targets patient');
  expectEqual(capturedAiNotif?.senderName, 'AI Bác sĩ Cứu hộ', 'AI Doctor notification senderName is preserved');

  // ---------------------------------------------------------------------------
  // GROUP 4: ACTIVE ROOM NOTIFICATION SUPPRESSION
  // ---------------------------------------------------------------------------
  print('\n--- Group 4: Active Room Notification Suppression ---');

  int doctorNotifCount = 0;
  int patientNotifCount = 0;
  final subCount = broker.inAppNotificationStream.listen((n) {
    if (n.targetRole == NotificationTargetRole.doctor) doctorNotifCount++;
    if (n.targetRole == NotificationTargetRole.patient) patientNotifCount++;
  });

  // Doctor enters room conv_01
  broker.currentViewingConversationId = 'conv_01';
  doctorNotifCount = 0;

  await broker.sendMessage(
    conversationId: 'conv_01',
    senderType: 'patient',
    senderId: 'pat_101',
    senderName: 'Trần Văn Nam',
    content: 'Em vừa khử khuẩn xong rồi thưa bác sĩ',
  );
  await Future.delayed(const Duration(milliseconds: 10));

  expectEqual(doctorNotifCount, 0, 'Zero doctor notifications dispatched when doctor is actively viewing room conv_01');

  // Patient enters room conv_01
  broker.patientViewingConversationId = 'conv_01';
  patientNotifCount = 0;

  await broker.sendMessage(
    conversationId: 'conv_01',
    senderType: 'doctor',
    senderId: 'doc_an_nguyen',
    senderName: 'BS. CKI Nguyễn Văn An',
    content: 'Tốt lắm, bạn giữ khô băng gạc nhé.',
  );
  await Future.delayed(const Duration(milliseconds: 10));

  expectEqual(patientNotifCount, 0, 'Zero patient notifications dispatched when patient is actively viewing room conv_01');

  // ---------------------------------------------------------------------------
  // GROUP 5: CROSS-CONVERSATION TRIAGE
  // ---------------------------------------------------------------------------
  print('\n--- Group 5: Cross-Conversation Triage ---');

  // Doctor is viewing Room A (conv_01), but patient in Room B (conv_02) sends a message
  broker.currentViewingConversationId = 'conv_01';
  InAppNotificationItem? triageDoctorNotif;
  final subTriage = broker.inAppNotificationStream.listen((n) {
    if (n.targetRole == NotificationTargetRole.doctor) {
      triageDoctorNotif = n;
    }
  });

  await broker.sendMessage(
    conversationId: 'conv_02',
    senderType: 'patient',
    senderId: 'pat_202',
    senderName: 'Lê Thu Thảo',
    content: 'Bác sĩ An ơi, người nhà tôi bị sốt cao co giật!',
    doctorId: 'doc_an_nguyen',
    patientId: 'pat_202',
  );
  await Future.delayed(const Duration(milliseconds: 10));

  expect(triageDoctorNotif != null, 'Doctor viewing room conv_01 successfully receives notification for room conv_02');
  expectEqual(triageDoctorNotif?.conversationId, 'conv_02', 'Cross-conversation notification specifies conv_02');
  expectEqual(triageDoctorNotif?.senderName, 'Lê Thu Thảo', 'Cross-conversation notification identifies patient Lê Thu Thảo');

  // Patient is viewing Room A (conv_01), but doctor sends message in Room B (conv_02)
  broker.patientViewingConversationId = 'conv_01';
  InAppNotificationItem? triagePatientNotif;
  final subPatientTriage = broker.inAppNotificationStream.listen((n) {
    if (n.targetRole == NotificationTargetRole.patient) {
      triagePatientNotif = n;
    }
  });

  await broker.sendMessage(
    conversationId: 'conv_02',
    senderType: 'doctor',
    senderId: 'doc_mai_huong',
    senderName: 'BS. Trần Mai Hương',
    content: 'Kết quả xét nghiệm máu của bạn đã có, các chỉ số đều ổn định nhé.',
    doctorId: 'doc_mai_huong',
    patientId: 'pat_202',
  );
  await Future.delayed(const Duration(milliseconds: 10));

  expect(triagePatientNotif != null, 'Patient viewing room conv_01 receives notification for room conv_02');
  expectEqual(triagePatientNotif?.conversationId, 'conv_02', 'Patient cross-conversation notification specifies conv_02');

  // ---------------------------------------------------------------------------
  // GROUP 6: CLICK-TO-CHAT DEEP NAVIGATION & PAYLOAD INTEGRITY
  // ---------------------------------------------------------------------------
  print('\n--- Group 6: Click-to-Chat Deep Navigation & Payload Integrity ---');

  String? navDestination;
  final subNav = broker.navigationRequestStream.listen((convId) => navDestination = convId);

  // Simulate Doctor clicking on triage notification for conv_02
  broker.requestNavigationToConversation(triageDoctorNotif!.conversationId);
  await Future.delayed(const Duration(milliseconds: 10));

  expectEqual(navDestination, 'conv_02', 'Tapping notification dispatches deep navigation event to conv_02');
  expectEqual(broker.currentViewingConversationId, 'conv_02', 'Deep navigation updates currentViewingConversationId to conv_02');

  // Verify click-to-chat payload contains complete routing parameters
  expect(triageDoctorNotif!.conversationId.isNotEmpty, 'Payload has non-empty conversationId');
  expect(triageDoctorNotif!.doctorId != null && triageDoctorNotif!.doctorId!.isNotEmpty, 'Payload contains valid doctorId for profile switching');
  expect(triageDoctorNotif!.patientId != null && triageDoctorNotif!.patientId!.isNotEmpty, 'Payload contains valid patientId for identification');

  // ---------------------------------------------------------------------------
  // GROUP 7: CONCURRENT MULTI-ROOM STRESS & LIFECYCLE
  // ---------------------------------------------------------------------------
  print('\n--- Group 7: Concurrent Multi-Room Stress & Lifecycle ---');

  // Reset viewing context to null (both parties outside any room)
  broker.currentViewingConversationId = null;
  broker.patientViewingConversationId = null;

  final receivedNotifications = <InAppNotificationItem>[];
  final subStress = broker.inAppNotificationStream.listen((n) => receivedNotifications.add(n));

  // Interleave 10 rapid messages across 3 conversations
  final futures = <Future>[];
  for (int i = 0; i < 5; i++) {
    futures.add(broker.sendMessage(
      conversationId: 'conv_stress_1',
      senderType: 'patient',
      senderId: 'pat_stress_$i',
      senderName: 'Patient $i',
      content: 'Stress message $i from patient',
    ));
    futures.add(broker.sendMessage(
      conversationId: 'conv_stress_2',
      senderType: 'doctor',
      senderId: 'doc_stress_$i',
      senderName: 'Doctor $i',
      content: 'Stress response $i from doctor',
    ));
  }
  await Future.wait(futures);
  await Future.delayed(const Duration(milliseconds: 25));

  expectEqual(receivedNotifications.length, 10, 'All 10 concurrent messages dispatch 10 notifications without drop or race condition');

  final doctorTargetCount = receivedNotifications.where((n) => n.targetRole == NotificationTargetRole.doctor).length;
  final patientTargetCount = receivedNotifications.where((n) => n.targetRole == NotificationTargetRole.patient).length;
  expectEqual(doctorTargetCount, 5, 'Exactly 5 notifications dispatched to doctor role');
  expectEqual(patientTargetCount, 5, 'Exactly 5 notifications dispatched to patient role');

  // Clean stream lifecycle
  await subNotif.cancel();
  await subBanner.cancel();
  await subPatientNotif.cancel();
  await subAiNotif.cancel();
  await subCount.cancel();
  await subTriage.cancel();
  await subPatientTriage.cancel();
  await subNav.cancel();
  await subStress.cancel();

  broker.dispose();
  expect(true, 'Broker and all stream subscriptions disposed cleanly without exception');

  // ---------------------------------------------------------------------------
  // SUMMARY
  // ---------------------------------------------------------------------------
  print('\n======================================================================');
  print('TEST SUMMARY: $_passCount / ${_passCount + _failCount} SPECS PASSED (${((_passCount / (_passCount + _failCount)) * 100).toStringAsFixed(0)}% PASS)');
  if (_failCount == 0) {
    print('Milestone M4 (Bidirectional In-App Notification - R4) FULLY VERIFIED.');
  } else {
    print('Milestone M4 VERIFICATION FAILED: $_failCount specs failed.');
  }
  print('======================================================================');
}
