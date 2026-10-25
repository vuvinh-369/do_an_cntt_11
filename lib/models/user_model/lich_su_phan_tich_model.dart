import 'package:flutter/material.dart';

/// Mô hình dữ liệu cho từng bản ghi trong màn hình "8. Lịch sử phân tích (Người dùng)" (Màn hình 8)
class AnalysisHistoryItemModel {
  final String id;
  final String injuryType;
  final int? confidencePercent;
  final String locationLabel;
  final String timestamp;
  final DateTime dateTime;
  final String? imageSourceName;
  final String? relatedTopicId;
  final Color baseSkinColor;
  final Color woundAccentColor;

  const AnalysisHistoryItemModel({
    required this.id,
    required this.injuryType,
    this.confidencePercent,
    required this.locationLabel,
    required this.timestamp,
    required this.dateTime,
    this.imageSourceName,
    this.relatedTopicId,
    this.baseSkinColor = const Color(0xFFE8BEAC),
    this.woundAccentColor = const Color(0xFFD9383A),
  });

  /// Hiển thị tiêu đề kèm phần trăm độ tin cậy (예: "Trầy xước (82%)")
  /// Nếu confidencePercent == null (như "Không phát hiện tổn thương rõ ràng") thì chỉ hiển thị tên
  String get displayTitle => confidencePercent != null
      ? '$injuryType ($confidencePercent%)'
      : injuryType;

  AnalysisHistoryItemModel copyWith({
    String? id,
    String? injuryType,
    int? confidencePercent,
    String? locationLabel,
    String? timestamp,
    DateTime? dateTime,
    String? imageSourceName,
    String? relatedTopicId,
    Color? baseSkinColor,
    Color? woundAccentColor,
  }) {
    return AnalysisHistoryItemModel(
      id: id ?? this.id,
      injuryType: injuryType ?? this.injuryType,
      confidencePercent: confidencePercent ?? this.confidencePercent,
      locationLabel: locationLabel ?? this.locationLabel,
      timestamp: timestamp ?? this.timestamp,
      dateTime: dateTime ?? this.dateTime,
      imageSourceName: imageSourceName ?? this.imageSourceName,
      relatedTopicId: relatedTopicId ?? this.relatedTopicId,
      baseSkinColor: baseSkinColor ?? this.baseSkinColor,
      woundAccentColor: woundAccentColor ?? this.woundAccentColor,
    );
  }
}
