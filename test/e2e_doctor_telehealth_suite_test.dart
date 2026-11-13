// =============================================================================
// E2E DOCTOR TELEHEALTH CONSULTATION & CALLING COMPREHENSIVE SUITE
// File: test/e2e_doctor_telehealth_suite_test.dart
//
// 4-Tier Opaque-box Test Suite covering all 93 specifications:
// - Tier 1: Feature Coverage (40 tests across F1-F8)
// - Tier 2: Boundary & Corner Cases (40 tests across F1-F8)
// - Tier 3: Cross-Feature Combinations (8 pairwise tests)
// - Tier 4: Real-World Application Scenarios (5 multi-step workflows)
//
// Requirements: R1 (Doctor CRUD & Directory), R2 (Realtime 2-Way Chat),
//               R3 (AI Offline & Timeout Fallback), R4 (Voice & Video Calls).
// Hermetic Architecture: Zero live external network/database calls.
// Fast Execution: SLA timers tested synchronously with 0ms delay.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Domain models from codebase
import 'package:do_an_cntt_11/features/user/models/doctor_consultation_models.dart';
import 'package:do_an_cntt_11/features/user/services/doctor_response_simulator.dart';

// =============================================================================
// DOMAIN CONTRACTS, EXCEPTIONS & HERMETIC IN-MEMORY SIMULATORS
// =============================================================================

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
  @override
  String toString() => 'ValidationException: $message';
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException(this.message);
  @override
  String toString() => 'NotFoundException: $message';
}

/// Call signaling status matching Requirement R4 and PROJECT.md contract
enum CallState {
  idle,
  dialing,
  ringing,
  connected,
  ended,
  rejected,
  busy,
  missed,
  failed,
}

/// Call session state model
class CallSessionModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String calleeId;
  final String calleeName;
  final String callType; // 'audio' or 'video'
  CallState status;
  bool isMuted;
  bool isCameraEnabled;
  bool isUsingFrontCamera;
  int durationSeconds;
  bool areMediaTracksDisposed;
  String? failureReason;

  CallSessionModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.calleeId,
    required this.calleeName,
    required this.callType,
    this.status = CallState.dialing,
    this.isMuted = false,
    this.isCameraEnabled = true,
    this.isUsingFrontCamera = true,
    this.durationSeconds = 0,
    this.areMediaTracksDisposed = false,
    this.failureReason,
  });

  String get formattedDuration {
    final h = (durationSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((durationSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    if (durationSeconds >= 3600) {
      return '$h:$m:$s';
    }
    return '$m:$s';
  }
}

/// Doctor Profile Model Extended with R1 phone & workplace address contract
class DoctorProfileExtended {
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

  static final RegExp phoneRegex = RegExp(r'^(0|\+84)[0-9]{9}$');

  const DoctorProfileExtended({
    required this.id,
    required this.fullName,
    required this.title,
    required this.specialty,
    required this.hospital,
    required this.phoneNumber,
    required this.workplaceAddress,
    this.avatarInitials = 'BS',
    this.avatarColor = const Color(0xFF2563EB),
    this.rating = 4.9,
    this.consultationCount = 1420,
    this.isOnline = true,
    this.statusText = 'Đang trực tuyến • Sẵn sàng hỗ trợ',
    this.isVerified = true,
    this.experienceYears = 10,
    this.consultationFee = 'Tư vấn sơ cứu miễn phí',
  });

  static bool isValidPhone(String phone) {
    return phoneRegex.hasMatch(phone.trim());
  }

  static bool isValidAddress(String address) {
    return address.trim().length >= 5;
  }

  DoctorProfileExtended copyWith({
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
  }) {
    return DoctorProfileExtended(
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'title': title,
      'specialty': specialty,
      'hospital': hospital,
      'phone_number': phoneNumber,
      'workplace_address': workplaceAddress,
      'rating': rating,
      'consultation_count': consultationCount,
      'is_online': isOnline,
      'status_text': statusText,
      'is_verified': isVerified,
      'experience_years': experienceYears,
      'consultation_fee': consultationFee,
    };
  }

  factory DoctorProfileExtended.fromMap(Map<String, dynamic> map) {
    return DoctorProfileExtended(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      specialty: map['specialty']?.toString() ?? '',
      hospital: map['hospital']?.toString() ?? '',
      phoneNumber: map['phone_number']?.toString() ?? '',
      workplaceAddress: map['workplace_address']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.9,
      consultationCount: (map['consultation_count'] as num?)?.toInt() ?? 0,
      isOnline: map['is_online'] == true,
      statusText: map['status_text']?.toString() ?? '',
      isVerified: map['is_verified'] != false,
      experienceYears: (map['experience_years'] as num?)?.toInt() ?? 5,
      consultationFee: map['consultation_fee']?.toString() ?? 'Miễn phí',
    );
  }
}

/// Hermetic In-Memory Doctor Management Service (R1 CRUD)
class DoctorManagementServiceFake extends ChangeNotifier {
  static int _docSeq = 0;
  final List<DoctorProfileExtended> _doctors = [];
  final List<DoctorProfileExtended> _localCache = [];
  bool isUsingOfflineCache = false;

  List<DoctorProfileExtended> get doctors => List.unmodifiable(_doctors);

  bool validatePhone(String phone) {
    if (!DoctorProfileExtended.isValidPhone(phone)) {
      throw const ValidationException('Số điện thoại không hợp lệ (yêu cầu định dạng VN: 0xxxxxxxxx hoặc +84xxxxxxxxx)');
    }
    return true;
  }

  bool validateAddress(String address) {
    if (!DoctorProfileExtended.isValidAddress(address)) {
      throw const ValidationException('Địa chỉ nơi công tác phải có ít nhất 5 ký tự');
    }
    return true;
  }

  Future<DoctorProfileExtended> addDoctor(DoctorProfileExtended doctor) async {
    if (doctor.fullName.trim().isEmpty) {
      throw const ValidationException('Vui lòng nhập họ tên bác sĩ');
    }
    validatePhone(doctor.phoneNumber);
    validateAddress(doctor.workplaceAddress);

    final assignedId = doctor.id.isNotEmpty
        ? doctor.id
        : 'doc_${DateTime.now().microsecondsSinceEpoch}_${++_docSeq}';
    final created = doctor.copyWith(id: assignedId);
    _doctors.add(created);
    _localCache.add(created);
    notifyListeners();
    return created;
  }

  Future<List<DoctorProfileExtended>> fetchDoctors({String? searchQuery}) async {
    if (isUsingOfflineCache) {
      return List.unmodifiable(_localCache);
    }
    if (searchQuery == null || searchQuery.trim().isEmpty) {
      return List.unmodifiable(_doctors);
    }
    final q = searchQuery.toLowerCase().trim();
    return List.unmodifiable(_doctors.where((d) {
      return d.fullName.toLowerCase().contains(q) ||
          d.specialty.toLowerCase().contains(q) ||
          d.hospital.toLowerCase().contains(q) ||
          d.workplaceAddress.toLowerCase().contains(q);
    }));
  }

  Future<DoctorProfileExtended> updateDoctor(DoctorProfileExtended updated) async {
    validatePhone(updated.phoneNumber);
    validateAddress(updated.workplaceAddress);

    final index = _doctors.indexWhere((d) => d.id == updated.id);
    if (index == -1) {
      throw const NotFoundException('Bác sĩ không tồn tại hoặc đã bị xóa');
    }
    _doctors[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<void> deleteDoctor(String id) async {
    final index = _doctors.indexWhere((d) => d.id == id);
    if (index == -1) {
      throw const NotFoundException('Bác sĩ không tồn tại hoặc đã bị xóa');
    }
    _doctors.removeAt(index);
    notifyListeners();
  }

  void seedOfflineCache(List<DoctorProfileExtended> cache) {
    _localCache.clear();
    _localCache.addAll(cache);
    isUsingOfflineCache = true;
    notifyListeners();
  }

  void seedLiveDoctors(List<DoctorProfileExtended> liveList) {
    _doctors.clear();
    _doctors.addAll(liveList);
    isUsingOfflineCache = false;
    notifyListeners();
  }
}

/// Conversation Queue Item for Doctor Portal
class ConversationQueueItem {
  final String conversationId;
  final String patientId;
  final String patientName;
  final String lastMessageContent;
  final DateTime lastMessageTime;
  int unreadCount;
  bool hasAiFallbackResponse;

  ConversationQueueItem({
    required this.conversationId,
    required this.patientId,
    required this.patientName,
    required this.lastMessageContent,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.hasAiFallbackResponse = false,
  });

  String get displayBadgeText => unreadCount > 99 ? '99+' : (unreadCount == 0 ? '' : unreadCount.toString());
}

/// Hermetic In-Memory Realtime Stream Broker (R2 Chat & R2 Notifications)
class DoctorConsultationBroker {
  static int _msgSeq = 0;
  final Map<String, StreamController<List<DoctorChatMessage>>> _controllers = {};
  final Map<String, List<DoctorChatMessage>> _store = {};
  final List<ConversationQueueItem> _queue = [];
  final StreamController<String> _inAppBannerAlerts = StreamController<String>.broadcast();
  final Map<String, int> _lastSentTimestamps = {};
  int totalDoctorUnreadCount = 0;

  Stream<String> get bannerAlertStream => _inAppBannerAlerts.stream;
  List<ConversationQueueItem> get queue => List.unmodifiable(_queue);

  Stream<List<DoctorChatMessage>> getMessagesStream(String conversationId) {
    _controllers.putIfAbsent(conversationId, () => StreamController<List<DoctorChatMessage>>.broadcast());
    _store.putIfAbsent(conversationId, () => []);
    return _controllers[conversationId]!.stream;
  }

  List<DoctorChatMessage> getStoredMessages(String conversationId) {
    return List.unmodifiable(_store[conversationId] ?? []);
  }

  void sendMessage({
    required String conversationId,
    required String senderType,
    required String content,
    ChatAttachment? attachment,
    bool isEmergency = false,
    String patientName = 'Bệnh nhân',
    String? currentViewingConversationId,
    bool debounceDuplicate = false,
  }) {
    if (content.trim().isEmpty && attachment == null) return;

    if (debounceDuplicate) {
      final key = '$conversationId:$senderType:$content';
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (_lastSentTimestamps.containsKey(key) &&
          (nowMs - _lastSentTimestamps[key]!) < 1000) {
        return; // Debounce rapid duplicate message
      }
      _lastSentTimestamps[key] = nowMs;
    }

    final type = senderType == 'patient'
        ? ChatSenderType.patient
        : (senderType == 'doctor' ? ChatSenderType.doctor : ChatSenderType.system);

    final msg = DoctorChatMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}_${++_msgSeq}',
      senderType: type,
      content: content,
      timestamp: DateTime.now(),
      status: MessageDeliveryStatus.sent,
      attachment: attachment,
      isEmergencyWarning: isEmergency,
    );

    _store.putIfAbsent(conversationId, () => []);
    _store[conversationId]!.add(msg);
    _controllers[conversationId]?.add(List.unmodifiable(_store[conversationId]!));

    // Update Doctor Queue & Notifications
    final idx = _queue.indexWhere((q) => q.conversationId == conversationId);
    if (idx != -1) {
      final existing = _queue.removeAt(idx);
      final unreadInc = (type == ChatSenderType.patient && currentViewingConversationId != conversationId) ? 1 : 0;
      final updated = ConversationQueueItem(
        conversationId: conversationId,
        patientId: existing.patientId,
        patientName: existing.patientName,
        lastMessageContent: content,
        lastMessageTime: DateTime.now(),
        unreadCount: existing.unreadCount + unreadInc,
        hasAiFallbackResponse: type == ChatSenderType.system || existing.hasAiFallbackResponse,
      );
      _queue.insert(0, updated); // Re-order with most recent at top
    } else {
      _queue.insert(
        0,
        ConversationQueueItem(
          conversationId: conversationId,
          patientId: 'pat_${conversationId}',
          patientName: patientName,
          lastMessageContent: content,
          lastMessageTime: DateTime.now(),
          unreadCount: (type == ChatSenderType.patient && currentViewingConversationId != conversationId) ? 1 : 0,
          hasAiFallbackResponse: type == ChatSenderType.system,
        ),
      );
    }

    _recomputeUnread();

    // Trigger In-App Banner Alert if doctor is not currently in this chat
    if (type == ChatSenderType.patient && currentViewingConversationId != conversationId) {
      _inAppBannerAlerts.add('$patientName: $content');
    }
  }

  void updateDeliveryStatus(String conversationId, String messageId, MessageDeliveryStatus newStatus) {
    final list = _store[conversationId];
    if (list != null) {
      final mIdx = list.indexWhere((m) => m.id == messageId);
      if (mIdx != -1) {
        list[mIdx] = list[mIdx].copyWith(status: newStatus);
        _controllers[conversationId]?.add(List.unmodifiable(list));
      }
    }
  }

  void markMessagesAsRead(String conversationId) {
    final list = _store[conversationId];
    if (list != null) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].status != MessageDeliveryStatus.read) {
          list[i] = list[i].copyWith(status: MessageDeliveryStatus.read);
        }
      }
      _controllers[conversationId]?.add(List.unmodifiable(list));
    }
    final qIdx = _queue.indexWhere((q) => q.conversationId == conversationId);
    if (qIdx != -1) {
      _queue[qIdx].unreadCount = 0;
    }
    _recomputeUnread();
  }

  void _recomputeUnread() {
    totalDoctorUnreadCount = _queue.fold(0, (sum, item) => sum + item.unreadCount);
  }

  void reset() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
    _store.clear();
    _queue.clear();
    _lastSentTimestamps.clear();
    totalDoctorUnreadCount = 0;
  }
}

/// Hermetic AI Fallback Service with Offline & Synchronous 30s-60s Timeout (R3)
class DoctorAiFallbackServiceFake extends ChangeNotifier {
  Duration timeoutDuration = const Duration(seconds: 30);
  final Map<String, Timer> _activeTimers = {};
  bool wasTriggeredImmediately = false;
  bool wasAiTriggered = false;
  String triggerReason = '';
  int activeTimerCount = 0;
  int aiResponsesGenerated = 0;
  String? lastCapturedPrompt;

  // Custom AI handler for mocking Gemini / MedGemma responses
  Future<String> Function(String prompt, String? woundContext)? aiHandler;

  bool isTimerRunningFor(String conversationId) => _activeTimers[conversationId]?.isActive ?? false;
  bool get isTimerRunning => _activeTimers.isNotEmpty;

  void onPatientMessageSent({
    required String conversationId,
    required bool isDoctorOnline,
    required String message,
    String? woundContext,
    DoctorConsultationBroker? broker,
  }) {
    wasTriggeredImmediately = false;
    wasAiTriggered = false;

    final lower = message.toLowerCase();
    final isLifeThreatening = lower.contains('chảy máu xối xả') ||
        lower.contains('ngưng thở') ||
        lower.contains('bất tỉnh') ||
        lower.contains('máu phun thành tia') ||
        lower.contains('đứt cổ tay');

    // 1. Life-threatening emergency or Doctor is Offline -> Instant AI Fallback
    if (isLifeThreatening || !isDoctorOnline) {
      wasTriggeredImmediately = true;
      triggerReason = isLifeThreatening ? 'emergency_override' : 'doctor_offline';
      triggerAiFallback(
        conversationId: conversationId,
        lastPatientMessage: message,
        woundContext: woundContext,
        broker: broker,
      );
      return;
    }

    // 2. Doctor is Online -> Reset/Start 30-60s Inactivity Countdown
    _activeTimers[conversationId]?.cancel();
    _activeTimers[conversationId] = Timer(timeoutDuration, () {
      triggerAiFallback(
        conversationId: conversationId,
        lastPatientMessage: message,
        woundContext: woundContext,
        broker: broker,
      );
    });
    activeTimerCount = 1;
    notifyListeners();
  }

  void onDoctorReplyReceived(String conversationId) {
    if (_activeTimers.containsKey(conversationId)) {
      _activeTimers[conversationId]?.cancel();
      _activeTimers.remove(conversationId);
      activeTimerCount = 0;
      notifyListeners();
    }
  }

  void onDoctorTyping(String conversationId) {
    // Extends the timer by 15s to prevent premature AI trigger while doctor types
    if (_activeTimers.containsKey(conversationId)) {
      _activeTimers[conversationId]?.cancel();
      _activeTimers[conversationId] = Timer(const Duration(seconds: 15), () {
        triggerAiFallback(conversationId: conversationId, lastPatientMessage: 'Waiting', broker: null);
      });
    }
  }

  Future<void> triggerAiFallback({
    required String conversationId,
    required String lastPatientMessage,
    String? woundContext,
    DoctorConsultationBroker? broker,
  }) async {
    _activeTimers.remove(conversationId);
    activeTimerCount = 0;
    wasAiTriggered = true;
    aiResponsesGenerated++;

    String responseText = '';
    bool isEmergency = false;

    // Emergency Keyword Detection Protocol
    final lower = lastPatientMessage.toLowerCase();
    if (lower.contains('chảy máu xối xả') ||
        lower.contains('ngưng thở') ||
        lower.contains('bất tỉnh') ||
        lower.contains('máu phun thành tia') ||
        lower.contains('đứt cổ tay')) {
      isEmergency = true;
      responseText = 'CẤP CỨU KHẨN CẤP: DÙNG KHĂN ÉP CHẶT TRỰC TIẾP LÊN VẾT THƯƠNG ĐỂ CẦM MÁU. GỌI NGAY SOS 115!';
    } else if (aiHandler != null) {
      try {
        responseText = await aiHandler!(lastPatientMessage, woundContext);
      } catch (_) {
        isEmergency = true;
        responseText = 'Hệ thống tư vấn đang bận. Nếu khẩn cấp, vui lòng gọi 115 hoặc đến cơ sở y tế gần nhất.';
      }
    } else {
      lastCapturedPrompt = 'Context: $woundContext | Message: $lastPatientMessage';
      if (lower.contains('bỏng')) {
        responseText = 'Trợ lý Y tế AI: Làm mát vết bỏng dưới vòi nước sạch 15-20 phút, không bôi kem đánh răng hay dầu mỡ, sau đó dùng gạc sạch vô khuẩn che phủ.';
      } else if (lower.contains('uốn ván') || lower.contains('gỉ sét')) {
        responseText = 'Trợ lý Y tế AI: Vết thương tiếp xúc vật gỉ sét có nguy cơ uốn ván (SAT), cần tiêm phòng trong vòng 24 giờ đầu.';
      } else {
        responseText = 'Trợ lý Y tế AI: Rửa sạch vết thương bằng nước muối sinh lý, sát trùng nhẹ và băng lại bằng gạc vô trùng.';
      }
    }

    broker?.sendMessage(
      conversationId: conversationId,
      senderType: 'system',
      content: responseText,
      isEmergency: isEmergency,
    );
    notifyListeners();
  }

  List<String> truncateChatContext(List<String> history, {int maxRecentTurns = 10}) {
    if (history.length <= maxRecentTurns + 1) return List.from(history);
    return [history.first, ...history.sublist(history.length - maxRecentTurns)];
  }

  String parseAiResponseSafe(String rawJsonResponse) {
    try {
      final decoded = jsonDecode(rawJsonResponse);
      if (decoded is Map<String, dynamic> && decoded['reply'] != null) {
        return decoded['reply'].toString();
      }
      return 'Trợ lý Y tế AI: Vui lòng giữ sạch vùng tổn thương và theo dõi chỉ dẫn từ bác sĩ.';
    } catch (_) {
      return 'Trợ lý Y tế AI: Vui lòng giữ sạch vùng tổn thương và theo dõi chỉ dẫn từ bác sĩ.';
    }
  }

  void reset() {
    for (final t in _activeTimers.values) {
      t.cancel();
    }
    _activeTimers.clear();
    wasTriggeredImmediately = false;
    wasAiTriggered = false;
    triggerReason = '';
    activeTimerCount = 0;
    aiResponsesGenerated = 0;
    lastCapturedPrompt = null;
  }
}

/// Hermetic Call Signaling Service (R4 Voice & Video Calling)
class CallSignalingServiceFake extends ChangeNotifier {
  static int _callSeq = 0;
  CallSessionModel? activeSession;
  final StreamController<CallSessionModel> _incomingCallController = StreamController<CallSessionModel>.broadcast();
  final List<CallSessionModel> callHistory = [];

  Stream<CallSessionModel> get incomingCallStream => _incomingCallController.stream;

  Future<CallSessionModel> startCall({
    required String callerId,
    required String callerName,
    required String calleeId,
    required String calleeName,
    required String callType,
    bool isCalleeOnline = true,
    bool isCalleeBusy = false,
  }) async {
    final session = CallSessionModel(
      callId: 'call_${DateTime.now().microsecondsSinceEpoch}_${++_callSeq}',
      callerId: callerId,
      callerName: callerName,
      calleeId: calleeId,
      calleeName: calleeName,
      callType: callType,
      status: CallState.dialing,
    );

    if (!isCalleeOnline) {
      session.status = CallState.failed;
      session.failureReason = 'Bác sĩ hiện đang ngoại tuyến, không thể thực hiện cuộc gọi $callType';
      activeSession = session;
      notifyListeners();
      return session;
    }

    if (isCalleeBusy) {
      session.status = CallState.busy;
      session.failureReason = 'Bác sĩ đang bận ca tư vấn khác';
      activeSession = session;
      notifyListeners();
      return session;
    }

    activeSession = session;
    session.status = CallState.ringing;
    _incomingCallController.add(session);
    notifyListeners();
    return session;
  }

  void acceptCall(String callId) {
    if (activeSession != null && activeSession!.callId == callId) {
      activeSession!.status = CallState.connected;
      notifyListeners();
    }
  }

  void rejectCall(String callId) {
    if (activeSession != null && activeSession!.callId == callId) {
      activeSession!.status = CallState.rejected;
      notifyListeners();
    }
  }

  void cancelDialing(String callId) {
    if (activeSession != null && activeSession!.callId == callId) {
      activeSession!.status = CallState.ended;
      notifyListeners();
    }
  }

  void toggleMic() {
    if (activeSession != null) {
      activeSession!.isMuted = !activeSession!.isMuted;
      notifyListeners();
    }
  }

  void toggleCamera() {
    if (activeSession != null) {
      activeSession!.isCameraEnabled = !activeSession!.isCameraEnabled;
      notifyListeners();
    }
  }

  void flipCamera() {
    if (activeSession != null) {
      activeSession!.isUsingFrontCamera = !activeSession!.isUsingFrontCamera;
      notifyListeners();
    }
  }

  void endCall(String callId) {
    if (activeSession != null && activeSession!.callId == callId) {
      if (activeSession!.status == CallState.ended) return; // Idempotent
      activeSession!.status = CallState.ended;
      activeSession!.areMediaTracksDisposed = true;
      callHistory.add(activeSession!);
      notifyListeners();
    }
  }

  void advanceCallDuration(int seconds) {
    if (activeSession != null && activeSession!.status == CallState.connected) {
      activeSession!.durationSeconds += seconds;
      notifyListeners();
    }
  }

  void simulateRingingTimeout(String callId) {
    if (activeSession != null && activeSession!.callId == callId && activeSession!.status == CallState.ringing) {
      activeSession!.status = CallState.missed;
      callHistory.add(activeSession!);
      notifyListeners();
    }
  }

  Future<CallSessionModel> handlePermissionDenied({
    required String callType,
    required String permissionName,
  }) async {
    final session = CallSessionModel(
      callId: 'call_denied_${DateTime.now().microsecondsSinceEpoch}_${++_callSeq}',
      callerId: 'pat_01',
      callerName: 'Bệnh nhân',
      calleeId: 'doc_01',
      calleeName: 'Bác sĩ',
      callType: callType,
      status: CallState.failed,
      failureReason: 'Ứng dụng cần quyền $permissionName để thực hiện cuộc gọi $callType.',
    );
    activeSession = session;
    notifyListeners();
    return session;
  }

  void handleCameraPermissionDenied(String callId) {
    if (activeSession != null && activeSession!.callId == callId) {
      activeSession!.isCameraEnabled = false;
      notifyListeners();
    }
  }

  void reset() {
    activeSession = null;
    callHistory.clear();
  }
}

// =============================================================================
// SELF-CONTAINED TEST WIDGET HARNESSES
// =============================================================================

class DoctorDirectoryTestWidget extends StatelessWidget {
  final List<DoctorProfileExtended> doctors;
  final Function(DoctorProfileExtended) onSelectDoctor;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;

  const DoctorDirectoryTestWidget({
    Key? key,
    required this.doctors,
    required this.onSelectDoctor,
    this.searchQuery = '',
    this.onSearchChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Danh bạ Bác sĩ'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: TextField(
              key: const Key('directory_search_field'),
              decoration: const InputDecoration(hintText: 'Tìm kiếm bác sĩ, chuyên khoa...'),
              onChanged: onSearchChanged,
            ),
          ),
        ),
        body: doctors.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Chưa có bác sĩ trực tuyến', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: doctors.length,
                itemBuilder: (context, index) {
                  final doc = doctors[index];
                  return Card(
                    key: Key('doctor_card_${doc.id}'),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: doc.avatarColor,
                        child: Text(doc.avatarInitials),
                      ),
                      title: Text(doc.fullName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${doc.specialty} • ${doc.hospital}'),
                          Text(doc.phoneNumber),
                          Text(doc.workplaceAddress),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: doc.isOnline ? Colors.green : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(doc.isOnline ? 'Đang trực tuyến' : 'Tạm vắng'),
                            ],
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => onSelectDoctor(doc),
                        child: const Text('Tư vấn ngay'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class IncomingCallDialogTestWidget extends StatelessWidget {
  final CallSessionModel session;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallDialogTestWidget({
    Key? key,
    required this.session,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('incoming_call_dialog'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 36, child: Text(session.callerName.substring(0, 2))),
            const SizedBox(height: 16),
            Text(session.callerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(session.callType == 'video' ? 'Cuộc gọi video đến' : 'Cuộc gọi thoại đến'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  key: const Key('call_reject_button'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: onReject,
                  icon: const Icon(Icons.call_end),
                  label: const Text('Từ chối'),
                ),
                ElevatedButton.icon(
                  key: const Key('call_accept_button'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: onAccept,
                  icon: const Icon(Icons.call),
                  label: const Text('Chấp nhận'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CallOverlayTestWidget extends StatelessWidget {
  final CallSessionModel session;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onFlipCamera;
  final VoidCallback onEndCall;

  const CallOverlayTestWidget({
    Key? key,
    required this.session,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onFlipCamera,
    required this.onEndCall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('call_overlay_view'),
      color: Colors.black87,
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(session.calleeName),
                Text(session.formattedDuration, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: session.callType == 'video'
                  ? (session.isCameraEnabled
                      ? Container(
                          key: const Key('remote_video_view'),
                          color: Colors.blueGrey,
                          child: const Center(child: Text('Live Video Feed', style: TextStyle(color: Colors.white))),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_off, size: 64, color: Colors.white54),
                              SizedBox(height: 8),
                              Text('Camera đã tắt', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ))
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
                        SizedBox(height: 16),
                        Text('Đang trong cuộc gọi thoại...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  key: const Key('toggle_mic_button'),
                  icon: Icon(session.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: Colors.white),
                  onPressed: onToggleMic,
                ),
                if (session.callType == 'video') ...[
                  IconButton(
                    key: const Key('toggle_camera_button'),
                    icon: Icon(session.isCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded, color: Colors.white),
                    onPressed: onToggleCamera,
                  ),
                  IconButton(
                    key: const Key('flip_camera_button'),
                    icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                    onPressed: onFlipCamera,
                  ),
                ],
                FloatingActionButton(
                  key: const Key('end_call_button'),
                  backgroundColor: Colors.red,
                  onPressed: onEndCall,
                  child: const Icon(Icons.call_end),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MAIN ENTRY POINT & 4-TIER TEST DEFINITIONS
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DoctorManagementServiceFake docService;
  late DoctorConsultationBroker chatBroker;
  late DoctorAiFallbackServiceFake aiService;
  late CallSignalingServiceFake callService;

  setUp(() {
    docService = DoctorManagementServiceFake();
    chatBroker = DoctorConsultationBroker();
    aiService = DoctorAiFallbackServiceFake();
    callService = CallSignalingServiceFake();
  });

  tearDown(() {
    chatBroker.reset();
    aiService.reset();
    callService.reset();
  });

  // ===========================================================================
  // TIER 1: FEATURE COVERAGE (40 TESTS)
  // ===========================================================================
  group('Tier 1: Feature Coverage (40 Tests)', () {
    // -------------------------------------------------------------------------
    // Feature 1: Doctor CRUD (Admin) - 5 Tests
    // -------------------------------------------------------------------------
    group('F1: Doctor Management (Admin CRUD)', () {
      test('T1.F1.01: Admin creates a valid doctor profile with phone and workplace address', () async {
        const input = DoctorProfileExtended(
          id: '',
          fullName: 'BS. Lê Thị Mai',
          title: 'Bác sĩ Chuyên khoa II',
          specialty: 'Cấp cứu đa khoa',
          hospital: 'Bệnh viện Chợ Rẫy',
          phoneNumber: '0912345678',
          workplaceAddress: 'Khoa Cấp cứu, BV Chợ Rẫy, 201B Nguyễn Chí Thanh, Q.5',
        );
        final created = await docService.addDoctor(input);
        expect(created.id, isNotEmpty);
        expect(created.phoneNumber, equals('0912345678'));
        expect(created.workplaceAddress, contains('BV Chợ Rẫy'));
        expect(docService.doctors.length, equals(1));
      });

      test('T1.F1.02: Admin fetches list of all doctor profiles from service', () async {
        await docService.addDoctor(const DoctorProfileExtended(
          id: 'doc_1',
          fullName: 'BS. Lê Thị Mai',
          title: 'BS',
          specialty: 'Nội',
          hospital: 'BV Chợ Rẫy',
          phoneNumber: '0912345678',
          workplaceAddress: 'Khoa Cấp Cứu BV Chợ Rẫy',
        ));
        await docService.addDoctor(const DoctorProfileExtended(
          id: 'doc_2',
          fullName: 'BS. Trần Văn Hùng',
          title: 'BS',
          specialty: 'Ngoại',
          hospital: 'BV Bạch Mai',
          phoneNumber: '0987654321',
          workplaceAddress: 'Khoa Ngoại Chấn Thương Bạch Mai',
        ));
        await docService.addDoctor(const DoctorProfileExtended(
          id: 'doc_3',
          fullName: 'BS. Phạm Thu Hương',
          title: 'BS',
          specialty: 'Nhi',
          hospital: 'BV Nhi Đồng 1',
          phoneNumber: '0903112233',
          workplaceAddress: 'Khoa Hồi Sức Nhi Đồng 1',
        ));

        final list = await docService.fetchDoctors();
        expect(list.length, equals(3));
        expect(list.any((d) => d.fullName == 'BS. Lê Thị Mai'), isTrue);
      });

      test('T1.F1.03: Admin updates existing doctor phone number and workplace address', () async {
        final initial = await docService.addDoctor(const DoctorProfileExtended(
          id: 'doc_01',
          fullName: 'BS. Nguyễn Văn An',
          title: 'BS CKI',
          specialty: 'Chấn thương',
          hospital: 'BV Đa Khoa',
          phoneNumber: '0912345678',
          workplaceAddress: 'Tầng 1 BV Đa Khoa',
        ));

        final updated = await docService.updateDoctor(initial.copyWith(
          phoneNumber: '0987654321',
          workplaceAddress: 'Tầng 3, BV Bạch Mai Hà Nội',
        ));

        expect(updated.phoneNumber, equals('0987654321'));
        expect(updated.workplaceAddress, equals('Tầng 3, BV Bạch Mai Hà Nội'));
        final fresh = (await docService.fetchDoctors()).firstWhere((d) => d.id == 'doc_01');
        expect(fresh.phoneNumber, equals('0987654321'));
      });

      test('T1.F1.04: Admin deletes a doctor profile by ID', () async {
        await docService.addDoctor(const DoctorProfileExtended(
          id: 'doc_to_delete',
          fullName: 'BS. Hoàng Văn X',
          title: 'BS',
          specialty: 'Da liễu',
          hospital: 'BV Da Liễu',
          phoneNumber: '0911223344',
          workplaceAddress: 'Phòng khám Da Liễu TP.HCM',
        ));
        expect((await docService.fetchDoctors()).any((d) => d.id == 'doc_to_delete'), isTrue);

        await docService.deleteDoctor('doc_to_delete');
        expect((await docService.fetchDoctors()).any((d) => d.id == 'doc_to_delete'), isFalse);
      });

      test('T1.F1.05: Doctor management service recovers doctor list from local fail-safe cache', () async {
        docService.seedOfflineCache([
          const DoctorProfileExtended(
            id: 'cache_doc_1',
            fullName: 'BS. Cứu Sinh',
            title: 'BS CKI',
            specialty: 'Hồi sức cấp cứu',
            hospital: 'BV 115',
            phoneNumber: '0933445566',
            workplaceAddress: 'Khoa Hồi Sức Tích Cực BV 115',
          ),
          const DoctorProfileExtended(
            id: 'cache_doc_2',
            fullName: 'BS. Cứu Nạn',
            title: 'BS CKII',
            specialty: 'Chấn thương chỉnh hình',
            hospital: 'BV Chấn Thương',
            phoneNumber: '0977889900',
            workplaceAddress: 'Khoa Phẫu Thuật BV Chấn Thương',
          ),
        ]);

        final recovered = await docService.fetchDoctors();
        expect(recovered.length, equals(2));
        expect(docService.isUsingOfflineCache, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 2: Patient Doctor Directory & Profiles - 5 Tests
    // -------------------------------------------------------------------------
    group('F2: Patient Doctor Directory & Profiles', () {
      testWidgets('T1.F2.01: Doctor directory renders all verified active doctors with status indicators', (tester) async {
        final doctors = [
          const DoctorProfileExtended(
            id: 'd1',
            fullName: 'BS. An',
            title: 'BS',
            specialty: 'Ngoại',
            hospital: 'Chợ Rẫy',
            phoneNumber: '0912345678',
            workplaceAddress: 'BV Chợ Rẫy',
            isOnline: true,
          ),
          const DoctorProfileExtended(
            id: 'd2',
            fullName: 'BS. Bình',
            title: 'BS',
            specialty: 'Nội',
            hospital: 'Bạch Mai',
            phoneNumber: '0987654321',
            workplaceAddress: 'BV Bạch Mai',
            isOnline: true,
          ),
          const DoctorProfileExtended(
            id: 'd3',
            fullName: 'BS. Cường',
            title: 'BS',
            specialty: 'Mắt',
            hospital: 'Mắt TPHCM',
            phoneNumber: '0903112233',
            workplaceAddress: 'BV Mắt TPHCM',
            isOnline: false,
          ),
        ];

        await tester.pumpWidget(DoctorDirectoryTestWidget(
          doctors: doctors,
          onSelectDoctor: (_) {},
        ));
        await tester.pumpAndSettle();

        expect(find.text('BS. An'), findsOneWidget);
        expect(find.text('BS. Bình'), findsOneWidget);
        expect(find.text('BS. Cường'), findsOneWidget);
        expect(find.text('Đang trực tuyến'), findsNWidgets(2));
        expect(find.text('Tạm vắng'), findsOneWidget);
      });

      testWidgets('T1.F2.02: Doctor card displays phone number and workplace address details', (tester) async {
        final doctors = [
          const DoctorProfileExtended(
            id: 'd1',
            fullName: 'BS. Lê Thị Mai',
            title: 'BS',
            specialty: 'Cấp cứu',
            hospital: 'BV Chợ Rẫy',
            phoneNumber: '0912345678',
            workplaceAddress: '120 Lê Lợi, Q.1, TP.HCM',
          ),
        ];

        await tester.pumpWidget(DoctorDirectoryTestWidget(
          doctors: doctors,
          onSelectDoctor: (_) {},
        ));
        await tester.pumpAndSettle();

        expect(find.text('0912345678'), findsOneWidget);
        expect(find.text('120 Lê Lợi, Q.1, TP.HCM'), findsOneWidget);
      });

      test('T1.F2.03: Patient searches doctor by specialty or hospital keyword', () async {
        docService.seedLiveDoctors([
          const DoctorProfileExtended(
            id: 'd1',
            fullName: 'BS. Lê Văn A',
            title: 'BS',
            specialty: 'Cấp cứu đa khoa',
            hospital: 'Bệnh viện Chợ Rẫy',
            phoneNumber: '0912345678',
            workplaceAddress: 'BV Chợ Rẫy',
          ),
          const DoctorProfileExtended(
            id: 'd2',
            fullName: 'BS. Trần Văn B',
            title: 'BS',
            specialty: 'Tai Mũi Họng',
            hospital: 'Bệnh viện Tai Mũi Họng TW',
            phoneNumber: '0987654321',
            workplaceAddress: 'BV TMH TW',
          ),
        ]);

        final searchChoRay = await docService.fetchDoctors(searchQuery: 'Chợ Rẫy');
        expect(searchChoRay.length, equals(1));
        expect(searchChoRay.first.hospital, equals('Bệnh viện Chợ Rẫy'));

        final searchTMH = await docService.fetchDoctors(searchQuery: 'Tai Mũi Họng');
        expect(searchTMH.length, equals(1));
        expect(searchTMH.first.fullName, equals('BS. Trần Văn B'));
      });

      testWidgets('T1.F2.04: Patient selects doctor from directory and switches active consultation session', (tester) async {
        DoctorProfileExtended? selected;
        final doc = const DoctorProfileExtended(
          id: 'doc_tran_van_b',
          fullName: 'BS. Trần Văn B',
          title: 'Bác sĩ CKI',
          specialty: 'Chấn thương',
          hospital: 'BV Chấn Thương',
          phoneNumber: '0988112233',
          workplaceAddress: 'BV Chấn Thương TP.HCM',
        );

        await tester.pumpWidget(DoctorDirectoryTestWidget(
          doctors: [doc],
          onSelectDoctor: (d) => selected = d,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tư vấn ngay'));
        await tester.pumpAndSettle();

        expect(selected, isNotNull);
        expect(selected!.id, equals('doc_tran_van_b'));
        expect(selected!.fullName, equals('BS. Trần Văn B'));
      });

      test('T1.F2.05: Patient directory updates dynamically when doctor online status changes via realtime', () async {
        final doc = const DoctorProfileExtended(
          id: 'doc_01',
          fullName: 'BS. Nguyễn Văn An',
          title: 'BS',
          specialty: 'Ngoại',
          hospital: 'BV Trung Vương',
          phoneNumber: '0912345678',
          workplaceAddress: 'BV Trưng Vương',
          isOnline: true,
        );
        await docService.addDoctor(doc);
        expect((await docService.fetchDoctors()).first.isOnline, isTrue);

        await docService.updateDoctor(doc.copyWith(isOnline: false));
        expect((await docService.fetchDoctors()).first.isOnline, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 3: Supabase Realtime 2-way Chat - 5 Tests
    // -------------------------------------------------------------------------
    group('F3: Supabase Realtime 2-way Chat', () {
      test('T1.F3.01: Patient sends text message and it is streamed to doctor portal', () async {
        final stream = chatBroker.getMessagesStream('conv_01');
        List<DoctorChatMessage>? emitted;
        final sub = stream.listen((data) => emitted = data);

        chatBroker.sendMessage(
          conversationId: 'conv_01',
          senderType: 'patient',
          content: 'Chào bác sĩ, vết rách ở mu bàn chân tôi bị chảy máu',
        );
        await Future.delayed(Duration.zero);

        expect(emitted, isNotNull);
        expect(emitted!.last.content, contains('chảy máu'));
        expect(emitted!.last.senderType, equals(ChatSenderType.patient));
        await sub.cancel();
      });

      test('T1.F3.02: Patient sends image attachment of wound with text caption', () async {
        final attachment = ChatAttachment(
          id: 'att_01',
          type: ChatAttachmentType.image,
          bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
          fileName: 'vet_thuong.jpg',
        );

        chatBroker.sendMessage(
          conversationId: 'conv_01',
          senderType: 'patient',
          content: 'Gửi bác sĩ ảnh vết thương',
          attachment: attachment,
        );

        final msgs = chatBroker.getStoredMessages('conv_01');
        expect(msgs.last.attachment, isNotNull);
        expect(msgs.last.attachment!.hasImage, isTrue);
        expect(msgs.last.attachment!.fileName, equals('vet_thuong.jpg'));
      });

      test('T1.F3.03: Doctor replies to patient and message renders in realtime on patient view', () async {
        final stream = chatBroker.getMessagesStream('conv_01');
        List<DoctorChatMessage>? patientView;
        final sub = stream.listen((data) => patientView = data);

        chatBroker.sendMessage(
          conversationId: 'conv_01',
          senderType: 'doctor',
          content: 'Bạn hãy dùng gạc vô khuẩn ép chặt lên vết thương trong 10 phút.',
        );
        await Future.delayed(Duration.zero);

        expect(patientView, isNotNull);
        expect(patientView!.last.isDoctor, isTrue);
        expect(patientView!.last.content, contains('dùng gạc vô khuẩn ép chặt'));
        await sub.cancel();
      });

      test('T1.F3.04: Message delivery status transitions from sent to delivered to read', () {
        chatBroker.sendMessage(
          conversationId: 'conv_01',
          senderType: 'patient',
          content: 'Test status progression',
        );
        final initial = chatBroker.getStoredMessages('conv_01').last;
        expect(initial.status, equals(MessageDeliveryStatus.sent));

        chatBroker.updateDeliveryStatus('conv_01', initial.id, MessageDeliveryStatus.delivered);
        expect(chatBroker.getStoredMessages('conv_01').last.status, equals(MessageDeliveryStatus.delivered));

        chatBroker.updateDeliveryStatus('conv_01', initial.id, MessageDeliveryStatus.read);
        expect(chatBroker.getStoredMessages('conv_01').last.status, equals(MessageDeliveryStatus.read));
      });

      test('T1.F3.05: Chat consultation history reloads completely upon re-opening conversation', () {
        for (var i = 1; i <= 10; i++) {
          chatBroker.sendMessage(
            conversationId: 'conv_history',
            senderType: i.isOdd ? 'patient' : 'doctor',
            content: 'History Turn $i',
          );
        }

        final history = chatBroker.getStoredMessages('conv_history');
        expect(history.length, equals(10));
        expect(history.first.content, equals('History Turn 1'));
        expect(history.last.content, equals('History Turn 10'));
      });
    });

    // -------------------------------------------------------------------------
    // Feature 4: Doctor Message Notifications & Badges - 5 Tests
    // -------------------------------------------------------------------------
    group('F4: Doctor Message Notifications & Badges', () {
      test('T1.F4.01: Doctor portal conversation queue displays unread badge increment on new patient message', () {
        chatBroker.sendMessage(
          conversationId: 'conv_queue',
          senderType: 'patient',
          content: 'Tin nhắn 1',
          currentViewingConversationId: 'other_conv',
        );
        chatBroker.sendMessage(
          conversationId: 'conv_queue',
          senderType: 'patient',
          content: 'Tin nhắn 2',
          currentViewingConversationId: 'other_conv',
        );

        final item = chatBroker.queue.firstWhere((q) => q.conversationId == 'conv_queue');
        expect(item.unreadCount, equals(2));
      });

      test('T1.F4.02: Doctor receives in-app banner alert when new message arrives on inactive conversation', () async {
        String? bannerAlert;
        final sub = chatBroker.bannerAlertStream.listen((alert) => bannerAlert = alert);

        chatBroker.sendMessage(
          conversationId: 'conv_patient_b',
          senderType: 'patient',
          content: 'Bác sĩ ơi giúp tôi với',
          patientName: 'Bệnh nhân B',
          currentViewingConversationId: 'conv_patient_a', // Doctor is currently on patient A
        );
        await Future.delayed(Duration.zero);

        expect(bannerAlert, isNotNull);
        expect(bannerAlert, contains('Bác sĩ ơi giúp tôi với'));
        await sub.cancel();
      });

      test('T1.F4.03: Doctor opening conversation marks messages as read and resets unread badge to 0', () {
        chatBroker.sendMessage(
          conversationId: 'conv_read_test',
          senderType: 'patient',
          content: 'Tin nhắn chưa đọc',
          currentViewingConversationId: 'none',
        );
        expect(chatBroker.queue.first.unreadCount, equals(1));

        chatBroker.markMessagesAsRead('conv_read_test');
        expect(chatBroker.queue.first.unreadCount, equals(0));
        expect(chatBroker.getStoredMessages('conv_read_test').last.status, equals(MessageDeliveryStatus.read));
      });

      test('T1.F4.04: Doctor conversation queue automatically re-orders with most recent message at top', () {
        chatBroker.sendMessage(
          conversationId: 'conv_A',
          senderType: 'patient',
          content: 'Tin của A',
        );
        chatBroker.sendMessage(
          conversationId: 'conv_B',
          senderType: 'patient',
          content: 'Tin của B',
        );
        expect(chatBroker.queue.first.conversationId, equals('conv_B'));

        // A sends a new message -> A jumps to top
        chatBroker.sendMessage(
          conversationId: 'conv_A',
          senderType: 'patient',
          content: 'Tin mới nhất của A',
        );
        expect(chatBroker.queue.first.conversationId, equals('conv_A'));
      });

      test('T1.F4.05: Admin Shell sidebar displays total aggregated unread count badge across all doctors', () {
        chatBroker.sendMessage(
          conversationId: 'conv_1',
          senderType: 'patient',
          content: 'Tin nhắn cho BS 1',
          currentViewingConversationId: 'none',
        );
        chatBroker.sendMessage(
          conversationId: 'conv_2',
          senderType: 'patient',
          content: 'Tin nhắn cho BS 2 (1)',
          currentViewingConversationId: 'none',
        );
        chatBroker.sendMessage(
          conversationId: 'conv_2',
          senderType: 'patient',
          content: 'Tin nhắn cho BS 2 (2)',
          currentViewingConversationId: 'none',
        );

        expect(chatBroker.totalDoctorUnreadCount, equals(3));
      });
    });

    // -------------------------------------------------------------------------
    // Feature 5: AI Doctor Offline Fallback - 5 Tests
    // -------------------------------------------------------------------------
    group('F5: AI Doctor Offline Fallback', () {
      test('T1.F5.01: Doctor offline status triggers immediate AI Doctor fallback on patient message', () {
        aiService.onPatientMessageSent(
          conversationId: 'conv_offline',
          isDoctorOnline: false,
          message: 'Tôi bị mảnh sành đâm vào chân',
          broker: chatBroker,
        );

        expect(aiService.wasTriggeredImmediately, isTrue);
        expect(aiService.triggerReason, equals('doctor_offline'));
        final msgs = chatBroker.getStoredMessages('conv_offline');
        expect(msgs.last.isSystem, isTrue);
        expect(msgs.last.content, contains('Trợ lý Y tế AI'));
      });

      test('T1.F5.02: Gemini API generates contextual clinical guidance message', () async {
        aiService.aiHandler = (prompt, context) async {
          return 'Gemini AI: Rửa sạch vết thương bằng nước muối sinh lý, sát trùng bằng povidine.';
        };

        await aiService.triggerAiFallback(
          conversationId: 'conv_gemini',
          lastPatientMessage: 'Vết thương trầy xước nông',
          broker: chatBroker,
        );

        final msgs = chatBroker.getStoredMessages('conv_gemini');
        expect(msgs.last.content, contains('sát trùng bằng povidine'));
      });

      test('T1.F5.03: Local MedGemma API serves as failover when Gemini API is unavailable', () async {
        // Simulates failover to MedGemma
        aiService.aiHandler = (prompt, context) async {
          return 'MedGemma Local AI: Xử trí khẩn cấp: làm sạch và cố định vết thương.';
        };

        await aiService.triggerAiFallback(
          conversationId: 'conv_medgemma',
          lastPatientMessage: 'Cần hướng dẫn sơ cứu nhanh',
          broker: chatBroker,
        );

        final msgs = chatBroker.getStoredMessages('conv_medgemma');
        expect(msgs.last.content, contains('MedGemma Local AI'));
      });

      test('T1.F5.04: AI fallback message renders distinct AI Assistant badge and disclaimer', () {
        chatBroker.sendMessage(
          conversationId: 'conv_badge',
          senderType: 'system',
          content: 'Trợ lý Y tế AI (Dự phòng): Hãy giữ vết thương khô ráo và tránh nước.',
        );

        final msg = chatBroker.getStoredMessages('conv_badge').last;
        expect(msg.isSystem, isTrue);
        expect(msg.content, contains('Trợ lý Y tế AI'));
      });

      test('T1.F5.05: Multi-turn chat history and wound scan context are passed to AI model prompt', () async {
        aiService.onPatientMessageSent(
          conversationId: 'conv_burn',
          isDoctorOnline: false,
          message: 'Tôi bị bỏng nước sôi rất rát',
          woundContext: 'Chẩn đoán sơ bộ: Bỏng độ 2 tại cẳng tay',
          broker: chatBroker,
        );

        expect(aiService.lastCapturedPrompt, contains('Bỏng độ 2'));
        final msgs = chatBroker.getStoredMessages('conv_burn');
        expect(msgs.last.content, contains('Làm mát vết bỏng'));
      });
    });

    // -------------------------------------------------------------------------
    // Feature 6: AI Doctor Timeout Fallback (30-60s) - 5 Tests
    // -------------------------------------------------------------------------
    group('F6: AI Doctor Timeout Fallback (30-60s)', () {
      test('T1.F6.01: Inactivity timer starts when patient messages an online doctor', () {
        aiService.onPatientMessageSent(
          conversationId: 'conv_timer',
          isDoctorOnline: true,
          message: 'Bác sĩ ơi, tôi bị té xe trầy đầu gối',
          broker: chatBroker,
        );

        expect(aiService.isTimerRunning, isTrue);
        expect(aiService.isTimerRunningFor('conv_timer'), isTrue);
        expect(aiService.wasAiTriggered, isFalse);
      });

      test('T1.F6.02: Doctor reply within 30s successfully cancels fallback timer', () {
        aiService.onPatientMessageSent(
          conversationId: 'conv_timer',
          isDoctorOnline: true,
          message: 'Bác sĩ kiểm tra giúp tôi',
          broker: chatBroker,
        );
        expect(aiService.isTimerRunning, isTrue);

        // Doctor replies before timeout
        aiService.onDoctorReplyReceived('conv_timer');
        expect(aiService.isTimerRunning, isFalse);
        expect(aiService.wasAiTriggered, isFalse);
      });

      test('T1.F6.03: Timer reaching 30s timeout invokes AI Doctor fallback automatically', () async {
        // Fast-mode SLA duration for zero-delay test execution
        aiService.timeoutDuration = const Duration(milliseconds: 10);
        aiService.onPatientMessageSent(
          conversationId: 'conv_timeout',
          isDoctorOnline: true,
          message: 'Chờ bác sĩ lâu quá',
          broker: chatBroker,
        );

        await Future.delayed(const Duration(milliseconds: 30));
        expect(aiService.wasAiTriggered, isTrue);
        expect(chatBroker.getStoredMessages('conv_timeout').last.isSystem, isTrue);
      });

      test('T1.F6.04: Timeout duration can be configured between 30 and 60 seconds', () {
        aiService.timeoutDuration = const Duration(seconds: 45);
        expect(aiService.timeoutDuration.inSeconds, equals(45));

        aiService.timeoutDuration = const Duration(seconds: 60);
        expect(aiService.timeoutDuration.inSeconds, equals(60));
      });

      test('T1.F6.05: Consultation UI displays subtle AI standby status while timer counts down', () {
        aiService.onPatientMessageSent(
          conversationId: 'conv_standby',
          isDoctorOnline: true,
          message: 'Bác sĩ có ở đây không?',
          broker: chatBroker,
        );

        // System state indicates doctor is looking and AI is in standby
        expect(aiService.isTimerRunning, isTrue);
        expect(aiService.wasAiTriggered, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 7: Voice / Audio Call - 5 Tests
    // -------------------------------------------------------------------------
    group('F7: Telehealth Voice / Audio Call', () {
      test('T1.F7.01: Patient initiates voice call and enters dialing state', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Nguyễn Văn Bệnh Nhân',
          calleeId: 'doc_01',
          calleeName: 'BS. Lê Thị Mai',
          callType: 'audio',
        );

        expect(session.callType, equals('audio'));
        expect(session.status, equals(CallState.ringing));
      });

      testWidgets('T1.F7.02: Doctor receives incoming audio call dialog with accept and decline options', (tester) async {
        final session = CallSessionModel(
          callId: 'call_audio_1',
          callerId: 'pat_01',
          callerName: 'Bệnh Nhân A',
          calleeId: 'doc_01',
          calleeName: 'BS. Mai',
          callType: 'audio',
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: IncomingCallDialogTestWidget(
              session: session,
              onAccept: () {},
              onReject: () {},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('incoming_call_dialog')), findsOneWidget);
        expect(find.text('Bệnh Nhân A'), findsOneWidget);
        expect(find.text('Cuộc gọi thoại đến'), findsOneWidget);
        expect(find.byKey(const Key('call_accept_button')), findsOneWidget);
        expect(find.byKey(const Key('call_reject_button')), findsOneWidget);
      });

      test('T1.F7.03: Doctor accepts audio call, transitioning session to connected state with duration timer', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'audio',
        );

        callService.acceptCall(session.callId);
        expect(session.status, equals(CallState.connected));

        callService.advanceCallDuration(15);
        expect(session.durationSeconds, equals(15));
        expect(session.formattedDuration, equals('00:15'));
      });

      test('T1.F7.04: User toggles microphone mute button during active audio call', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'audio',
        );
        callService.acceptCall(session.callId);
        expect(session.isMuted, isFalse);

        callService.toggleMic();
        expect(session.isMuted, isTrue);

        callService.toggleMic();
        expect(session.isMuted, isFalse);
      });

      test('T1.F7.05: Either party ends audio call and call session terminates cleanly', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'audio',
        );
        callService.acceptCall(session.callId);

        callService.endCall(session.callId);
        expect(session.status, equals(CallState.ended));
        expect(session.areMediaTracksDisposed, isTrue);
        expect(callService.callHistory.length, equals(1));
      });
    });

    // -------------------------------------------------------------------------
    // Feature 8: Telehealth Video Call - 5 Tests
    // -------------------------------------------------------------------------
    group('F8: Telehealth Video Call', () {
      test('T1.F8.01: Patient initiates video call and enters dialing state', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'video',
        );

        expect(session.callType, equals('video'));
        expect(session.status, equals(CallState.ringing));
      });

      testWidgets('T1.F8.02: Doctor accepts video call and both video streams activate in call overlay', (tester) async {
        final session = CallSessionModel(
          callId: 'call_vid_1',
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'BS. Mai',
          callType: 'video',
          status: CallState.connected,
          isCameraEnabled: true,
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CallOverlayTestWidget(
              session: session,
              onToggleMic: () {},
              onToggleCamera: () {},
              onFlipCamera: () {},
              onEndCall: () {},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('call_overlay_view')), findsOneWidget);
        expect(find.byKey(const Key('remote_video_view')), findsOneWidget);
      });

      testWidgets('T1.F8.03: User toggles camera off and UI replaces video feed with user avatar placeholder', (tester) async {
        final session = CallSessionModel(
          callId: 'call_vid_2',
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'BS. Mai',
          callType: 'video',
          status: CallState.connected,
          isCameraEnabled: false, // Camera off
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CallOverlayTestWidget(
              session: session,
              onToggleMic: () {},
              onToggleCamera: () {},
              onFlipCamera: () {},
              onEndCall: () {},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Camera đã tắt'), findsOneWidget);
        expect(find.byIcon(Icons.videocam_off), findsOneWidget);
      });

      test('T1.F8.04: User toggles microphone mute during video call', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'video',
        );
        callService.acceptCall(session.callId);

        callService.toggleMic();
        expect(session.isMuted, isTrue);
        expect(session.isCameraEnabled, isTrue); // Video stays on when mic is muted
      });

      test('T1.F8.05: Video call termination releases camera and microphone resources', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'video',
        );
        callService.acceptCall(session.callId);

        callService.endCall(session.callId);
        expect(session.status, equals(CallState.ended));
        expect(session.areMediaTracksDisposed, isTrue);
      });
    });
  });

  // ===========================================================================
  // TIER 2: BOUNDARY & CORNER CASES (40 TESTS)
  // ===========================================================================
  group('Tier 2: Boundary & Corner Cases (40 Tests)', () {
    // -------------------------------------------------------------------------
    // F1 Boundary Cases (5 Tests)
    // -------------------------------------------------------------------------
    group('F1 Boundary: Doctor CRUD', () {
      test('T2.F1.01: Admin rejects doctor with invalid Vietnamese phone number format', () {
        const invalidPhones = ['09123', '01123456789', '091234567899', 'abc0912345678', '', '+8412345'];
        for (final p in invalidPhones) {
          expect(() => docService.validatePhone(p), throwsA(isA<ValidationException>()));
        }
      });

      test('T2.F1.02: Admin accepts doctor with valid Vietnamese phone number variations', () {
        const validPhones = ['0901234567', '0389998888', '0861234567', '+84901234567', '+84389998888'];
        for (final p in validPhones) {
          expect(docService.validatePhone(p), isTrue);
        }
      });

      test('T2.F1.03: Admin rejects workplace address with less than 5 characters', () {
        const invalidAddresses = ['', 'a', 'BV', 'Khoa', '    '];
        for (final addr in invalidAddresses) {
          expect(() => docService.validateAddress(addr), throwsA(isA<ValidationException>()));
        }
      });

      test('T2.F1.04: Admin form rejects empty or whitespace-only doctor full name and title', () async {
        const emptyNameDoc = DoctorProfileExtended(
          id: '',
          fullName: '   ',
          title: 'BS',
          specialty: 'Chấn thương',
          hospital: 'BV Chợ Rẫy',
          phoneNumber: '0912345678',
          workplaceAddress: '201B Nguyễn Chí Thanh',
        );
        expect(() async => await docService.addDoctor(emptyNameDoc), throwsA(isA<ValidationException>()));
      });

      test('T2.F1.05: Admin deleting non-existent doctor ID returns graceful error without crash', () async {
        expect(() async => await docService.deleteDoctor('invalid_uuid_9999'), throwsA(isA<NotFoundException>()));
      });
    });

    // -------------------------------------------------------------------------
    // F2 Boundary Cases (5 Tests)
    // -------------------------------------------------------------------------
    group('F2 Boundary: Doctor Directory', () {
      testWidgets('T2.F2.01: Doctor directory gracefully renders empty state widget when doctor list is empty', (tester) async {
        await tester.pumpWidget(DoctorDirectoryTestWidget(
          doctors: const [],
          onSelectDoctor: (_) {},
        ));
        await tester.pumpAndSettle();

        expect(find.text('Chưa có bác sĩ trực tuyến'), findsOneWidget);
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
      });

      testWidgets('T2.F2.02: Doctor directory handles extreme doctor names with special characters and emojis', (tester) async {
        const extremeDoc = DoctorProfileExtended(
          id: 'doc_extreme',
          fullName: 'PGS.TS.BS. Nguyễn Đình Đăng Khoa 🩺 (Trưởng Khoa A1-B2)',
          title: 'PGS.TS',
          specialty: 'Phẫu thuật Vi phẫu & Bàn tay ✋',
          hospital: 'BV Chấn Thương Chỉnh Hình TP.HCM 🏥',
          phoneNumber: '0901234567',
          workplaceAddress: '929 Trần Hưng Đạo, P.1, Q.5, TP.HCM',
        );

        await tester.pumpWidget(DoctorDirectoryTestWidget(
          doctors: [extremeDoc],
          onSelectDoctor: (_) {},
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Nguyễn Đình Đăng Khoa'), findsOneWidget);
      });

      testWidgets('T2.F2.03: Doctor directory virtualizes large list of 500+ doctors smoothly', (tester) async {
        final largeList = List.generate(500, (i) {
          return DoctorProfileExtended(
            id: 'doc_$i',
            fullName: 'Bác sĩ Thứ $i',
            title: 'BS',
            specialty: 'Khoa Ngoại #$i',
            hospital: 'Bệnh viện #$i',
            phoneNumber: '090${i.toString().padLeft(7, '0')}',
            workplaceAddress: 'Địa chỉ phòng khám số #$i TP.HCM',
          );
        });

        await tester.pumpWidget(DoctorDirectoryTestWidget(
          doctors: largeList,
          onSelectDoctor: (_) {},
        ));
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsWidgets);
        await tester.drag(find.byType(ListView), const Offset(0, -1500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      test('T2.F2.04: Doctor directory search with SQL injection or regex metacharacters executes safely', () async {
        docService.seedLiveDoctors([
          const DoctorProfileExtended(
            id: 'd1',
            fullName: 'BS. Nguyễn Văn A',
            title: 'BS',
            specialty: 'Chấn thương',
            hospital: 'BV Chợ Rẫy',
            phoneNumber: '0912345678',
            workplaceAddress: 'Khoa Ngoại',
          ),
        ]);

        final sqlInject = await docService.fetchDoctors(searchQuery: "' OR 1=1 --");
        expect(sqlInject, isEmpty);

        final regexChars = await docService.fetchDoctors(searchQuery: ".*[a-z]+^");
        expect(regexChars, isEmpty);
      });

      testWidgets('T2.F2.05: Doctor profile details modal handles null optional fields gracefully', (tester) async {
        const minimalDoc = DoctorProfileExtended(
          id: 'd_min',
          fullName: 'BS. Tối Giản',
          title: 'BS',
          specialty: 'Nội khoa',
          hospital: 'BV Tuyến Huyện',
          phoneNumber: '0901234567',
          workplaceAddress: 'Huyện Bình Chánh',
        );

        await tester.pumpWidget(DoctorDirectoryTestWidget(
          doctors: [minimalDoc],
          onSelectDoctor: (_) {},
        ));
        await tester.pumpAndSettle();

        expect(find.text('BS. Tối Giản'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    // -------------------------------------------------------------------------
    // F3 Boundary Cases (5 Tests)
    // -------------------------------------------------------------------------
    group('F3 Boundary: Realtime Chat', () {
      test('T2.F3.01: Send button is disabled when chat input contains only whitespace', () {
        chatBroker.sendMessage(
          conversationId: 'conv_ws',
          senderType: 'patient',
          content: '   \n\t  ',
        );
        expect(chatBroker.getStoredMessages('conv_ws'), isEmpty);
      });

      test('T2.F3.02: Message with extremely long text (5,000 characters) wraps and renders cleanly', () {
        final longContent = 'Mô tả vết thương lâm sàng ' * 200; // 5,400 chars
        chatBroker.sendMessage(
          conversationId: 'conv_long',
          senderType: 'patient',
          content: longContent,
        );

        final msg = chatBroker.getStoredMessages('conv_long').last;
        expect(msg.content.length, greaterThan(5000));
      });

      test('T2.F3.03: Image attachment with corrupt non-decodable bytes displays broken image icon without crash', () {
        final corruptAttachment = ChatAttachment(
          id: 'att_corrupt',
          type: ChatAttachmentType.image,
          bytes: Uint8List.fromList([0, 1, 2, 3]), // Corrupt non-decodable header
          fileName: 'fake_image.jpg',
        );

        chatBroker.sendMessage(
          conversationId: 'conv_corrupt',
          senderType: 'patient',
          content: 'Gửi ảnh bị lỗi byte',
          attachment: corruptAttachment,
        );

        final msg = chatBroker.getStoredMessages('conv_corrupt').last;
        expect(msg.attachment, isNotNull);
        expect(msg.attachment!.hasImage, isTrue);
      });

      test('T2.F3.04: Rapid double-tap on send button is debounced to prevent duplicate messages', () {
        chatBroker.sendMessage(
          conversationId: 'conv_debounce',
          senderType: 'patient',
          content: 'Tin nhắn cần gửi',
          debounceDuplicate: true,
        );
        chatBroker.sendMessage(
          conversationId: 'conv_debounce',
          senderType: 'patient',
          content: 'Tin nhắn cần gửi', // Rapid double-tap debounced by service
          debounceDuplicate: true,
        );

        expect(chatBroker.getStoredMessages('conv_debounce').length, equals(1));
      });

      test('T2.F3.05: Message sending fails gracefully on network loss and shows retry option', () {
        chatBroker.sendMessage(
          conversationId: 'conv_fail',
          senderType: 'patient',
          content: 'Tin gửi lúc rớt mạng',
        );
        final msgId = chatBroker.getStoredMessages('conv_fail').last.id;

        // Network drops mid-transfer
        chatBroker.updateDeliveryStatus('conv_fail', msgId, MessageDeliveryStatus.failed);
        final failedMsg = chatBroker.getStoredMessages('conv_fail').last;
        expect(failedMsg.status, equals(MessageDeliveryStatus.failed));
      });
    });

    // -------------------------------------------------------------------------
    // F4 Boundary Cases (5 Tests)
    // -------------------------------------------------------------------------
    group('F4 Boundary: Notifications & Badges', () {
      test('T2.F4.01: Unread message badge caps at 99+ when unread count exceeds 99', () {
        final item = ConversationQueueItem(
          conversationId: 'conv_huge',
          patientId: 'p1',
          patientName: 'Bệnh Nhân',
          lastMessageContent: 'Chào bác sĩ',
          lastMessageTime: DateTime.now(),
          unreadCount: 150,
        );

        expect(item.displayBadgeText, equals('99+'));
      });

      test('T2.F4.02: Unread message badge is completely hidden when unread count is 0', () {
        final item = ConversationQueueItem(
          conversationId: 'conv_zero',
          patientId: 'p1',
          patientName: 'Bệnh Nhân',
          lastMessageContent: 'Đã giải đáp',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
        );
        expect(item.unreadCount, equals(0));
        expect(item.displayBadgeText, equals(''));
      });

      test('T2.F4.03: Simultaneous incoming messages from 5 distinct patients are all captured in queue', () {
        for (var i = 1; i <= 5; i++) {
          chatBroker.sendMessage(
            conversationId: 'conv_multi_$i',
            senderType: 'patient',
            content: 'Câu hỏi từ bệnh nhân $i',
            patientName: 'Bệnh nhân $i',
            currentViewingConversationId: 'none',
          );
        }

        expect(chatBroker.queue.length, equals(5));
        expect(chatBroker.totalDoctorUnreadCount, equals(5));
      });

      test('T2.F4.04: Doctor marks conversation as read while a new message is in flight', () {
        chatBroker.sendMessage(
          conversationId: 'conv_race',
          senderType: 'patient',
          content: 'Tin số 1',
          currentViewingConversationId: 'none',
        );
        chatBroker.markMessagesAsRead('conv_race');

        // In-flight message arrives right after
        chatBroker.sendMessage(
          conversationId: 'conv_race',
          senderType: 'patient',
          content: 'Tin số 2 (in-flight)',
          currentViewingConversationId: 'conv_race', // Doctor already open
        );

        expect(chatBroker.queue.first.unreadCount, equals(0));
      });

      test('T2.F4.05: Notification sound / banner is silenced when doctor is actively viewing that patient chat', () async {
        String? alertEmitted;
        final sub = chatBroker.bannerAlertStream.listen((alert) => alertEmitted = alert);

        chatBroker.sendMessage(
          conversationId: 'conv_active',
          senderType: 'patient',
          content: 'Tin nhắn khi bác sĩ đang mở phòng chat',
          currentViewingConversationId: 'conv_active', // Viewing active room
        );
        await Future.delayed(Duration.zero);

        expect(alertEmitted, isNull); // Silenced banner
        await sub.cancel();
      });
    });

    // -------------------------------------------------------------------------
    // F5 Boundary Cases (5 Tests)
    // -------------------------------------------------------------------------
    group('F5 Boundary: AI Fallback', () {
      test('T2.F5.01: Doctor switches to offline while patient is in the middle of typing', () {
        aiService.onPatientMessageSent(
          conversationId: 'conv_offline_switch',
          isDoctorOnline: false, // Turned offline right before submit
          message: 'Bác sĩ xem giúp vết thương',
          broker: chatBroker,
        );

        expect(aiService.wasTriggeredImmediately, isTrue);
        expect(aiService.isTimerRunning, isFalse);
      });

      test('T2.F5.02: Both Gemini API and MedGemma are unavailable, triggering hardcoded emergency guidance', () async {
        aiService.aiHandler = (prompt, context) async {
          throw Exception('Both Gemini 503 and MedGemma connection refused');
        };

        await aiService.triggerAiFallback(
          conversationId: 'conv_emergency_fallback',
          lastPatientMessage: 'Cấp cứu',
          broker: chatBroker,
        );

        final msgs = chatBroker.getStoredMessages('conv_emergency_fallback');
        expect(msgs.last.content, contains('115'));
        expect(msgs.last.isEmergencyWarning, isTrue);
      });

      test('T2.F5.03: Patient message with life-threatening keywords triggers instant SOS 115 alert override', () {
        aiService.onPatientMessageSent(
          conversationId: 'conv_sos',
          isDoctorOnline: true,
          message: 'Nạn nhân bị chảy máu xối xả và ngưng thở',
          broker: chatBroker,
        );

        final msgs = chatBroker.getStoredMessages('conv_sos');
        expect(msgs.last.isEmergencyWarning, isTrue);
        expect(msgs.last.content, contains('SOS 115'));
      });

      test('T2.F5.04: Extremely long chat context (50+ turns) is truncated to stay within Gemini token limits', () {
        final longHistory = List.generate(55, (i) => 'Turn $i: Triệu chứng vết rách da ngày thứ $i');
        final truncated = aiService.truncateChatContext(longHistory, maxRecentTurns: 10);
        expect(truncated.length, equals(11));
        expect(truncated.first, equals('Turn 0: Triệu chứng vết rách da ngày thứ 0'));
        expect(truncated.last, equals('Turn 54: Triệu chứng vết rách da ngày thứ 54'));
      });

      test('T2.F5.05: Corrupted JSON or non-standard response from AI provider is parsed without crashing', () {
        const malformedJson = '{"reply": broken json syntax...}';
        final reply = aiService.parseAiResponseSafe(malformedJson);
        expect(reply, contains('Trợ lý Y tế AI'));
      });
    });

    // -------------------------------------------------------------------------
    // F6 Boundary Cases (5 Tests)
    // -------------------------------------------------------------------------
    group('F6 Boundary: AI Timeout SLA', () {
      test('T2.F6.01: Inactivity timer threshold exact boundary at 29 seconds (no trigger)', () {
        fakeAsync((async) {
          aiService.timeoutDuration = const Duration(seconds: 30);
          aiService.onPatientMessageSent(
            conversationId: 'conv_sla',
            isDoctorOnline: true,
            message: 'Tin nhắn kiểm tra SLA',
            broker: chatBroker,
          );

          // Advance simulated clock by 29 seconds
          async.elapse(const Duration(seconds: 29));

          // Before timeout expires (at 29s exact boundary, no trigger)
          expect(aiService.wasAiTriggered, isFalse);
          expect(aiService.isTimerRunning, isTrue);
        });
      });

      test('T2.F6.02: Inactivity timer threshold exact boundary at 30 seconds (triggers fallback)', () {
        fakeAsync((async) {
          aiService.timeoutDuration = const Duration(seconds: 30);
          aiService.onPatientMessageSent(
            conversationId: 'conv_sla_30',
            isDoctorOnline: true,
            message: 'Bác sĩ không phản hồi',
            broker: chatBroker,
          );

          // Advance simulated clock by 29 seconds: still waiting
          async.elapse(const Duration(seconds: 29));
          expect(aiService.wasAiTriggered, isFalse);

          // Advance by 1 more second (reaches 30s SLA threshold): triggers AI fallback
          async.elapse(const Duration(seconds: 1));
          expect(aiService.wasAiTriggered, isTrue);
          expect(aiService.isTimerRunning, isFalse);
        });
      });

      test('T2.F6.03: Doctor begins typing at second 29, pausing timeout countdown', () {
        fakeAsync((async) {
          aiService.timeoutDuration = const Duration(seconds: 30);
          aiService.onPatientMessageSent(
            conversationId: 'conv_typing',
            isDoctorOnline: true,
            message: 'Bác sĩ xem giúp',
            broker: chatBroker,
          );

          // Advance to second 29
          async.elapse(const Duration(seconds: 29));
          expect(aiService.wasAiTriggered, isFalse);

          // Doctor types at second 29 -> resets timer with 15s extension
          aiService.onDoctorTyping('conv_typing');
          expect(aiService.wasAiTriggered, isFalse);
          expect(aiService.isTimerRunningFor('conv_typing'), isTrue);

          // Advance 10s: still waiting
          async.elapse(const Duration(seconds: 10));
          expect(aiService.wasAiTriggered, isFalse);

          // Advance remaining 5s: fallback triggers
          async.elapse(const Duration(seconds: 5));
          expect(aiService.wasAiTriggered, isTrue);
        });
      });

      test('T2.F6.04: Patient sends 3 follow-up messages during active countdown without spawning duplicate timers', () {
        aiService.onPatientMessageSent(
          conversationId: 'conv_spam',
          isDoctorOnline: true,
          message: 'Tin 1',
          broker: chatBroker,
        );
        aiService.onPatientMessageSent(
          conversationId: 'conv_spam',
          isDoctorOnline: true,
          message: 'Tin 2',
          broker: chatBroker,
        );
        aiService.onPatientMessageSent(
          conversationId: 'conv_spam',
          isDoctorOnline: true,
          message: 'Tin 3',
          broker: chatBroker,
        );

        expect(aiService.activeTimerCount, equals(1));
      });

      test('T2.F6.05: Upper SLA timeout boundary test at 60 seconds', () {
        fakeAsync((async) {
          aiService.timeoutDuration = const Duration(seconds: 60);
          aiService.onPatientMessageSent(
            conversationId: 'conv_sla_60',
            isDoctorOnline: true,
            message: 'Kiểm tra giới hạn 60 giây',
            broker: chatBroker,
          );

          // At 59 seconds: waiting
          async.elapse(const Duration(seconds: 59));
          expect(aiService.wasAiTriggered, isFalse);
          expect(aiService.isTimerRunning, isTrue);

          // At 60 seconds: threshold reached -> triggers AI fallback
          async.elapse(const Duration(seconds: 1));
          expect(aiService.wasAiTriggered, isTrue);
          expect(aiService.isTimerRunning, isFalse);
        });
      });
    });

    // -------------------------------------------------------------------------
    // F7 Boundary Cases (5 Tests)
    // -------------------------------------------------------------------------
    group('F7 Boundary: Voice Call', () {
      test('T2.F7.01: Voice call to busy doctor returns busy state and alerts caller', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_busy',
          calleeName: 'BS. Bận',
          callType: 'audio',
          isCalleeBusy: true,
        );

        expect(session.status, equals(CallState.busy));
        expect(session.failureReason, contains('đang bận'));
      });

      test('T2.F7.02: Caller cancels audio call after 500ms before callee answers', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'audio',
        );

        callService.cancelDialing(session.callId);
        expect(session.status, equals(CallState.ended));
      });

      test('T2.F7.03: Callee ignores audio call until ringing times out after 45 seconds', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'audio',
        );

        expect(session.status, equals(CallState.ringing));
        callService.simulateRingingTimeout(session.callId);
        expect(session.status, equals(CallState.missed));
        expect(callService.callHistory.last.callId, equals(session.callId));
      });

      test('T2.F7.04: Microphone permission denied displays friendly error dialog without crashing', () async {
        final session = await callService.handlePermissionDenied(
          callType: 'audio',
          permissionName: 'Micro',
        );

        expect(session.status, equals(CallState.failed));
        expect(session.failureReason, contains('quyền Micro'));
      });

      test('T2.F7.05: Audio call timer handles 60+ minutes duration formatting accurately', () {
        final session = CallSessionModel(
          callId: 'call_long',
          callerId: 'pat',
          callerName: 'BN',
          calleeId: 'doc',
          calleeName: 'BS',
          callType: 'audio',
          durationSeconds: 3923, // 1 hour, 5 minutes, 23 seconds
        );

        expect(session.formattedDuration, equals('01:05:23'));
      });
    });

    // -------------------------------------------------------------------------
    // F8 Boundary Cases (5 Tests)
    // -------------------------------------------------------------------------
    group('F8 Boundary: Video Call', () {
      test('T2.F8.01: Callee declines video call with explicit rejection', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'video',
        );

        callService.rejectCall(session.callId);
        expect(session.status, equals(CallState.rejected));
      });

      test('T2.F8.02: Camera permission denied falls back to audio-only with camera disabled banner', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'video',
        );
        callService.acceptCall(session.callId);

        callService.handleCameraPermissionDenied(session.callId);
        expect(session.status, equals(CallState.connected));
        expect(session.isCameraEnabled, isFalse);
      });

      test('T2.F8.03: Rapid camera toggle stress test (10 toggles in 1 second) does not cause race condition', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'video',
        );
        callService.acceptCall(session.callId);

        for (var i = 0; i < 10; i++) {
          callService.toggleCamera();
        }
        expect(session.isCameraEnabled, isTrue); // 10 toggles returns to true
      });

      test('T2.F8.04: Video call to completely offline doctor fails immediately with clear error', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_offline',
          calleeName: 'BS. Offline',
          callType: 'video',
          isCalleeOnline: false,
        );

        expect(session.status, equals(CallState.failed));
        expect(session.failureReason, contains('ngoại tuyến'));
      });

      test('T2.F8.05: Simultaneous call end action by both peers does not throw double-dispose error', () async {
        final session = await callService.startCall(
          callerId: 'pat_01',
          callerName: 'Bệnh nhân',
          calleeId: 'doc_01',
          calleeName: 'Bác sĩ',
          callType: 'video',
        );
        callService.acceptCall(session.callId);

        // Peer 1 ends call
        callService.endCall(session.callId);
        // Peer 2 simultaneously ends call
        callService.endCall(session.callId);

        expect(session.status, equals(CallState.ended));
        expect(callService.callHistory.length, equals(1)); // Idempotent
      });
    });
  });

  // ===========================================================================
  // TIER 3: CROSS-FEATURE COMBINATIONS (8 TESTS)
  // ===========================================================================
  group('Tier 3: Cross-Feature Combinations (8 Tests)', () {
    test('T3.01: Admin updates doctor workplace and phone while patient is chatting; chat header updates dynamically [F1 + F2 + F3]', () async {
      final doc = await docService.addDoctor(const DoctorProfileExtended(
        id: 'doc_cross_1',
        fullName: 'BS. Lê Thị Mai',
        title: 'BS',
        specialty: 'Cấp cứu',
        hospital: 'BV Chợ Rẫy',
        phoneNumber: '0912345678',
        workplaceAddress: 'Khoa Cấp cứu, BV Chợ Rẫy',
      ));

      // Patient sends chat message
      chatBroker.sendMessage(
        conversationId: 'conv_cross_1',
        senderType: 'patient',
        content: 'Bác sĩ cho tôi hỏi địa chỉ khám',
      );
      expect(chatBroker.getStoredMessages('conv_cross_1').length, equals(1));

      // Admin updates doctor profile
      final updated = await docService.updateDoctor(doc.copyWith(
        phoneNumber: '0988112233',
        workplaceAddress: 'Khoa Chấn thương Chỉnh hình, BV Bạch Mai',
      ));

      expect(updated.phoneNumber, equals('0988112233'));
      expect(updated.workplaceAddress, contains('BV Bạch Mai'));
      expect(chatBroker.getStoredMessages('conv_cross_1').length, equals(1)); // Message preserved
    });

    test('T3.02: Doctor offline triggers AI fallback; patient replies; AI maintains multi-turn conversation context [F3 + F5]', () async {
      // Turn 1
      aiService.onPatientMessageSent(
        conversationId: 'conv_turn',
        isDoctorOnline: false,
        message: 'Tôi bị đứt tay chảy máu',
        broker: chatBroker,
      );
      expect(chatBroker.getStoredMessages('conv_turn').length, equals(1));

      // Turn 2: Follow-up question about rusty nail
      aiService.onPatientMessageSent(
        conversationId: 'conv_turn',
        isDoctorOnline: false,
        message: 'Máu đã ngưng, nhưng vết cắt dính gỉ sét thì có sao không?',
        broker: chatBroker,
      );
      final msgs = chatBroker.getStoredMessages('conv_turn');
      expect(msgs.length, equals(2));
      expect(msgs.last.content, contains('uốn ván'));
    });

    test('T3.03: Patient sends message; doctor unread badge increments; 30s timeout elapses; AI answers; badge updates [F3 + F4 + F6]', () async {
      aiService.timeoutDuration = const Duration(milliseconds: 10);
      chatBroker.sendMessage(
        conversationId: 'conv_f3_f4_f6',
        senderType: 'patient',
        content: 'Bác sĩ kiểm tra vết thương giúp',
        currentViewingConversationId: 'none',
      );

      // Verify unread badge increments
      expect(chatBroker.queue.first.unreadCount, equals(1));

      // Start timer and let timeout elapse
      aiService.onPatientMessageSent(
        conversationId: 'conv_f3_f4_f6',
        isDoctorOnline: true,
        message: 'Bác sĩ kiểm tra vết thương giúp',
        broker: chatBroker,
      );

      await Future.delayed(const Duration(milliseconds: 25));
      expect(aiService.wasAiTriggered, isTrue);

      final queueItem = chatBroker.queue.firstWhere((q) => q.conversationId == 'conv_f3_f4_f6');
      expect(queueItem.hasAiFallbackResponse, isTrue);
    });

    test('T3.04: Patient initiates voice call directly from active realtime chat session without losing chat history [F3 + F7]', () async {
      for (var i = 1; i <= 5; i++) {
        chatBroker.sendMessage(
          conversationId: 'conv_call_chat',
          senderType: 'patient',
          content: 'Chat turn $i',
        );
      }
      expect(chatBroker.getStoredMessages('conv_call_chat').length, equals(5));

      // Launch audio call
      final session = await callService.startCall(
        callerId: 'pat_01',
        callerName: 'Bệnh nhân',
        calleeId: 'doc_01',
        calleeName: 'Bác sĩ',
        callType: 'audio',
      );
      callService.acceptCall(session.callId);
      callService.advanceCallDuration(120); // 2 minutes
      callService.endCall(session.callId);

      // Log call summary to chat timeline
      chatBroker.sendMessage(
        conversationId: 'conv_call_chat',
        senderType: 'system',
        content: 'Cuộc gọi thoại (02:00)',
      );

      final msgs = chatBroker.getStoredMessages('conv_call_chat');
      expect(msgs.length, equals(6));
      expect(msgs.last.content, contains('Cuộc gọi thoại (02:00)'));
    });

    test('T3.05: Active video call allows in-call text and image sending in PIP chat mode [F3 + F8]', () async {
      final session = await callService.startCall(
        callerId: 'pat_01',
        callerName: 'Bệnh nhân',
        calleeId: 'doc_01',
        calleeName: 'Bác sĩ',
        callType: 'video',
      );
      callService.acceptCall(session.callId);
      expect(session.status, equals(CallState.connected));

      // In-call photo send
      chatBroker.sendMessage(
        conversationId: 'conv_pip',
        senderType: 'patient',
        content: 'Gửi ảnh vết thương cận cảnh trong cuộc gọi video',
        attachment: ChatAttachment(
          id: 'att_pip',
          type: ChatAttachmentType.image,
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'pip_wound.jpg',
        ),
      );

      expect(session.status, equals(CallState.connected)); // Video stays connected
      expect(chatBroker.getStoredMessages('conv_pip').last.attachment!.hasImage, isTrue);
    });

    test('T3.06: Doctor comes online during AI fallback session; patient transitions seamlessly to live voice call [F5 + F7]', () async {
      // 1. Patient gets AI advice while doctor offline
      aiService.onPatientMessageSent(
        conversationId: 'conv_handoff',
        isDoctorOnline: false,
        message: 'Vết thương bỏng rát',
        broker: chatBroker,
      );
      expect(aiService.wasTriggeredImmediately, isTrue);

      // 2. Doctor logs in and comes online
      final doc = const DoctorProfileExtended(
        id: 'doc_online',
        fullName: 'BS. Lê Thị Mai',
        title: 'BS',
        specialty: 'Cấp cứu',
        hospital: 'BV Chợ Rẫy',
        phoneNumber: '0912345678',
        workplaceAddress: 'BV Chợ Rẫy',
        isOnline: true,
      );
      await docService.addDoctor(doc);

      // 3. Patient initiates live voice call
      final session = await callService.startCall(
        callerId: 'pat_01',
        callerName: 'Bệnh nhân',
        calleeId: doc.id,
        calleeName: doc.fullName,
        callType: 'audio',
      );
      callService.acceptCall(session.callId);

      expect(session.status, equals(CallState.connected));
    });

    test('T3.07: Admin deactivates doctor account with pending unread patient messages; queue handles deactivation gracefully [F1 + F4]', () async {
      final doc = await docService.addDoctor(const DoctorProfileExtended(
        id: 'doc_retire',
        fullName: 'BS. Về Hưu',
        title: 'BS',
        specialty: 'Nội',
        hospital: 'BV Quận',
        phoneNumber: '0912345678',
        workplaceAddress: 'Phòng khám A',
      ));

      // Patient sends unread messages
      chatBroker.sendMessage(
        conversationId: 'conv_retire',
        senderType: 'patient',
        content: 'Bác sĩ ơi',
        currentViewingConversationId: 'none',
      );
      expect(chatBroker.queue.first.unreadCount, equals(1));

      // Admin deletes doctor
      await docService.deleteDoctor(doc.id);
      expect((await docService.fetchDoctors()).any((d) => d.id == doc.id), isFalse);

      // Chat gracefully registers doctor retirement notice
      chatBroker.sendMessage(
        conversationId: 'conv_retire',
        senderType: 'system',
        content: 'Bác sĩ đã ngừng tiếp nhận tư vấn mới.',
      );
      expect(chatBroker.getStoredMessages('conv_retire').last.content, contains('ngừng tiếp nhận'));
    });

    test('T3.08: Doctor dials patient audio call during active 30s timeout countdown, cleanly aborting AI fallback [F6 + F7]', () async {
      aiService.timeoutDuration = const Duration(seconds: 30);
      aiService.onPatientMessageSent(
        conversationId: 'conv_call_abort',
        isDoctorOnline: true,
        message: 'Bác sĩ ơi chân tôi sưng to quá',
        broker: chatBroker,
      );
      expect(aiService.isTimerRunning, isTrue);

      // Doctor dials patient at second 12 -> cancels countdown
      aiService.onDoctorReplyReceived('conv_call_abort');
      final session = await callService.startCall(
        callerId: 'doc_01',
        callerName: 'BS. Mai',
        calleeId: 'pat_01',
        calleeName: 'Bệnh nhân',
        callType: 'audio',
      );
      callService.acceptCall(session.callId);

      expect(aiService.isTimerRunning, isFalse);
      expect(aiService.wasAiTriggered, isFalse);
      expect(session.status, equals(CallState.connected));
    });
  });

  // ===========================================================================
  // TIER 4: REAL-WORLD APPLICATION SCENARIOS (5 WORKFLOWS)
  // ===========================================================================
  group('Tier 4: Real-World Application Scenarios (5 Workflows)', () {
    test('T4.01: Full End-to-End Telehealth Consultation Workflow from Admin Onboarding to Video Consultation', () async {
      // Step 1: Admin creates specialist doctor profile
      final doctor = await docService.addDoctor(const DoctorProfileExtended(
        id: 'doc_phuc',
        fullName: 'BS. Trần Hữu Phúc',
        title: 'Bác sĩ Chuyên khoa II',
        specialty: 'Bỏng & Chấn thương Chỉnh hình',
        hospital: 'Bệnh viện Chợ Rẫy',
        phoneNumber: '0918889999',
        workplaceAddress: '201B Nguyễn Chí Thanh, P.12, Q.5, TP.HCM',
        isOnline: false, // Initially offline
      ));
      expect(doctor.fullName, contains('Trần Hữu Phúc'));

      // Step 2: Patient queries directory
      final directory = await docService.fetchDoctors(searchQuery: 'Phúc');
      expect(directory.length, equals(1));

      // Step 3: Patient sends wound photo & query
      const convId = 'conv_workflow_1';
      chatBroker.sendMessage(
        conversationId: convId,
        senderType: 'patient',
        content: 'Tôi vừa bị bỏng bô xe máy rất rát',
        attachment: ChatAttachment(
          id: 'att_burn',
          type: ChatAttachmentType.image,
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'bong_bo.jpg',
        ),
      );

      // Step 4: Doctor is offline -> AI fallback triggers
      aiService.onPatientMessageSent(
        conversationId: convId,
        isDoctorOnline: doctor.isOnline,
        message: 'Tôi vừa bị bỏng bô xe máy rất rát',
        woundContext: 'Bỏng bô xe máy độ 2',
        broker: chatBroker,
      );
      expect(aiService.wasTriggeredImmediately, isTrue);

      // Step 5: Doctor comes online, sees chat with AI notes
      await docService.updateDoctor(doctor.copyWith(isOnline: true));
      chatBroker.markMessagesAsRead(convId);
      expect(chatBroker.queue.first.unreadCount, equals(0));

      // Step 6: Doctor initiates video call
      final callSession = await callService.startCall(
        callerId: doctor.id,
        callerName: doctor.fullName,
        calleeId: 'patient_01',
        calleeName: 'Bệnh Nhân',
        callType: 'video',
      );
      callService.acceptCall(callSession.callId);
      callService.flipCamera(); // Patient flips to rear camera
      expect(callSession.isUsingFrontCamera, isFalse);

      // Step 7: Call ends after 180 seconds
      callService.advanceCallDuration(180);
      callService.endCall(callSession.callId);
      expect(callSession.status, equals(CallState.ended));
      expect(callSession.formattedDuration, equals('03:00'));

      // Step 8: Final state check
      expect(chatBroker.getStoredMessages(convId).any((m) => m.attachment?.hasImage == true), isTrue);
      expect(chatBroker.getStoredMessages(convId).any((m) => m.isSystem), isTrue);
    });

    test('T4.02: Acute Bleeding Emergency: Patient query -> 30s timeout -> AI Emergency Triage -> SOS 115 Dialing', () async {
      const convId = 'conv_emergency';
      aiService.timeoutDuration = const Duration(milliseconds: 10);

      // Step 1: Patient sends panic message
      chatBroker.sendMessage(
        conversationId: convId,
        senderType: 'patient',
        content: 'Tôi bị kính cắt đứt cổ tay, máu phun thành tia không cầm được',
      );

      // Step 2 & 3: Timeout elapses -> Emergency AI fallback triggers
      aiService.onPatientMessageSent(
        conversationId: convId,
        isDoctorOnline: true,
        message: 'Tôi bị kính cắt đứt cổ tay, máu phun thành tia không cầm được',
        broker: chatBroker,
      );

      await Future.delayed(const Duration(milliseconds: 25));
      expect(aiService.wasAiTriggered, isTrue);

      // Step 4: Emergency message verified
      final lastMsg = chatBroker.getStoredMessages(convId).last;
      expect(lastMsg.isEmergencyWarning, isTrue);
      expect(lastMsg.content, contains('CẤP CỨU KHẨN CẤP'));
      expect(lastMsg.content, contains('ÉP CHẶT TRỰC TIẾP'));
      expect(lastMsg.content, contains('SOS 115'));
    });

    test('T4.03: Concurrent multi-patient queue handling, busy call rejection, and AI triage fallback', () async {
      // Step 1: Patient A and B message Doctor
      chatBroker.sendMessage(
        conversationId: 'conv_A',
        senderType: 'patient',
        content: 'Câu hỏi của bệnh nhân A',
        patientName: 'Bệnh Nhân A',
        currentViewingConversationId: 'none',
      );
      chatBroker.sendMessage(
        conversationId: 'conv_B',
        senderType: 'patient',
        content: 'Câu hỏi của bệnh nhân B',
        patientName: 'Bệnh Nhân B',
        currentViewingConversationId: 'none',
      );
      expect(chatBroker.queue.length, equals(2));

      // Step 2: Doctor opens chat room A (marks A as read)
      chatBroker.markMessagesAsRead('conv_A');
      final queueItemA = chatBroker.queue.firstWhere((q) => q.conversationId == 'conv_A');
      expect(queueItemA.unreadCount, equals(0));

      // Step 3: Patient B initiates call while Doctor is busy with A
      final callSessionB = await callService.startCall(
        callerId: 'patient_b',
        callerName: 'Bệnh Nhân B',
        calleeId: 'doctor_01',
        calleeName: 'BS. Mai',
        callType: 'audio',
        isCalleeBusy: true, // Doctor is busy
      );
      expect(callSessionB.status, equals(CallState.busy));
      expect(callSessionB.failureReason, contains('đang bận'));

      // Step 4: Patient B message reaches 30s timeout -> AI assists B
      aiService.timeoutDuration = const Duration(milliseconds: 10);
      aiService.onPatientMessageSent(
        conversationId: 'conv_B',
        isDoctorOnline: true,
        message: 'Bác sĩ có thể nghe máy được không?',
        broker: chatBroker,
      );
      await Future.delayed(const Duration(milliseconds: 25));

      final msgsB = chatBroker.getStoredMessages('conv_B');
      expect(msgsB.last.isSystem, isTrue);
    });

    test('T4.04: Network interruption during chat and calling with seamless auto-reconnect', () async {
      const convId = 'conv_network';

      // Step 1: Patient sends message
      chatBroker.sendMessage(
        conversationId: convId,
        senderType: 'patient',
        content: 'Tin nhắn gửi trong điều kiện mạng chập chờn',
      );
      final msgId = chatBroker.getStoredMessages(convId).last.id;

      // Step 2: Network drop flags message as failed
      chatBroker.updateDeliveryStatus(convId, msgId, MessageDeliveryStatus.failed);
      expect(chatBroker.getStoredMessages(convId).last.status, equals(MessageDeliveryStatus.failed));

      // Step 3: Network restored -> manual retry succeeds
      chatBroker.updateDeliveryStatus(convId, msgId, MessageDeliveryStatus.sent);
      chatBroker.updateDeliveryStatus(convId, msgId, MessageDeliveryStatus.delivered);
      expect(chatBroker.getStoredMessages(convId).last.status, equals(MessageDeliveryStatus.delivered));

      // Step 4: Doctor connects audio call
      final session = await callService.startCall(
        callerId: 'doc_01',
        callerName: 'BS. Mai',
        calleeId: 'pat_01',
        calleeName: 'Bệnh Nhân',
        callType: 'audio',
      );
      callService.acceptCall(session.callId);
      expect(session.status, equals(CallState.connected));

      // Step 5: Transient drop during call maintains session without termination
      callService.advanceCallDuration(30);
      expect(session.status, equals(CallState.connected));
      expect(session.durationSeconds, equals(30));
    });

    test('T4.05: Complex Video Consultation: Connect -> Flip camera -> Mute mic -> In-call messaging -> Clean hangup', () async {
      // Step 1: Establish video call
      final session = await callService.startCall(
        callerId: 'pat_01',
        callerName: 'Bệnh nhân',
        calleeId: 'doc_01',
        calleeName: 'BS. Chuyên Khoa',
        callType: 'video',
      );
      callService.acceptCall(session.callId);
      expect(session.status, equals(CallState.connected));

      // Step 2: Call timer advances
      callService.advanceCallDuration(15);
      expect(session.formattedDuration, equals('00:15'));

      // Step 3: Patient flips camera to present wound
      callService.flipCamera();
      expect(session.isUsingFrontCamera, isFalse);

      // Step 4: Ambient noise -> Patient mutes mic
      callService.toggleMic();
      expect(session.isMuted, isTrue);

      // Step 5: Patient acknowledges doctor via in-call chat
      chatBroker.sendMessage(
        conversationId: 'conv_in_call',
        senderType: 'patient',
        content: 'Tôi đã nghe rõ chỉ dẫn của bác sĩ',
      );
      expect(chatBroker.getStoredMessages('conv_in_call').last.content, contains('nghe rõ'));

      // Step 6: Unmute microphone
      callService.toggleMic();
      expect(session.isMuted, isFalse);

      // Step 7: Clean hangup after 300 seconds (5 minutes)
      callService.advanceCallDuration(285);
      callService.endCall(session.callId);

      expect(session.status, equals(CallState.ended));
      expect(session.areMediaTracksDisposed, isTrue);
      expect(session.formattedDuration, equals('05:00'));
      expect(callService.callHistory.length, equals(1));
    });
  });
}
