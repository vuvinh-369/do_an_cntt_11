import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import 'user_navigation_viewmodel.dart';
import 'first_aid_viewmodel.dart';

mixin ChatBoxAiViewModel on DieuHuongCoSoViewModel, HuongDanSoCuuViewModel {
  // Bộ điều khiển nhập liệu và cuộn danh sách tin nhắn trên Màn hình 6: ChatBox AI
  final TextEditingController chatInputController = TextEditingController();
  final ScrollController chatScrollController = ScrollController();
  String _currentChatInput = '';
  String get currentChatInput => _currentChatInput;

  // Lịch sử tin nhắn hội thoại trên Màn hình 6: Khởi tạo RỖNG khi mới vào
  final List<ChatMessageModel> _chatMessages = [];
  List<ChatMessageModel> get chatMessages => List.unmodifiable(_chatMessages);

  // Danh sách các câu hỏi gợi ý nhanh khi khung chat đang trống
  final List<String> quickSuggestedQuestions = const [
    'Làm sao để xử lý khi bị bỏng nhẹ?',
    'Cách sơ cứu khi bị trầy xước ngoài da?',
    'Xử lý vết cắt chảy máu như thế nào?',
    'Làm gì khi bị bầm tím phần mềm?',
  ];

  // =========================================================================
  // LOGIC TƯƠNG TÁC CHATBOX AI & TỰ ĐỘNG CUỘN TIN NHẮN LÊN TRÊN (MÀN HÌNH 6)
  // =========================================================================

  void updateChatInput(String value) {
    _currentChatInput = value;
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

  void sendChatMessage([String? submittedText]) {
    final rawText = (submittedText ?? chatInputController.text).trim();
    if (rawText.isEmpty) return;

    final now = DateTime.now();
    final formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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

    final aiReply = _generateGroundedAiReply(rawText, formattedTime);
    _chatMessages.add(aiReply);

    notifyListeners();
    _scrollToLatestMessage();
  }

  ChatMessageModel _generateGroundedAiReply(
    String userQuestion,
    String timestamp,
  ) {
    final normalized = userQuestion.toLowerCase().trim();

    if (normalized == 'hi' ||
        normalized == 'hello' ||
        normalized == 'chào' ||
        normalized == 'alo' ||
        normalized.startsWith('xin chào') ||
        normalized.startsWith('chào ai')) {
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText: 'Xin chào! Tôi là Trợ lý Cứu hộ AI. Bạn có thể đặt câu hỏi trực tiếp về các tình huống sơ cứu sau:',
        numberedSteps: const [
          'Cách xử lý khi bị bỏng nhẹ (bỏng nước sôi, bỏng nhiệt).',
          'Cách làm sạch và băng bó vết trầy xước ngoài da.',
          'Cách cầm máu và sát trùng vết cắt / vết rách.',
          'Cách chườm lạnh giảm sưng khi bị bầm tím, dị vật hoặc ngộ độc.',
        ],
        timestamp: timestamp,
      );
    }

    if (normalized.contains('bỏng') || normalized.contains('phỏng')) {
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Với vết bỏng nhẹ (độ 1), bạn có thể làm theo các bước sau:',
        numberedSteps: const [
          'Làm mát vùng bỏng bằng nước sạch mát trong 10–20 phút.',
          'Không chọc vỡ bóng nước (nếu có).',
          'Bôi thuốc mỡ kháng sinh và băng gạc sạch.',
          'Theo dõi, nếu có dấu hiệu nhiễm trùng hoặc đau tăng, hãy đi khám bác sĩ.',
        ],
        timestamp: timestamp,
        relatedTopicId: 'burn',
      );
    }

    if (normalized.contains('trầy') || normalized.contains('xước')) {
      final guide = firstAidGuidesByTopic['abrasion']!;
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Đối với tình huống ${guide.severityText.toLowerCase()}, bạn hãy thực hiện theo các bước sơ cứu đã kiểm chứng sau:',
        numberedSteps: guide.steps
            .map((step) => '${step.title}: ${step.description}')
            .toList(),
        timestamp: timestamp,
        relatedTopicId: 'abrasion',
      );
    }

    if (normalized.contains('cắt') ||
        normalized.contains('rách') ||
        normalized.contains('đứt tay') ||
        normalized.contains('chảy máu')) {
      final guide = firstAidGuidesByTopic['cut_laceration']!;
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Khi gặp ${guide.severityText.toLowerCase()}, bạn cần thực hiện các bước sơ cứu sau:',
        numberedSteps: guide.steps
            .map((step) => '${step.title}: ${step.description}')
            .toList(),
        timestamp: timestamp,
        relatedTopicId: 'cut_laceration',
      );
    }

    if (normalized.contains('bầm') || normalized.contains('tím')) {
      final guide = firstAidGuidesByTopic['bruise']!;
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Với tình trạng ${guide.severityText.toLowerCase()}, bạn có thể xử lý theo các bước sau:',
        numberedSteps: guide.steps
            .map((step) => '${step.title}: ${step.description}')
            .toList(),
        timestamp: timestamp,
        relatedTopicId: 'bruise',
      );
    }

    if (normalized.contains('dị vật') ||
        normalized.contains('dằm') ||
        normalized.contains('mảnh vỡ')) {
      final guide = firstAidGuidesByTopic['foreign_body']!;
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Khi xử lý ${guide.severityText.toLowerCase()}, bạn hãy tuân thủ các bước an toàn sau:',
        numberedSteps: guide.steps
            .map((step) => '${step.title}: ${step.description}')
            .toList(),
        timestamp: timestamp,
        relatedTopicId: 'foreign_body',
      );
    }

    if (normalized.contains('ngộ độc') || normalized.contains('nhiễm độc')) {
      final guide = firstAidGuidesByTopic['poisoning']!;
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Trong trường hợp ${guide.severityText.toLowerCase()}, bạn cần thực hiện ngay các bước sau:',
        numberedSteps: guide.steps
            .map((step) => '${step.title}: ${step.description}')
            .toList(),
        timestamp: timestamp,
        relatedTopicId: 'poisoning',
      );
    }

    return ChatMessageModel(
      id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
      isUser: false,
      messageText: 'Hiện tại hệ thống chỉ cung cấp hướng dẫn đã kiểm chứng cho 6 tình huống sơ cứu cơ bản (Bỏng, Trầy xước, Vết cắt/Vết rách, Bầm, Dị vật, Ngộ độc) và chưa có đủ cơ sở dữ liệu y khoa đã xác thực cho câu hỏi của bạn.',
      numberedSteps: const [
        'Vui lòng mô tả rõ một trong các tình trạng trên hoặc mở mục "Hướng dẫn sơ cứu" / "Kiến thức" ở thanh menu bên trái.',
        'Nếu nạn nhân có dấu hiệu nguy cấp, hãy liên hệ ngay cơ sở y tế gần nhất hoặc gọi cấp cứu 115.',
      ],
      timestamp: timestamp,
    );
  }
}
