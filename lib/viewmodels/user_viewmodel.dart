import 'package:flutter/material.dart';

import '../models/user_model.dart';

class UserViewModel extends ChangeNotifier {
  // Chỉ số màn hình hiện tại: 0 = Trang chủ, 1 = Phân tích ảnh AI
  int _currentScreenIndex = 0;
  int get currentScreenIndex => _currentScreenIndex;

  // Trạng thái tab đang chọn trên Top Navigation Bar: ['Trang chủ', 'Kiến thức', 'Tài liệu', 'Lịch sử']
  int _selectedNavIndex = 0;
  int get selectedNavIndex => _selectedNavIndex;

  // Trạng thái mục đang chọn trên Sidebar bên trái của màn hình Phân tích ảnh AI
  int _selectedSidebarIndex = 1;
  int get selectedSidebarIndex => _selectedSidebarIndex;

  // Tên người dùng hiển thị trên góc phải Header
  final String currentUserName = 'Nguyễn Văn A';

  // Trạng thái tên file ảnh đã chọn/chụp giả lập (null nếu chưa chọn ảnh)
  String? _selectedImageName;
  String? get selectedImageName => _selectedImageName;

  // Danh sách 4 mục menu ngang trên Top Navigation Bar
  final List<String> navItems = const [
    'Trang chủ',
    'Kiến thức',
    'Tài liệu',
    'Lịch sử',
  ];

  // Danh sách 6 mục menu dọc trên Sidebar bên trái (Màn hình 2)
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

  // Cấu hình văn bản chuẩn theo thiết kế màn hình "Phân tích hình ảnh tổn thương"
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
  // LOGIC ĐIỀU HƯỚNG GIỮA TRANG CHỦ VÀ MÀN HÌNH PHÂN TÍCH ẢNH AI
  // =========================================================================

  /// Chuyển sang màn hình Trang chủ
  void navigateToHome() {
    _currentScreenIndex = 0;
    _selectedNavIndex = 0;
    _selectedSidebarIndex = 0;
    notifyListeners();
  }

  /// Chuyển sang màn hình Phân tích ảnh AI
  void navigateToAiAnalysis() {
    _currentScreenIndex = 1;
    _selectedSidebarIndex = 1;
    notifyListeners();
  }

  /// Xử lý khi bấm chọn mục trên Top Navigation Bar
  void selectNavIndex(int index) {
    _selectedNavIndex = index;
    if (index == 0) {
      _currentScreenIndex = 0;
      _selectedSidebarIndex = 0;
    } else if (index == 1) {
      // Đồng bộ với mục Kiến thức trên Sidebar
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

  /// Xử lý khi bấm chọn mục trên thanh Sidebar bên trái (Màn hình 2)
  void selectSidebarIndex(int index) {
    _selectedSidebarIndex = index;
    if (index == 0) {
      // Bấm "Trang chủ" trên Sidebar -> Quay về màn hình Trang chủ
      _currentScreenIndex = 0;
      _selectedNavIndex = 0;
    } else if (index == 1) {
      // Bấm "Phân tích ảnh AI" -> Hiển thị màn hình Phân tích ảnh AI
      _currentScreenIndex = 1;
    } else {
      debugPrint(
        '[UserViewModel] Chuyển mục Sidebar: ${sidebarMenuItems[index].title}',
      );
    }
    notifyListeners();
  }

  // =========================================================================
  // CÁC HÀM SỰ KIỆN & CALLBACK CHỜ TÍCH HỢP NGHIỆP VỤ (STUB FUNCTIONS)
  // =========================================================================

  /// Sự kiện bấm nút "Phân tích hình ảnh ngay" trên Banner Trang chủ -> Mở màn hình Phân tích ảnh AI
  void onAnalyzeImageNowPressed() {
    debugPrint('[UserViewModel] Chuyển sang màn hình: Phân tích ảnh AI');
    navigateToAiAnalysis();
  }

  void onLookupKnowledgePressed() {
    debugPrint('[UserViewModel] Bấm nút: Tra cứu kiến thức');
  }

  void onSearchPressed() {
    debugPrint('[UserViewModel] Bấm nút: Tìm kiếm trên thanh điều hướng');
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
    }
  }

  void onSituationCardTapped(CommonSituationModel situation) {
    debugPrint(
      '[UserViewModel] Chọn tình huống thường gặp: ${situation.title}',
    );
  }

  /// Sự kiện bấm nút "Chọn ảnh" hoặc bấm vào vùng Kéo thả ảnh trên màn hình Phân tích ảnh AI
  void onSelectImageFromFilePressed() {
    debugPrint(
      '[UserViewModel] Mở hộp thoại chọn file ảnh (Hỗ trợ JPG, PNG, WEBP <= 10MB)',
    );
  }

  /// Sự kiện bấm nút "Chụp ảnh bằng camera" trên màn hình Phân tích ảnh AI
  void onCaptureFromCameraPressed() {
    debugPrint('[UserViewModel] Mở thiết bị Camera để chụp ảnh vết thương');
  }
}
