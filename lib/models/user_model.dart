import 'package:flutter/material.dart';

/// Mô hình dữ liệu cho mỗi Thẻ tính năng (Feature Card) trên Trang chủ (Màn hình 1)
class FeatureCardModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;

  const FeatureCardModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
  });
}

/// Mô hình dữ liệu cho mỗi thẻ trong mục "Tình huống thường gặp" trên Trang chủ (Màn hình 1)
class CommonSituationModel {
  final String id;
  final String title;
  final String? imageUrl;
  final Color baseSkinColor;
  final Color woundAccentColor;
  final IconData medicalIcon;

  const CommonSituationModel({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.baseSkinColor,
    required this.woundAccentColor,
    required this.medicalIcon,
  });
}

/// Mô hình dữ liệu cho từng mục menu trên thanh Sidebar bên trái (Màn hình 2, 3, 4, 5, 6)
class SidebarMenuItemModel {
  final String id;
  final String title;
  final IconData icon;

  const SidebarMenuItemModel({
    required this.id,
    required this.title,
    required this.icon,
  });
}

/// Mô hình dữ liệu cấu hình văn bản hiển thị cho khu vực Phân tích hình ảnh tổn thương (Màn hình 2)
class AiUploadSpecModel {
  final String screenTitle;
  final String dropzonePrefixText;
  final String dropzoneActionText;
  final String supportedFormatsText;
  final String selectButtonLabel;
  final String dividerText;
  final String cameraButtonLabel;
  final String noticeBoldText;
  final String noticeDetailText;

  const AiUploadSpecModel({
    required this.screenTitle,
    required this.dropzonePrefixText,
    required this.dropzoneActionText,
    required this.supportedFormatsText,
    required this.selectButtonLabel,
    required this.dividerText,
    required this.cameraButtonLabel,
    required this.noticeBoldText,
    required this.noticeDetailText,
  });
}

/// Mô hình dữ liệu cho từng tùy chọn trong mục "Chọn vị trí tổn thương" (Màn hình 3)
class InjuryLocationOptionModel {
  final String id;
  final String label;
  final IconData fallbackIcon;

  const InjuryLocationOptionModel({
    required this.id,
    required this.label,
    required this.fallbackIcon,
  });
}

/// Mô hình dữ liệu cho Kết quả phân tích hình ảnh AI (Màn hình 3)
class AiAnalysisResultModel {
  final String bannerTitle;
  final String confidenceLabelPrefix;
  final int confidencePercent;
  final String injuryType;
  final String boundingBoxLabel;
  final String infoCardTitle;
  final String injuryTypeLabel;
  final String confidenceRowLabel;
  final String locationRowLabel;
  final String locationSectionTitle;
  final String bottomNoticeText;
  final String primaryActionLabel;
  final String? analyzedImageUrl;

  const AiAnalysisResultModel({
    required this.bannerTitle,
    required this.confidenceLabelPrefix,
    required this.confidencePercent,
    required this.injuryType,
    required this.boundingBoxLabel,
    required this.infoCardTitle,
    required this.injuryTypeLabel,
    required this.confidenceRowLabel,
    required this.locationRowLabel,
    required this.locationSectionTitle,
    required this.bottomNoticeText,
    required this.primaryActionLabel,
    this.analyzedImageUrl,
  });

  String get formattedConfidence => '$confidencePercent%';
  String get bannerConfidenceText =>
      '$confidenceLabelPrefix $confidencePercent%';
}

/// Mô hình dữ liệu cho từng bước trong danh sách "Các bước sơ cứu" (Màn hình 4)
class FirstAidStepModel {
  final int stepNumber;
  final String id;
  final String title;
  final String description;
  final IconData fallbackIcon;

  const FirstAidStepModel({
    required this.stepNumber,
    required this.id,
    required this.title,
    required this.description,
    required this.fallbackIcon,
  });
}

/// Mô hình dữ liệu cho toàn bộ màn hình "4. Hướng dẫn sơ cứu (Người dùng)" (Màn hình 4)
class FirstAidGuideModel {
  final String topicId;
  final String screenTitle;
  final String statusBoxTitle;
  final String severityText;
  final String safetyNoteText;
  final String stepsSectionTitle;
  final List<FirstAidStepModel> steps;
  final String redWarningTitle;
  final List<String> redWarningBullets;
  final String backButtonLabel;

  const FirstAidGuideModel({
    required this.topicId,
    required this.screenTitle,
    required this.statusBoxTitle,
    required this.severityText,
    required this.safetyNoteText,
    required this.stepsSectionTitle,
    required this.steps,
    required this.redWarningTitle,
    required this.redWarningBullets,
    required this.backButtonLabel,
  });
}

/// Mô hình dữ liệu cho từng nút lọc Danh mục trên màn hình "5. Tra cứu kiến thức" (Màn hình 5)
class KnowledgeCategoryModel {
  final String id;
  final String label;

  const KnowledgeCategoryModel({required this.id, required this.label});
}

/// Mô hình dữ liệu cho từng Thẻ Kiến thức Sơ cứu trên màn hình "5. Tra cứu kiến thức" (Màn hình 5)
class KnowledgeTopicModel {
  final String id;
  final String categoryId;
  final String title;
  final String subtitle;
  final String? imageUrl;

  const KnowledgeTopicModel({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.subtitle,
    this.imageUrl,
  });
}

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
