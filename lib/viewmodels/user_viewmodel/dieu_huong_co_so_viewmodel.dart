import 'package:flutter/material.dart';

import '../../models/user_model.dart';

mixin DieuHuongCoSoViewModel on ChangeNotifier {
  // Chỉ số màn hình hiện tại:
  // 0 = Trang chủ (Màn hình 1)
  // 1 = Phân tích ảnh AI - Tải/Chụp ảnh (Màn hình 2)
  // 2 = Kết quả phân tích (Màn hình 3)
  // 3 = Hướng dẫn sơ cứu (Màn hình 4)
  // 4 = Tra cứu kiến thức (Màn hình 5)
  // 5 = ChatBox AI (Màn hình 6)
  // 6 = Kho tài liệu y tế - Quản lý tài liệu cục bộ trên thiết bị (Màn hình 7)
  // 7 = Lịch sử phân tích (Màn hình 8)
  int _currentScreenIndex = 0;
  int get currentScreenIndex => _currentScreenIndex;

  // Trạng thái tab đang chọn trên Top Navigation Bar: ['Trang chủ', 'Kiến thức', 'Tài liệu', 'Lịch sử']
  int _selectedNavIndex = 0;
  int get selectedNavIndex => _selectedNavIndex;

  // Trạng thái mục đang chọn trên Sidebar bên trái (Màn hình 2, 3, 4, 5, 6, 7, 8)
  // 0: Trang chủ, 1: Phân tích ảnh AI, 2: Hướng dẫn sơ cứu, 3: Kiến thức, 4: Tài liệu, 5: Lịch sử phân tích, 6: ChatBox AI
  int _selectedSidebarIndex = 1;
  int get selectedSidebarIndex => _selectedSidebarIndex;

  // Tên người dùng hiển thị trên góc phải Header
  final String currentUserName = 'Nguyễn Văn A';

  // Trạng thái tên file ảnh đã chọn/chụp giả lập
  String? _selectedImageName;
  String? get selectedImageName => _selectedImageName;

  // Chủ đề hướng dẫn sơ cứu đang được chọn để hiển thị trên Màn hình 4 (Mặc định: 'abrasion' -> 'Trầy xước')
  String _selectedGuideTopicId = 'abrasion';
  String get selectedGuideTopicId => _selectedGuideTopicId;

  // Khai báo getter trừu tượng để kiểm tra hợp lệ chủ đề sơ cứu khi điều hướng
  Map<String, FirstAidGuideModel> get firstAidGuidesByTopic;

  // Hook tự động được gọi khi người dùng chụp/tải ảnh mới để lưu vào Lịch sử phân tích (Màn hình 8)
  @protected
  void onNewAnalysisRecorded({required String imageSourceName}) {}

  // Danh sách 4 mục menu ngang trên Top Navigation Bar
  final List<String> navItems = const [
    'Trang chủ',
    'Kiến thức',
    'Tài liệu',
    'Lịch sử',
  ];

  // Danh sách 7 mục menu dọc trên Sidebar bên trái (Bổ sung "Lịch sử phân tích" ngay dưới "Tài liệu")
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
      icon: Icons.history_outlined,
    ),
    SidebarMenuItemModel(
      id: 'ai_chatbox',
      title: 'ChatBox AI',
      icon: Icons.smart_toy_outlined,
    ),
  ];

  // =========================================================================
  // LOGIC ĐIỀU HƯỚNG XUYÊN SUỐT GIỮA 8 MÀN HÌNH (1 <-> 2 <-> 3 <-> 4 <-> 5 <-> 6 <-> 7 <-> 8)
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
  /// Tự động kích hoạt lưu bản ghi vào Lịch sử phân tích nếu recordHistory == true
  void navigateToAnalysisResult({
    String? imageSourceName,
    bool recordHistory = true,
  }) {
    final resolvedImageName = imageSourceName ?? 'wound_sample_arm.jpg';
    _selectedImageName = resolvedImageName;
    if (recordHistory) {
      onNewAnalysisRecorded(imageSourceName: resolvedImageName);
    }
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

  /// Chuyển sang Màn hình 6: ChatBox AI (Người dùng)
  void navigateToChatBoxAi() {
    _currentScreenIndex = 5;
    _selectedSidebarIndex = 6;
    notifyListeners();
  }

  /// Chuyển sang Màn hình 7: Kho tài liệu y tế (Quản lý tài liệu lưu trữ cục bộ trên thiết bị)
  void navigateToMedicalDocuments() {
    _currentScreenIndex = 6;
    _selectedSidebarIndex = 4;
    _selectedNavIndex = 2;
    notifyListeners();
  }

  /// Chuyển sang Màn hình 8: Lịch sử phân tích (Người dùng)
  void navigateToAnalysisHistory() {
    _currentScreenIndex = 7;
    _selectedSidebarIndex = 5;
    _selectedNavIndex = 3;
    notifyListeners();
  }

  /// Xử lý khi bấm chọn mục trên Top Navigation Bar: ['Trang chủ', 'Kiến thức', 'Tài liệu', 'Lịch sử']
  void selectNavIndex(int index) {
    _selectedNavIndex = index;
    if (index == 0) {
      _currentScreenIndex = 0;
      _selectedSidebarIndex = 0;
    } else if (index == 1) {
      _currentScreenIndex = 4;
      _selectedSidebarIndex = 3;
    } else if (index == 2) {
      _currentScreenIndex = 6;
      _selectedSidebarIndex = 4;
    } else if (index == 3) {
      _currentScreenIndex = 7;
      _selectedSidebarIndex = 5;
    }
    notifyListeners();
  }

  /// Xử lý khi bấm chọn mục trên thanh Sidebar bên trái
  /// 0: Trang chủ, 1: Phân tích ảnh AI, 2: Hướng dẫn sơ cứu, 3: Kiến thức, 4: Tài liệu, 5: Lịch sử phân tích, 6: ChatBox AI
  void selectSidebarIndex(int index) {
    _selectedSidebarIndex = index;
    if (index == 0) {
      _currentScreenIndex = 0;
      _selectedNavIndex = 0;
    } else if (index == 1) {
      _currentScreenIndex = 1;
    } else if (index == 2) {
      _currentScreenIndex = 3;
    } else if (index == 3) {
      _currentScreenIndex = 4;
      _selectedNavIndex = 1;
    } else if (index == 4) {
      _currentScreenIndex = 6;
      _selectedNavIndex = 2;
    } else if (index == 5) {
      _currentScreenIndex = 7;
      _selectedNavIndex = 3;
    } else if (index == 6) {
      _currentScreenIndex = 5;
    }
    notifyListeners();
  }

  void onProfileAvatarPressed() {
    debugPrint(
      '[UserViewModel] Bấm vào thông tin người dùng: $currentUserName',
    );
  }
}
