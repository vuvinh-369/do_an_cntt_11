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
