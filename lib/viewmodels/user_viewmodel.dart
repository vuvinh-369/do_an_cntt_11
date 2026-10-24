import 'package:flutter/material.dart';

import '../models/user_model.dart';

class UserViewModel extends ChangeNotifier {
  // Chỉ số màn hình hiện tại:
  // 0 = Trang chủ (Màn hình 1)
  // 1 = Phân tích ảnh AI - Tải/Chụp ảnh (Màn hình 2)
  // 2 = Kết quả phân tích (Màn hình 3)
  // 3 = Hướng dẫn sơ cứu (Màn hình 4)
  // 4 = Tra cứu kiến thức (Màn hình 5)
  // 5 = ChatBox AI (Màn hình 6)
  // 6 = Kho tài liệu y tế - Quản lý tài liệu cục bộ trên thiết bị (Màn hình 7)
  int _currentScreenIndex = 0;
  int get currentScreenIndex => _currentScreenIndex;

  // Trạng thái tab đang chọn trên Top Navigation Bar: ['Trang chủ', 'Kiến thức', 'Tài liệu', 'Lịch sử']
  int _selectedNavIndex = 0;
  int get selectedNavIndex => _selectedNavIndex;

  // Trạng thái mục đang chọn trên Sidebar bên trái (Màn hình 2, 3, 4, 5, 6, 7)
  // 0: Trang chủ, 1: Phân tích ảnh AI, 2: Hướng dẫn sơ cứu, 3: Kiến thức, 4: Tài liệu, 5: ChatBox AI
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

  // Bộ điều khiển nhập liệu và cuộn danh sách tin nhắn trên Màn hình 6: ChatBox AI
  final TextEditingController chatInputController = TextEditingController();
  final ScrollController chatScrollController = ScrollController();
  String _currentChatInput = '';
  String get currentChatInput => _currentChatInput;

  // Trạng thái tìm kiếm, lọc danh mục và phân trang trên Màn hình 7: Kho tài liệu y tế
  final TextEditingController documentSearchController =
      TextEditingController();
  String _documentSearchQuery = '';
  String get documentSearchQuery => _documentSearchQuery;

  String _selectedDocumentCategoryId = 'all';
  String get selectedDocumentCategoryId => _selectedDocumentCategoryId;

  int _currentDocumentPage = 1;
  int get currentDocumentPage => _currentDocumentPage;

  // Danh sách các tệp mẫu có sẵn trên thiết bị để người dùng chọn nhanh khi bấm "+ Thêm tài liệu"
  final List<Map<String, String>> sampleDeviceFiles = const [
    {
      'fileName': 'so_tay_so_cuu_gia_dinh_2026.pdf',
      'fileExtension': 'PDF',
      'fileSize': '2.4 MB',
      'localFilePath': 'C:/Users/NguyenVanA/Documents/Medical/so_tay_so_cuu_gia_dinh_2026.pdf',
    },
    {
      'fileName': 'quy_trinh_xu_ly_bong_nhiet.docx',
      'fileExtension': 'DOCX',
      'fileSize': '850 KB',
      'localFilePath': 'C:/Users/NguyenVanA/Documents/Medical/quy_trinh_xu_ly_bong_nhiet.docx',
    },
    {
      'fileName': 'huong_dan_cam_mau_vet_cat.pdf',
      'fileExtension': 'PDF',
      'fileSize': '1.6 MB',
      'localFilePath':
          'C:/Users/NguyenVanA/Documents/Medical/huong_dan_cam_mau_vet_cat.pdf',
    },
    {
      'fileName': 'bang_kiem_dung_cu_y_te_ca_nhan.txt',
      'fileExtension': 'TXT',
      'fileSize': '120 KB',
      'localFilePath': 'C:/Users/NguyenVanA/Documents/Medical/bang_kiem_dung_cu_y_te_ca_nhan.txt',
    },
  ];

  // Danh sách 4 mục menu ngang trên Top Navigation Bar
  final List<String> navItems = const [
    'Trang chủ',
    'Kiến thức',
    'Tài liệu',
    'Lịch sử',
  ];

  // Danh sách 6 mục menu dọc trên Sidebar bên trái
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
      id: 'ai_chatbox',
      title: 'ChatBox AI',
      icon: Icons.smart_toy_outlined,
    ),
  ];

  // Lịch sử tin nhắn hội thoại trên Màn hình 6: Khởi tạo RỖNG khi mới vào
  final List<ChatMessageModel> _chatMessages = [];
  List<ChatMessageModel> get chatMessages => List.unmodifiable(_chatMessages);

  // Danh sách các câu hỏi gợi ý nhanh khi khung chat đang trống
  final List<String> quickSuggestedQuestions = const [
    'Làm sao để xử lý khi bị bỏng nhẹ?',
    'Cách sơ cứu khi bị trầy xước ngoài da?',
    'Xử lý vết cắt chảy máu như thế nào?',
    'Làm gì khi bị bầm tím phần mềm?',
  ];

  // Danh sách 6 danh mục bên trái và trong Dropdown của Màn hình 7: "Kho tài liệu y tế"
  final List<MedicalDocumentCategoryModel> documentCategories = const [
    MedicalDocumentCategoryModel(
      id: 'all',
      sidebarLabel: 'Tất cả (24)',
      dropdownLabel: 'Tất cả danh mục',
      icon: Icons.folder_copy_outlined,
    ),
    MedicalDocumentCategoryModel(
      id: 'basic_first_aid',
      sidebarLabel: 'Sơ cứu cơ bản',
      dropdownLabel: 'Sơ cứu cơ bản',
      icon: Icons.fact_check_outlined,
    ),
    MedicalDocumentCategoryModel(
      id: 'wound',
      sidebarLabel: 'Vết thương (6)',
      dropdownLabel: 'Vết thương',
      icon: Icons.assignment_outlined,
    ),
    MedicalDocumentCategoryModel(
      id: 'burn',
      sidebarLabel: 'Bỏng',
      dropdownLabel: 'Bỏng',
      icon: Icons.local_hospital_outlined,
    ),
    MedicalDocumentCategoryModel(
      id: 'foreign_body',
      sidebarLabel: 'Dị vật',
      dropdownLabel: 'Dị vật',
      icon: Icons.medication_outlined,
    ),
    MedicalDocumentCategoryModel(
      id: 'other',
      sidebarLabel: 'Khác',
      dropdownLabel: 'Khác',
      icon: Icons.person_outline_rounded,
    ),
  ];

  // Danh sách tài liệu y tế được lưu trữ cục bộ trên thiết bị (Có thể Thêm, Mở, Tìm kiếm, Phân loại, Sửa, Xóa)
  final List<MedicalDocumentModel> _medicalDocuments = [
    // --- TRANG 1 (Khớp 100% với ảnh thiết kế Kho tài liệu y tế) ---
    const MedicalDocumentModel(
      id: 'doc_1',
      title: 'Hướng dẫn sơ cứu cơ bản',
      categoryId: 'basic_first_aid',
      categoryLabel: 'Sơ cứu cơ bản',
      dateAdded: '12/10/2025',
      pageGroup: 1,
      fileName: 'huong_dan_so_cuu_co_ban.pdf',
      fileExtension: 'PDF',
      fileSize: '1.8 MB',
      localFilePath: 'C:/Users/NguyenVanA/Documents/KhoTaiLieuYTe/huong_dan_so_cuu_co_ban.pdf',
      summary: 'Tài liệu tổng hợp quy trình đánh giá hiện trường, kiểm tra phản ứng của nạn nhân và các nguyên tắc sơ cứu ban đầu an toàn được lưu trữ cục bộ trên thiết bị.',
      contentPoints: [
        '1. Đảm bảo an toàn cho bản thân và nạn nhân trước khi tiếp cận hiện trường.',
        '2. Kiểm tra sự tỉnh táo, đường thở và nhịp thở của người bị nạn.',
        '3. Rửa tay sạch hoặc đeo găng tay y tế trước khi tiếp xúc với vết thương hở.',
        '4. Gọi cấp cứu 115 ngay nếu nạn nhân bất tỉnh, khó thở hoặc chảy máu không cầm.',
      ],
      relatedGuideTopicId: 'abrasion',
    ),
    const MedicalDocumentModel(
      id: 'doc_2',
      title: 'Xử lý vết thương ngoài da',
      categoryId: 'wound',
      categoryLabel: 'Vết thương',
      dateAdded: '10/10/2025',
      pageGroup: 1,
      fileName: 'xu_ly_vet_thuong_ngoai_da.pdf',
      fileExtension: 'PDF',
      fileSize: '1.4 MB',
      localFilePath: 'C:/Users/NguyenVanA/Documents/KhoTaiLieuYTe/xu_ly_vet_thuong_ngoai_da.pdf',
      summary: 'Quy trình chuẩn làm sạch, sát khuẩn và băng bó các vết trầy xước, vết cắt hoặc vết rách nông ngoài da giúp ngăn ngừa nhiễm trùng.',
      contentPoints: [
        '1. Dùng gạc vô trùng ấn nhẹ trực tiếp lên vết thương để cầm máu ban đầu.',
        '2. Rửa vết thương dưới vòi nước sạch hoặc nước muối sinh lý NaCl 0.9%.',
        '3. Thoa dung dịch sát khuẩn nhẹ (Povidone-Iodine) xung quanh vùng tổn thương.',
        '4. Che phủ bằng băng gạc vô trùng và thay băng hàng ngày hoặc khi bị ướt.',
      ],
      relatedGuideTopicId: 'cut_laceration',
    ),
    const MedicalDocumentModel(
      id: 'doc_3',
      title: 'Sơ cứu bỏng',
      categoryId: 'burn',
      categoryLabel: 'Bỏng',
      dateAdded: '08/10/2025',
      pageGroup: 1,
      fileName: 'so_cuu_bong_nhiet.pdf',
      fileExtension: 'PDF',
      fileSize: '1.1 MB',
      localFilePath:
          'C:/Users/NguyenVanA/Documents/KhoTaiLieuYTe/so_cuu_bong_nhiet.pdf',
      summary: 'Hướng dẫn làm mát vùng da bị bỏng nhiệt đúng cách, giảm tổn thương mô sâu và các điều tuyệt đối tránh khi sơ cứu bỏng.',
      contentPoints: [
        '1. Đưa vùng da bị bỏng dưới dòng nước mát sạch chảy nhẹ trong 15 – 20 phút.',
        '2. Tháo bỏ sớm nhẫn, vòng tay, đồng hồ trước khi vùng bỏng bị sưng nề.',
        '3. Tuyệt đối không chọc vỡ bóng nước, không bôi kem đánh răng, mỡ trăn hay nước mắm.',
        '4. Che phủ nhẹ nhàng bằng gạc vô trùng không dính và theo dõi dấu hiệu nhiễm trùng.',
      ],
      relatedGuideTopicId: 'burn',
    ),
    const MedicalDocumentModel(
      id: 'doc_4',
      title: 'Nhận biết và xử lý dị vật',
      categoryId: 'foreign_body',
      categoryLabel: 'Dị vật',
      dateAdded: '05/10/2025',
      pageGroup: 1,
      fileName: 'nhan_biet_va_xu_ly_di_vat.docx',
      fileExtension: 'DOCX',
      fileSize: '920 KB',
      localFilePath: 'C:/Users/NguyenVanA/Documents/KhoTaiLieuYTe/nhan_biet_va_xu_ly_di_vat.docx',
      summary: 'Cách phân biệt dị vật nông trên bề mặt da và dị vật đâm sâu để xử lý an toàn, tránh làm tổn thương mạch máu và dây thần kinh.',
      contentPoints: [
        '1. Quan sát kỹ vị trí, kích thước và độ sâu của dị vật trên da.',
        '2. Với dằm nhỏ nằm nông: Dùng nhíp đã khử trùng cồn gắp nhẹ theo chiều dị vật đâm vào.',
        '3. Với dị vật lớn hoặc đâm sâu: Tuyệt đối không tự rút ra, hãy chèn gạc cố định xung quanh.',
        '4. Đưa người bệnh đến cơ sở y tế gần nhất nếu dị vật sâu hoặc có nguy cơ uốn ván.',
      ],
      relatedGuideTopicId: 'foreign_body',
    ),
    const MedicalDocumentModel(
      id: 'doc_5',
      title: 'Các dấu hiệu cảnh báo nguy hiểm',
      categoryId: 'other',
      categoryLabel: 'Khác',
      dateAdded: '03/10/2025',
      pageGroup: 1,
      fileName: 'cac_dau_hieu_canh_bao_nguy_hiem.pdf',
      fileExtension: 'PDF',
      fileSize: '1.5 MB',
      localFilePath: 'C:/Users/NguyenVanA/Documents/KhoTaiLieuYTe/cac_dau_hieu_canh_bao_nguy_hiem.pdf',
      summary: 'Danh mục các triệu chứng cảnh báo đỏ (Red Flags) sau chấn thương hoặc ngộ độc đòi hỏi phải chuyển viện cấp cứu ngay lập tức.',
      contentPoints: [
        '1. Vết thương chảy máu thành tia hoặc không cầm máu sau 15 phút ấn trực tiếp.',
        '2. Vùng tổn thương sưng nóng đỏ đau tăng nhanh, chảy dịch mủ hoặc kèm sốt cao.',
        '3. Nạn nhân có biểu hiện hoa mắt, chóng mặt, vã mồ hôi lạnh, thở gấp hoặc lơ mơ.',
        '4. Bỏng diện rộng, bỏng vùng mặt/cổ/bàn tay hoặc nghi ngờ ngộ độc hóa chất.',
      ],
      relatedGuideTopicId: 'poisoning',
    ),

    // --- TRANG 2 ---
    const MedicalDocumentModel(
      id: 'doc_6',
      title: 'Cầm máu vết cắt và vết rách sâu',
      categoryId: 'wound',
      categoryLabel: 'Vết thương',
      dateAdded: '01/10/2025',
      pageGroup: 2,
      fileName: 'cam_mau_vet_cat_sau.pdf',
      fileExtension: 'PDF',
      fileSize: '1.3 MB',
      localFilePath:
          'C:/Users/NguyenVanA/Documents/KhoTaiLieuYTe/cam_mau_vet_cat_sau.pdf',
      summary: 'Kỹ thuật băng ép trực tiếp và kê cao chi bị thương nhằm kiểm soát chảy máu hiệu quả trước khi đến cơ sở y tế.',
      contentPoints: [
        '1. Đặt lớp gạc dày vô trùng trực tiếp lên miệng vết cắt và ấn giữ liên tục.',
        '2. Nếu máu thấm ướt lớp gạc đầu tiên, đặt chồng thêm lớp gạc mới lên trên, không tháo lớp cũ.',
        '3. Kê cao vùng tay hoặc chân bị thương cao hơn mức tim nếu không nghi ngờ gãy xương.',
      ],
      relatedGuideTopicId: 'cut_laceration',
    ),
    const MedicalDocumentModel(
      id: 'doc_7',
      title: 'Chăm sóc vết bầm tím phần mềm',
      categoryId: 'wound',
      categoryLabel: 'Vết thương',
      dateAdded: '28/09/2025',
      pageGroup: 2,
      fileName: 'cham_soc_vet_bam_tim.docx',
      fileExtension: 'DOCX',
      fileSize: '780 KB',
      localFilePath: 'C:/Users/NguyenVanA/Documents/KhoTaiLieuYTe/cham_soc_vet_bam_tim.docx',
      summary: 'Hướng dẫn áp dụng quy tắc chườm lạnh trong 24 giờ đầu và chườm ấm sau 48 giờ để giảm sưng đau và tan máu bầm.',
      contentPoints: [
        '1. Chườm lạnh bằng túi đá bọc khăn sạch 15 – 20 phút mỗi lần trong 24 giờ đầu.',
        '2. Tuyệt đối không xoa bóp dầu nóng ngay sau khi mới va đập.',
        '3. Sau 48 giờ, có thể chườm ấm nhẹ để tăng tuần hoàn giúp tan vết bầm.',
      ],
      relatedGuideTopicId: 'bruise',
    ),
    const MedicalDocumentModel(
      id: 'doc_8',
      title: 'Sơ cứu ngộ độc thực phẩm tại nhà',
      categoryId: 'other',
      categoryLabel: 'Khác',
      dateAdded: '25/09/2025',
      pageGroup: 2,
      fileName: 'so_cuu_ngo_doc_thuc_pham.pdf',
      fileExtension: 'PDF',
      fileSize: '1.6 MB',
      localFilePath: 'C:/Users/NguyenVanA/Documents/KhoTaiLieuYTe/so_cuu_ngo_doc_thuc_pham.pdf',
      summary: 'Cách bù nước điện giải Oresol và theo dõi dấu hiệu mất nước khi nghi ngờ ngộ độc thức ăn.',
      contentPoints: [
        '1. Ngừng ngay việc sử dụng thực phẩm nghi ngờ gây ngộ độc.',
        '2. Cho người bệnh uống từng ngụm nhỏ dung dịch Oresol pha đúng tỷ lệ.',
        '3. Đưa đi khám ngay nếu nôn ói liên tục, sốt cao hoặc li bì.',
      ],
      relatedGuideTopicId: 'poisoning',
    ),

    // --- TRANG 3 ---
    const MedicalDocumentModel(
      id: 'doc_9',
      title: 'Danh mục dụng cụ trong hộp sơ cứu gia đình',
      categoryId: 'basic_first_aid',
      categoryLabel: 'Sơ cứu cơ bản',
      dateAdded: '20/09/2025',
      pageGroup: 3,
      fileName: 'danh_muc_hop_so_cuu_gia_dinh.txt',
      fileExtension: 'TXT',
      fileSize: '95 KB',
      localFilePath: 'C:/Users/NguyenVanA/Documents/KhoTaiLieuYTe/danh_muc_hop_so_cuu_gia_dinh.txt',
      summary: 'Danh sách các vật tư y tế thiết yếu cần chuẩn bị sẵn trong tủ thuốc và túi sơ cứu cá nhân.',
      contentPoints: [
        '1. Băng gạc vô trùng các kích cỡ, băng cuộn y tế và băng cá nhân.',
        '2. Nước muối sinh lý NaCl 0.9% và dung dịch sát khuẩn Povidone-Iodine.',
        '3. Nhíp y tế, kéo đầu tù, găng tay y tế sạch và nhiệt kế.',
      ],
      relatedGuideTopicId: 'abrasion',
    ),
    const MedicalDocumentModel(
      id: 'doc_10',
      title: 'Phòng ngừa nhiễm trùng vết thương hở',
      categoryId: 'wound',
      categoryLabel: 'Vết thương',
      dateAdded: '15/09/2025',
      pageGroup: 3,
      fileName: 'phong_ngua_nhiem_trung_vet_thuong.pdf',
      fileExtension: 'PDF',
      fileSize: '1.2 MB',
      localFilePath: 'C:/Users/NguyenVanA/Documents/KhoTaiLieuYTe/phong_ngua_nhiem_trung_vet_thuong.pdf',
      summary: 'Hướng dẫn theo dõi quá trình lành thương và nhận biết sớm các biểu hiện nhiễm khuẩn ngoài da.',
      contentPoints: [
        '1. Giữ vết thương luôn khô ráo, sạch sẽ và thay băng đúng định kỳ.',
        '2. Không tự ý rắc bột kháng sinh hoặc đắp lá cây lên vết thương hở.',
        '3. Đi khám bác sĩ nếu vết thương sưng tấy, tấy đỏ lan rộng hoặc chảy dịch vàng.',
      ],
      relatedGuideTopicId: 'abrasion',
    ),
  ];

  List<MedicalDocumentModel> get allMedicalDocuments =>
      List.unmodifiable(_medicalDocuments);

  /// Lấy nhãn hiển thị trên cột danh mục bên trái (Cập nhật số lượng động khi người dùng thêm/xóa tài liệu)
  String getDocumentCategorySidebarLabel(
    MedicalDocumentCategoryModel category,
  ) {
    final userAddedCount = _medicalDocuments.where((d) => d.isUserAdded).length;
    if (category.id == 'all') {
      final totalCount = 24 + userAddedCount;
      return 'Tất cả ($totalCount)';
    }
    if (category.id == 'wound') {
      final userAddedWound = _medicalDocuments
          .where((d) => d.isUserAdded && d.categoryId == 'wound')
          .length;
      return 'Vết thương (${6 + userAddedWound})';
    }
    return category.sidebarLabel;
  }

  /// Lấy nhãn tên danh mục từ `categoryId`
  String getCategoryLabelById(String categoryId) {
    for (final cat in documentCategories) {
      if (cat.id == categoryId && cat.id != 'all') {
        return cat.dropdownLabel;
      }
    }
    return 'Sơ cứu cơ bản';
  }

  /// Lấy danh sách tài liệu hiển thị trên bảng dựa theo Bộ lọc danh mục, Từ khóa tìm kiếm và Phân trang
  List<MedicalDocumentModel> get filteredMedicalDocuments {
    final query = _documentSearchQuery.trim().toLowerCase();
    final isFilteringOrSearching =
        _selectedDocumentCategoryId != 'all' || query.isNotEmpty;

    final matched = _medicalDocuments.where((doc) {
      final matchesCategory =
          _selectedDocumentCategoryId == 'all' ||
          doc.categoryId == _selectedDocumentCategoryId;
      final matchesQuery =
          query.isEmpty ||
          doc.title.toLowerCase().contains(query) ||
          doc.categoryLabel.toLowerCase().contains(query) ||
          doc.fileName.toLowerCase().contains(query) ||
          doc.dateAdded.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    // Khi đang ở chế độ mặc định ("Tất cả" và chưa nhập từ khóa), hiển thị theo trang 1, 2, 3
    if (!isFilteringOrSearching) {
      return matched
          .where((doc) => doc.pageGroup == _currentDocumentPage)
          .toList();
    }

    return matched;
  }

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

  // Từ điển dữ liệu Hướng dẫn sơ cứu (Màn hình 4) tương ứng với từng vết thương
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
  // LOGIC ĐIỀU HƯỚNG XUYÊN SUỐT GIỮA 7 MÀN HÌNH (1 <-> 2 <-> 3 <-> 4 <-> 5 <-> 6 <-> 7)
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

  /// Chuyển sang Màn hình 6: ChatBox AI (Người dùng)
  void navigateToChatBoxAi() {
    _currentScreenIndex = 5;
    _selectedSidebarIndex = 5;
    notifyListeners();
  }

  /// Chuyển sang Màn hình 7: Kho tài liệu y tế (Quản lý tài liệu lưu trữ cục bộ trên thiết bị)
  void navigateToMedicalDocuments() {
    _currentScreenIndex = 6;
    _selectedSidebarIndex = 4;
    _selectedNavIndex = 2;
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
      _currentScreenIndex = 5;
      _selectedSidebarIndex = 5;
    }
    notifyListeners();
  }

  /// Xử lý khi bấm chọn mục trên thanh Sidebar bên trái
  /// 0: Trang chủ, 1: Phân tích ảnh AI, 2: Hướng dẫn sơ cứu, 3: Kiến thức, 4: Tài liệu, 5: ChatBox AI
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
      _currentScreenIndex = 5;
    }
    notifyListeners();
  }

  /// Cập nhật vị trí tổn thương khi người dùng chọn 1 trong 5 vị trí trên Màn hình 3
  void selectInjuryLocation(String locationId) {
    if (_selectedLocationId == locationId) return;
    _selectedLocationId = locationId;
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
    notifyListeners();
  }

  /// Sự kiện click vào từng thẻ vết thương trên Màn hình 5 -> Mở ngay Màn hình 4 (Hướng dẫn sơ cứu)
  void onKnowledgeTopicCardTapped(KnowledgeTopicModel topic) {
    navigateToFirstAidGuide(topicId: topic.id);
  }

  // =========================================================================
  // LOGIC QUẢN LÝ KHO TÀI LIỆU Y TẾ CỤC BỘ TRÊN THIẾT BỊ (MÀN HÌNH 7)
  // 1. Thêm tài liệu | 2. Mở tài liệu | 3. Tìm kiếm | 4. Phân loại | 5. Quản lý | 6. Lưu cục bộ
  // =========================================================================

  /// 1. Thêm tài liệu mới từ tệp lưu trữ cục bộ trên thiết bị
  void addLocalMedicalDocument({
    required String title,
    required String categoryId,
    required String fileName,
    required String fileExtension,
    required String fileSize,
    required String localFilePath,
    required String summary,
    List<String>? contentPoints,
  }) {
    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final categoryLabel = getCategoryLabelById(categoryId);

    String? mappedGuideTopicId;
    if (categoryId == 'burn') {
      mappedGuideTopicId = 'burn';
    } else if (categoryId == 'wound') {
      mappedGuideTopicId = 'cut_laceration';
    } else if (categoryId == 'foreign_body') {
      mappedGuideTopicId = 'foreign_body';
    } else if (categoryId == 'other') {
      mappedGuideTopicId = 'poisoning';
    } else {
      mappedGuideTopicId = 'abrasion';
    }

    final newDoc = MedicalDocumentModel(
      id: 'local_doc_${now.microsecondsSinceEpoch}',
      title: title.trim(),
      categoryId: categoryId,
      categoryLabel: categoryLabel,
      dateAdded: formattedDate,
      pageGroup: 1,
      fileName: fileName.trim(),
      fileExtension: fileExtension.toUpperCase(),
      fileSize: fileSize,
      localFilePath: localFilePath.trim(),
      isUserAdded: true,
      summary: summary.trim().isEmpty
          ? 'Tài liệu y tế được người dùng thêm và lưu trữ cục bộ trên thiết bị.'
          : summary.trim(),
      contentPoints: (contentPoints != null && contentPoints.isNotEmpty)
          ? contentPoints
          : const [
              '1. Tệp tài liệu đã được lưu trữ trong bộ nhớ cục bộ của thiết bị.',
              '2. Có thể tra cứu nhanh ngoại tuyến (Offline) bất cứ lúc nào.',
              '3. Tuân thủ hướng dẫn sơ cứu an toàn và liên hệ y tế khi cần thiết.',
            ],
      relatedGuideTopicId: mappedGuideTopicId,
    );

    // Chèn lên đầu danh sách để hiển thị ngay ở đầu bảng Trang 1
    _medicalDocuments.insert(0, newDoc);
    _currentDocumentPage = 1;
    notifyListeners();
  }

  /// 2. Cập nhật / Phân loại lại tài liệu y tế (Quản lý tài liệu)
  void updateMedicalDocument({
    required String id,
    required String newTitle,
    required String newCategoryId,
    required String newSummary,
  }) {
    final index = _medicalDocuments.indexWhere((doc) => doc.id == id);
    if (index == -1) return;

    final current = _medicalDocuments[index];
    final updatedCategoryLabel = getCategoryLabelById(newCategoryId);

    _medicalDocuments[index] = current.copyWith(
      title: newTitle.trim().isEmpty ? current.title : newTitle.trim(),
      categoryId: newCategoryId,
      categoryLabel: updatedCategoryLabel,
      summary: newSummary.trim().isEmpty ? current.summary : newSummary.trim(),
    );
    notifyListeners();
  }

  /// 3. Xóa tài liệu khỏi danh sách quản lý trên thiết bị
  void deleteMedicalDocument(String id) {
    _medicalDocuments.removeWhere((doc) => doc.id == id);
    notifyListeners();
  }

  /// 4. Tìm kiếm tài liệu y tế theo từ khóa
  void updateDocumentSearchQuery(String query) {
    _documentSearchQuery = query;
    _currentDocumentPage = 1;
    notifyListeners();
  }

  /// 5. Phân loại / Lọc danh mục tài liệu (đồng bộ cả menu dọc bên trái và Dropdown phía trên)
  void selectDocumentCategory(String categoryId) {
    if (_selectedDocumentCategoryId == categoryId) return;
    _selectedDocumentCategoryId = categoryId;
    _currentDocumentPage = 1;
    notifyListeners();
  }

  /// 6. Chuyển trang trên thanh phân trang (1, 2, 3) của Kho tài liệu y tế
  void selectDocumentPage(int page) {
    if (page < 1 || page > 3) return;
    if (_currentDocumentPage == page) return;
    _currentDocumentPage = page;
    notifyListeners();
  }

  void goToPreviousDocumentPage() {
    if (_currentDocumentPage > 1) {
      _currentDocumentPage--;
      notifyListeners();
    }
  }

  void goToNextDocumentPage() {
    if (_currentDocumentPage < 3) {
      _currentDocumentPage++;
      notifyListeners();
    }
  }

  // =========================================================================
  // LOGIC TƯƠNG TÁC CHATBOX AI & TỰ ĐỘNG CUỘN TIN NHẮN LÊN TRÊN (MÀN HÌNH 6)
  // =========================================================================

  void updateChatInput(String value) {
    _currentChatInput = value;
  }

  void _scrollToLatestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatScrollController.hasClients) {
        chatScrollController.animateTo(
          chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void sendChatMessage([String? submittedText]) {
    final rawText = (submittedText ?? chatInputController.text).trim();
    if (rawText.isEmpty) return;

    final now = DateTime.now();
    final formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    _chatMessages.add(
      ChatMessageModel(
        id: 'user_${now.microsecondsSinceEpoch}',
        isUser: true,
        messageText: rawText,
        timestamp: formattedTime,
      ),
    );

    chatInputController.clear();
    _currentChatInput = '';

    final aiReply = _generateGroundedAiReply(rawText, formattedTime);
    _chatMessages.add(aiReply);

    notifyListeners();
    _scrollToLatestMessage();
  }

  ChatMessageModel _generateGroundedAiReply(
    String userQuestion,
    String timestamp,
  ) {
    final normalized = userQuestion.toLowerCase().trim();

    if (normalized == 'hi' ||
        normalized == 'hello' ||
        normalized == 'chào' ||
        normalized == 'alo' ||
        normalized.startsWith('xin chào') ||
        normalized.startsWith('chào ai')) {
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText: 'Xin chào! Tôi là Trợ lý Cứu hộ AI. Bạn có thể đặt câu hỏi trực tiếp về các tình huống sơ cứu sau:',
        numberedSteps: const [
          'Cách xử lý khi bị bỏng nhẹ (bỏng nước sôi, bỏng nhiệt).',
          'Cách làm sạch và băng bó vết trầy xước ngoài da.',
          'Cách cầm máu và sát trùng vết cắt / vết rách.',
          'Cách chườm lạnh giảm sưng khi bị bầm tím, dị vật hoặc ngộ độc.',
        ],
        timestamp: timestamp,
      );
    }

    if (normalized.contains('bỏng') || normalized.contains('phỏng')) {
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Với vết bỏng nhẹ (độ 1), bạn có thể làm theo các bước sau:',
        numberedSteps: const [
          'Làm mát vùng bỏng bằng nước sạch mát trong 10–20 phút.',
          'Không chọc vỡ bóng nước (nếu có).',
          'Bôi thuốc mỡ kháng sinh và băng gạc sạch.',
          'Theo dõi, nếu có dấu hiệu nhiễm trùng hoặc đau tăng, hãy đi khám bác sĩ.',
        ],
        timestamp: timestamp,
        relatedTopicId: 'burn',
      );
    }

    if (normalized.contains('trầy') || normalized.contains('xước')) {
      final guide = firstAidGuidesByTopic['abrasion']!;
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Đối với tình huống ${guide.severityText.toLowerCase()}, bạn hãy thực hiện theo các bước sơ cứu đã kiểm chứng sau:',
        numberedSteps: guide.steps
            .map((step) => '${step.title}: ${step.description}')
            .toList(),
        timestamp: timestamp,
        relatedTopicId: 'abrasion',
      );
    }

    if (normalized.contains('cắt') ||
        normalized.contains('rách') ||
        normalized.contains('đứt tay') ||
        normalized.contains('chảy máu')) {
      final guide = firstAidGuidesByTopic['cut_laceration']!;
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Khi gặp ${guide.severityText.toLowerCase()}, bạn cần thực hiện các bước sơ cứu sau:',
        numberedSteps: guide.steps
            .map((step) => '${step.title}: ${step.description}')
            .toList(),
        timestamp: timestamp,
        relatedTopicId: 'cut_laceration',
      );
    }

    if (normalized.contains('bầm') || normalized.contains('tím')) {
      final guide = firstAidGuidesByTopic['bruise']!;
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Với tình trạng ${guide.severityText.toLowerCase()}, bạn có thể xử lý theo các bước sau:',
        numberedSteps: guide.steps
            .map((step) => '${step.title}: ${step.description}')
            .toList(),
        timestamp: timestamp,
        relatedTopicId: 'bruise',
      );
    }

    if (normalized.contains('dị vật') ||
        normalized.contains('dằm') ||
        normalized.contains('mảnh vỡ')) {
      final guide = firstAidGuidesByTopic['foreign_body']!;
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Khi xử lý ${guide.severityText.toLowerCase()}, bạn hãy tuân thủ các bước an toàn sau:',
        numberedSteps: guide.steps
            .map((step) => '${step.title}: ${step.description}')
            .toList(),
        timestamp: timestamp,
        relatedTopicId: 'foreign_body',
      );
    }

    if (normalized.contains('ngộ độc') || normalized.contains('nhiễm độc')) {
      final guide = firstAidGuidesByTopic['poisoning']!;
      return ChatMessageModel(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        messageText:
            'Trong trường hợp ${guide.severityText.toLowerCase()}, bạn cần thực hiện ngay các bước sau:',
        numberedSteps: guide.steps
            .map((step) => '${step.title}: ${step.description}')
            .toList(),
        timestamp: timestamp,
        relatedTopicId: 'poisoning',
      );
    }

    return ChatMessageModel(
      id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
      isUser: false,
      messageText: 'Hiện tại hệ thống chỉ cung cấp hướng dẫn đã kiểm chứng cho 6 tình huống sơ cứu cơ bản (Bỏng, Trầy xước, Vết cắt/Vết rách, Bầm, Dị vật, Ngộ độc) và chưa có đủ cơ sở dữ liệu y khoa đã xác thực cho câu hỏi của bạn.',
      numberedSteps: const [
        'Vui lòng mô tả rõ một trong các tình trạng trên hoặc mở mục "Hướng dẫn sơ cứu" / "Kiến thức" ở thanh menu bên trái.',
        'Nếu nạn nhân có dấu hiệu nguy cấp, hãy liên hệ ngay cơ sở y tế gần nhất hoặc gọi cấp cứu 115.',
      ],
      timestamp: timestamp,
    );
  }

  // =========================================================================
  // CÁC HÀM SỰ KIỆN & CALLBACK ĐIỀU HƯỚNG NGHIỆP VỤ
  // =========================================================================

  void onAnalyzeImageNowPressed() {
    navigateToAiAnalysis();
  }

  void onLookupKnowledgePressed() {
    navigateToKnowledgeLookup();
  }

  void onSearchPressed() {
    navigateToKnowledgeLookup();
  }

  void onProfileAvatarPressed() {
    debugPrint(
      '[UserViewModel] Bấm vào thông tin người dùng: $currentUserName',
    );
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

  void onSelectImageFromFilePressed() {
    navigateToAnalysisResult(imageSourceName: 'selected_arm_abrasion.jpg');
  }

  void onCaptureFromCameraPressed() {
    navigateToAnalysisResult(imageSourceName: 'camera_capture_abrasion.jpg');
  }

  void onViewFirstAidGuidePressed() {
    navigateToFirstAidGuide(topicId: 'abrasion');
  }

  void onBackToImageAnalysisPressed() {
    navigateToAiAnalysis();
  }

  @override
  void dispose() {
    chatInputController.dispose();
    chatScrollController.dispose();
    documentSearchController.dispose();
    super.dispose();
  }
}
