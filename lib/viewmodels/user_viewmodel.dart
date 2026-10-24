import 'package:flutter/material.dart';

import '../models/user_model.dart';

class UserViewModel extends ChangeNotifier {
  // Chỉ số màn hình hiện tại:
  // 0 = Trang chủ (Màn hình 1)
  // 1 = Phân tích ảnh AI - Tải/Chụp ảnh (Màn hình 2)
  // 2 = Kết quả phân tích (Màn hình 3)
  // 3 = Hướng dẫn sơ cứu (Màn hình 4)
  // 4 = Tra cứu kiến thức (Màn hình 5)
  int _currentScreenIndex = 0;
  int get currentScreenIndex => _currentScreenIndex;

  // Trạng thái tab đang chọn trên Top Navigation Bar: ['Trang chủ', 'Kiến thức', 'Tài liệu', 'Lịch sử']
  int _selectedNavIndex = 0;
  int get selectedNavIndex => _selectedNavIndex;

  // Trạng thái mục đang chọn trên Sidebar bên trái (Màn hình 2, 3, 4, 5)
  // 0: Trang chủ, 1: Phân tích ảnh AI, 2: Hướng dẫn sơ cứu, 3: Kiến thức, 4: Tài liệu, 5: Lịch sử phân tích
  int _selectedSidebarIndex = 1;
  int get selectedSidebarIndex => _selectedSidebarIndex;

  // Tên người dùng hiển thị trên góc phải Header
  final String currentUserName = 'Nguyễn Văn A';

  // Trạng thái tên file ảnh đã chọn/chụp giả lập
  String? _selectedImageName;
  String? get selectedImageName => _selectedImageName;

  // Trạng thái vị trí tổn thương đang được chọn trên Màn hình 3 (Mặc định: 'arm' -> 'Cánh tay')
  String _selectedLocationId = 'arm';
  String get selectedLocationId => _selectedLocationId;

  // Chủ đề hướng dẫn sơ cứu đang được chọn để hiển thị trên Màn hình 4 (Mặc định: 'abrasion' -> 'Trầy xước')
  String _selectedGuideTopicId = 'abrasion';
  String get selectedGuideTopicId => _selectedGuideTopicId;

  // Danh mục đang chọn trên Màn hình 5: Tra cứu kiến thức (Mặc định: 'all' -> 'Tất cả')
  String _selectedKnowledgeCategoryId = 'all';
  String get selectedKnowledgeCategoryId => _selectedKnowledgeCategoryId;

  // Từ khóa tìm kiếm trên Màn hình 5: Tra cứu kiến thức
  String _knowledgeSearchQuery = '';
  String get knowledgeSearchQuery => _knowledgeSearchQuery;

  // Danh sách 4 mục menu ngang trên Top Navigation Bar
  final List<String> navItems = const [
    'Trang chủ',
    'Kiến thức',
    'Tài liệu',
    'Lịch sử',
  ];

  // Danh sách 6 mục menu dọc trên Sidebar bên trái (Màn hình 2, 3, 4, 5)
  final List<SidebarMenuItemModel> sidebarMenuItems = const [
    SidebarMenuItemModel(
      id: 'home',
      title: 'Trang chủ',
      icon: Icons.home_outlined,
    ),
    SidebarMenuItemModel(
      id: 'ai_analysis',
      title: 'Phân tích ảnh AI',
      icon: Icons.center_focus_strong_outlined,
    ),
    SidebarMenuItemModel(
      id: 'first_aid_guide',
      title: 'Hướng dẫn sơ cứu',
      icon: Icons.medical_services_outlined,
    ),
    SidebarMenuItemModel(
      id: 'knowledge',
      title: 'Kiến thức',
      icon: Icons.menu_book_outlined,
    ),
    SidebarMenuItemModel(
      id: 'documents',
      title: 'Tài liệu',
      icon: Icons.description_outlined,
    ),
    SidebarMenuItemModel(
      id: 'analysis_history',
      title: 'Lịch sử phân tích',
      icon: Icons.history,
    ),
  ];

  // Cấu hình văn bản chuẩn theo thiết kế màn hình "Phân tích hình ảnh tổn thương" (Màn hình 2)
  final AiUploadSpecModel uploadSpec = const AiUploadSpecModel(
    screenTitle: 'Phân tích hình ảnh tổn thương',
    dropzonePrefixText: 'Kéo thả ảnh vào đây hoặc ',
    dropzoneActionText: 'chọn ảnh',
    supportedFormatsText: 'Hỗ trợ: JPG, PNG, WEBP (tối đa 10MB)',
    selectButtonLabel: 'Chọn ảnh',
    dividerText: 'Hoặc chụp ảnh',
    cameraButtonLabel: 'Chụp ảnh bằng camera',
    noticeBoldText:
        'Lưu ý: Hệ thống chỉ hỗ trợ phân tích các vết thương ngoài da.',
    noticeDetailText: 'Nếu kết quả không đủ độ tin cậy, chúng tôi sẽ không tự động đưa ra hướng dẫn sơ cứu.',
  );

  // Cấu hình dữ liệu chuẩn theo thiết kế Màn hình 3: "Kết quả phân tích (Người dùng)"
  final AiAnalysisResultModel analysisResult = const AiAnalysisResultModel(
    bannerTitle: 'Kết quả phân tích',
    confidenceLabelPrefix: 'Độ tin cậy:',
    confidencePercent: 92,
    injuryType: 'Trầy xước',
    boundingBoxLabel: 'Trầy xước 92%',
    infoCardTitle: 'Thông tin nhận diện',
    injuryTypeLabel: 'Loại tổn thương:',
    confidenceRowLabel: 'Độ tin cậy:',
    locationRowLabel: 'Vị trí:',
    locationSectionTitle: 'Chọn vị trí tổn thương',
    bottomNoticeText: 'Hệ thống đã nhận diện được tổn thương. Vui lòng chọn vị trí cụ thể để xem hướng dẫn sơ cứu phù hợp.',
    primaryActionLabel: 'Xem hướng dẫn sơ cứu',
  );

  // Danh sách 5 vị trí tổn thương trên Màn hình 3
  final List<InjuryLocationOptionModel> injuryLocations = const [
    InjuryLocationOptionModel(
      id: 'arm',
      label: 'Cánh tay',
      fallbackIcon: Icons.front_hand_outlined,
    ),
    InjuryLocationOptionModel(
      id: 'leg',
      label: 'Chân',
      fallbackIcon: Icons.directions_walk_outlined,
    ),
    InjuryLocationOptionModel(
      id: 'head',
      label: 'Đầu',
      fallbackIcon: Icons.face_outlined,
    ),
    InjuryLocationOptionModel(
      id: 'back',
      label: 'Lưng',
      fallbackIcon: Icons.accessibility_new_outlined,
    ),
    InjuryLocationOptionModel(
      id: 'other',
      label: 'Khác',
      fallbackIcon: Icons.open_with_outlined,
    ),
  ];

  // Danh sách 5 danh mục lọc trên Màn hình 5: "5. Tra cứu kiến thức (Người dùng)"
  final List<KnowledgeCategoryModel> knowledgeCategories = const [
    KnowledgeCategoryModel(id: 'all', label: 'Tất cả'),
    KnowledgeCategoryModel(id: 'wound', label: 'Vết thương'),
    KnowledgeCategoryModel(id: 'burn', label: 'Bỏng'),
    KnowledgeCategoryModel(id: 'musculoskeletal', label: 'Xương khớp'),
    KnowledgeCategoryModel(id: 'other', label: 'Khác'),
  ];

  // Danh sách 6 thẻ kiến thức sơ cứu chuẩn theo ảnh thiết kế Màn hình 5
  final List<KnowledgeTopicModel> knowledgeTopics = const [
    KnowledgeTopicModel(
      id: 'abrasion',
      categoryId: 'wound',
      title: 'Trầy xước',
      subtitle: 'Cách xử lý và chăm sóc',
    ),
    KnowledgeTopicModel(
      id: 'cut_laceration',
      categoryId: 'wound',
      title: 'Vết cắt / Vết rách',
      subtitle: 'Cầm máu và sát trùng',
    ),
    KnowledgeTopicModel(
      id: 'burn',
      categoryId: 'burn',
      title: 'Bỏng',
      subtitle: 'Xử lý bỏng đúng cách',
    ),
    KnowledgeTopicModel(
      id: 'bruise',
      categoryId: 'musculoskeletal',
      title: 'Bầm',
      subtitle: 'Giảm sưng và đau',
    ),
    KnowledgeTopicModel(
      id: 'foreign_body',
      categoryId: 'other',
      title: 'Dị vật',
      subtitle: 'Xử lý khi có dị vật',
    ),
    KnowledgeTopicModel(
      id: 'poisoning',
      categoryId: 'other',
      title: 'Ngộ độc',
      subtitle: 'Nhận biết và xử lý',
    ),
  ];

  /// Danh sách các thẻ kiến thức sau khi áp dụng bộ lọc Danh mục và Từ khóa tìm kiếm
  List<KnowledgeTopicModel> get filteredKnowledgeTopics {
    final query = _knowledgeSearchQuery.trim().toLowerCase();
    return knowledgeTopics.where((topic) {
      final matchesCategory =
          _selectedKnowledgeCategoryId == 'all' ||
          topic.categoryId == _selectedKnowledgeCategoryId;
      final matchesQuery =
          query.isEmpty ||
          topic.title.toLowerCase().contains(query) ||
          topic.subtitle.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  // Từ điển dữ liệu Hướng dẫn sơ cứu (Màn hình 4) tương ứng với từng vết thương khi click từ Màn hình 5 hoặc Trang chủ
  final Map<String, FirstAidGuideModel> firstAidGuidesByTopic = const {
    'abrasion': FirstAidGuideModel(
      topicId: 'abrasion',
      screenTitle: 'Hướng dẫn sơ cứu – Trầy xước',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Trầy xước nhẹ',
      safetyNoteText: 'Không có dấu hiệu nguy hiểm',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'wash_hands',
          title: 'Rửa tay sạch',
          description: 'Đảm bảo vệ sinh trước khi xử lý vết thương.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'clean_wound',
          title: 'Làm sạch vết thương',
          description: 'Dùng nước sạch hoặc dung dịch sát khuẩn nhẹ.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Sát trùng',
          description: 'Dùng dung dịch sát khuẩn (như povidone-iodine).',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Băng vết thương',
          description: 'Dùng gạc sạch và băng cố định nhẹ.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Vết thương sâu, chảy máu nhiều.',
        'Có dấu hiệu nhiễm trùng (sưng, đỏ, nóng, đau).',
        'Không cầm máu sau 15 phút.',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
    'cut_laceration': FirstAidGuideModel(
      topicId: 'cut_laceration',
      screenTitle: 'Hướng dẫn sơ cứu – Vết cắt / Vết rách',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Vết cắt / Vết rách ngoài da',
      safetyNoteText: 'Cần cầm máu và sát trùng đúng cách',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'wash_hands',
          title: 'Rửa tay sạch & Cầm máu',
          description:
              'Dùng gạc sạch ấn nhẹ trực tiếp lên vết thương để cầm máu.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'clean_wound',
          title: 'Làm sạch vết thương',
          description: 'Rửa nhẹ nhàng bằng nước muối sinh lý hoặc nước sạch.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Sát trùng',
          description: 'Thoa dung dịch sát khuẩn quanh mép vết cắt.',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Băng vết thương',
          description:
              'Đặt gạc vô trùng và băng kín vừa phải để bảo vệ vết thương.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Vết thương sâu, bờ vết rách hở rộng hoặc chảy máu nhiều.',
        'Có dấu hiệu nhiễm trùng (sưng, đỏ, nóng, đau).',
        'Không cầm máu sau 15 phút ấn trực tiếp.',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
    'burn': FirstAidGuideModel(
      topicId: 'burn',
      screenTitle: 'Hướng dẫn sơ cứu – Bỏng',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Bỏng bề mặt ngoài da',
      safetyNoteText: 'Cần làm mát vùng bỏng ngay lập tức',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'clean_wound',
          title: 'Làm mát vết bỏng',
          description:
              'Xả nước mát sạch nhẹ nhàng lên vùng bỏng từ 15 – 20 phút.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'wash_hands',
          title: 'Tháo bỏ vật dụng gây chèn ép',
          description:
              'Nhẹ nhàng tháo nhẫn, đồng hồ, vòng tay trước khi vùng da sưng.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Giữ sạch vùng da bỏng',
          description:
              'Không chọc vỡ bóng nước, không bôi kem đánh răng hoặc nước mắm.',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Che phủ vết bỏng',
          description:
              'Dùng gạc vô trùng không dính che nhẹ lên vùng da bị bỏng.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Vết bỏng diện rộng, phồng rộp lớn hoặc bỏng ở mặt, bàn tay, khớp.',
        'Bỏng do hóa chất, điện giật hoặc có dấu hiệu nhiễm trùng.',
        'Người bị bỏng sốt cao, đau rát dữ dội hoặc choáng váng.',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
    'bruise': FirstAidGuideModel(
      topicId: 'bruise',
      screenTitle: 'Hướng dẫn sơ cứu – Bầm',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Bầm tím phần mềm dưới da',
      safetyNoteText: 'Không có dấu hiệu rách da hở',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'clean_wound',
          title: 'Chườm lạnh sớm',
          description:
              'Bọc túi đá trong khăn sạch và chườm lên vùng bầm 15 – 20 phút.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'wash_hands',
          title: 'Nghỉ ngơi và hạn chế vận động mạnh',
          description:
              'Tránh va đập thêm hoặc xoa bóp dầu nóng trong 24 giờ đầu.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Kê cao vùng bị thương',
          description:
              'Nếu có thể, kê cao vùng tay/chân bị bầm để giảm sưng nề.',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Theo dõi sự thay đổi màu sắc',
          description: 'Sau 48 giờ có thể chườm ấm nhẹ để hỗ trợ tan máu bầm.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Vùng bầm sưng to nhanh, đau nhức dữ dội hoặc nghi ngờ gãy xương.',
        'Không thể cử động khớp hoặc chi tại vùng bị chấn thương.',
        'Vết bầm không giảm sau 2 tuần hoặc xuất hiện tự nhiên không rõ nguyên nhân.',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
    'foreign_body': FirstAidGuideModel(
      topicId: 'foreign_body',
      screenTitle: 'Hướng dẫn sơ cứu – Dị vật',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Dị vật ngoài da',
      safetyNoteText: 'Thận trọng, không tự ý rút dị vật đâm sâu',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'wash_hands',
          title: 'Rửa tay sạch và đánh giá dị vật',
          description: 'Quan sát kỹ vị trí, kích thước và độ sâu của dị vật.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'clean_wound',
          title: 'Xử lý dị vật nhỏ nông trên bề mặt',
          description:
              'Dùng nhíp đã khử trùng cồn nhẹ nhàng gắp dằm/dị vật nhỏ nông.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Làm sạch và sát trùng',
          description:
              'Rửa bằng nước muối sinh lý và thoa dung dịch povidone-iodine.',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Cố định và băng bảo vệ',
          description: 'Nếu dị vật lớn đâm sâu, giữ nguyên và chèn gạc cố định quanh dị vật.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Dị vật đâm sâu, kích thước lớn hoặc nằm gần mắt, mạch máu lớn.',
        'Có dấu hiệu nhiễm trùng (sưng, đỏ, nóng, đau, chảy mủ).',
        'Dị vật là mảnh kim loại rỉ sét, thủy tinh vỡ hoặc không lấy ra hết được.',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
    'poisoning': FirstAidGuideModel(
      topicId: 'poisoning',
      screenTitle: 'Hướng dẫn sơ cứu – Ngộ độc',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Nghi ngờ ngộ độc thực phẩm / tiếp xúc',
      safetyNoteText: 'Theo dõi sát dấu hiệu sinh tồn của người bệnh',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'wash_hands',
          title: 'Ngừng ngay tiếp xúc với tác nhân gây độc',
          description: 'Ngưng ăn uống thực phẩm nghi ngờ hoặc đưa nạn nhân ra nơi thoáng khí.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'clean_wound',
          title: 'Bù nước và điện giải đúng cách',
          description: 'Cho uống từng ngụm nhỏ dung dịch Oresol hoặc nước ấm nếu còn tỉnh táo.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Giữ lại mẫu thực phẩm hoặc nhãn chất độc',
          description: 'Lưu giữ mẫu vật để nhân viên y tế xác định chính xác nguyên nhân.',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Đặt nằm nghỉ ở tư thế an toàn',
          description: 'Cho người bệnh nằm đầu thấp, nghiêng mặt sang một bên nếu buồn nôn.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Nôn ói liên tục, tiêu chảy nhiều lần, sốt cao hoặc đau bụng dữ dội.',
        'Có dấu hiệu mất nước nặng, môi khô, mạch nhanh, lơ mơ hoặc co giật.',
        'Ngộ độc hóa chất, thuốc trừ sâu, nấm lạ (tuyệt đối không tự gây nôn nếu lơ mơ).',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
  };

  /// Lấy dữ liệu Hướng dẫn sơ cứu hiện tại để hiển thị trên Màn hình 4
  FirstAidGuideModel get firstAidGuide {
    return firstAidGuidesByTopic[_selectedGuideTopicId] ??
        firstAidGuidesByTopic['abrasion']!;
  }

  /// Lấy nhãn tên vị trí tổn thương đang được chọn để hiển thị trong thẻ "Thông tin nhận diện"
  String get selectedLocationLabel {
    for (final option in injuryLocations) {
      if (option.id == _selectedLocationId) {
        return option.label;
      }
    }
    return injuryLocations.first.label;
  }

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

  // =========================================================================
  // LOGIC ĐIỀU HƯỚNG XUYÊN SUỐT GIỮA 5 MÀN HÌNH (1 <-> 2 <-> 3 <-> 4 <-> 5)
  // =========================================================================

  /// Chuyển sang Màn hình 1: Trang chủ
  void navigateToHome() {
    _currentScreenIndex = 0;
    _selectedNavIndex = 0;
    _selectedSidebarIndex = 0;
    notifyListeners();
  }

  /// Chuyển sang Màn hình 2: Phân tích ảnh AI (Tải ảnh / Chụp ảnh)
  void navigateToAiAnalysis() {
    _currentScreenIndex = 1;
    _selectedSidebarIndex = 1;
    notifyListeners();
  }

  /// Chuyển sang Màn hình 3: Kết quả phân tích (Người dùng)
  void navigateToAnalysisResult({String? imageSourceName}) {
    _selectedImageName = imageSourceName ?? 'wound_sample_arm.jpg';
    _currentScreenIndex = 2;
    _selectedSidebarIndex = 1;
    notifyListeners();
  }

  /// Chuyển sang Màn hình 4: Hướng dẫn sơ cứu (Người dùng)
  void navigateToFirstAidGuide({String? topicId}) {
    if (topicId != null && firstAidGuidesByTopic.containsKey(topicId)) {
      _selectedGuideTopicId = topicId;
    }
    _currentScreenIndex = 3;
    _selectedSidebarIndex = 2;
    notifyListeners();
  }

  /// Chuyển sang Màn hình 5: Tra cứu kiến thức (Người dùng)
  void navigateToKnowledgeLookup() {
    _currentScreenIndex = 4;
    _selectedSidebarIndex = 3;
    _selectedNavIndex = 1;
    notifyListeners();
  }

  /// Xử lý khi bấm chọn mục trên Top Navigation Bar
  void selectNavIndex(int index) {
    _selectedNavIndex = index;
    if (index == 0) {
      _currentScreenIndex = 0;
      _selectedSidebarIndex = 0;
    } else if (index == 1) {
      // Bấm "Kiến thức" trên Top Navigation Bar -> Mở Màn hình 5 (Tra cứu kiến thức)
      _currentScreenIndex = 4;
      _selectedSidebarIndex = 3;
    } else if (index == 2) {
      // Đồng bộ với mục Tài liệu trên Sidebar
      _selectedSidebarIndex = 4;
    } else if (index == 3) {
      // Đồng bộ với mục Lịch sử phân tích trên Sidebar
      _selectedSidebarIndex = 5;
    }
    notifyListeners();
  }

  /// Xử lý khi bấm chọn mục trên thanh Sidebar bên trái (Màn hình 2, 3, 4, 5)
  void selectSidebarIndex(int index) {
    _selectedSidebarIndex = index;
    if (index == 0) {
      // Bấm "Trang chủ" trên Sidebar -> Quay về Màn hình 1
      _currentScreenIndex = 0;
      _selectedNavIndex = 0;
    } else if (index == 1) {
      // Bấm "Phân tích ảnh AI" -> Mở Màn hình 2
      _currentScreenIndex = 1;
    } else if (index == 2) {
      // Bấm "Hướng dẫn sơ cứu" -> Mở Màn hình 4
      _currentScreenIndex = 3;
    } else if (index == 3) {
      // Bấm "Kiến thức" -> Mở Màn hình 5 (Tra cứu kiến thức)
      _currentScreenIndex = 4;
      _selectedNavIndex = 1;
    } else {
      debugPrint(
        '[UserViewModel] Chuyển mục Sidebar: ${sidebarMenuItems[index].title}',
      );
    }
    notifyListeners();
  }

  /// Cập nhật vị trí tổn thương khi người dùng chọn 1 trong 5 vị trí trên Màn hình 3
  void selectInjuryLocation(String locationId) {
    if (_selectedLocationId == locationId) return;
    _selectedLocationId = locationId;
    debugPrint(
      '[UserViewModel] Đã chọn vị trí tổn thương: $selectedLocationLabel ($locationId)',
    );
    notifyListeners();
  }

  /// Chọn danh mục lọc trên Màn hình 5 (Tất cả, Vết thương, Bỏng, Xương khớp, Khác)
  void selectKnowledgeCategory(String categoryId) {
    if (_selectedKnowledgeCategoryId == categoryId) return;
    _selectedKnowledgeCategoryId = categoryId;
    notifyListeners();
  }

  /// Cập nhật từ khóa tìm kiếm trên Màn hình 5
  void updateKnowledgeSearchQuery(String query) {
    _knowledgeSearchQuery = query;
    notifyListeners();
  }

  /// Sự kiện bấm nút "Tìm kiếm" màu xanh trên Màn hình 5
  void onKnowledgeSearchSubmitted() {
    debugPrint(
      '[UserViewModel] Thực hiện tìm kiếm kiến thức với từ khóa: "$_knowledgeSearchQuery"',
    );
    notifyListeners();
  }

  /// Sự kiện click vào từng thẻ vết thương trên Màn hình 5 -> Mở ngay Màn hình 4 (Hướng dẫn sơ cứu)
  void onKnowledgeTopicCardTapped(KnowledgeTopicModel topic) {
    debugPrint(
      '[UserViewModel] Click thẻ kiến thức "${topic.title}" -> Mở ngay Hướng dẫn sơ cứu',
    );
    navigateToFirstAidGuide(topicId: topic.id);
  }

  // =========================================================================
  // CÁC HÀM SỰ KIỆN & CALLBACK ĐIỀU HƯỚNG NGHIỆP VỤ
  // =========================================================================

  /// Sự kiện bấm nút "Phân tích hình ảnh ngay" trên Banner Trang chủ -> Mở Màn hình 2
  void onAnalyzeImageNowPressed() {
    debugPrint('[UserViewModel] Chuyển sang màn hình: Phân tích ảnh AI');
    navigateToAiAnalysis();
  }

  /// Sự kiện bấm nút "Tra cứu kiến thức" trên Banner Trang chủ -> Mở Màn hình 5
  void onLookupKnowledgePressed() {
    debugPrint('[UserViewModel] Chuyển sang màn hình: 5. Tra cứu kiến thức');
    navigateToKnowledgeLookup();
  }

  void onSearchPressed() {
    debugPrint('[UserViewModel] Bấm nút: Tìm kiếm trên thanh điều hướng');
    navigateToKnowledgeLookup();
  }

  void onProfileAvatarPressed() {
    debugPrint(
      '[UserViewModel] Bấm vào thông tin người dùng: $currentUserName',
    );
  }

  /// Sự kiện bấm vào 1 trong 4 Thẻ tính năng trên Trang chủ
  void onFeatureCardTapped(FeatureCardModel card) {
    debugPrint('[UserViewModel] Chọn thẻ tính năng: ${card.title}');
    if (card.id == 'ai_image_analysis') {
      navigateToAiAnalysis();
    } else if (card.id == 'first_aid_guide') {
      navigateToFirstAidGuide(topicId: 'abrasion');
    } else if (card.id == 'knowledge_lookup') {
      navigateToKnowledgeLookup();
    }
  }

  /// Sự kiện bấm vào thẻ Tình huống thường gặp trên Trang chủ -> Mở ngay Hướng dẫn sơ cứu tương ứng
  void onSituationCardTapped(CommonSituationModel situation) {
    debugPrint(
      '[UserViewModel] Chọn tình huống thường gặp: ${situation.title}',
    );
    if (firstAidGuidesByTopic.containsKey(situation.id)) {
      navigateToFirstAidGuide(topicId: situation.id);
    } else {
      navigateToFirstAidGuide(topicId: 'abrasion');
    }
  }

  /// Sự kiện bấm nút "Chọn ảnh" hoặc vùng Kéo thả ảnh trên Màn hình 2 -> Chuyển sang Màn hình 3
  void onSelectImageFromFilePressed() {
    debugPrint(
      '[UserViewModel] Chọn ảnh từ thiết bị thành công -> Hiển thị Màn hình 3: Kết quả phân tích',
    );
    navigateToAnalysisResult(imageSourceName: 'selected_arm_abrasion.jpg');
  }

  /// Sự kiện bấm nút "Chụp ảnh bằng camera" trên Màn hình 2 -> Chuyển sang Màn hình 3
  void onCaptureFromCameraPressed() {
    debugPrint(
      '[UserViewModel] Chụp ảnh từ Camera thành công -> Hiển thị Màn hình 3: Kết quả phân tích',
    );
    navigateToAnalysisResult(imageSourceName: 'camera_capture_abrasion.jpg');
  }

  /// Sự kiện bấm nút "Xem hướng dẫn sơ cứu ->" trên Màn hình 3 -> Chuyển sang Màn hình 4
  void onViewFirstAidGuidePressed() {
    debugPrint(
      '[UserViewModel] Chuyển sang Màn hình 4 (Hướng dẫn sơ cứu) cho tổn thương: '
      '${analysisResult.injuryType} (${analysisResult.formattedConfidence}) - '
      'Vị trí: $selectedLocationLabel',
    );
    navigateToFirstAidGuide(topicId: 'abrasion');
  }

  /// Sự kiện bấm nút "Quay lại phân tích ảnh" trên Màn hình 4 -> Quay lại Màn hình 2
  void onBackToImageAnalysisPressed() {
    debugPrint(
      '[UserViewModel] Bấm "Quay lại phân tích ảnh" -> Quay về Màn hình 2 (Phân tích ảnh AI)',
    );
    navigateToAiAnalysis();
  }
}
