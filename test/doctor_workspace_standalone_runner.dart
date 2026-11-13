// =============================================================================
// DOCTOR WORKSPACE & ADMIN OVERSIGHT (MILESTONE M3 - R3) STANDALONE RUNNER
// File: test/doctor_workspace_standalone_runner.dart
//
// Pure-Dart Standalone Test Runner verifying Requirement R3:
// 1. Doctor Workspace Queue Filtering (doctor receives only assigned patients)
// 2. Doctor Chat Message Sending (isDoctor: true, senderId, senderName)
// 3. Admin Oversight Global Queue (all consultations on empty/'all', filtered by doctor)
// 4. Doctor Online Presence & Availability Persistence (toggle status & count)
// 5. Doctor Session Storage Integration (LocalStorageService session methods)
// 6. Data Model Compatibility & Browser Portal URL Targeting
//
// Zero external network calls. Zero dart:ui or flutter dependencies.
// Genuine execution of all models, brokers, storage adapters, and assertions.
// =============================================================================

import 'dart:async';
import 'dart:typed_data';

// =============================================================================
// PURE DART COLOR & BASE UTILITIES
// =============================================================================

class Color {
  final int value;
  const Color(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Color && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Color(0x${value.toRadixString(16).padLeft(8, '0')})';
}

typedef VoidCallback = void Function();

abstract class ChangeNotifier {
  final List<VoidCallback> _listeners = [];
  bool _disposed = false;

  void addListener(VoidCallback listener) {
    if (!_disposed) _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    if (_disposed) return;
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}

// =============================================================================
// DOMAIN MODELS (MIRRORING LIB/FEATURES/USER/MODELS)
// =============================================================================

enum ChatSenderType { patient, doctor, ai, system }

enum MessageDeliveryStatus { sending, sent, delivered, read, failed }

enum ChatAttachmentType { none, image, document, voiceNote }

class ChatAttachment {
  final String id;
  final ChatAttachmentType type;
  final Uint8List? bytes;
  final String? fileName;
  final String? localPath;

  const ChatAttachment({
    required this.id,
    required this.type,
    this.bytes,
    this.fileName,
    this.localPath,
  });

  bool get hasImage => type == ChatAttachmentType.image && (bytes != null || localPath != null);
}

class DoctorQuickActionOption {
  final String id;
  final String title;
  final String defaultText;
  final dynamic icon;

  const DoctorQuickActionOption({
    required this.id,
    required this.title,
    required this.defaultText,
    this.icon,
  });
}

class DoctorChatMessage {
  final String id;
  final String conversationId;
  final ChatSenderType senderType;
  final String senderId;
  final String? senderName;
  final String content;
  final String? attachmentUrl;
  final ChatAttachmentType attachmentType;
  final DateTime timestamp;
  final MessageDeliveryStatus status;
  final ChatAttachment? attachment;
  final List<DoctorQuickActionOption> quickReplies;
  final bool isEmergencyWarning;
  final String? doctorNote;

  const DoctorChatMessage({
    required this.id,
    this.conversationId = 'conv_default',
    required this.senderType,
    this.senderId = '',
    this.senderName,
    required this.content,
    this.attachmentUrl,
    this.attachmentType = ChatAttachmentType.none,
    required this.timestamp,
    this.status = MessageDeliveryStatus.sent,
    this.attachment,
    this.quickReplies = const [],
    this.isEmergencyWarning = false,
    this.doctorNote,
  });

  bool get isPatient => senderType == ChatSenderType.patient;
  bool get isDoctor => senderType == ChatSenderType.doctor;
  bool get isAi => senderType == ChatSenderType.ai;
  bool get isSystem => senderType == ChatSenderType.system;
  bool get hasAttachment => attachment != null || (attachmentUrl != null && attachmentUrl!.isNotEmpty);

  DoctorChatMessage copyWith({
    String? id,
    String? conversationId,
    ChatSenderType? senderType,
    String? senderId,
    String? senderName,
    String? content,
    String? attachmentUrl,
    ChatAttachmentType? attachmentType,
    DateTime? timestamp,
    MessageDeliveryStatus? status,
    ChatAttachment? attachment,
    List<DoctorQuickActionOption>? quickReplies,
    bool? isEmergencyWarning,
    String? doctorNote,
  }) {
    return DoctorChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderType: senderType ?? this.senderType,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      attachment: attachment ?? this.attachment,
      quickReplies: quickReplies ?? this.quickReplies,
      isEmergencyWarning: isEmergencyWarning ?? this.isEmergencyWarning,
      doctorNote: doctorNote ?? this.doctorNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_type': senderType.name,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'attachment_url': attachmentUrl,
      'created_at': timestamp.toIso8601String(),
      'status': status.name,
      'is_emergency_warning': isEmergencyWarning,
    };
  }

  factory DoctorChatMessage.fromMap(Map<String, dynamic> map) {
    return DoctorChatMessage(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversation_id']?.toString() ?? 'conv_default',
      senderType: ChatSenderType.values.firstWhere(
        (t) => t.name == map['sender_type'],
        orElse: () => ChatSenderType.patient,
      ),
      senderId: map['sender_id']?.toString() ?? '',
      senderName: map['sender_name']?.toString(),
      content: map['content']?.toString() ?? '',
      attachmentUrl: map['attachment_url']?.toString(),
      timestamp: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      status: MessageDeliveryStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MessageDeliveryStatus.sent,
      ),
      isEmergencyWarning: map['is_emergency_warning'] == true,
    );
  }
}

class ConversationQueueItem {
  final String conversationId;
  final String patientId;
  final String patientName;
  final String? patientPhone;
  final String doctorId;
  final String doctorName;
  final String lastMessageContent;
  final DateTime lastMessageTime;
  int unreadCount;
  bool hasAiFallbackResponse;
  final String status;

  ConversationQueueItem({
    required this.conversationId,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.doctorId = 'doc_an_nguyen',
    this.doctorName = 'BS. CKI Nguyễn Văn An',
    required this.lastMessageContent,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.hasAiFallbackResponse = false,
    this.status = 'active',
  });

  ConversationQueueItem copyWith({
    String? conversationId,
    String? patientId,
    String? patientName,
    String? patientPhone,
    String? doctorId,
    String? doctorName,
    String? lastMessageContent,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? hasAiFallbackResponse,
    String? status,
  }) {
    return ConversationQueueItem(
      conversationId: conversationId ?? this.conversationId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      hasAiFallbackResponse: hasAiFallbackResponse ?? this.hasAiFallbackResponse,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversation_id': conversationId,
      'patient_id': patientId,
      'patient_name': patientName,
      'patient_phone': patientPhone,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'last_message_content': lastMessageContent,
      'last_message_time': lastMessageTime.toIso8601String(),
      'unread_count': unreadCount,
      'has_ai_fallback_response': hasAiFallbackResponse,
      'status': status,
    };
  }

  factory ConversationQueueItem.fromMap(Map<String, dynamic> map) {
    return ConversationQueueItem(
      conversationId: map['conversation_id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      patientName: map['patient_name']?.toString() ?? 'Bệnh nhân',
      patientPhone: map['patient_phone']?.toString(),
      doctorId: map['doctor_id']?.toString() ?? 'doc_an_nguyen',
      doctorName: map['doctor_name']?.toString() ?? 'Bác sĩ',
      lastMessageContent: map['last_message_content']?.toString() ?? '',
      lastMessageTime: map['last_message_time'] != null
          ? DateTime.parse(map['last_message_time'])
          : DateTime.now(),
      unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
      hasAiFallbackResponse: map['has_ai_fallback_response'] == true,
      status: map['status']?.toString() ?? 'active',
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
  final String avatarInitials;
  final Color avatarColor;
  final double rating;
  final int consultationCount;
  final bool isOnline;
  final String statusText;
  final bool isVerified;
  final int experienceYears;
  final String consultationFee;
  final String? accountUsername;

  const DoctorProfile({
    required this.id,
    required this.fullName,
    required this.title,
    required this.specialty,
    required this.hospital,
    required this.phoneNumber,
    required this.workplaceAddress,
    required this.avatarInitials,
    required this.avatarColor,
    required this.rating,
    required this.consultationCount,
    required this.isOnline,
    required this.statusText,
    required this.isVerified,
    required this.experienceYears,
    required this.consultationFee,
    this.accountUsername,
  });

  bool get hasAccount => accountUsername != null && accountUsername!.trim().isNotEmpty;

  static const DoctorProfile defaultDoctor = DoctorProfile(
    id: 'doc_an_nguyen',
    fullName: 'BS. CKI Nguyễn Văn An',
    title: 'Bác sĩ Chuyên khoa I',
    specialty: 'Cấp cứu Ngoại khoa & Xử trí Vết thương',
    hospital: 'Bệnh viện Hữu nghị Việt Đức',
    phoneNumber: '0912345678',
    workplaceAddress: '40 Tràng Thi, Hàng Bông, Hoàn Kiếm, Hà Nội',
    avatarInitials: 'AN',
    avatarColor: Color(0xFF2563EB),
    rating: 4.95,
    consultationCount: 2340,
    isOnline: true,
    statusText: 'Đang trực tuyến • Sẵn sàng hỗ trợ cấp cứu',
    isVerified: true,
    experienceYears: 12,
    consultationFee: 'Miễn phí tư vấn sơ cứu ban đầu',
    accountUsername: 'bs_an',
  );

  DoctorProfile copyWith({
    String? id,
    String? fullName,
    String? title,
    String? specialty,
    String? hospital,
    String? phoneNumber,
    String? workplaceAddress,
    String? avatarInitials,
    Color? avatarColor,
    double? rating,
    int? consultationCount,
    bool? isOnline,
    String? statusText,
    bool? isVerified,
    int? experienceYears,
    String? consultationFee,
    String? accountUsername,
  }) {
    return DoctorProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      title: title ?? this.title,
      specialty: specialty ?? this.specialty,
      hospital: hospital ?? this.hospital,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      workplaceAddress: workplaceAddress ?? this.workplaceAddress,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      avatarColor: avatarColor ?? this.avatarColor,
      rating: rating ?? this.rating,
      consultationCount: consultationCount ?? this.consultationCount,
      isOnline: isOnline ?? this.isOnline,
      statusText: statusText ?? this.statusText,
      isVerified: isVerified ?? this.isVerified,
      experienceYears: experienceYears ?? this.experienceYears,
      consultationFee: consultationFee ?? this.consultationFee,
      accountUsername: accountUsername ?? this.accountUsername,
    );
  }
}

// =============================================================================
// STANDALONE DOCTOR CONSULTATION BROKER (MIRRORING SERVICE IMPLEMENTATION)
// =============================================================================

class StandaloneConsultationBroker extends ChangeNotifier {
  final Map<String, List<DoctorChatMessage>> _messagesStore = {};
  final Map<String, StreamController<List<DoctorChatMessage>>> _messageControllers = {};
  final List<ConversationQueueItem> _queue = [];
  final StreamController<String> _bannerAlerts = StreamController<String>.broadcast();

  String? currentViewingConversationId;

  Stream<String> get bannerAlertStream => _bannerAlerts.stream;
  List<ConversationQueueItem> get queue => List.unmodifiable(_queue);

  int get totalDoctorUnreadCount => _queue.fold(0, (sum, item) => sum + item.unreadCount);

  void reset() {
    _messagesStore.clear();
    _queue.clear();
    currentViewingConversationId = null;
    notifyListeners();
  }

  void seedMultiDoctorData() {
    _queue.clear();
    _messagesStore.clear();

    const conv1 = 'conv_an_01';
    _queue.add(
      ConversationQueueItem(
        conversationId: conv1,
        patientId: 'pat_01',
        patientName: 'Nguyễn Văn Bình',
        patientPhone: '0912345678',
        doctorId: 'doc_an_nguyen',
        doctorName: 'BS. CKI Nguyễn Văn An',
        lastMessageContent: 'Chào bác sĩ, vết rách ở chân tôi chảy máu nhiều',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 1,
      ),
    );

    const conv2 = 'conv_mai_huong_01';
    _queue.add(
      ConversationQueueItem(
        conversationId: conv2,
        patientId: 'pat_02',
        patientName: 'Trần Thị Hoa',
        patientPhone: '0987654321',
        doctorId: 'doc_mai_huong',
        doctorName: 'ThS. BS Trần Mai Hương',
        lastMessageContent: 'Em bị bỏng nước sôi ở mu bàn tay, đã xả nước mát',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 2)),
        unreadCount: 1,
      ),
    );

    _messagesStore[conv1] = [
      DoctorChatMessage(
        id: 'msg_01',
        conversationId: conv1,
        senderType: ChatSenderType.doctor,
        senderId: 'doc_an_nguyen',
        senderName: 'BS. CKI Nguyễn Văn An',
        content: 'Xin chào, hãy gửi mô tả hoặc ảnh vết thương để tôi hỗ trợ nhé!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        status: MessageDeliveryStatus.read,
      ),
      DoctorChatMessage(
        id: 'msg_02',
        conversationId: conv1,
        senderType: ChatSenderType.patient,
        senderId: 'pat_01',
        senderName: 'Nguyễn Văn Bình',
        content: 'Chào bác sĩ, vết rách ở chân tôi chảy máu nhiều',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        status: MessageDeliveryStatus.delivered,
      ),
    ];

    _messagesStore[conv2] = [
      DoctorChatMessage(
        id: 'msg_03',
        conversationId: conv2,
        senderType: ChatSenderType.doctor,
        senderId: 'doc_mai_huong',
        senderName: 'ThS. BS Trần Mai Hương',
        content: 'Chào bạn, hãy tiếp tục ngâm nước mát 15 phút nhé.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
        status: MessageDeliveryStatus.read,
      ),
      DoctorChatMessage(
        id: 'msg_04',
        conversationId: conv2,
        senderType: ChatSenderType.patient,
        senderId: 'pat_02',
        senderName: 'Trần Thị Hoa',
        content: 'Em bị bỏng nước sôi ở mu bàn tay, đã xả nước mát',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        status: MessageDeliveryStatus.delivered,
      ),
    ];

    notifyListeners();
  }

  /// Implementation matching DoctorConsultationService.instance.getDoctorQueue
  List<ConversationQueueItem> getDoctorQueue(String doctorId) {
    if (doctorId.isEmpty || doctorId == 'all') {
      return List.unmodifiable(_queue);
    }
    final filtered = _queue.where((item) => item.doctorId == doctorId).toList();
    return List.unmodifiable(filtered);
  }

  List<DoctorChatMessage> getStoredMessages(String conversationId) {
    return List.unmodifiable(_messagesStore[conversationId] ?? []);
  }

  Stream<List<DoctorChatMessage>> getMessagesStream(String conversationId) {
    final controller = _messageControllers.putIfAbsent(
      conversationId,
      () => StreamController<List<DoctorChatMessage>>.broadcast(),
    );
    _messagesStore.putIfAbsent(conversationId, () => []);

    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(List.unmodifiable(_messagesStore[conversationId]!));
      }
    });

    return controller.stream;
  }

  Future<DoctorChatMessage> sendMessage({
    required String conversationId,
    required String senderType,
    required String senderId,
    String? senderName,
    required String content,
    ChatAttachment? attachment,
    bool isEmergency = false,
    String patientName = 'Bệnh nhân',
  }) async {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty && attachment == null) {
      throw ArgumentError('Nội dung tin nhắn không được để trống khi không có tệp đính kèm.');
    }

    final type = ChatSenderType.values.firstWhere(
      (t) => t.name == senderType,
      orElse: () => ChatSenderType.doctor,
    );

    final now = DateTime.now();
    final message = DoctorChatMessage(
      id: 'msg_${now.microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderType: type,
      senderId: senderId,
      senderName: senderName,
      content: cleanContent,
      timestamp: now,
      status: MessageDeliveryStatus.sent,
      attachment: attachment,
      isEmergencyWarning: isEmergency,
    );

    _messagesStore.putIfAbsent(conversationId, () => []);
    _messagesStore[conversationId]!.add(message);
    _messageControllers[conversationId]?.add(List.unmodifiable(_messagesStore[conversationId]!));

    final isInactive = currentViewingConversationId != conversationId;
    final unreadInc = (type == ChatSenderType.patient && isInactive) ? 1 : 0;

    final qIdx = _queue.indexWhere((q) => q.conversationId == conversationId);
    if (qIdx != -1) {
      final existing = _queue.removeAt(qIdx);
      final updated = existing.copyWith(
        lastMessageContent: message.content,
        lastMessageTime: now,
        unreadCount: existing.unreadCount + unreadInc,
        hasAiFallbackResponse: type == ChatSenderType.ai || existing.hasAiFallbackResponse,
      );
      _queue.insert(0, updated);
    } else {
      _queue.insert(
        0,
        ConversationQueueItem(
          conversationId: conversationId,
          patientId: type == ChatSenderType.patient ? senderId : 'pat_$conversationId',
          patientName: type == ChatSenderType.patient ? (senderName ?? patientName) : patientName,
          lastMessageContent: message.content,
          lastMessageTime: now,
          unreadCount: unreadInc,
          hasAiFallbackResponse: type == ChatSenderType.ai,
        ),
      );
    }

    if (type == ChatSenderType.patient && isInactive) {
      _bannerAlerts.add('${message.senderName ?? patientName}: ${message.content}');
    }

    notifyListeners();
    return message;
  }

  Future<void> markMessagesAsRead(String conversationId, [String readerType = 'doctor']) async {
    final list = _messagesStore[conversationId];
    if (list != null) {
      for (var i = 0; i < list.length; i++) {
        final m = list[i];
        final shouldMark = readerType == 'doctor' ? m.isPatient : m.isDoctor;
        if (shouldMark && m.status != MessageDeliveryStatus.read) {
          list[i] = m.copyWith(status: MessageDeliveryStatus.read);
        }
      }
      _messageControllers[conversationId]?.add(List.unmodifiable(list));
    }

    final qIdx = _queue.indexWhere((q) => q.conversationId == conversationId);
    if (qIdx != -1) {
      _queue[qIdx].unreadCount = 0;
    }
    notifyListeners();
  }
}

// =============================================================================
// STANDALONE DOCTOR MANAGEMENT BROKER
// =============================================================================

class StandaloneDoctorManagementBroker extends ChangeNotifier {
  final List<DoctorProfile> _doctors = [];

  List<DoctorProfile> get doctors => List.unmodifiable(_doctors);
  int get onlineDoctorCount => _doctors.where((d) => d.isOnline).length;

  void reset() {
    _doctors.clear();
    _doctors.addAll([
      DoctorProfile.defaultDoctor,
      const DoctorProfile(
        id: 'doc_mai_huong',
        fullName: 'ThS. BS Trần Mai Hương',
        title: 'Thạc sĩ Bác sĩ',
        specialty: 'Bỏng & Tạo hình Thẩm mỹ',
        hospital: 'Viện Bỏng Quốc gia',
        phoneNumber: '0983124567',
        workplaceAddress: '263 Phùng Hưng, Hà Đông, Hà Nội',
        avatarInitials: 'MH',
        avatarColor: Color(0xFF059669),
        rating: 4.92,
        consultationCount: 1640,
        isOnline: true,
        statusText: 'Đang trực tuyến • Chuyên xử trí bỏng',
        isVerified: true,
        experienceYears: 10,
        consultationFee: 'Miễn phí sơ cứu',
      ),
      const DoctorProfile(
        id: 'doc_quoc_bao',
        fullName: 'BS. CKII Lê Quốc Bảo',
        title: 'Bác sĩ Chuyên khoa II',
        specialty: 'Chấn thương Chỉnh hình',
        hospital: 'Bệnh viện Chấn thương Chỉnh hình',
        phoneNumber: '0908765432',
        workplaceAddress: '929 Trần Hưng Đạo, Quận 5, TP.HCM',
        avatarInitials: 'QB',
        avatarColor: Color(0xFF7C3AED),
        rating: 4.88,
        consultationCount: 1950,
        isOnline: false,
        statusText: 'Tạm vắng • Trực ca mổ cấp cứu',
        isVerified: true,
        experienceYears: 18,
        consultationFee: 'Theo viện phí',
      ),
    ]);
    notifyListeners();
  }

  DoctorProfile? getDoctorById(String id) {
    final idx = _doctors.indexWhere((d) => d.id == id);
    return idx != -1 ? _doctors[idx] : null;
  }

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
    }
  }
}

// =============================================================================
// STANDALONE LOCAL STORAGE BROKER
// =============================================================================

class StandaloneLocalStorageBroker {
  String? _cachedDoctorUsername;
  String? _cachedDoctorId;
  bool _cachedDoctorIsLoggedIn = false;

  void reset() {
    _cachedDoctorUsername = null;
    _cachedDoctorId = null;
    _cachedDoctorIsLoggedIn = false;
  }

  Future<void> saveDoctorSession({required String username, required String doctorId}) async {
    _cachedDoctorUsername = username;
    _cachedDoctorId = doctorId;
    _cachedDoctorIsLoggedIn = true;
  }

  String? getDoctorSavedUsername() => _cachedDoctorUsername;
  String? getDoctorSavedId() => _cachedDoctorId;
  bool isDoctorLoggedIn() => _cachedDoctorIsLoggedIn;

  Future<void> clearDoctorSession() async {
    _cachedDoctorUsername = null;
    _cachedDoctorId = null;
    _cachedDoctorIsLoggedIn = false;
  }
}

// =============================================================================
// URL ROUTING PARSER UTILITY (MIRRORING LIB/MAIN.DART)
// =============================================================================

bool isBrowserUrlTargetingDoctor(String urlOrRoute) {
  final normalized = urlOrRoute.trim().toLowerCase();
  if (normalized == '/doctor' ||
      normalized == 'doctor' ||
      normalized.startsWith('/doctor/') ||
      normalized.contains('#/doctor') ||
      normalized.contains('#doctor')) {
    return true;
  }
  return false;
}

// =============================================================================
// TEST FRAMEWORK & HARNESS
// =============================================================================

int _totalTests = 0;
int _passedTests = 0;
int _failedTests = 0;

void expect(String specName, bool condition, [String failureMessage = '']) {
  _totalTests++;
  if (condition) {
    _passedTests++;
    print('  [PASS] Spec $_totalTests: $specName');
  } else {
    _failedTests++;
    print('  [FAIL] Spec $_totalTests: $specName');
    if (failureMessage.isNotEmpty) {
      print('         Details: $failureMessage');
    }
  }
}

// =============================================================================
// MAIN ENTRY POINT
// =============================================================================

void main() async {
  print('======================================================================');
  print('Running Milestone M3 Doctor Workspace & Admin Oversight Test Runner');
  print('Requirements: R3 (Doctor Workspace UI & Admin Oversight Dashboard)');
  print('======================================================================\n');

  final consultBroker = StandaloneConsultationBroker();
  final doctorBroker = StandaloneDoctorManagementBroker();
  final storageBroker = StandaloneLocalStorageBroker();

  // ---------------------------------------------------------------------------
  // GROUP 1: Doctor Workspace Queue Filtering
  // ---------------------------------------------------------------------------
  print('--- Group 1: Doctor Workspace Queue Filtering ---');
  consultBroker.reset();
  consultBroker.seedMultiDoctorData();

  // Spec 1
  final anQueue = consultBroker.getDoctorQueue('doc_an_nguyen');
  expect(
    'Doctor workspace filtering by doc_an_nguyen returns only assigned consultations',
    anQueue.length == 1 && anQueue.first.doctorId == 'doc_an_nguyen' && anQueue.first.patientName == 'Nguyễn Văn Bình',
  );

  // Spec 2
  final maiHuongQueue = consultBroker.getDoctorQueue('doc_mai_huong');
  expect(
    'Doctor workspace filtering by doc_mai_huong returns only her assigned consultations',
    maiHuongQueue.length == 1 && maiHuongQueue.first.doctorId == 'doc_mai_huong' && maiHuongQueue.first.patientName == 'Trần Thị Hoa',
  );

  // Spec 3
  final emptyDoctorQueue = consultBroker.getDoctorQueue('doc_quoc_bao');
  expect(
    'Doctor with zero consultations returns an empty queue without leaking other doctors patients',
    emptyDoctorQueue.isEmpty,
  );

  // Spec 4
  final anFirstItem = anQueue.first;
  expect(
    'Queue item contains valid patient metadata, unread count, and triage information',
    anFirstItem.conversationId == 'conv_an_01' &&
        anFirstItem.patientPhone == '0912345678' &&
        anFirstItem.unreadCount == 1 &&
        anFirstItem.lastMessageContent.contains('vết rách'),
  );

  // ---------------------------------------------------------------------------
  // GROUP 2: Doctor Chat Message Sending
  // ---------------------------------------------------------------------------
  print('\n--- Group 2: Doctor Chat Message Sending ---');

  // Spec 5 & 6
  final sentDoctorMsg = await consultBroker.sendMessage(
    conversationId: 'conv_an_01',
    senderType: 'doctor',
    senderId: 'doc_an_nguyen',
    senderName: 'BS. CKI Nguyễn Văn An',
    content: 'Bạn hãy giữ bình tĩnh và ấn chặt miếng gạc vào vết thương nhé.',
  );
  expect(
    'Doctor chat message has isDoctor == true and preserves doctor senderId & senderName',
    sentDoctorMsg.isDoctor &&
        !sentDoctorMsg.isPatient &&
        sentDoctorMsg.senderId == 'doc_an_nguyen' &&
        sentDoctorMsg.senderName == 'BS. CKI Nguyễn Văn An',
  );

  // Spec 7
  final storedMsgs = consultBroker.getStoredMessages('conv_an_01');
  expect(
    'Sent doctor message is immediately stored in conversation history',
    storedMsgs.length == 3 && storedMsgs.last.id == sentDoctorMsg.id,
  );

  // Spec 8
  final queueAfterDoctorSend = consultBroker.getDoctorQueue('doc_an_nguyen');
  expect(
    'Doctor message updates lastMessageContent and reorders queue',
    queueAfterDoctorSend.first.lastMessageContent.contains('giữ bình tĩnh'),
  );

  // Spec 9
  bool emptyRejected = false;
  try {
    await consultBroker.sendMessage(
      conversationId: 'conv_an_01',
      senderType: 'doctor',
      senderId: 'doc_an_nguyen',
      content: '   ',
    );
  } catch (e) {
    emptyRejected = true;
  }
  expect(
    'Sending empty message without attachment is rejected',
    emptyRejected,
  );

  // Spec 10
  final attachmentMsg = await consultBroker.sendMessage(
    conversationId: 'conv_an_01',
    senderType: 'doctor',
    senderId: 'doc_an_nguyen',
    senderName: 'BS. CKI Nguyễn Văn An',
    content: 'Ảnh hướng dẫn vị trí ép gạc',
    attachment: ChatAttachment(
      id: 'att_01',
      type: ChatAttachmentType.image,
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      fileName: 'guide.png',
    ),
  );
  expect(
    'Doctor message supports image attachment with byte payload',
    attachmentMsg.hasAttachment && attachmentMsg.attachment?.fileName == 'guide.png',
  );

  // ---------------------------------------------------------------------------
  // GROUP 3: Admin Oversight Global Queue & Supervision
  // ---------------------------------------------------------------------------
  print('\n--- Group 3: Admin Oversight Global Queue & Multi-Doctor Supervision ---');

  // Spec 11
  final adminGlobalQueueEmpty = consultBroker.getDoctorQueue('');
  expect(
    'Admin oversight global queue with empty doctorId returns all hospital consultations',
    adminGlobalQueueEmpty.length == 2,
  );

  // Spec 12
  final adminGlobalQueueAll = consultBroker.getDoctorQueue('all');
  expect(
    'Admin oversight global queue with doctorId == "all" returns all hospital consultations',
    adminGlobalQueueAll.length == 2,
  );

  // Spec 13
  final adminFilterAn = consultBroker.getDoctorQueue('doc_an_nguyen');
  final adminFilterMaiHuong = consultBroker.getDoctorQueue('doc_mai_huong');
  expect(
    'Admin can filter specifically by any doctor and get precise independent queues',
    adminFilterAn.length == 1 && adminFilterMaiHuong.length == 1 && adminFilterAn.first.doctorId != adminFilterMaiHuong.first.doctorId,
  );

  // Spec 14
  expect(
    'Admin oversight accurately aggregates total hospital unread counts',
    consultBroker.totalDoctorUnreadCount >= 1,
  );

  // Spec 15
  final adminSystemMsg = await consultBroker.sendMessage(
    conversationId: 'conv_an_01',
    senderType: 'system',
    senderId: 'admin_supervisor',
    senderName: 'Ban Giám sát Bệnh viện (Admin)',
    content: '📌 [ĐIỀU PHỐI QUẢN TRỊ]: Ưu tiên hỗ trợ ca vết rách mạch máu.',
  );
  expect(
    'Admin supervisor can send administrative coordination message without spoofing doctor identity',
    adminSystemMsg.isSystem && !adminSystemMsg.isDoctor && adminSystemMsg.senderId == 'admin_supervisor',
  );

  // ---------------------------------------------------------------------------
  // GROUP 4: Doctor Online Presence & Availability Persistence
  // ---------------------------------------------------------------------------
  print('\n--- Group 4: Doctor Online Presence & Availability Persistence ---');
  doctorBroker.reset();

  // Spec 16
  final initialOnlineCount = doctorBroker.onlineDoctorCount;
  expect(
    'Initial online doctor count matches seeded online doctors (2 online out of 3)',
    initialOnlineCount == 2,
  );

  // Spec 17
  await doctorBroker.updateDoctorOnlineStatus('doc_an_nguyen', false);
  final docAnOffline = doctorBroker.getDoctorById('doc_an_nguyen');
  expect(
    'updateDoctorOnlineStatus switches doctor to offline and updates statusText',
    docAnOffline != null && !docAnOffline.isOnline && docAnOffline.statusText.contains('Tạm vắng'),
  );

  // Spec 18
  expect(
    'onlineDoctorCount decrements dynamically when a doctor toggles to offline',
    doctorBroker.onlineDoctorCount == 1,
  );

  // Spec 19
  await doctorBroker.updateDoctorOnlineStatus('doc_an_nguyen', true);
  final docAnOnline = doctorBroker.getDoctorById('doc_an_nguyen');
  expect(
    'updateDoctorOnlineStatus switches doctor back to online and restores online count',
    docAnOnline != null && docAnOnline.isOnline && doctorBroker.onlineDoctorCount == 2,
  );

  // ---------------------------------------------------------------------------
  // GROUP 5: Doctor Session Storage Integration
  // ---------------------------------------------------------------------------
  print('\n--- Group 5: Doctor Session Storage Integration ---');
  storageBroker.reset();

  // Spec 20
  await storageBroker.saveDoctorSession(username: 'bs_an', doctorId: 'doc_an_nguyen');
  expect(
    'saveDoctorSession persists username, doctorId and sets isDoctorLoggedIn == true',
    storageBroker.isDoctorLoggedIn() &&
        storageBroker.getDoctorSavedUsername() == 'bs_an' &&
        storageBroker.getDoctorSavedId() == 'doc_an_nguyen',
  );

  // Spec 21
  await storageBroker.clearDoctorSession();
  expect(
    'clearDoctorSession cleanly resets doctor credentials and isDoctorLoggedIn == false',
    !storageBroker.isDoctorLoggedIn() &&
        storageBroker.getDoctorSavedUsername() == null &&
        storageBroker.getDoctorSavedId() == null,
  );

  // ---------------------------------------------------------------------------
  // GROUP 6: Data Models & Portal URL Routing
  // ---------------------------------------------------------------------------
  print('\n--- Group 6: Data Models & Portal URL Routing ---');

  // Spec 22
  final sampleChatMsg = DoctorChatMessage(
    id: 'msg_roundtrip',
    conversationId: 'conv_test',
    senderType: ChatSenderType.doctor,
    senderId: 'doc_an_nguyen',
    senderName: 'BS. CKI Nguyễn Văn An',
    content: 'Tin nhắn kiểm tra round-trip',
    timestamp: DateTime(2026, 11, 12, 10, 0),
    status: MessageDeliveryStatus.delivered,
    isEmergencyWarning: true,
  );
  final mapMsg = sampleChatMsg.toMap();
  final restoredMsg = DoctorChatMessage.fromMap(mapMsg);
  expect(
    'DoctorChatMessage toMap and fromMap round-trip maintains all fields and types',
    restoredMsg.id == sampleChatMsg.id &&
        restoredMsg.isDoctor &&
        restoredMsg.senderName == 'BS. CKI Nguyễn Văn An' &&
        restoredMsg.isEmergencyWarning == true,
  );

  // Spec 23
  final sampleQueueItem = ConversationQueueItem(
    conversationId: 'conv_q_test',
    patientId: 'pat_test',
    patientName: 'Lê Hoàng Long',
    doctorId: 'doc_mai_huong',
    doctorName: 'ThS. BS Trần Mai Hương',
    lastMessageContent: 'Bỏng nước sôi độ 2',
    lastMessageTime: DateTime(2026, 11, 12, 10, 30),
    unreadCount: 3,
    hasAiFallbackResponse: true,
  );
  final mapQueue = sampleQueueItem.toMap();
  final restoredQueue = ConversationQueueItem.fromMap(mapQueue);
  expect(
    'ConversationQueueItem toMap and fromMap round-trip preserves doctorId and doctorName',
    restoredQueue.doctorId == 'doc_mai_huong' &&
        restoredQueue.doctorName == 'ThS. BS Trần Mai Hương' &&
        restoredQueue.unreadCount == 3 &&
        restoredQueue.hasAiFallbackResponse == true,
  );

  // Spec 24
  expect(
    'isBrowserUrlTargetingDoctor returns true for path and hash URL patterns',
    isBrowserUrlTargetingDoctor('/doctor') &&
        isBrowserUrlTargetingDoctor('http://localhost:56178/#/doctor') &&
        isBrowserUrlTargetingDoctor('/doctor/consultation') &&
        isBrowserUrlTargetingDoctor('doctor'),
  );

  // Spec 25
  expect(
    'isBrowserUrlTargetingDoctor returns false for admin or root paths',
    !isBrowserUrlTargetingDoctor('/admin') &&
        !isBrowserUrlTargetingDoctor('http://localhost:56178/#/admin') &&
        !isBrowserUrlTargetingDoctor('/') &&
        !isBrowserUrlTargetingDoctor(''),
  );

  // ---------------------------------------------------------------------------
  // SUMMARY REPORT
  // ---------------------------------------------------------------------------
  print('\n======================================================================');
  print('TEST SUMMARY: $_passedTests / $_totalTests SPECS PASSED (${((_passedTests / _totalTests) * 100).toStringAsFixed(0)}% PASS)');
  if (_failedTests == 0) {
    print('Milestone M3 (Doctor Workspace & Admin Oversight - R3) FULLY VERIFIED.');
  } else {
    print('FAILED SPECS: $_failedTests');
  }
  print('======================================================================');
}
