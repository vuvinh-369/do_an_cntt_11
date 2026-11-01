import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/first_aid_models.dart';
import '../models/navigation_model.dart';

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

  // Trạng thái mục đang chọn trên Sidebar bên trái:
  // 0: Trang chủ, 1: Phân tích ảnh AI, 2: Kiến thức sơ cứu, 3: Tài liệu, 4: Lịch sử phân tích, 5: ChatBox AI
  int _selectedSidebarIndex = 1;
  int get selectedSidebarIndex => _selectedSidebarIndex;

  // Ngăn xếp lịch sử điều hướng màn hình hỗ trợ nút Quay lại (Back button)
  final List<int> _navigationHistory = [0];
  bool get canNavigateBack => _navigationHistory.length > 1 || _currentScreenIndex != 0;

  void _pushScreen(int screenIndex) {
    if (_navigationHistory.isEmpty) {
      _navigationHistory.add(0);
    }
    if (_navigationHistory.last != screenIndex) {
      _navigationHistory.add(screenIndex);
    }
  }

  /// Quay lại màn hình trước đó trong lịch sử, hoặc trở về Trang chủ nếu không còn lịch sử
  void navigateBack() {
    if (_navigationHistory.length > 1) {
      _navigationHistory.removeLast();
      _currentScreenIndex = _navigationHistory.last;
    } else {
      _currentScreenIndex = 0;
      _navigationHistory.clear();
      _navigationHistory.add(0);
    }
    _syncSidebarAndNavIndex();
    notifyListeners();
  }

  void _syncSidebarAndNavIndex() {
    switch (_currentScreenIndex) {
      case 0:
        _selectedNavIndex = 0;
        _selectedSidebarIndex = 0;
        break;
      case 1:
      case 2:
        _selectedNavIndex = -1;
        _selectedSidebarIndex = 1; // Phân tích ảnh AI
        break;
      case 3:
      case 4:
        _selectedNavIndex = 1; // Kiến thức
        _selectedSidebarIndex = 2; // Kiến thức sơ cứu
        break;
      case 5:
        _selectedNavIndex = -1;
        _selectedSidebarIndex = 5; // ChatBox AI
        break;
      case 6:
        _selectedNavIndex = 2; // Tài liệu
        _selectedSidebarIndex = 3; // Tài liệu
        break;
      case 7:
        _selectedNavIndex = 3; // Lịch sử
        _selectedSidebarIndex = 4; // Lịch sử phân tích
        break;
      default:
        _selectedNavIndex = 0;
        _selectedSidebarIndex = 0;
    }
  }

  // Trạng thái tài khoản người dùng: Khách vãng lai (không bắt buộc đăng nhập) hoặc Đã đăng nhập
  bool _isUserLoggedIn = false;
  bool get isUserLoggedIn => _isUserLoggedIn;

  // Tên người dùng hiển thị trên góc phải Header
  String get currentUserName =>
      _isUserLoggedIn ? 'Nguyễn Văn A' : 'Khách';

  void loginUser([String name = 'Nguyễn Văn A']) {
    _isUserLoggedIn = true;
    notifyListeners();
  }

  void logoutUser() {
    _isUserLoggedIn = false;
    notifyListeners();
  }

  // Trạng thái tên file ảnh đã chọn/chụp giả lập
  String? _selectedImageName;
  String? get selectedImageName => _selectedImageName;

  // Chủ đề hướng dẫn sơ cứu đang được chọn để hiển thị trên Màn hình 4 (Mặc định: 'abrasion' -> 'Trầy xước')
  String _selectedGuideTopicId = 'abrasion';
  String get selectedGuideTopicId => _selectedGuideTopicId;

  // Khai báo getter trừu tượng để kiểm tra hợp lệ chủ đề sơ cứu khi điều hướng
  Map<String, FirstAidGuideModel> get firstAidGuidesByTopic;

  // Hook tự động được gọi khi người dùng chụp/tải ảnh mới để lưu vào Lịch sử phân tích trong RAM
  @protected
  void onNewAnalysisRecorded({
    required String imageSourceName,
    String? injuryType,
    int? confidencePercent,
    String? locationLabel,
    String? topicId,
    Uint8List? rawImageBytes,
  }) {}

  // Danh sách 4 mục menu ngang trên Top Navigation Bar
  final List<String> navItems = const [
    'Trang chủ',
    'Kiến thức',
    'Tài liệu',
    'Lịch sử',
  ];

  // Danh sách 6 mục menu dọc trên Sidebar bên trái (Đã loại bỏ Hướng dẫn sơ cứu trùng lặp và hợp nhất vào Kiến thức sơ cứu)
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
      id: 'knowledge',
      title: 'Kiến thức sơ cứu',
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
  // LOGIC ĐIỀU HƯỚNG XUYÊN SUỐT GIỮA CÁC MÀN HÌNH
  // =========================================================================

  /// Chuyển sang Màn hình 1: Trang chủ
  void navigateToHome() {
    _currentScreenIndex = 0;
    _navigationHistory.clear();
    _navigationHistory.add(0);
    _syncSidebarAndNavIndex();
    notifyListeners();
  }

  /// Chuyển sang Màn hình 2: Phân tích ảnh AI (Tải ảnh / Chụp ảnh)
  void navigateToAiAnalysis() {
    _pushScreen(1);
    _currentScreenIndex = 1;
    _syncSidebarAndNavIndex();
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
    _pushScreen(2);
    _currentScreenIndex = 2;
    _syncSidebarAndNavIndex();
    notifyListeners();
  }

  /// Chuyển sang Chi tiết Hướng dẫn sơ cứu (Dưới phân hệ Kiến thức sơ cứu)
  void navigateToFirstAidGuide({String? topicId}) {
    if (topicId != null && firstAidGuidesByTopic.containsKey(topicId)) {
      _selectedGuideTopicId = topicId;
    }
    _pushScreen(3);
    _currentScreenIndex = 3;
    _syncSidebarAndNavIndex();
    notifyListeners();
  }

  /// Chuyển sang Màn hình Tra cứu kiến thức sơ cứu (Người dùng)
  void navigateToKnowledgeLookup() {
    _pushScreen(4);
    _currentScreenIndex = 4;
    _syncSidebarAndNavIndex();
    notifyListeners();
  }

  /// Chuyển sang Màn hình ChatBox AI (Người dùng)
  void navigateToChatBoxAi() {
    _pushScreen(5);
    _currentScreenIndex = 5;
    _syncSidebarAndNavIndex();
    notifyListeners();
  }

  /// Chuyển sang Kho tài liệu y tế (Quản lý tài liệu lưu trữ cục bộ trên thiết bị)
  void navigateToMedicalDocuments() {
    _pushScreen(6);
    _currentScreenIndex = 6;
    _syncSidebarAndNavIndex();
    notifyListeners();
  }

  /// Chuyển sang Lịch sử phân tích (Người dùng)
  void navigateToAnalysisHistory() {
    _pushScreen(7);
    _currentScreenIndex = 7;
    _syncSidebarAndNavIndex();
    notifyListeners();
  }

  /// Xử lý khi bấm chọn mục trên Top Navigation Bar: ['Trang chủ', 'Kiến thức', 'Tài liệu', 'Lịch sử']
  void selectNavIndex(int index) {
    if (index == 0) {
      navigateToHome();
    } else if (index == 1) {
      navigateToKnowledgeLookup();
    } else if (index == 2) {
      navigateToMedicalDocuments();
    } else if (index == 3) {
      navigateToAnalysisHistory();
    }
  }

  /// Xử lý khi bấm chọn mục trên thanh Sidebar bên trái:
  /// 0: Trang chủ, 1: Phân tích ảnh AI, 2: Kiến thức sơ cứu, 3: Tài liệu, 4: Lịch sử phân tích, 5: ChatBox AI
  void selectSidebarIndex(int index) {
    if (index == 0) {
      navigateToHome();
    } else if (index == 1) {
      navigateToAiAnalysis();
    } else if (index == 2) {
      navigateToKnowledgeLookup();
    } else if (index == 3) {
      navigateToMedicalDocuments();
    } else if (index == 4) {
      navigateToAnalysisHistory();
    } else if (index == 5) {
      navigateToChatBoxAi();
    }
  }

  void onProfileAvatarPressed() {
    debugPrint(
      '[UserViewModel] Bấm vào thông tin người dùng: $currentUserName',
    );
  }
}
