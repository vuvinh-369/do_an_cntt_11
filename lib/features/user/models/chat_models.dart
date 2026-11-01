import 'package:flutter/material.dart';

/// Mô hình dữ liệu cho từng Tin nhắn trong màn hình "6. ChatBox AI (Người dùng)" (Màn hình 6)
class ChatMessageModel {
  final String id;
  final bool isUser;
  final String messageText;
  final List<String> numberedSteps;
  final String timestamp;
  final String? relatedTopicId;
  final String? modelSource;

  const ChatMessageModel({
    required this.id,
    required this.isUser,
    required this.messageText,
    this.numberedSteps = const [],
    required this.timestamp,
    this.relatedTopicId,
    this.modelSource,
  });
}

/// Mô hình thông tin định danh cho từng Model AI trong danh sách chọn (Model Switcher)
class ChatModelInfo {
  final String id;
  final String name;
  final String shortName;
  final String description;
  final String provider;
  final IconData icon;
  final Color brandColor;
  final String tagLabel;
  final Color tagColor;
  final bool isBeta;

  const ChatModelInfo({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.provider,
    required this.icon,
    required this.brandColor,
    required this.tagLabel,
    required this.tagColor,
    this.isBeta = false,
  });
}

/// Danh sách 2 model cốt lõi của hệ thống (Gemini & MedGemma Server)
const List<ChatModelInfo> kDefaultChatModels = [
  ChatModelInfo(
    id: 'gemini',
    name: 'Google Gemini 3.8 Flash',
    shortName: 'Gemini 3.8 Flash',
    description:
        'Mô hình Flash thế hệ 3.8 mới nhất của Google DeepMind. Tốc độ vượt trội, xử lý suy luận nhiều bước, hỗ trợ tư vấn sơ cứu tổn thương da và chuẩn hóa y tế 24/7.',
    provider: 'Google AI Studio (gemini-3.8-flash)',
    icon: Icons.auto_awesome,
    brandColor: Color(0xFF2563EB),
    tagLabel: 'Bản 3.8 Flash',
    tagColor: Color(0xFF10B981),
    isBeta: false,
  ),
  ChatModelInfo(
    id: 'medgemma',
    name: 'MedGemma Medical AI',
    shortName: 'MedGemma (LAN Server)',
    description:
        'Mô hình ngôn ngữ y sinh học mã nguồn mở (Gemma fine-tuned y tế) gọi từ máy chủ Server nội bộ / Bệnh viện (Đang thiết lập cổng kết nối).',
    provider: 'Local Hospital Server / Máy chủ LAN',
    icon: Icons.health_and_safety_rounded,
    brandColor: Color(0xFF7C3AED),
    tagLabel: 'Server LAN (Thử nghiệm)',
    tagColor: Color(0xFF8B5CF6),
    isBeta: true,
  ),
];
