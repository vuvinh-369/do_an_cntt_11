import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:do_an_cntt_11/core/rule_engine/rule_engine_service.dart';
import 'package:do_an_cntt_11/core/rule_engine/rule_models.dart';
import 'package:do_an_cntt_11/core/storage/local_storage_service.dart';
import 'package:do_an_cntt_11/features/admin/models/admin_management_models.dart';
import 'package:do_an_cntt_11/features/admin/viewmodels/admin_viewmodel.dart';
import 'package:do_an_cntt_11/features/user/models/document_models.dart';
import 'package:do_an_cntt_11/features/user/viewmodels/user_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Link & URL Persistence Tests (Thoát app mở lại vẫn lưu)', () {
    test('1. MedicalSourceLink: Sửa URL nguồn trích xuất y khoa được lưu vào LocalStorage và nạp lại khi mở app', () async {
      final ruleEngine = RuleEngineService();
      
      const updatedUrl = 'https://custom-redcross-url.vn/so-cuu-2026';
      final existingSource = ruleEngine.medicalSources.first;
      
      // Thực hiện cập nhật URL mới
      ruleEngine.updateMedicalSource(
        existingSource.id,
        existingSource.copyWith(url: updatedUrl),
      );

      // Đợi microtask persist
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Kiểm tra trong LocalStorage
      final savedLinks = await LocalStorageService.instance.loadMedicalSourceLinks();
      expect(savedLinks.isNotEmpty, isTrue);
      final match = savedLinks.firstWhere((item) => item['id'] == existingSource.id);
      expect(match['url'], equals(updatedUrl));

      // Giả lập mở lại app: nạp lại từ storage
      await ruleEngine.loadPersistedMedicalSources();

      expect(ruleEngine.medicalSources.firstWhere((s) => s.id == existingSource.id).url, equals(updatedUrl));
    });

    test('2. KnowledgeArticle: Sửa sourceUrl bài viết cẩm nang được lưu bền vững', () async {
      final adminVm = AdminViewModel();
      await adminVm.loadPersistedKnowledgeArticles();

      final firstArticle = adminVm.filteredKnowledgeArticles.first;
      const newSourceUrl = 'https://bv-cho-ray.vn/huong-dan-xu-tri';

      adminVm.updateKnowledgeArticle(
        firstArticle.copyWith(sourceUrl: newSourceUrl),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final savedArticles = await LocalStorageService.instance.loadKnowledgeArticles();
      expect(savedArticles.isNotEmpty, isTrue);
      final matchedArticle = savedArticles.firstWhere((a) => a['id'] == firstArticle.id);
      expect(matchedArticle['source_url'], equals(newSourceUrl));
    });

    test('3. MedicalDocument: Sửa externalUrl tài liệu y tế được lưu bền vững', () async {
      final userVm = UserViewModel();
      await userVm.loadPersistedMedicalDocuments();

      final firstDoc = userVm.allMedicalDocuments.first;
      const newDocUrl = 'https://who.int/guidelines/first-aid-updated';

      userVm.updateMedicalDocument(
        id: firstDoc.id,
        newTitle: firstDoc.title,
        newCategoryId: firstDoc.categoryId,
        newSummary: firstDoc.summary,
        newExternalUrl: newDocUrl,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final savedDocs = await LocalStorageService.instance.loadMedicalDocuments();
      expect(savedDocs.isNotEmpty, isTrue);
      final matchedDoc = savedDocs.firstWhere((d) => d['id'] == firstDoc.id);
      expect(matchedDoc['external_url'], equals(newDocUrl));
    });
  });
}
