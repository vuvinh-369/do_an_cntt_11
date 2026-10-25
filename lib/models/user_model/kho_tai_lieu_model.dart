import 'package:flutter/material.dart';

/// Mô hình dữ liệu cho từng mục Danh mục trong màn hình "Kho tài liệu y tế (Người dùng)" (Màn hình 7)
class MedicalDocumentCategoryModel {
  final String id;
  final String sidebarLabel;
  final String dropdownLabel;
  final IconData icon;

  const MedicalDocumentCategoryModel({
    required this.id,
    required this.sidebarLabel,
    required this.dropdownLabel,
    required this.icon,
  });
}

/// Mô hình dữ liệu cho từng Tài liệu Y tế được lưu trữ cục bộ trên thiết bị (Màn hình 7)
class MedicalDocumentModel {
  final String id;
  final String title;
  final String categoryId;
  final String categoryLabel;
  final String dateAdded;
  final int pageGroup;
  final String fileName;
  final String fileExtension;
  final String fileSize;
  final String localFilePath;
  final bool isUserAdded;
  final String summary;
  final List<String> contentPoints;
  final String? relatedGuideTopicId;

  const MedicalDocumentModel({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.categoryLabel,
    required this.dateAdded,
    this.pageGroup = 1,
    required this.fileName,
    this.fileExtension = 'PDF',
    this.fileSize = '1.2 MB',
    required this.localFilePath,
    this.isUserAdded = false,
    required this.summary,
    required this.contentPoints,
    this.relatedGuideTopicId,
  });

  MedicalDocumentModel copyWith({
    String? id,
    String? title,
    String? categoryId,
    String? categoryLabel,
    String? dateAdded,
    int? pageGroup,
    String? fileName,
    String? fileExtension,
    String? fileSize,
    String? localFilePath,
    bool? isUserAdded,
    String? summary,
    List<String>? contentPoints,
    String? relatedGuideTopicId,
  }) {
    return MedicalDocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      dateAdded: dateAdded ?? this.dateAdded,
      pageGroup: pageGroup ?? this.pageGroup,
      fileName: fileName ?? this.fileName,
      fileExtension: fileExtension ?? this.fileExtension,
      fileSize: fileSize ?? this.fileSize,
      localFilePath: localFilePath ?? this.localFilePath,
      isUserAdded: isUserAdded ?? this.isUserAdded,
      summary: summary ?? this.summary,
      contentPoints: contentPoints ?? this.contentPoints,
      relatedGuideTopicId: relatedGuideTopicId ?? this.relatedGuideTopicId,
    );
  }
}
