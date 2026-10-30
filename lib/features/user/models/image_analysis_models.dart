import 'package:flutter/material.dart';

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
