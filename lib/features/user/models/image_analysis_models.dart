import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Mô hình cấu hình hiển thị cho khu vực Tải lên hình ảnh phân tích (Màn hình 2)
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

/// Mô hình dữ liệu cho tùy chọn trong mục "Chọn vị trí tổn thương" (Màn hình 3)
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

/// Mô hình dữ liệu cho tùy chọn sửa đổi thủ công loại vết thương (Màn hình 3)
class ManualInjuryOptionModel {
  final String id; // 'tray_xuoc', 'vet_cat_rach', 'bong', 'bam_tim'
  final String label;
  final String topicId;
  final String severity;
  final IconData icon;
  final String description;

  const ManualInjuryOptionModel({
    required this.id,
    required this.label,
    required this.topicId,
    required this.severity,
    required this.icon,
    required this.description,
  });
}

/// Mô hình dữ liệu Kết quả phân tích hình ảnh AI (Màn hình 3)
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

  // Dữ liệu ảnh thực tế & Kết quả từ YOLO model
  final Uint8List? rawImageBytes;
  final String? imageFileName;
  final String detectedTopicId;
  final bool isDetected;
  final List<double>? boundingBox; // [x1, y1, x2, y2]
  final double? originalImageWidth;
  final double? originalImageHeight;
  final String? detectionMessage;

  // Trạng thái can thiệp thủ công & độ tương phản
  final bool isManualSelection;
  final double appliedContrast;

  const AiAnalysisResultModel({
    required this.bannerTitle,
    this.confidenceLabelPrefix = 'Độ tin cậy:',
    required this.confidencePercent,
    required this.injuryType,
    required this.boundingBoxLabel,
    this.infoCardTitle = 'Thông tin nhận diện AI',
    this.injuryTypeLabel = 'Loại tổn thương:',
    this.confidenceRowLabel = 'Độ tin cậy:',
    this.locationRowLabel = 'Vị trí:',
    this.locationSectionTitle = 'Chọn vị trí tổn thương',
    this.bottomNoticeText =
        'Hệ thống đã phân tích tổn thương. Vui lòng chọn vị trí cụ thể để xem hướng dẫn sơ cứu phù hợp.',
    this.primaryActionLabel = 'Xem hướng dẫn sơ cứu',
    this.analyzedImageUrl,
    this.rawImageBytes,
    this.imageFileName,
    this.detectedTopicId = 'abrasion',
    this.isDetected = true,
    this.boundingBox,
    this.originalImageWidth,
    this.originalImageHeight,
    this.detectionMessage,
    this.isManualSelection = false,
    this.appliedContrast = 1.0,
  });

  String get formattedConfidence =>
      isManualSelection ? '100% (Xác nhận thủ công)' : '$confidencePercent%';
  String get bannerConfidenceText =>
      isManualSelection ? 'Xác nhận thủ công' : '$confidenceLabelPrefix $confidencePercent%';

  AiAnalysisResultModel copyWith({
    String? bannerTitle,
    String? confidenceLabelPrefix,
    int? confidencePercent,
    String? injuryType,
    String? boundingBoxLabel,
    String? infoCardTitle,
    String? injuryTypeLabel,
    String? confidenceRowLabel,
    String? locationRowLabel,
    String? locationSectionTitle,
    String? bottomNoticeText,
    String? primaryActionLabel,
    String? analyzedImageUrl,
    Uint8List? rawImageBytes,
    String? imageFileName,
    String? detectedTopicId,
    bool? isDetected,
    List<double>? boundingBox,
    double? originalImageWidth,
    double? originalImageHeight,
    String? detectionMessage,
    bool? isManualSelection,
    double? appliedContrast,
  }) {
    return AiAnalysisResultModel(
      bannerTitle: bannerTitle ?? this.bannerTitle,
      confidenceLabelPrefix: confidenceLabelPrefix ?? this.confidenceLabelPrefix,
      confidencePercent: confidencePercent ?? this.confidencePercent,
      injuryType: injuryType ?? this.injuryType,
      boundingBoxLabel: boundingBoxLabel ?? this.boundingBoxLabel,
      infoCardTitle: infoCardTitle ?? this.infoCardTitle,
      injuryTypeLabel: injuryTypeLabel ?? this.injuryTypeLabel,
      confidenceRowLabel: confidenceRowLabel ?? this.confidenceRowLabel,
      locationRowLabel: locationRowLabel ?? this.locationRowLabel,
      locationSectionTitle: locationSectionTitle ?? this.locationSectionTitle,
      bottomNoticeText: bottomNoticeText ?? this.bottomNoticeText,
      primaryActionLabel: primaryActionLabel ?? this.primaryActionLabel,
      analyzedImageUrl: analyzedImageUrl ?? this.analyzedImageUrl,
      rawImageBytes: rawImageBytes ?? this.rawImageBytes,
      imageFileName: imageFileName ?? this.imageFileName,
      detectedTopicId: detectedTopicId ?? this.detectedTopicId,
      isDetected: isDetected ?? this.isDetected,
      boundingBox: boundingBox ?? this.boundingBox,
      originalImageWidth: originalImageWidth ?? this.originalImageWidth,
      originalImageHeight: originalImageHeight ?? this.originalImageHeight,
      detectionMessage: detectionMessage ?? this.detectionMessage,
      isManualSelection: isManualSelection ?? this.isManualSelection,
      appliedContrast: appliedContrast ?? this.appliedContrast,
    );
  }
}
