import 'package:flutter/material.dart';

import '../models/home_models.dart';
import 'user_navigation_viewmodel.dart';
import 'first_aid_viewmodel.dart';

mixin TrangChuViewModel on DieuHuongCoSoViewModel, HuongDanSoCuuViewModel {
  // Danh sách dữ liệu cho 6 Thẻ Tính năng (Feature Cards) trên Trang chủ
  final List<FeatureCardModel> featureCards = const [
    FeatureCardModel(
      id: 'ai_image_analysis',
      title: 'Phân tích ảnh AI',
      description: 'Nhận diện tổn thương và phân loại vết thương',
      icon: Icons.camera_enhance_outlined,
      iconColor: Color(0xFF0D9488), // Xanh ngọc (Teal)
      iconBackgroundColor: Color(0xFFE6F4F1),
      badge: 'Thị giác AI',
    ),
    FeatureCardModel(
      id: 'knowledge_lookup',
      title: 'Kiến thức sơ cứu',
      description: 'Quy trình và cẩm nang sơ cứu chuẩn y tế',
      icon: Icons.menu_book_outlined,
      iconColor: Color(0xFF2563EB), // Xanh dương (Blue)
      iconBackgroundColor: Color(0xFFEBF2FE),
      badge: 'Chuẩn y tế',
    ),
    FeatureCardModel(
      id: 'medical_documents',
      title: 'Kho tài liệu y tế',
      description: 'Sổ tay & cẩm nang lưu trữ trên máy',
      icon: Icons.description_outlined,
      iconColor: Color(0xFF16A34A), // Xanh lá (Green)
      iconBackgroundColor: Color(0xFFE8F7EE),
      badge: 'Offline',
    ),
    FeatureCardModel(
      id: 'ai_chatbox',
      title: 'ChatBox AI',
      description: 'Hỏi đáp nhanh với trợ lý sơ cứu 24/7',
      icon: Icons.smart_toy_outlined,
      iconColor: Color(0xFF7C3AED), // Tím (Purple)
      iconBackgroundColor: Color(0xFFF2EBFE),
      badge: 'Hỗ trợ 24/7',
    ),
    FeatureCardModel(
      id: 'doctor_consultation',
      title: 'Tư vấn Bác sĩ',
      description: 'Trao đổi trực tiếp 1-1 với bác sĩ chuyên khoa',
      icon: Icons.medical_services_outlined,
      iconColor: Color(0xFF0284C7), // Xanh chuyên khoa
      iconBackgroundColor: Color(0xFFE0F2FE),
      badge: 'Trực tuyến 1-1',
    ),
    FeatureCardModel(
      id: 'daily_care',
      title: 'Chăm sóc sức khỏe hằng ngày',
      description: 'Bài học về vận động, uống nước, ăn uống và nghỉ ngơi',
      icon: Icons.spa_outlined,
      iconColor: Color(0xFF059669), // Xanh ngọc lục bảo (Emerald)
      iconBackgroundColor: Color(0xFFE6F7F0),
      badge: 'Sống khỏe',
    ),
  ];

  // Danh sách dữ liệu cho 5 thẻ "Tình huống thường gặp" trên Trang chủ
  final List<CommonSituationModel> commonSituations = const [
    CommonSituationModel(
      id: 'abrasion',
      title: 'Trầy xước',
      baseSkinColor: Color(0xFFE8C5B0),
      woundAccentColor: Color(0xFFC85A48),
      medicalIcon: Icons.grain,
    ),
    CommonSituationModel(
      id: 'cut_laceration',
      title: 'Vết cắt / Vết rách',
      baseSkinColor: Color(0xFFF2D2BD),
      woundAccentColor: Color(0xFFD96B52),
      medicalIcon: Icons.content_cut,
    ),
    CommonSituationModel(
      id: 'burn',
      title: 'Bỏng',
      baseSkinColor: Color(0xFFE5B89B),
      woundAccentColor: Color(0xFFE04F3E),
      medicalIcon: Icons.local_fire_department_outlined,
    ),
    CommonSituationModel(
      id: 'bruise',
      title: 'Bầm',
      baseSkinColor: Color(0xFFEACBB8),
      woundAccentColor: Color(0xFF8E5B72),
      medicalIcon: Icons.blur_circular,
    ),
    CommonSituationModel(
      id: 'other_wounds',
      title: 'Vết thương khác',
      baseSkinColor: Color(0xFFD6C2B4),
      woundAccentColor: Color(0xFF2563EB),
      medicalIcon: Icons.menu_book_rounded,
    ),
  ];

  void onAnalyzeImageNowPressed() {
    navigateToAiAnalysis();
  }

  void onLookupKnowledgePressed() {
    navigateToKnowledgeLookup();
  }

  void onSearchPressed() {
    navigateToKnowledgeLookup();
  }

  void onFeatureCardTapped(FeatureCardModel card) {
    if (card.id == 'ai_image_analysis') {
      navigateToAiAnalysis();
    } else if (card.id == 'knowledge_lookup' || card.id == 'first_aid_guide') {
      navigateToKnowledgeLookup();
    } else if (card.id == 'medical_documents') {
      navigateToMedicalDocuments();
    } else if (card.id == 'ai_chatbox') {
      navigateToChatBoxAi();
    } else if (card.id == 'doctor_consultation') {
      navigateToDoctorConsultation();
    } else if (card.id == 'daily_care') {
      navigateToDailyCare();
    }
  }

  void onSituationCardTapped(CommonSituationModel situation) {
    if (situation.id == 'other_wounds' || situation.id == 'no_clear_injury') {
      // Khi nhấn vào "Vết thương khác" -> chuyển ngay sang màn hình Tra cứu kiến thức sơ cứu
      navigateToKnowledgeLookup();
      return;
    }
    if (firstAidGuidesByTopic.containsKey(situation.id)) {
      navigateToFirstAidGuide(topicId: situation.id);
    } else {
      navigateToKnowledgeLookup();
    }
  }
}
