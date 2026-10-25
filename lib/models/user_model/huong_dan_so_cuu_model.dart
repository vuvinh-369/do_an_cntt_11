import 'package:flutter/material.dart';

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
