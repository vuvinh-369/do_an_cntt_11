import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import 'dieu_huong_co_so_viewmodel.dart';

mixin LichSuPhanTichViewModel on DieuHuongCoSoViewModel {
  // Danh sách các tùy chọn trong Dropdown lọc kết quả trên Màn hình 8
  final List<String> historyResultFilterOptions = const [
    'Tất cả kết quả',
    'Trầy xước',
    'Bầm',
    'Không phát hiện tổn thương rõ ràng',
    'Vết cắt',
    'Bỏng',
  ];

  String _selectedHistoryResultFilter = 'Tất cả kết quả';
  String get selectedHistoryResultFilter => _selectedHistoryResultFilter;

  DateTime? _historyFromDate;
  DateTime? get historyFromDate => _historyFromDate;

  DateTime? _historyToDate;
  DateTime? get historyToDate => _historyToDate;

  // Danh sách lịch sử phân tích khởi tạo đúng với 5 bản ghi trong thiết kế Màn hình 8
  final List<AnalysisHistoryItemModel> _analysisHistoryItems = [
    AnalysisHistoryItemModel(
      id: 'hist_1',
      injuryType: 'Trầy xước',
      confidencePercent: 82,
      locationLabel: 'Cánh tay',
      timestamp: '25/10/2025 14:30',
      dateTime: DateTime(2025, 10, 25, 14, 30),
      imageSourceName: 'tray_xuoc_canh_tay.jpg',
      relatedTopicId: 'abrasion',
      baseSkinColor: const Color(0xFFE7B89E),
      woundAccentColor: const Color(0xFFD63638),
    ),
    AnalysisHistoryItemModel(
      id: 'hist_2',
      injuryType: 'Bầm',
      confidencePercent: 67,
      locationLabel: 'Chân',
      timestamp: '24/10/2025 16:30',
      dateTime: DateTime(2025, 10, 24, 16, 30),
      imageSourceName: 'vet_bam_chan.jpg',
      relatedTopicId: 'bruise',
      baseSkinColor: const Color(0xFFDCA88E),
      woundAccentColor: const Color(0xFF7E22CE),
    ),
    AnalysisHistoryItemModel(
      id: 'hist_3',
      injuryType: 'Không phát hiện tổn thương rõ ràng',
      confidencePercent: null,
      locationLabel: '-',
      timestamp: '23/10/2025 10:15',
      dateTime: DateTime(2025, 10, 23, 10, 15),
      imageSourceName: 'khong_phat_hien.jpg',
      relatedTopicId: null,
      baseSkinColor: const Color(0xFFE2B49A),
      woundAccentColor: const Color(0xFFC08470),
    ),
    AnalysisHistoryItemModel(
      id: 'hist_4',
      injuryType: 'Vết cắt',
      confidencePercent: 85,
      locationLabel: 'Ngón tay',
      timestamp: '22/10/2025 09:40',
      dateTime: DateTime(2025, 10, 22, 9, 40),
      imageSourceName: 'vet_cat_ngon_tay.jpg',
      relatedTopicId: 'cut',
      baseSkinColor: const Color(0xFFE5B59C),
      woundAccentColor: const Color(0xFFB91C1C),
    ),
    AnalysisHistoryItemModel(
      id: 'hist_5',
      injuryType: 'Bỏng',
      confidencePercent: 88,
      locationLabel: 'Bàn tay',
      timestamp: '20/10/2025 18:05',
      dateTime: DateTime(2025, 10, 20, 18, 5),
      imageSourceName: 'bong_ban_tay.jpg',
      relatedTopicId: 'burn',
      baseSkinColor: const Color(0xFFDFAC92),
      woundAccentColor: const Color(0xFFEA580C),
    ),
  ];

  /// Danh sách lịch sử sau khi áp dụng bộ lọc Từ ngày - Đến ngày và Loại kết quả
  List<AnalysisHistoryItemModel> get filteredAnalysisHistoryItems {
    return _analysisHistoryItems.where((item) {
      // 1. Lọc theo loại kết quả
      if (_selectedHistoryResultFilter != 'Tất cả kết quả') {
        if (item.injuryType.toLowerCase() !=
            _selectedHistoryResultFilter.toLowerCase()) {
          return false;
        }
      }

      // 2. Lọc theo ngày bắt đầu (Từ ngày)
      if (_historyFromDate != null) {
        final startOfDay = DateTime(
          _historyFromDate!.year,
          _historyFromDate!.month,
          _historyFromDate!.day,
        );
        if (item.dateTime.isBefore(startOfDay)) {
          return false;
        }
      }

      // 3. Lọc theo ngày kết thúc (Đến ngày)
      if (_historyToDate != null) {
        final endOfDay = DateTime(
          _historyToDate!.year,
          _historyToDate!.month,
          _historyToDate!.day,
          23,
          59,
          59,
        );
        if (item.dateTime.isAfter(endOfDay)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Văn bản hiển thị trên ô lọc khoảng ngày ("Từ ngày  —  Đến ngày")
  String get formattedDateRangeLabel {
    if (_historyFromDate == null && _historyToDate == null) {
      return 'Từ ngày   —   Đến ngày';
    }
    final fromStr = _historyFromDate != null
        ? _formatDateOnly(_historyFromDate!)
        : 'Từ ngày';
    final toStr = _historyToDate != null
        ? _formatDateOnly(_historyToDate!)
        : 'Đến ngày';
    return '$fromStr   —   $toStr';
  }

  /// Thay đổi bộ lọc loại kết quả trong Dropdown
  void setHistoryResultFilter(String? filterValue) {
    if (filterValue == null) return;
    _selectedHistoryResultFilter = filterValue;
    notifyListeners();
  }

  /// Cập nhật khoảng ngày lọc từ DateRangePicker
  void setHistoryDateRange(DateTimeRange? range) {
    _historyFromDate = range?.start;
    _historyToDate = range?.end;
    notifyListeners();
  }

  /// Xóa bộ lọc ngày về mặc định
  void clearHistoryDateRange() {
    _historyFromDate = null;
    _historyToDate = null;
    notifyListeners();
  }

  /// TỰ ĐỘNG LƯU LỊCH SỬ: Được kích hoạt tự động mỗi khi navigateToAnalysisResult() chạy
  @override
  void onNewAnalysisRecorded({required String imageSourceName}) {
    final now = DateTime.now();
    final lowerName = imageSourceName.toLowerCase();

    // Nhận diện thông minh loại tổn thương từ tên ảnh hoặc dùng mặc định từ kết quả AI (Màn hình 3)
    String detectedInjuryType = 'Trầy xước';
    int? detectedConfidence = 82;
    String detectedLocation = 'Cánh tay';
    String? topicId = 'abrasion';
    Color woundColor = const Color(0xFFD63638);

    if (lowerName.contains('burn') || lowerName.contains('bong')) {
      detectedInjuryType = 'Bỏng';
      detectedConfidence = 88;
      detectedLocation = 'Bàn tay';
      topicId = 'burn';
      woundColor = const Color(0xFFEA580C);
    } else if (lowerName.contains('cut') || lowerName.contains('cat')) {
      detectedInjuryType = 'Vết cắt';
      detectedConfidence = 85;
      detectedLocation = 'Ngón tay';
      topicId = 'cut';
      woundColor = const Color(0xFFB91C1C);
    } else if (lowerName.contains('bruise') || lowerName.contains('bam')) {
      detectedInjuryType = 'Bầm';
      detectedConfidence = 67;
      detectedLocation = 'Chân';
      topicId = 'bruise';
      woundColor = const Color(0xFF7E22CE);
    } else if (lowerName.contains('none') || lowerName.contains('normal')) {
      detectedInjuryType = 'Không phát hiện tổn thương rõ ràng';
      detectedConfidence = null;
      detectedLocation = '-';
      topicId = null;
      woundColor = const Color(0xFFC08470);
    }

    final newRecord = AnalysisHistoryItemModel(
      id: 'hist_${now.millisecondsSinceEpoch}',
      injuryType: detectedInjuryType,
      confidencePercent: detectedConfidence,
      locationLabel: detectedLocation,
      timestamp: _formatDateTime(now),
      dateTime: now,
      imageSourceName: imageSourceName,
      relatedTopicId: topicId,
      baseSkinColor: const Color(0xFFE7B89E),
      woundAccentColor: woundColor,
    );

    _analysisHistoryItems.insert(0, newRecord);
  }

  /// Cho phép cập nhật lại vị trí tổn thương của bản ghi mới nhất khi người dùng đổi vị trí ở Màn hình 3
  void updateLatestHistoryLocation(String newLocationLabel) {
    if (_analysisHistoryItems.isEmpty) return;
    _analysisHistoryItems[0] = _analysisHistoryItems[0].copyWith(
      locationLabel: newLocationLabel,
    );
    notifyListeners();
  }

  /// Xử lý khi người dùng bấm vào 1 thẻ trong danh sách Lịch sử phân tích
  void onHistoryItemTapped(AnalysisHistoryItemModel item) {
    if (item.relatedTopicId != null &&
        firstAidGuidesByTopic.containsKey(item.relatedTopicId)) {
      navigateToFirstAidGuide(topicId: item.relatedTopicId);
    } else {
      // Chuyển sang màn hình Kết quả phân tích mà không tạo bản ghi trùng lặp
      navigateToAnalysisResult(
        imageSourceName: item.imageSourceName,
        recordHistory: false,
      );
    }
  }

  String _formatDateOnly(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }

  String _formatDateTime(DateTime dt) {
    final datePart = _formatDateOnly(dt);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$datePart $hour:$minute';
  }
}
