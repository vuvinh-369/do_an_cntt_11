import 'package:flutter/material.dart';

import '../models/home_models.dart';
import '../models/first_aid_models.dart';
import 'user_navigation_viewmodel.dart';
import 'first_aid_viewmodel.dart';

mixin TrangChuViewModel on DieuHuongCoSoViewModel, HuongDanSoCuuViewModel {
  // Danh sách dữ liệu cho 4 Thẻ Tính năng (Feature Cards) trên Trang chủ
  final List<FeatureCardModel> featureCards = const [
    FeatureCardModel(
      id: 'ai_image_analysis',
      title: 'Phân tích ảnh AI',
      description: 'Nhận diện tổn thương và phân loại',
      icon: Icons.camera_enhance_outlined,
      iconColor: Color(0xFF0D9488), // Xanh ngọc (Teal)
      iconBackgroundColor: Color(0xFFE6F4F1),
    ),
    FeatureCardModel(
      id: 'first_aid_guide',
      title: 'Hướng dẫn sơ cứu',
      description: 'Các bước xử lý chi tiết dễ hiểu',
      icon: Icons.fact_check_outlined,
      iconColor: Color(0xFF16A34A), // Xanh lá (Green)
      iconBackgroundColor: Color(0xFFE8F7EE),
    ),
    FeatureCardModel(
      id: 'knowledge_lookup',
      title: 'Tra cứu kiến thức',
      description: 'Tìm hiểu các tình trạng thường gặp',
      icon: Icons.menu_book_outlined,
      iconColor: Color(0xFF2563EB), // Xanh dương (Blue)
      iconBackgroundColor: Color(0xFFEBF2FE),
    ),
    FeatureCardModel(
      id: 'ai_chatbox',
      title: 'ChatBox AI',
      description: 'Hỏi đáp nhanh với AI về sơ cứu',
      icon: Icons.smart_toy_outlined,
      iconColor: Color(0xFF7C3AED), // Tím (Purple)
      iconBackgroundColor: Color(0xFFF2EBFE),
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
      id: 'no_clear_injury',
      title: 'Không phát hiện tổn thương rõ ràng',
      baseSkinColor: Color(0xFFE6C3AD),
      woundAccentColor: Color(0xFF9E7B6B),
      medicalIcon: Icons.check_circle_outline,
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
    } else if (card.id == 'first_aid_guide') {
      navigateToFirstAidGuide(topicId: 'abrasion');
    } else if (card.id == 'knowledge_lookup') {
      navigateToKnowledgeLookup();
    } else if (card.id == 'ai_chatbox') {
      navigateToChatBoxAi();
    }
  }

  void onSituationCardTapped(CommonSituationModel situation) {
    if (firstAidGuidesByTopic.containsKey(situation.id)) {
      navigateToFirstAidGuide(topicId: situation.id);
    } else {
      navigateToFirstAidGuide(topicId: 'abrasion');
    }
  }
}
