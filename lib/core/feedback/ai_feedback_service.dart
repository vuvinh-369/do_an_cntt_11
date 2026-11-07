// File: lib/core/feedback/ai_feedback_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'ai_feedback_model.dart';

/// Dịch vụ quản lý phản hồi & đánh giá AI từ người dùng (User Feedback Loop)
/// Lưu tạm trong RAM (In-Memory) để thu thập dữ liệu giúp cải thiện mô hình trong tương lai.
class AiFeedbackService extends ChangeNotifier {
  static final AiFeedbackService instance = AiFeedbackService._internal();

  AiFeedbackService._internal() {
    _seedSampleFeedbacks();
  }

  final List<AiFeedbackModel> _feedbacks = [];

  List<AiFeedbackModel> get feedbacks => List.unmodifiable(_feedbacks);

  int get totalCount => _feedbacks.length;

  int get inaccurateCount =>
      _feedbacks.where((f) => f.feedbackType == AiFeedbackType.inaccurate).length;

  int get helpfulCount =>
      _feedbacks.where((f) => f.feedbackType == AiFeedbackType.helpful).length;

  double get accuracyRate =>
      totalCount > 0 ? (helpfulCount / totalCount * 100.0) : 100.0;

  /// Người dùng gửi đánh giá đúng / sai về kết quả AI
  void submitFeedback(AiFeedbackModel feedback) {
    _feedbacks.insert(0, feedback);
    notifyListeners();
  }

  /// Xóa phản hồi
  void deleteFeedback(String id) {
    _feedbacks.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  /// Xuất tập dữ liệu phản hồi người dùng dạng JSON để phục vụ phân tích sai số và huấn luyện lại AI
  String exportFeedbackDatasetJson() {
    final exportData = {
      'exported_at': DateTime.now().toIso8601String(),
      'description':
          'Tập dữ liệu phản hồi từ người dùng về kết quả dự đoán của AI (Đúng/Sai) phục vụ nghiên cứu và cải thiện mô hình.',
      'total_records': _feedbacks.length,
      'stats': {
        'accurate_count': helpfulCount,
        'inaccurate_count': inaccurateCount,
        'accuracy_rate_percent': accuracyRate.toStringAsFixed(1),
      },
      'feedback_records': _feedbacks.map((item) => item.toExportJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Khởi tạo sẵn một số ca đánh giá thực tế từ người dùng để kiểm thử tại /admin
  void _seedSampleFeedbacks() {
    final now = DateTime.now();

    _feedbacks.addAll([
      // Ca 1: Người dùng đánh giá SAI - YOLO nhận diện nhầm vết trầy xước thành vết bỏng
      AiFeedbackModel(
        id: 'fb_seed_001',
        analysisId: 'ana_yolo_20261107_883',
        timestamp: now.subtract(const Duration(minutes: 25)),
        userDisplayName: '@quang_huy',
        sourceModel: AiSourceModel.yoloVision,
        feedbackType: AiFeedbackType.inaccurate,
        issueCategory: 'YOLO nhận diện nhầm loại tổn thương',
        userComment:
            'YOLO nhận diện nhầm vết trầy xước thành vết bỏng. Vết thương do ngã xe chà xát xuống đường nhựa, chỉ tróc biểu bì rỉ dịch chứ không bị bỏng nhiệt.',
        userProposedLabel: 'Trầy xước ngoài da',
        detectedWoundSummary: 'Bỏng nhiệt / hóa chất (88%)',
        woundLocation: 'Cẳng tay',
        painLevel: 'Đau rát nhẹ (1-4/10)',
        observedSymptoms: const ['Tróc biểu bì bề mặt', 'Rỉ dịch nhẹ'],
        imageFileName: 'vet_tray_xuoc_cang_tay.jpg',
      ),

      // Ca 2: Người dùng đánh giá SAI - Nhầm bầm tím thành vết rách da
      AiFeedbackModel(
        id: 'fb_seed_002',
        analysisId: 'ana_yolo_20261106_412',
        timestamp: now.subtract(const Duration(hours: 18)),
        userDisplayName: '@minh_ngoc',
        sourceModel: AiSourceModel.yoloVision,
        feedbackType: AiFeedbackType.inaccurate,
        issueCategory: 'YOLO nhận diện nhầm loại tổn thương',
        userComment:
            'Ảnh tụ máu bầm tím sau va chạm thể thao đá bóng nhưng AI lại đoán là vết cắt rách da. Da còn nguyên vẹn không chảy máu.',
        userProposedLabel: 'Bầm tím / đụng dập',
        detectedWoundSummary: 'Vết cắt / rách da (74%)',
        woundLocation: 'Bắp chân',
        painLevel: 'Đau tức dữ dội (7-10/10)',
        observedSymptoms: const ['Không chảy máu', 'Sưng nề tím tái'],
        imageFileName: 'bam_tim_the_thao.jpg',
      ),

      // Ca 3: Người dùng đánh giá ĐÚNG / HỮU ÍCH
      AiFeedbackModel(
        id: 'fb_seed_003',
        analysisId: 'ana_yolo_20261105_119',
        timestamp: now.subtract(const Duration(days: 2)),
        userDisplayName: '@lan_anh',
        sourceModel: AiSourceModel.yoloVision,
        feedbackType: AiFeedbackType.helpful,
        issueCategory: 'Chính xác & Hữu ích',
        userComment:
            'Nhận diện rất chính xác vết cắt sâu ở mu bàn tay do mảnh kính vỡ, hướng dẫn sơ cứu cầm máu kịp thời.',
        detectedWoundSummary: 'Vết cắt / rách da (95%)',
        woundLocation: 'Bàn tay',
        painLevel: 'Đau nặng (7-10/10)',
        observedSymptoms: const ['Chảy máu nhiều liên tục'],
      ),
    ]);
  }
}
