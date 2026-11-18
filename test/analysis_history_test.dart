import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:do_an_cntt_11/core/history/analysis_history_service.dart';
import 'package:do_an_cntt_11/core/storage/local_storage_service.dart';
import 'package:do_an_cntt_11/features/user/models/history_models.dart';
import 'package:do_an_cntt_11/features/user/viewmodels/user_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.instance.loadAnalysisHistory();
  });

  group('AnalysisHistoryService Dual-Mode & LocalStorage Tests', () {
    test('loadFromLocalStorage populates default fallback scans if empty', () async {
      final service = AnalysisHistoryService.instance;
      await service.loadFromLocalStorage();

      expect(service.items.isNotEmpty, isTrue);
      expect(service.totalScans, greaterThanOrEqualTo(4));
      expect(service.averageConfidence, greaterThan(70.0));
    });

    test('recordAnalysis saves item to memory and persists to LocalStorage', () async {
      final service = AnalysisHistoryService.instance;
      await service.loadFromLocalStorage();

      final initialCount = service.totalScans;
      final ok = await service.recordAnalysis(
        username: 'test_user',
        injuryTypeId: 'cut_laceration',
        injuryTypeName: 'Vết cắt sâu',
        confidenceScore: 89.5,
        severityLevel: 'severe',
        locationLabel: 'Ngón trỏ',
        symptoms: ['Chảy máu nhiều'],
        painLevel: 6,
        firstAidSummary: 'Băng ép cầm máu',
      );

      // Local persistence should always succeed even without Supabase
      expect(service.totalScans, equals(initialCount + 1));
      expect(service.items.first.injuryType, equals('Vết cắt sâu'));
      expect(service.items.first.username, equals('test_user'));
      expect(service.items.first.severityLevel, equals('severe'));
      expect(service.items.first.locationLabel, equals('Ngón trỏ'));

      // Verify LocalStorage was written
      final cached = await LocalStorageService.instance.loadAnalysisHistory();
      expect(cached.any((m) => m['injury_type_name'] == 'Vết cắt sâu'), isTrue);
    });

    test('getItemsForUser filters correctly by username and returns all for null', () async {
      final service = AnalysisHistoryService.instance;
      await service.loadFromLocalStorage();

      final userScans = service.getItemsForUser('benhnhan_01');
      expect(userScans.every((i) => i.username == 'benhnhan_01' || i.username == null), isTrue);

      final allScans = service.getItemsForUser(null);
      expect(allScans.length, equals(service.items.length));
    });

    test('deleteRecord removes item and updates LocalStorage', () async {
      final service = AnalysisHistoryService.instance;
      await service.loadFromLocalStorage();

      final itemToDelete = service.items.first;
      final deletedId = itemToDelete.id;

      await service.deleteRecord(deletedId);
      expect(service.items.any((i) => i.id == deletedId), isFalse);

      final cached = await LocalStorageService.instance.loadAnalysisHistory();
      expect(cached.any((m) => m['id'] == deletedId), isFalse);
    });
  });

  group('LichSuPhanTichViewModel Tests in UserViewModel', () {
    test('onNewAnalysisRecorded creates new item and synchronizes with Service', () async {
      final userVm = UserViewModel();
      await userVm.fetchHistoryFromSupabase(silent: true);

      final prevCount = userVm.filteredAnalysisHistoryItems.length;

      userVm.onNewAnalysisRecorded(
        imageSourceName: 'test_abrasion.jpg',
        injuryType: 'Trầy xước nhẹ',
        confidencePercent: 91,
        locationLabel: 'Cẳng tay',
        topicId: 'abrasion',
      );

      expect(userVm.filteredAnalysisHistoryItems.length, equals(prevCount + 1));
      expect(userVm.filteredAnalysisHistoryItems.first.injuryType, equals('Trầy xước nhẹ'));
      expect(userVm.filteredAnalysisHistoryItems.first.locationLabel, equals('Cẳng tay'));

      // Also verify AnalysisHistoryService received it
      expect(
        AnalysisHistoryService.instance.items.any((i) => i.injuryType == 'Trầy xước nhẹ'),
        isTrue,
      );
    });

    test('filter by injury type works correctly', () async {
      final userVm = UserViewModel();
      await userVm.fetchHistoryFromSupabase(silent: true);

      userVm.setHistoryResultFilter('Bỏng');
      for (final item in userVm.filteredAnalysisHistoryItems) {
        expect(item.injuryType.toLowerCase().contains('bỏng'), isTrue);
      }

      userVm.setHistoryResultFilter('Tất cả kết quả');
      expect(userVm.filteredAnalysisHistoryItems.length, greaterThanOrEqualTo(1));
    });

    test('pagination works as expected (5 items per page)', () async {
      final userVm = UserViewModel();
      await userVm.fetchHistoryFromSupabase(silent: true);

      expect(userVm.currentHistoryPage, equals(1));
      expect(userVm.paginatedAnalysisHistoryItems.length, lessThanOrEqualTo(5));

      if (userVm.totalHistoryPages > 1) {
        userVm.goToNextHistoryPage();
        expect(userVm.currentHistoryPage, equals(2));
        userVm.goToPreviousHistoryPage();
        expect(userVm.currentHistoryPage, equals(1));
      }
    });
  });
}
