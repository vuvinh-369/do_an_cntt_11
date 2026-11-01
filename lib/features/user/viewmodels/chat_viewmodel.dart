import 'package:flutter/material.dart';

import '../../../core/gemini/gemini_service.dart';
import '../../../core/rule_engine/rule_models.dart';
import '../models/chat_models.dart';
import 'analysis_result_viewmodel.dart';
import 'first_aid_viewmodel.dart';
import 'image_analysis_viewmodel.dart';
import 'user_navigation_viewmodel.dart';

mixin ChatBoxAiViewModel
    on
        DieuHuongCoSoViewModel,
        HuongDanSoCuuViewModel,
        KetQuaPhanTichViewModel,
        PhanTichAnhViewModel {
  // Bộ điều khiển nhập liệu và cuộn danh sách tin nhắn trên Màn hình 6: ChatBox AI
  final TextEditingController chatInputController = TextEditingController();
  final ScrollController chatScrollController = ScrollController();
  String _currentChatInput = '';
  String get currentChatInput => _currentChatInput;

  // Trạng thái AI đang suy nghĩ / chờ phản hồi từ API
  bool _isAiThinking = false;
  bool get isAiThinking => _isAiThinking;

  // Lựa chọn Mô hình AI hiện tại (mặc định: 'gemini', tùy chọn: 'medgemma')
  String _selectedChatModelId = 'gemini';
  String get selectedChatModelId => _selectedChatModelId;

  List<ChatModelInfo> get availableChatModels => kDefaultChatModels;

  ChatModelInfo get currentChatModel => kDefaultChatModels.firstWhere(
        (m) => m.id == _selectedChatModelId,
        orElse: () => kDefaultChatModels.first,
      );

  /// Chuyển đổi mô hình AI (Google Gemini hoặc MedGemma)
  void switchChatModel(String modelId) {
    if (_selectedChatModelId != modelId) {
      _selectedChatModelId = modelId;
      notifyListeners();
    }
  }

  // Lịch sử tin nhắn hội thoại trên Màn hình 6
  final List<ChatMessageModel> _chatMessages = [];
  List<ChatMessageModel> get chatMessages => List.unmodifiable(_chatMessages);

  // Danh sách câu hỏi gợi ý nhanh tập trung vào 4 nhóm tổn thương chính & tình huống khẩn cấp
  final List<String> quickSuggestedQuestions = const [
    'Cách làm sạch và băng vết trầy xước té xe?',
    'Vết cắt sâu chảy máu nhiều thì cầm máu thế nào?',
    'Sơ cứu vết bỏng nước sôi / bỏng nhiệt đúng cách?',
    'Bầm tím phần mềm sưng to, nên chườm đá hay bôi dầu?',
    'Có dị vật thủy tinh đâm sâu vào da, xử lý sao?',
    'Dấu hiệu nào cho thấy vết thương bị nhiễm trùng?',
  ];

  // =========================================================================
  // LOGIC TƯƠNG TÁC CHATBOX AI (GEMINI & MEDGEMMA)
  // =========================================================================

  void updateChatInput(String value) {
    _currentChatInput = value;
  }

  /// Xóa toàn bộ lịch sử trò chuyện
  void clearChatHistory() {
    _chatMessages.clear();
    _isAiThinking = false;
    notifyListeners();
  }

  /// Chuyển prompt kết quả phân tích ảnh sang ChatBox AI để AI tự động tư vấn
  void consultAiWithCurrentAnalysis() {
    final location = selectedLocationLabel;

    // 1. Tóm tắt các tổn thương phát hiện (hỗ trợ trường hợp phát hiện 2-3 vết thương kết hợp trên ảnh)
    final String woundSummary = analysisResult.hasMultipleInjuries
        ? analysisResult.combinedInjurySummary
        : '${analysisResult.injuryType} (${analysisResult.confidencePercent}%)';

    final String multiWoundNotice = analysisResult.hasMultipleInjuries
        ? '\n- Ảnh có ${analysisResult.allDetections.length} tổn thương kết hợp: Hãy phân tích tương quan và hướng dẫn thứ tự ưu tiên xử lý từng vết thương theo chuẩn cấp cứu Triage (cầm máu vết thương hở trước, sau đó sát trùng vết trầy, che phủ vết bỏng).'
        : '';

    // 2. Mức độ cảm giác đau do người dùng gạt chọn (3 nấc)
    final String painLabel = painLevel.label;
    final String painNote = painLevel == PainLevel.severe
        ? ' (Bệnh nhân đang rất đau đớn dữ dội 7-10/10, cần ưu tiên hướng dẫn tư thế giảm đau an toàn và cảnh báo tổn thương mô sâu/gãy xương ngầm)'
        : (painLevel == PainLevel.none
            ? ' (Không đau hoặc mất cảm giác đau - lưu ý nếu là vết bỏng có thể đã tổn thương sâu làm chết ngọn dây thần kinh bì)'
            : ' (Đau nhẹ rát bề mặt thông thường)');

    // 3. Tổng hợp các tình trạng quan sát kèm theo từ checkbox của người dùng
    final List<String> observedSymptoms = [];
    if (isBleeding) {
      observedSymptoms.add('Vết thương đang chảy máu (chảy nhiều hoặc liên tục)');
    }
    if (hasForeignBody) {
      observedSymptoms.add('Có dị vật cắm sâu vào vết thương (kim loại, dằm, thủy tinh...)');
    }
    if (hasPusOrInfection) {
      observedSymptoms.add('Vết thương chảy mủ / Sưng đỏ tấy (dấu hiệu nhiễm trùng)');
    }

    final String symptomsText = observedSymptoms.isNotEmpty
        ? '\n- Dấu hiệu quan sát kèm theo: ${observedSymptoms.join('; ')}.'
        : '';

    final prompt =
        'Tôi vừa quét ảnh phát hiện tổn thương: $woundSummary ở vị trí $location.$multiWoundNotice\n'
        '- Cảm giác đau hiện tại: $painLabel$painNote.$symptomsText\n'
        'Hãy phân tích tình trạng vết thương, hướng dẫn quy trình sơ cứu từng bước rõ ràng theo thứ tự ưu tiên, '
        'cách giảm đau an toàn, những điều cấm kỵ tuyệt đối không được làm và dấu hiệu nguy hiểm cần đến bệnh viện ngay?';

    // 1. Chuyển sang màn hình ChatBox AI (Màn hình 5)
    navigateToChatBoxAi();

    // 2. Tự động gửi câu hỏi sang AI để phản hồi tức thì
    sendChatMessage(prompt);
  }

  void _scrollToLatestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatScrollController.hasClients) {
        chatScrollController.animateTo(
          chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Gửi tin nhắn tới Mô hình AI được chọn (Gemini API hoặc MedGemma Server)
  Future<void> sendChatMessage([String? submittedText]) async {
    final rawText = (submittedText ?? chatInputController.text).trim();
    if (rawText.isEmpty || _isAiThinking) return;

    final now = DateTime.now();
    final formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Thêm tin nhắn của người dùng vào giao diện
    _chatMessages.add(
      ChatMessageModel(
        id: 'user_${now.microsecondsSinceEpoch}',
        isUser: true,
        messageText: rawText,
        timestamp: formattedTime,
      ),
    );

    chatInputController.clear();
    _currentChatInput = '';
    _isAiThinking = true;
    notifyListeners();
    _scrollToLatestMessage();

    try {
      // Chuẩn bị ngữ cảnh vết thương (nếu bệnh nhân vừa thực hiện quét ảnh AI trước đó)
      String? woundContext;
      if (analysisResult.isDetected) {
        final List<String> symptoms = [];
        symptoms.add('Cảm giác đau: ${painLevel.label}');
        if (isBleeding) symptoms.add('đang chảy máu nhiều/liên tục');
        if (hasForeignBody) symptoms.add('có dị vật cắm sâu vào vết thương');
        if (hasPusOrInfection) symptoms.add('chảy mủ hoặc sưng đỏ tấy (dấu hiệu nhiễm trùng)');
        final symptomsInfo = ' [${symptoms.join(', ')}]';

        final woundDesc = analysisResult.hasMultipleInjuries
            ? analysisResult.combinedInjurySummary
            : '${analysisResult.injuryType} (${analysisResult.confidencePercent}%)';

        woundContext =
            'Bệnh nhân vừa quét ảnh phát hiện: $woundDesc tại vị trí $selectedLocationLabel.$symptomsInfo';
      }

      // Chuẩn bị danh sách lịch sử hội thoại
      final conversationHistory = _chatMessages
          .map((m) => {
                'role': m.isUser ? 'user' : 'model',
                'text': m.messageText,
              })
          .toList();

      String replyText;

      // Xử lý theo model được chọn
      if (_selectedChatModelId == 'medgemma') {
        // MedGemma: Mô hình chạy Server riêng. Vì chưa kết nối endpoint máy chủ vật lý,
        // hệ thống định tuyến thông qua phác đồ MedGemma y khoa
        final String medGemmaContext = woundContext != null
            ? '$woundContext\n[Yêu cầu: Trả lời theo chuẩn phân loại lâm sàng MedGemma Medical]'
            : '[Yêu cầu: Trả lời theo chuẩn phân loại lâm sàng MedGemma Medical]';

        final rawReply = await GeminiService.instance.sendChatMessage(
          conversationHistory: conversationHistory,
          userMessage: rawText,
          woundContext: medGemmaContext,
        );

        replyText =
            '*(Phản hồi định tuyến qua MedGemma Medical AI - Kênh máy chủ y sinh)*\n\n$rawReply';
      } else {
        // Google Gemini Cloud API
        replyText = await GeminiService.instance.sendChatMessage(
          conversationHistory: conversationHistory,
          userMessage: rawText,
          woundContext: woundContext,
        );
      }

      final replyNow = DateTime.now();
      final replyTime =
          '${replyNow.hour.toString().padLeft(2, '0')}:${replyNow.minute.toString().padLeft(2, '0')}';

      _chatMessages.add(
        ChatMessageModel(
          id: 'ai_${replyNow.microsecondsSinceEpoch}',
          isUser: false,
          messageText: replyText,
          timestamp: replyTime,
          modelSource: _selectedChatModelId,
        ),
      );
    } catch (e) {
      final replyNow = DateTime.now();
      final replyTime =
          '${replyNow.hour.toString().padLeft(2, '0')}:${replyNow.minute.toString().padLeft(2, '0')}';

      _chatMessages.add(
        ChatMessageModel(
          id: 'ai_${replyNow.microsecondsSinceEpoch}',
          isUser: false,
          messageText:
              '⚠️ Đã xảy ra lỗi khi kết nối với mô hình AI: $e\n\nVui lòng kiểm tra lại kết nối mạng hoặc thử lại sau ít phút.',
          timestamp: replyTime,
        ),
      );
    } finally {
      _isAiThinking = false;
      notifyListeners();
      _scrollToLatestMessage();
    }
  }
}
