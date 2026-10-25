/// Mô hình dữ liệu cho từng Tin nhắn trong màn hình "6. ChatBox AI (Người dùng)" (Màn hình 6)
class ChatMessageModel {
  final String id;
  final bool isUser;
  final String messageText;
  final List<String> numberedSteps;
  final String timestamp;
  final String? relatedTopicId;

  const ChatMessageModel({
    required this.id,
    required this.isUser,
    required this.messageText,
    this.numberedSteps = const [],
    required this.timestamp,
    this.relatedTopicId,
  });
}
