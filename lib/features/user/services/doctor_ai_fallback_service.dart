// File: lib/features/user/services/doctor_ai_fallback_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../core/gemini/gemini_service.dart';
import '../models/doctor_consultation_models.dart';
import 'doctor_consultation_service.dart';

/// Dịch vụ kích hoạt Trợ lý Bác sĩ AI dự phòng (Gemini API / MedGemma)
/// Tự động phản hồi bệnh nhân khi Bác sĩ thật offline hoặc không trả lời trong vòng 30-60 giây.
class DoctorAiFallbackService extends ChangeNotifier {
  DoctorAiFallbackService._internal();

  /// Singleton instance
  static final DoctorAiFallbackService instance = DoctorAiFallbackService._internal();

  /// Thời gian chờ mặc định kích hoạt AI dự phòng (từ 30s đến 60s, mặc định 45s)
  Duration _timeoutDuration = const Duration(seconds: 45);
  Duration get timeoutDuration => _timeoutDuration;
  set timeoutDuration(Duration duration) {
    _timeoutDuration = duration;
    notifyListeners();
  }

  /// Quản lý danh sách đếm ngược hoạt động theo từng mã cuộc hội thoại (conversationId)
  final Map<String, Timer> _activeTimers = {};

  /// Lưu trữ thời gian bắt đầu và thời hạn của từng timer phục vụ tính năng gia hạn (extension)
  final Map<String, DateTime> _timerStartTimes = {};
  final Map<String, Duration> _timerDurations = {};

  /// Đếm số lượt AI đã phản hồi
  int _aiResponsesGenerated = 0;
  int get aiResponsesGenerated => _aiResponsesGenerated;

  /// Cờ kiểm tra cuộc gọi gần nhất có được kích hoạt tức thì hay không
  bool _wasTriggeredImmediately = false;
  bool get wasTriggeredImmediately => _wasTriggeredImmediately;

  /// Lý do kích hoạt gần nhất ('doctor_offline', 'doctor_timeout', 'manual')
  String? _lastTriggerReason;
  String? get lastTriggerReason => _lastTriggerReason;

  /// Nội dung phản hồi AI gần nhất
  String? _lastGeneratedResponse;
  String? get lastGeneratedResponse => _lastGeneratedResponse;

  /// Danh mục các từ khóa cấp cứu nguy kịch đe dọa tính mạng (Emergency Keyword Protocol)
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

  // ===========================================================================
  // INSPECTION & LIVENESS GETTERS
  // ===========================================================================

  /// Kiểm tra có timer nào đang chạy cho cuộc hội thoại này không
  bool isTimerRunningFor(String conversationId) => _activeTimers.containsKey(conversationId);

  /// Kiểm tra xem có bất kỳ timer nào đang hoạt động trong toàn hệ thống
  bool get isTimerRunning => _activeTimers.isNotEmpty;

  /// Số lượng timer đếm ngược đang kích hoạt
  int get activeTimerCount => _activeTimers.length;

  /// Danh sách các conversationId đang có timer đếm ngược
  List<String> get activeConversationIds => List.unmodifiable(_activeTimers.keys);

  // ===========================================================================
  // CORE TIMEOUT & EVENT HANDLERS
  // ===========================================================================

  /// Được gọi khi Bệnh nhân gửi một tin nhắn mới vào phòng hội chẩn
  void onPatientMessageSent({
    required String conversationId,
    required String message,
    required bool isDoctorOnline,
    String? woundContext,
    DoctorProfile? doctor,
    List<String>? chatHistory,
  }) {
    // 1. Trường hợp Bác sĩ đang Offline -> Kích hoạt AI trả lời tức thì
    if (!isDoctorOnline) {
      _cancelTimerFor(conversationId);
      _wasTriggeredImmediately = true;
      _lastTriggerReason = 'doctor_offline';
      notifyListeners();

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

    // 2. Trường hợp Bác sĩ Online -> Khởi động / Đặt lại bộ đếm ngược 30-60 giây
    _cancelTimerFor(conversationId);
    _wasTriggeredImmediately = false;
    _lastTriggerReason = null;

    final assignedDuration = _timeoutDuration;
    _timerStartTimes[conversationId] = DateTime.now();
    _timerDurations[conversationId] = assignedDuration;

    _activeTimers[conversationId] = Timer(assignedDuration, () {
      _activeTimers.remove(conversationId);
      _timerStartTimes.remove(conversationId);
      _timerDurations.remove(conversationId);

      _wasTriggeredImmediately = false;
      _lastTriggerReason = 'doctor_timeout';
      notifyListeners();

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

    notifyListeners();
  }

  /// Được gọi khi Bác sĩ gửi phản hồi thành công -> Hủy bộ đếm ngược AI
  void onDoctorReplyReceived(String conversationId) {
    final hadTimer = _cancelTimerFor(conversationId);
    if (hadTimer) {
      notifyListeners();
    }
  }

  /// Được gọi khi phát hiện Bác sĩ đang soạn tin (Typing) -> Gia hạn thêm thời gian
  void onDoctorTyping(
    String conversationId, {
    Duration extensionDuration = const Duration(seconds: 15),
  }) {
    if (!_activeTimers.containsKey(conversationId)) return;

    // Hủy timer cũ
    _activeTimers[conversationId]?.cancel();

    // Tính toán thời gian mới (gia hạn thêm)
    final startTime = _timerStartTimes[conversationId] ?? DateTime.now();
    final totalDuration = _timerDurations[conversationId] ?? _timeoutDuration;
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
      notifyListeners();

      unawaited(
        triggerAiFallback(
          conversationId: conversationId,
          lastPatientMessage: 'Bệnh nhân đang chờ phản hồi từ bác sĩ',
          reason: 'doctor_timeout',
          wasImmediate: false,
        ),
      );
    });

    notifyListeners();
  }

  // ===========================================================================
  // AI GENERATION & EMERGENCY PROTOCOL
  // ===========================================================================

  /// Kích hoạt tạo phản hồi AI và gửi trực tiếp vào phòng trò chuyện
  Future<void> triggerAiFallback({
    required String conversationId,
    required String lastPatientMessage,
    String? woundContext,
    DoctorProfile? doctor,
    String reason = 'doctor_offline',
    bool wasImmediate = false,
    List<String>? chatHistory,
  }) async {
    _cancelTimerFor(conversationId);
    _lastTriggerReason = reason;
    _wasTriggeredImmediately = wasImmediate;

    final trimmedMessage = lastPatientMessage.trim();
    final isEmergency = isEmergencyKeyword(trimmedMessage);

    String replyContent;

    if (isEmergency) {
      // 1. Phản hồi cấp cứu SOS 115 lập tức
      replyContent = generateEmergencySosAdvice(trimmedMessage);
    } else {
      // 2. Phản hồi sơ cứu / y khoa qua Gemini API hoặc bộ máy dự phòng lâm sàng
      try {
        final prompt = _buildMedicalPrompt(
          patientMessage: trimmedMessage,
          woundContext: woundContext,
          doctor: doctor,
          chatHistory: chatHistory,
          reason: reason,
        );

        final geminiResponse = await GeminiService.instance.generateFirstAidAdvice(
          prompt,
          woundContext,
        );

        if (geminiResponse.trim().isNotEmpty) {
          replyContent = _formatAiDoctorReply(
            geminiResponse,
            doctor: doctor,
            reason: reason,
          );
        } else {
          replyContent = _buildMedicalFallbackAdvice(trimmedMessage, doctor: doctor);
        }
      } catch (e) {
        debugPrint('[DoctorAiFallbackService] Lỗi gọi Gemini: $e, chuyển fallback lâm sàng');
        replyContent = _buildMedicalFallbackAdvice(trimmedMessage, doctor: doctor);
      }
    }

    _lastGeneratedResponse = replyContent;
    _aiResponsesGenerated++;

    // 3. Gửi tin nhắn qua DoctorConsultationService với senderType: 'ai'
    await DoctorConsultationService.instance.sendMessage(
      conversationId: conversationId,
      senderType: 'ai',
      senderId: 'ai_assistant',
      senderName: 'Trợ lý Bác sĩ AI (Gemini / MedGemma)',
      content: replyContent,
      isEmergency: isEmergency,
    );

    notifyListeners();
  }

  /// Kiểm tra nội dung tin nhắn có chứa từ khóa cấp cứu nguy kịch không
  bool isEmergencyKeyword(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    for (final kw in emergencyKeywords) {
      if (lower.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  /// Tạo thông điệp sơ cấp cứu SOS 115 khẩn cấp
  String generateEmergencySosAdvice(String detectedMessage) {
    String foundKeyword = 'dấu hiệu khẩn cấp';
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
        '3. 🫁 **Nếu khó thở / tím tái / ngất xỉu:** Đặt bệnh nhân nằm nghiêng an toàn để thông thoáng đường thở. Nếu ngưng thở, ép tim ngoài lồng ngực (CPR) 100-120 lần/phút.\n'
        '4. 🛑 **Tuyệt đối KHÔNG:** Không tự ý cho uống nước, không đắp thuốc lá hay các chất lạ lên vết thương.\n\n'
        '*(Trợ lý Bác sĩ AI kích hoạt cảnh báo đỏ tự động trong khi chờ nhân viên y tế)*';
  }

  /// Xây dựng câu hỏi chuẩn y khoa cho Gemini
  String _buildMedicalPrompt({
    required String patientMessage,
    String? woundContext,
    DoctorProfile? doctor,
    List<String>? chatHistory,
    required String reason,
  }) {
    final buffer = StringBuffer();
    final doctorName = doctor?.fullName ?? 'Bác sĩ phụ trách';

    buffer.writeln(
      'Bạn là Trợ lý Bác sĩ AI lâm sàng đại diện cho $doctorName trong hệ thống khám bệnh từ xa.',
    );
    if (reason == 'doctor_offline') {
      buffer.writeln('Bác sĩ hiện đang vắng mặt/ngoài giờ trực tuyến.');
    } else {
      buffer.writeln('Bác sĩ đang tiếp nhận nhiều bệnh nhân và chưa kịp phản hồi sau thời gian chờ.');
    }
    buffer.writeln('Hãy đưa ra lời khuyên sơ cứu ban đầu chuẩn y tế, ngắn gọn, súc tích và an toàn.');

    if (woundContext != null && woundContext.isNotEmpty) {
      buffer.writeln('\n[Thông tin hồ sơ tổn thương]:\n$woundContext');
    }

    if (chatHistory != null && chatHistory.isNotEmpty) {
      final truncated = truncateChatContext(chatHistory, maxRecentTurns: 6);
      buffer.writeln('\n[Lịch sử trao đổi gần nhất]:');
      for (final turn in truncated) {
        buffer.writeln('- $turn');
      }
    }

    buffer.writeln('\n[Tin nhắn mới nhất của bệnh nhân]: "$patientMessage"');
    buffer.writeln('\nYêu cầu: Hướng dẫn sơ cứu từng bước rõ ràng, nêu rõ những điều KHÔNG ĐƯỢC LÀM và dấu hiệu cần đến bệnh viện.');

    return buffer.toString();
  }

  /// Định dạng tin nhắn AI phản hồi kèm dấu ấn nhận diện Trợ lý AI
  String _formatAiDoctorReply(
    String aiResponse, {
    DoctorProfile? doctor,
    required String reason,
  }) {
    final note = reason == 'doctor_offline'
        ? 'Bác sĩ hiện không trực tuyến. Trợ lý AI MedGemma/Gemini hỗ trợ phản hồi tự động:'
        : 'Bác sĩ đang bận ca hội chẩn. Trợ lý AI MedGemma/Gemini tạm thời hướng dẫn bạn:';

    return '🤖 **[TRỢ LÝ BÁC SĨ AI PHẢN HỒI DỰ PHÒNG]**\n'
        '*($note)*\n\n'
        '$aiResponse\n\n'
        '--- \n'
        '💡 *Lưu ý: Hướng dẫn trên mang tính tham khảo sơ cứu ban đầu. Bác sĩ chuyên khoa sẽ xem lại cuộc trò chuyện và đưa ra kết luận chi tiết ngay khi có mặt.*';
  }

  /// Bộ câu trả lời y tế dự phòng lâm sàng ngoại tuyến
  String _buildMedicalFallbackAdvice(String patientMessage, {DoctorProfile? doctor}) {
    final lower = patientMessage.toLowerCase();

    if (lower.contains('bỏng') || lower.contains('phỏng') || lower.contains('nước sôi')) {
      return '🤖 **[TRỢ LÝ BÁC SĨ AI DỰ PHÒNG]**\n\n'
          '### 🩹 HƯỚNG DẪN XỬ TRÍ SƠ CỨU BỎNG NHIỆT / NƯỚC SÔI:\n'
          '1. **Hạ nhiệt ngay:** Xả nước sạch mát (15-20°C) nhẹ nhàng lên vùng bỏng trong 15-20 phút.\n'
          '2. **Tháo trang sức:** Nhanh chóng tháo nhẫn, đồng hồ trước khi vị trí tổn thương sưng nề.\n'
          '3. **Bảo vệ:** Che phủ bằng gạc vô trùng ẩm hoặc màng bọc thực phẩm sạch.\n'
          '4. **Tuyệt đối không:** Không chườm đá lạnh trực tiếp, không bôi kem đánh răng hoặc mỡ trăn, không chọc vỡ bóng nước.';
    }

    if (lower.contains('uốn ván') || lower.contains('sat') || lower.contains('gỉ sét') || lower.contains('đinh')) {
      return '🤖 **[TRỢ LÝ BÁC SĨ AI DỰ PHÒNG]**\n\n'
          '### 💉 TƯ VẤN TIÊM PHÒNG UỐN VÁN (SAT / TETAVAX):\n'
          '1. **Nguy cơ cao:** Các vết thương dính bùn đất, cứa bởi đinh gỉ sét, cành cây mục hoặc súc vật cắn có nguy cơ nhiễm trực khuẩn uốn ván rất cao.\n'
          '2. **Thời gian vàng:** Cần tiêm huyết thanh kháng độc tố uốn ván (SAT) trong vòng **24 - 48 giờ** sau khi bị thương.\n'
          '3. **Xử trí ngay:** Rửa sạch vết thương bằng xà phòng dưới vòi nước chảy, sát khuẩn bằng Povidone-Iodine 10% và đến trung tâm tiêm chủng gần nhất.';
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
        'Chào bạn, hệ thống AI Bác sĩ ghi nhận câu hỏi của bạn. Trong khi chờ Bác sĩ phản hồi:\n'
        '• Nếu có vết thương ngoài da: Hãy rửa sạch bằng nước muối sinh lý 0.9% và băng gạc vô trùng bảo vệ.\n'
        '• Nếu có dấu hiệu sốt, sưng nóng đỏ đau hoặc chảy dịch mủ: Hãy thông báo cụ thể để bác sĩ hướng dẫn đơn thuốc phù hợp.\n'
        '• Nếu xuất hiện dấu hiệu khẩn cấp, vui lòng gọi cấp cứu 115 ngay.';
  }

  // ===========================================================================
  // UTILITIES: CONTEXT TRUNCATION & SAFE PARSING
  // ===========================================================================

  /// Cắt ngắn ngữ cảnh lịch sử trò chuyện để tránh vượt quá giới hạn token
  List<String> truncateChatContext(List<String>? history, {int maxRecentTurns = 10}) {
    if (history == null || history.isEmpty) return const [];
    if (history.length <= maxRecentTurns) {
      return List.unmodifiable(history);
    }
    return List.unmodifiable(history.sublist(history.length - maxRecentTurns));
  }

  /// Phân tích an toàn chuỗi phản hồi AI (hỗ trợ cả JSON bọc mã markdown)
  Map<String, dynamic> parseAiResponseSafe(String rawJsonResponse) {
    if (rawJsonResponse.trim().isEmpty) {
      return {
        'content': '',
        'isEmergency': false,
        'parsed': false,
      };
    }

    try {
      var cleaned = rawJsonResponse.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return {
          ...decoded,
          'parsed': true,
        };
      }
    } catch (_) {}

    return {
      'content': rawJsonResponse.trim(),
      'isEmergency': isEmergencyKeyword(rawJsonResponse),
      'parsed': false,
    };
  }

  // ===========================================================================
  // RESET & CLEANUP
  // ===========================================================================

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

  /// Khôi phục trạng thái ban đầu của dịch vụ
  void reset() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _timerStartTimes.clear();
    _timerDurations.clear();
    _timeoutDuration = const Duration(seconds: 45);
    _aiResponsesGenerated = 0;
    _wasTriggeredImmediately = false;
    _lastTriggerReason = null;
    _lastGeneratedResponse = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    super.dispose();
  }
}
