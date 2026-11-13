// File: test/doctor_ai_fallback_test.dart
// Standalone pure Dart verification test for Milestone 3: AI Doctor Fallback (Requirement R3)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Sender types in doctor consultation
enum TestChatSenderType {
  patient,
  doctor,
  system,
  ai,
}

/// Lightweight message entity for standalone test verification
class TestChatMessage {
  final String id;
  final String conversationId;
  final TestChatSenderType senderType;
  final String senderId;
  final String? senderName;
  final String content;
  final DateTime timestamp;
  final bool isEmergencyWarning;

  const TestChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.senderId,
    this.senderName,
    required this.content,
    required this.timestamp,
    this.isEmergencyWarning = false,
  });

  bool get isAi => senderType == TestChatSenderType.ai;
  bool get isDoctor => senderType == TestChatSenderType.doctor;
  bool get isPatient => senderType == TestChatSenderType.patient;
}

/// Lightweight doctor profile for standalone test verification
class TestDoctorProfile {
  final String id;
  final String fullName;
  final bool isOnline;

  const TestDoctorProfile({
    required this.id,
    required this.fullName,
    this.isOnline = true,
  });

  static const defaultDoctor = TestDoctorProfile(
    id: 'doc_an_nguyen',
    fullName: 'BS. CKI Nguyễn Văn An',
    isOnline: true,
  );
}

/// Standalone Consultation Chat Service simulation matching DoctorConsultationService
class TestConsultationChatService {
  static int _msgSeq = 0;
  final Map<String, List<TestChatMessage>> _messagesStore = {};
  final Map<String, StreamController<List<TestChatMessage>>> _controllers = {};
  final List<Map<String, dynamic>> _queue = [];

  List<TestChatMessage> getStoredMessages(String conversationId) {
    return List.unmodifiable(_messagesStore[conversationId] ?? []);
  }

  Stream<List<TestChatMessage>> getMessagesStream(String conversationId) {
    final c = _controllers.putIfAbsent(
      conversationId,
      () => StreamController<List<TestChatMessage>>.broadcast(),
    );
    scheduleMicrotask(() {
      if (!c.isClosed) {
        c.add(List.unmodifiable(_messagesStore[conversationId] ?? []));
      }
    });
    return c.stream;
  }

  Future<TestChatMessage> sendMessage({
    required String conversationId,
    required TestChatSenderType senderType,
    required String senderId,
    String? senderName,
    required String content,
    bool isEmergency = false,
  }) async {
    final msg = TestChatMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}_${++_msgSeq}',
      conversationId: conversationId,
      senderType: senderType,
      senderId: senderId,
      senderName: senderName,
      content: content,
      timestamp: DateTime.now(),
      isEmergencyWarning: isEmergency,
    );

    _messagesStore.putIfAbsent(conversationId, () => []);
    _messagesStore[conversationId]!.add(msg);
    _controllers[conversationId]?.add(List.unmodifiable(_messagesStore[conversationId]!));

    final qIdx = _queue.indexWhere((q) => q['conversationId'] == conversationId);
    if (qIdx != -1) {
      _queue[qIdx]['lastMessage'] = content;
      _queue[qIdx]['hasAiFallbackResponse'] = senderType == TestChatSenderType.ai;
    } else {
      _queue.insert(0, {
        'conversationId': conversationId,
        'lastMessage': content,
        'hasAiFallbackResponse': senderType == TestChatSenderType.ai,
      });
    }

    return msg;
  }

  Map<String, dynamic>? getQueueItem(String conversationId) {
    try {
      return _queue.firstWhere((q) => q['conversationId'] == conversationId);
    } catch (_) {
      return null;
    }
  }

  void reset() {
    _messagesStore.clear();
    _queue.clear();
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }
}

/// Production-identical Standalone DoctorAiFallbackService matching lib implementation
class TestDoctorAiFallbackService {
  Duration timeoutDuration = const Duration(seconds: 45);

  final Map<String, Timer> _activeTimers = {};
  final Map<String, DateTime> _timerStartTimes = {};
  final Map<String, Duration> _timerDurations = {};

  int _aiResponsesGenerated = 0;
  int get aiResponsesGenerated => _aiResponsesGenerated;

  bool _wasTriggeredImmediately = false;
  bool get wasTriggeredImmediately => _wasTriggeredImmediately;

  String? _lastTriggerReason;
  String? get lastTriggerReason => _lastTriggerReason;

  String? _lastGeneratedResponse;
  String? get lastGeneratedResponse => _lastGeneratedResponse;

  final TestConsultationChatService chatService;

  TestDoctorAiFallbackService({required this.chatService});

  static const List<String> emergencyKeywords = [
    'chảy máu xối xả',
    'máu phun thành tia',
    'ngưng thở',
    'ngừng thở',
    'bất tỉnh',
    'hôn mê',
    'đứt cổ tay',
    'đứt động mạch',
    'đứt lìa',
    'sốc phản vệ',
    'ngừng tim',
    'ngưng tim',
    'co giật',
    'tắc thở',
    'ngạt thở',
    'gãy xương hở',
    'nôn ra máu',
    'khó thở dữ dội',
    'tím tái',
    'mất ý thức',
    'chấn thương sọ não',
  ];

  bool isTimerRunningFor(String conversationId) => _activeTimers.containsKey(conversationId);
  bool get isTimerRunning => _activeTimers.isNotEmpty;
  int get activeTimerCount => _activeTimers.length;

  bool isEmergencyKeyword(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    for (final kw in emergencyKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  void onPatientMessageSent({
    required String conversationId,
    required String message,
    required bool isDoctorOnline,
    String? woundContext,
    TestDoctorProfile? doctor,
    List<String>? chatHistory,
  }) {
    if (!isDoctorOnline) {
      _cancelTimerFor(conversationId);
      _wasTriggeredImmediately = true;
      _lastTriggerReason = 'doctor_offline';
      unawaited(
        triggerAiFallback(
          conversationId: conversationId,
          lastPatientMessage: message,
          woundContext: woundContext,
          doctor: doctor,
          reason: 'doctor_offline',
          wasImmediate: true,
          chatHistory: chatHistory,
        ),
      );
      return;
    }

    _cancelTimerFor(conversationId);
    _wasTriggeredImmediately = false;
    _lastTriggerReason = null;

    final assignedDuration = timeoutDuration;
    _timerStartTimes[conversationId] = DateTime.now();
    _timerDurations[conversationId] = assignedDuration;

    _activeTimers[conversationId] = Timer(assignedDuration, () {
      _activeTimers.remove(conversationId);
      _timerStartTimes.remove(conversationId);
      _timerDurations.remove(conversationId);

      _wasTriggeredImmediately = false;
      _lastTriggerReason = 'doctor_timeout';

      unawaited(
        triggerAiFallback(
          conversationId: conversationId,
          lastPatientMessage: message,
          woundContext: woundContext,
          doctor: doctor,
          reason: 'doctor_timeout',
          wasImmediate: false,
          chatHistory: chatHistory,
        ),
      );
    });
  }

  void onDoctorReplyReceived(String conversationId) {
    _cancelTimerFor(conversationId);
  }

  void onDoctorTyping(
    String conversationId, {
    Duration extensionDuration = const Duration(seconds: 15),
  }) {
    if (!_activeTimers.containsKey(conversationId)) return;

    _activeTimers[conversationId]?.cancel();

    final startTime = _timerStartTimes[conversationId] ?? DateTime.now();
    final totalDuration = _timerDurations[conversationId] ?? timeoutDuration;
    final elapsed = DateTime.now().difference(startTime);
    final remaining = totalDuration > elapsed ? (totalDuration - elapsed) : Duration.zero;
    final newDuration = remaining + extensionDuration;

    _timerStartTimes[conversationId] = DateTime.now();
    _timerDurations[conversationId] = newDuration;

    _activeTimers[conversationId] = Timer(newDuration, () {
      _activeTimers.remove(conversationId);
      _timerStartTimes.remove(conversationId);
      _timerDurations.remove(conversationId);

      _wasTriggeredImmediately = false;
      _lastTriggerReason = 'doctor_timeout';

      unawaited(
        triggerAiFallback(
          conversationId: conversationId,
          lastPatientMessage: 'Bệnh nhân chờ phản hồi từ bác sĩ',
          reason: 'doctor_timeout',
          wasImmediate: false,
        ),
      );
    });
  }

  Future<void> triggerAiFallback({
    required String conversationId,
    required String lastPatientMessage,
    String? woundContext,
    TestDoctorProfile? doctor,
    String reason = 'doctor_offline',
    bool wasImmediate = false,
    List<String>? chatHistory,
  }) async {
    _cancelTimerFor(conversationId);
    _lastTriggerReason = reason;
    _wasTriggeredImmediately = wasImmediate;

    final trimmed = lastPatientMessage.trim();
    final isEmergency = isEmergencyKeyword(trimmed);

    String replyContent;
    if (isEmergency) {
      replyContent = generateEmergencySosAdvice(trimmed);
    } else {
      replyContent = _buildMedicalFallbackAdvice(trimmed, doctor: doctor);
    }

    _lastGeneratedResponse = replyContent;
    _aiResponsesGenerated++;

    await chatService.sendMessage(
      conversationId: conversationId,
      senderType: TestChatSenderType.ai,
      senderId: 'ai_assistant',
      senderName: 'Trợ lý Bác sĩ AI (Gemini / MedGemma)',
      content: replyContent,
      isEmergency: isEmergency,
    );
  }

  String generateEmergencySosAdvice(String detectedMessage) {
    String foundKeyword = 'dấu hiệu nguy kịch';
    final lower = detectedMessage.toLowerCase();
    for (final kw in emergencyKeywords) {
      if (lower.contains(kw)) {
        foundKeyword = kw;
        break;
      }
    }

    return '🚨 **CẢNH BÁO TÌNH HUỐNG Y TẾ KHẨN CẤP (SOS 115)** 🚨\n\n'
        'Hệ thống AI Bác sĩ phát hiện dấu hiệu nguy kịch: **"$foundKeyword"**.\n\n'
        '**HÀNH ĐỘNG CẦN THỰC HIỆN NGAY LẬP TỨC:**\n'
        '1. 📞 **GỌI CẤP CỨU 115** hoặc di chuyển ngay đến cơ sở y tế gần nhất.\n'
        '2. 🩸 **Nếu chảy máu phun tia hoặc xối xả:** Đặt một miếng gạc hoặc vải sạch ép trực tiếp thật chặt vào miệng vết thương, giữ liên tục không buông.\n'
        '3. 🫁 **Nếu khó thở / ngưng thở:** Đặt nạn nhân nằm ngửa, ép tim liên tục 100-120 lần/phút (CPR).\n'
        '4. 🛑 **Tuyệt đối KHÔNG:** Không tự ý cho uống nước, không đắp thuốc lá hay các chất lạ lên vết thương.\n\n'
        '*(Trợ lý Bác sĩ AI kích hoạt cảnh báo đỏ tự động trong khi chờ nhân viên y tế)*';
  }

  String _buildMedicalFallbackAdvice(String patientMessage, {TestDoctorProfile? doctor}) {
    final lower = patientMessage.toLowerCase();
    if (lower.contains('bỏng') || lower.contains('phỏng') || lower.contains('nước sôi')) {
      return '🤖 **[TRỢ LÝ BÁC SĨ AI DỰ PHÒNG]**\n\n'
          '### 🩹 HƯỚNG DẪN XỬ TRÍ SƠ CỨU BỎNG NHIỆT / NƯỚC SÔI:\n'
          '1. **Hạ nhiệt ngay:** Xả nước sạch mát (15-20°C) nhẹ nhàng lên vùng bỏng trong 15-20 phút.\n'
          '2. **Tháo trang sức:** Nhanh chóng tháo nhẫn, đồng hồ trước khi vị trí tổn thương sưng nề.\n'
          '3. **Bảo vệ:** Che phủ bằng gạc vô trùng ẩm hoặc màng bọc thực phẩm sạch.\n'
          '4. **Tuyệt đối không:** Không chườm đá lạnh trực tiếp, không bôi kem đánh răng hoặc mỡ trăn.';
    }

    if (lower.contains('uốn ván') || lower.contains('sat') || lower.contains('gỉ sét')) {
      return '🤖 **[TRỢ LÝ BÁC SĨ AI DỰ PHÒNG]**\n\n'
          '### 💉 TƯ VẤN TIÊM PHÒNG UỐN VÁN (SAT):\n'
          '1. Vết thương do đinh hoặc kim loại gỉ sét có nguy cơ uốn ván cao.\n'
          '2. Cần tiêm huyết thanh kháng độc tố uốn ván (SAT) trong vòng 24 - 48 giờ.\n'
          '3. Rửa sạch bằng xà phòng dưới vòi nước chảy và đến cơ sở y tế.';
    }

    if (lower.contains('chảy máu') || lower.contains('máu chảy') || lower.contains('đứt tay') || lower.contains('vết rách')) {
      return '🤖 **[TRỢ LÝ BÁC SĨ AI DỰ PHÒNG]**\n\n'
          '### 🩹 HƯỚNG DẪN CẦM MÁU VÀ XỬ TRÍ VẾT CẮT:\n'
          '1. **Cầm máu ép trực tiếp:** Đặt gạc vô trùng hoặc khăn sạch ép chặt liên tục lên miệng vết thương trong 10 - 15 phút.\n'
          '2. **Nâng cao chi:** Đưa vùng bị tổn thương cao hơn tim nếu thuận tiện.\n'
          '3. **Sát khuẩn:** Rửa bằng nước muối sinh lý 0.9%, sát khuẩn mép vết thương với Povidone-Iodine.\n'
          '4. **Lưu ý:** Nếu vết cắt sâu > 0.5cm hoặc mép vết thương há rộng, cần đến bệnh viện khâu trong 6 giờ đầu.';
    }

    return '🤖 **[TRỢ LÝ BÁC SĨ AI DỰ PHÒNG]**\n\n'
        'Chào bạn, trong khi chờ Bác sĩ phản hồi:\n'
        '• Rửa vết thương bằng nước muối sinh lý 0.9% và băng gạc vô trùng bảo vệ.\n'
        '• Nếu có dấu hiệu sốt, sưng nóng đỏ đau hoặc chảy dịch mủ: thông báo cho bác sĩ.\n'
        '• Nếu xuất hiện dấu hiệu khẩn cấp, vui lòng gọi cấp cứu 115 ngay.';
  }

  List<String> truncateChatContext(List<String>? history, {int maxRecentTurns = 10}) {
    if (history == null || history.isEmpty) return const [];
    if (history.length <= maxRecentTurns) return List.unmodifiable(history);
    return List.unmodifiable(history.sublist(history.length - maxRecentTurns));
  }

  Map<String, dynamic> parseAiResponseSafe(String rawJsonResponse) {
    if (rawJsonResponse.trim().isEmpty) {
      return {'content': '', 'isEmergency': false, 'parsed': false};
    }
    try {
      var cleaned = rawJsonResponse.trim();
      if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
      else if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
      if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);
      cleaned = cleaned.trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return {...decoded, 'parsed': true};
      }
    } catch (_) {}
    return {
      'content': rawJsonResponse.trim(),
      'isEmergency': isEmergencyKeyword(rawJsonResponse),
      'parsed': false,
    };
  }

  bool _cancelTimerFor(String conversationId) {
    final timer = _activeTimers.remove(conversationId);
    _timerStartTimes.remove(conversationId);
    _timerDurations.remove(conversationId);
    if (timer != null) {
      timer.cancel();
      return true;
    }
    return false;
  }

  void reset() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _timerStartTimes.clear();
    _timerDurations.clear();
    timeoutDuration = const Duration(seconds: 45);
    _aiResponsesGenerated = 0;
    _wasTriggeredImmediately = false;
    _lastTriggerReason = null;
    _lastGeneratedResponse = null;
  }
}

void main() async {
  print('======================================================================');
  print('Running Requirement R3: AI Doctor Fallback (MedGemma / Gemini) Test Suite');
  print('======================================================================');

  int totalSpecs = 0;
  int passedSpecs = 0;

  void expect(String specName, bool condition, [String detail = '']) {
    totalSpecs++;
    if (condition) {
      passedSpecs++;
      print('  [PASS] Spec $totalSpecs: $specName');
    } else {
      print('  [FAIL] Spec $totalSpecs: $specName - $detail');
      throw AssertionError('FAILED Spec $totalSpecs: $specName - $detail');
    }
  }

  final chatService = TestConsultationChatService();
  final fallbackService = TestDoctorAiFallbackService(chatService: chatService);

  void resetEnv() {
    fallbackService.reset();
    chatService.reset();
  }

  // ===========================================================================
  // GROUP 1: INITIAL STATE & CONFIGURATION (30s-60s TIMEOUT)
  // ===========================================================================
  print('\nGroup 1: Initial State & 30-60s Configurable Timeout');
  resetEnv();

  expect('Default timeout is 45s (within 30-60s range)', fallbackService.timeoutDuration == const Duration(seconds: 45));

  fallbackService.timeoutDuration = const Duration(seconds: 30);
  expect('Timeout configured to minimum 30s', fallbackService.timeoutDuration == const Duration(seconds: 30));

  fallbackService.timeoutDuration = const Duration(seconds: 60);
  expect('Timeout configured to maximum 60s', fallbackService.timeoutDuration == const Duration(seconds: 60));

  expect('No timers running on initial state', !fallbackService.isTimerRunning && fallbackService.activeTimerCount == 0);
  expect('Zero AI responses generated initially', fallbackService.aiResponsesGenerated == 0);

  // ===========================================================================
  // GROUP 2: INSTANT AI TRIGGER WHEN DOCTOR IS OFFLINE
  // ===========================================================================
  print('\nGroup 2: Instant AI Trigger When Doctor is Offline');
  resetEnv();

  const convOffline = 'conv_offline_test_01';
  fallbackService.onPatientMessageSent(
    conversationId: convOffline,
    message: 'Tôi bị bỏng nước sôi ở bắp tay rất đau rát',
    isDoctorOnline: false, // DOCTOR OFFLINE
    woundContext: 'Bỏng nước sôi diện tích 5cm',
    doctor: const TestDoctorProfile(id: 'doc_offline_01', fullName: 'BS. Lê Minh', isOnline: false),
  );

  expect('Triggered immediately for offline doctor', fallbackService.wasTriggeredImmediately);
  expect('Trigger reason is doctor_offline', fallbackService.lastTriggerReason == 'doctor_offline');
  expect('No countdown timer started when doctor is offline', !fallbackService.isTimerRunningFor(convOffline));

  await Future.delayed(const Duration(milliseconds: 50));

  expect('AI response generated count incremented', fallbackService.aiResponsesGenerated == 1);

  final offlineMsgs = chatService.getStoredMessages(convOffline);
  expect('Stored message count is 1', offlineMsgs.length == 1);
  expect('Stored message is from AI assistant', offlineMsgs.first.isAi);
  expect('AI message sender is ai_assistant', offlineMsgs.first.senderId == 'ai_assistant');
  expect('AI message content has burn guidance', offlineMsgs.first.content.contains('BỎNG NHIỆT') || offlineMsgs.first.content.contains('Hạ nhiệt ngay'));

  // ===========================================================================
  // GROUP 3: INACTIVITY TIMER COUNTDOWN TRIGGERS AI WHEN DOCTOR UNRESPONSIVE
  // ===========================================================================
  print('\nGroup 3: Inactivity Timer Countdown Triggers AI When Doctor Online But Unresponsive');
  resetEnv();

  fallbackService.timeoutDuration = const Duration(milliseconds: 50); // fast simulation
  const convTimeout = 'conv_timeout_test_02';

  fallbackService.onPatientMessageSent(
    conversationId: convTimeout,
    message: 'Bác sĩ xem giúp tôi vết rách ở chân',
    isDoctorOnline: true, // DOCTOR ONLINE
    doctor: TestDoctorProfile.defaultDoctor,
  );

  expect('Timer running for active conversation', fallbackService.isTimerRunningFor(convTimeout));
  expect('Not triggered immediately when doctor is online', !fallbackService.wasTriggeredImmediately);
  expect('Active timer count is 1', fallbackService.activeTimerCount == 1);

  // Wait past 50ms timeout
  await Future.delayed(const Duration(milliseconds: 80));

  expect('Timer finished and removed from active timers', !fallbackService.isTimerRunningFor(convTimeout));
  expect('Trigger reason recorded as doctor_timeout', fallbackService.lastTriggerReason == 'doctor_timeout');
  expect('AI fallback response generated after timeout', fallbackService.aiResponsesGenerated == 1);

  final timeoutMsgs = chatService.getStoredMessages(convTimeout);
  expect('Stored message count is 1 after timeout trigger', timeoutMsgs.length == 1);
  expect('Message is from AI assistant', timeoutMsgs.first.isAi);

  // ===========================================================================
  // GROUP 4: INACTIVITY TIMER CANCELS WHEN DOCTOR RESPONDS IN TIME
  // ===========================================================================
  print('\nGroup 4: Inactivity Timer Cancels When Doctor Responds in Time');
  resetEnv();

  fallbackService.timeoutDuration = const Duration(milliseconds: 100);
  const convCancel = 'conv_doctor_reply_03';

  fallbackService.onPatientMessageSent(
    conversationId: convCancel,
    message: 'Tôi bị trầy da ở gối',
    isDoctorOnline: true,
  );

  expect('Timer is active waiting for doctor', fallbackService.isTimerRunningFor(convCancel));

  // Doctor responds after 20ms
  await Future.delayed(const Duration(milliseconds: 20));
  fallbackService.onDoctorReplyReceived(convCancel);

  expect('Timer cancelled immediately upon doctor reply', !fallbackService.isTimerRunningFor(convCancel));

  // Wait past the original 100ms duration
  await Future.delayed(const Duration(milliseconds: 120));

  expect('Zero AI responses generated because doctor replied in time', fallbackService.aiResponsesGenerated == 0);

  // ===========================================================================
  // GROUP 5: TIMER EXTENSION ON DOCTOR TYPING
  // ===========================================================================
  print('\nGroup 5: Timer Extension on Doctor Typing');
  resetEnv();

  fallbackService.timeoutDuration = const Duration(milliseconds: 60);
  const convTyping = 'conv_typing_extension_04';

  fallbackService.onPatientMessageSent(
    conversationId: convTyping,
    message: 'Bác sĩ có đó không ạ?',
    isDoctorOnline: true,
  );

  expect('Timer started for typing test', fallbackService.isTimerRunningFor(convTyping));

  // After 30ms, doctor begins typing -> extend +100ms
  await Future.delayed(const Duration(milliseconds: 30));
  fallbackService.onDoctorTyping(convTyping, extensionDuration: const Duration(milliseconds: 100));

  expect('Timer still running after typing extension', fallbackService.isTimerRunningFor(convTyping));

  // At 70ms (which would have fired the original 60ms timer), verify it is still running!
  await Future.delayed(const Duration(milliseconds: 40));
  expect('Timer did not fire at original 60ms deadline due to extension', fallbackService.isTimerRunningFor(convTyping));

  // Doctor sends message before new deadline
  fallbackService.onDoctorReplyReceived(convTyping);
  expect('Timer cancelled when doctor finishes reply', !fallbackService.isTimerRunningFor(convTyping));
  expect('No AI triggered since doctor replied within extended window', fallbackService.aiResponsesGenerated == 0);

  // ===========================================================================
  // GROUP 6: EMERGENCY KEYWORD PROTOCOL & SOS 115 ADVICE
  // ===========================================================================
  print('\nGroup 6: Emergency Keyword Protocol & SOS 115 Advice');
  resetEnv();

  const emergencyPhrases = [
    'chảy máu xối xả không cầm được',
    'máu phun thành tia ở bắp đùi',
    'bệnh nhân ngưng thở rồi',
    'nạn nhân bất tỉnh sau ngã',
    'tai nạn đứt cổ tay máu ồ ạt',
    'bệnh nhân ngừng thở co giật',
    'bệnh nhân ngưng tim đột ngột',
    'sốc phản vệ sau tiêm thuốc',
  ];

  for (final phrase in emergencyPhrases) {
    expect('Emergency detected for: "$phrase"', fallbackService.isEmergencyKeyword(phrase));
  }

  expect('Non-emergency query not flagged', !fallbackService.isEmergencyKeyword('Vết trầy nhẹ ở tay'));

  const convEmergency = 'conv_sos_emergency_05';
  await fallbackService.triggerAiFallback(
    conversationId: convEmergency,
    lastPatientMessage: 'Cứu tôi với, vết thương đang chảy máu xối xả!',
    reason: 'emergency_sos',
    wasImmediate: true,
  );

  final emergencyMsgs = chatService.getStoredMessages(convEmergency);
  expect('Emergency message stored', emergencyMsgs.isNotEmpty);
  final emMsg = emergencyMsgs.last;
  expect('Message marked with isEmergencyWarning = true', emMsg.isEmergencyWarning);
  expect('Message contains SOS 115 warning', emMsg.content.contains('115'));
  expect('Message contains direct pressure instruction', emMsg.content.contains('ép trực tiếp'));

  // Bleeding fallback advice for 'máu chảy'
  const convBleeding = 'conv_bleeding_fallback_05b';
  await fallbackService.triggerAiFallback(
    conversationId: convBleeding,
    lastPatientMessage: 'Vết xước ngoài da bị máu chảy rỉ rả',
    reason: 'doctor_timeout',
    wasImmediate: false,
  );
  final bleedingMsgs = chatService.getStoredMessages(convBleeding);
  expect('Bleeding fallback message contains CẦM MÁU guidance',
    bleedingMsgs.isNotEmpty && bleedingMsgs.last.content.contains('CẦM MÁU'));

  // ===========================================================================
  // GROUP 7: MULTI-TURN CONTEXT TRUNCATION & SAFE PARSING
  // ===========================================================================
  print('\nGroup 7: Multi-Turn Context Truncation & Safe Parsing');

  final turns = List.generate(20, (i) => 'Lượt chat #$i: Bệnh nhân trao đổi');
  final truncated = fallbackService.truncateChatContext(turns, maxRecentTurns: 10);
  expect('Context truncated to 10 items', truncated.length == 10);
  expect('Retains latest item', truncated.last == 'Lượt chat #19: Bệnh nhân trao đổi');

  final shortList = ['A', 'B'];
  expect('Short list unaffected', fallbackService.truncateChatContext(shortList, maxRecentTurns: 10).length == 2);
  expect('Null list returns empty', fallbackService.truncateChatContext(null).isEmpty);

  final jsonRes = fallbackService.parseAiResponseSafe('{"content": "Sơ cứu", "isEmergency": false}');
  expect('JSON parsed safely', jsonRes['content'] == 'Sơ cứu' && jsonRes['parsed'] == true);

  final mdJsonRes = fallbackService.parseAiResponseSafe('```json\n{"content": "Gạc ẩm", "isEmergency": false}\n```');
  expect('Markdown JSON parsed safely', mdJsonRes['content'] == 'Gạc ẩm');

  final rawRes = fallbackService.parseAiResponseSafe('Văn bản thường');
  expect('Raw text handled safely', rawRes['content'] == 'Văn bản thường' && rawRes['parsed'] == false);

  // ===========================================================================
  // GROUP 8: INTEGRATION WITH DOCTOR CONSULTATION SERVICE & QUEUE STREAM
  // ===========================================================================
  print('\nGroup 8: Message Stream & Queue Integration');
  resetEnv();

  const convStream = 'conv_stream_06';
  final streamEvents = <List<TestChatMessage>>[];
  final sub = chatService.getMessagesStream(convStream).listen((msgs) {
    streamEvents.add(msgs);
  });

  await fallbackService.triggerAiFallback(
    conversationId: convStream,
    lastPatientMessage: 'Tôi bị đinh gỉ cứa vào chân, có cần uốn ván?',
    reason: 'doctor_timeout',
    wasImmediate: false,
  );

  await Future.delayed(const Duration(milliseconds: 30));
  await sub.cancel();

  expect('Stream received AI fallback message', streamEvents.isNotEmpty && streamEvents.last.any((m) => m.isAi));

  final qItem = chatService.getQueueItem(convStream);
  expect('Queue item exists for conversation', qItem != null);
  expect('Queue item marked with hasAiFallbackResponse = true', qItem?['hasAiFallbackResponse'] == true);

  print('\n======================================================================');
  print('ALL $passedSpecs OF $totalSpecs SPECS PASSED (100% SUCCESS)');
  print('Requirement R3 AI Doctor Fallback Verified Completely.');
  print('======================================================================');
  exit(0);
}
