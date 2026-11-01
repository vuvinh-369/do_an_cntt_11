import '../models/knowledge_models.dart';
import 'user_navigation_viewmodel.dart';
import 'first_aid_viewmodel.dart';

mixin TraCuuKienThucViewModel
    on DieuHuongCoSoViewModel, HuongDanSoCuuViewModel {
  // Danh mục đang chọn trên Màn hình 5: Tra cứu kiến thức (Mặc định: 'all' -> 'Tất cả')
  String _selectedKnowledgeCategoryId = 'all';
  String get selectedKnowledgeCategoryId => _selectedKnowledgeCategoryId;

  // Từ khóa tìm kiếm trên Màn hình 5: Tra cứu kiến thức
  String _knowledgeSearchQuery = '';
  String get knowledgeSearchQuery => _knowledgeSearchQuery;

  // Danh sách các danh mục lọc trên Màn hình 5: 4 nhóm tổn thương AI + Vết thương khác
  final List<KnowledgeCategoryModel> knowledgeCategories = const [
    KnowledgeCategoryModel(id: 'all', label: 'Tất cả'),
    KnowledgeCategoryModel(id: 'abrasion', label: 'Trầy xước'),
    KnowledgeCategoryModel(id: 'cut_laceration', label: 'Vết cắt / rách'),
    KnowledgeCategoryModel(id: 'burn', label: 'Bỏng'),
    KnowledgeCategoryModel(id: 'bruise', label: 'Bầm tím'),
    KnowledgeCategoryModel(id: 'other_wounds', label: 'Vết thương khác'),
  ];

  // Danh sách các thẻ kiến thức sơ cứu trọng tâm và mở rộng của hệ thống
  final List<KnowledgeTopicModel> knowledgeTopics = const [
    KnowledgeTopicModel(
      id: 'abrasion',
      categoryId: 'abrasion',
      title: 'Trầy xước ngoài da',
      subtitle: 'Cách làm sạch, sát trùng và chăm sóc tổn thương nông',
    ),
    KnowledgeTopicModel(
      id: 'cut_laceration',
      categoryId: 'cut_laceration',
      title: 'Vết cắt / Vết rách da',
      subtitle: 'Kỹ thuật cầm máu, xử lý dị vật & băng ép miệng vết thương',
    ),
    KnowledgeTopicModel(
      id: 'burn',
      categoryId: 'burn',
      title: 'Bỏng nhiệt ngoài da',
      subtitle: 'Làm mát tức thì dưới vòi nước và bảo vệ bọng nước',
    ),
    KnowledgeTopicModel(
      id: 'bruise',
      categoryId: 'bruise',
      title: 'Bầm tím phần mềm',
      subtitle: 'Áp dụng quy trình 4 bước R.I.C.E giảm đau, tiêu sưng hiệu quả',
    ),
    KnowledgeTopicModel(
      id: 'other_wounds',
      categoryId: 'other_wounds',
      title: 'Vết thương khác & Dị vật cắm sâu',
      subtitle: 'Nguyên tắc cố định dị vật, bất động chi và phòng uốn ván',
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
}
