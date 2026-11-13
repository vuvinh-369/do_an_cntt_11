// File: test/ai_feedback_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:do_an_cntt_11/core/feedback/ai_feedback_model.dart';
import 'package:do_an_cntt_11/core/feedback/ai_feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiFeedbackService Dual-Mode Persistence & LocalStorage Tests', () {
    test('submitFeedback saves to in-memory list and persists to LocalStorage', () async {
      final service = AiFeedbackService.instance;
      service.setFeedbacks([]); // Reset

      final feedback = AiFeedbackModel(
        id: 'fb_test_01',
        timestamp: DateTime.now(),
        userDisplayName: '@testuser',
        sourceModel: AiSourceModel.yoloVision,
        feedbackType: AiFeedbackType.inaccurate,
        issueCategory: 'Nhận diện nhầm',
        userComment: 'Vết trầy nhẹ nhưng AI báo bỏng độ 2',
        detectedWoundSummary: 'Bỏng nhiệt (85%)',
        userProposedLabel: 'Trầy xước ngoài da',
        observedSymptoms: ['Có dị vật'],
      );

      await service.submitFeedback(feedback);

      expect(service.totalCount, equals(1));
      expect(service.inaccurateCount, equals(1));
      expect(service.helpfulCount, equals(0));
      expect(service.accuracyRate, equals(0.0));

      // Verify LocalStorage contains the saved feedback
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('ai_feedbacks_cache_v1');
      expect(savedJson, isNotNull);
      expect(savedJson!.contains('fb_test_01'), isTrue);
      expect(savedJson.contains('Trầy xước ngoài da'), isTrue);
    });

    test('deleteFeedback removes item from list and updates LocalStorage', () async {
      final service = AiFeedbackService.instance;

      final feedback = AiFeedbackModel(
        id: 'fb_delete_me',
        timestamp: DateTime.now(),
        userDisplayName: '@testuser',
        feedbackType: AiFeedbackType.helpful,
        issueCategory: 'Hữu ích',
        userComment: 'Chính xác',
        detectedWoundSummary: 'Vết cắt (90%)',
      );

      await service.submitFeedback(feedback);
      expect(service.feedbacks.any((f) => f.id == 'fb_delete_me'), isTrue);

      await service.deleteFeedback('fb_delete_me');
      expect(service.feedbacks.any((f) => f.id == 'fb_delete_me'), isFalse);

      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('ai_feedbacks_cache_v1');
      expect(savedJson!.contains('fb_delete_me'), isFalse);
    });

    test('exportFeedbackDatasetJson outputs valid formatted JSON', () async {
      final service = AiFeedbackService.instance;
      service.setFeedbacks([]);

      await service.submitFeedback(
        AiFeedbackModel(
          id: 'fb_export_test',
          timestamp: DateTime.now(),
          feedbackType: AiFeedbackType.helpful,
          issueCategory: 'Chính xác',
          userComment: 'Tốt',
          detectedWoundSummary: 'Trầy xước',
        ),
      );

      final jsonOutput = service.exportFeedbackDatasetJson();
      expect(jsonOutput.contains('"total_records": 1'), isTrue);
      expect(jsonOutput.contains('"fb_export_test"'), isTrue);
    });
  });
}
