import 'package:flutter/material.dart';

/// Mô hình dữ liệu cho mỗi Thẻ tính năng (Feature Card) trên Trang chủ
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

/// Mô hình dữ liệu cho mỗi thẻ trong mục "Tình huống thường gặp" trên Trang chủ
class CommonSituationModel {
  final String id;
  final String title;
  final String?
  imageUrl; // Đường dẫn ảnh mạng hoặc để null dùng placeholder an toàn
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

/// Mô hình dữ liệu cho từng mục menu trên thanh Sidebar bên trái (Màn hình 2)
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

/// Mô hình dữ liệu cấu hình văn bản hiển thị cho khu vực Phân tích hình ảnh tổn thương
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
