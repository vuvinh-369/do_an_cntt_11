import 'dart:async';
import '../../../core/history/analysis_history_service.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/history_models.dart';
import '../../../core/supabase/supabase_service.dart';
import 'user_navigation_viewmodel.dart';

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

  bool _historyListenerRegistered = false;
  bool _isHistoryDisposed = false;

  /// Khởi tạo lịch sử phân tích từ LocalStorage/Service ngay khi UserViewModel được tạo
  void initAnalysisHistory() {
    _isHistoryDisposed = false;
    _syncHistoryFromService();
    if (!_historyListenerRegistered) {
      AnalysisHistoryService.instance.addListener(_onAnalysisHistoryServiceChanged);
      _historyListenerRegistered = true;
    }
  }

  /// Hủy đăng ký listener khi ViewModel bị dispose
  void disposeAnalysisHistory() {
    _isHistoryDisposed = true;
    if (_historyListenerRegistered) {
      AnalysisHistoryService.instance.removeListener(_onAnalysisHistoryServiceChanged);
      _historyListenerRegistered = false;
    }
  }

  void _onAnalysisHistoryServiceChanged() {
    if (_isHistoryDisposed) return;
    _syncHistoryFromService();
  }

  void _syncHistoryFromService() {
    if (_isHistoryDisposed) return;
    final username = currentUser?.username;
    final items = AnalysisHistoryService.instance.getItemsForUser(username);
    _analysisHistoryItems.clear();
    _analysisHistoryItems.addAll(items);
    notifyListeners();
  }

  /// Nạp danh sách lịch sử phân tích từ Supabase và LocalStorage
  Future<void> fetchHistoryFromSupabase({bool silent = false}) async {
    try {
      await AnalysisHistoryService.instance.fetchHistoryFromSupabase(silent: silent);
      _syncHistoryFromService();
    } catch (e) {
      debugPrint('[HistoryViewModel] Lấy lịch sử Supabase: $e');
      _syncHistoryFromService();
    }
  }

  @override
  void onUserSessionChanged() {
    super.onUserSessionChanged();
    _syncHistoryFromService();
    unawaited(fetchHistoryFromSupabase(silent: true));
  }

  @override
  void onNavigateToAnalysisHistory() {
    super.onNavigateToAnalysisHistory();
    _syncHistoryFromService();
    unawaited(fetchHistoryFromSupabase(silent: true));
  }

  // Danh sách lịch sử phân tích (Đồng bộ thời gian thực với Supabase Database)
  final List<AnalysisHistoryItemModel> _analysisHistoryItems = [];

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

  // Phân trang Lịch sử phân tích (5 ca / trang)
  int _currentHistoryPage = 1;
  int get currentHistoryPage => _currentHistoryPage;
  static const int historyPageSize = 5;

  int get totalHistoryPages {
    final total = (filteredAnalysisHistoryItems.length / historyPageSize).ceil();
    return total < 1 ? 1 : total;
  }

  List<AnalysisHistoryItemModel> get paginatedAnalysisHistoryItems {
    final all = filteredAnalysisHistoryItems;
    final startIndex = (_currentHistoryPage - 1) * historyPageSize;
    if (startIndex >= all.length) return [];
    final endIndex = (startIndex + historyPageSize > all.length)
        ? all.length
        : startIndex + historyPageSize;
    return all.sublist(startIndex, endIndex);
  }

  void selectHistoryPage(int page) {
    if (page < 1 || page > totalHistoryPages) return;
    if (_currentHistoryPage == page) return;
    _currentHistoryPage = page;
    notifyListeners();
  }

  void goToPreviousHistoryPage() {
    if (_currentHistoryPage > 1) {
      _currentHistoryPage--;
      notifyListeners();
    }
  }

  void goToNextHistoryPage() {
    if (_currentHistoryPage < totalHistoryPages) {
      _currentHistoryPage++;
      notifyListeners();
    }
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
    _currentHistoryPage = 1;
    notifyListeners();
  }

  /// Cập nhật khoảng ngày lọc từ DateRangePicker
  void setHistoryDateRange(DateTimeRange? range) {
    _historyFromDate = range?.start;
    _historyToDate = range?.end;
    _currentHistoryPage = 1;
    notifyListeners();
  }

  /// Xóa bộ lọc ngày về mặc định
  void clearHistoryDateRange() {
    _historyFromDate = null;
    _historyToDate = null;
    _currentHistoryPage = 1;
    notifyListeners();
  }

  /// TỰ ĐỘNG LƯU LỊCH SỬ VÀO DATABASE SUPABASE: Kích hoạt khi quét phân tích ảnh xong
  @override
  void onNewAnalysisRecorded({
    required String imageSourceName,
    String? injuryType,
    int? confidencePercent,
    String? locationLabel,
    String? topicId,
    Uint8List? rawImageBytes,
  }) {
    final now = DateTime.now();
    final lowerName = imageSourceName.toLowerCase();

    // Sử dụng trực tiếp giá trị thực tế nếu có, hoặc suy luận từ tên ảnh
    String detectedInjuryType = injuryType ?? 'Trầy xước';
    int? detectedConfidence = confidencePercent ?? 82;
    String detectedLocation = locationLabel ?? 'Cánh tay';
    String? assignedTopicId = topicId ?? 'abrasion';
    Color woundColor = const Color(0xFFD63638);

    if (injuryType == null) {
      if (lowerName.contains('burn') || lowerName.contains('bong')) {
        detectedInjuryType = 'Bỏng';
        detectedConfidence = 88;
        detectedLocation = 'Bàn tay';
        assignedTopicId = 'burn';
        woundColor = const Color(0xFFEA580C);
      } else if (lowerName.contains('cut') || lowerName.contains('cat')) {
        detectedInjuryType = 'Vết cắt';
        detectedConfidence = 85;
        detectedLocation = 'Ngón tay';
        assignedTopicId = 'cut_laceration';
        woundColor = const Color(0xFFB91C1C);
      } else if (lowerName.contains('bruise') || lowerName.contains('bam')) {
        detectedInjuryType = 'Bầm';
        detectedConfidence = 67;
        detectedLocation = 'Chân';
        assignedTopicId = 'bruise';
        woundColor = const Color(0xFF7E22CE);
      } else if (lowerName.contains('none') || lowerName.contains('normal')) {
        detectedInjuryType = 'Không phát hiện tổn thương rõ ràng';
        detectedConfidence = null;
        detectedLocation = '-';
        assignedTopicId = null;
        woundColor = const Color(0xFFC08470);
      }
    }

    final currentUsername = currentUser?.username.trim();
    final newRecord = AnalysisHistoryItemModel(
      id: 'hist_${now.millisecondsSinceEpoch}',
      username: (currentUsername != null && currentUsername.isNotEmpty)
          ? currentUsername
          : null,
      injuryType: detectedInjuryType,
      confidencePercent: detectedConfidence,
      locationLabel: detectedLocation,
      timestamp: _formatDateTime(now),
      dateTime: now,
      imageSourceName: imageSourceName,
      relatedTopicId: assignedTopicId,
      baseSkinColor: const Color(0xFFE7B89E),
      woundAccentColor: woundColor,
      rawImageBytes: rawImageBytes,
    );

    _analysisHistoryItems.removeWhere((i) => i.id == newRecord.id);
    _analysisHistoryItems.insert(0, newRecord);
    _currentHistoryPage = 1;
    notifyListeners();

    // Đồng bộ lập tức vào Service và LocalStorage (Bền vững 100%)
    unawaited(AnalysisHistoryService.instance.addDirectItem(newRecord));

    // Đồng bộ lên Supabase Cloud CHỈ KHI người dùng đã đăng nhập (tuân thủ khóa ngoại username)
    try {
      final client = SupabaseService.instance.client;
      if (client != null && currentUsername != null && currentUsername.isNotEmpty) {
        client.from('analysis_history').insert({
          'id': newRecord.id,
          'username': currentUsername,
          'injury_type_id': assignedTopicId ?? 'abrasion',
          'injury_type_name': detectedInjuryType,
          'confidence_score': detectedConfidence?.toDouble() ?? 80.0,
          'severity_level': 'moderate',
          'location_label': detectedLocation,
          'image_url': imageSourceName,
          'created_at': now.toIso8601String(),
        }).then((_) {
          AnalysisHistoryService.instance.fetchHistoryFromSupabase(silent: true);
        }).catchError((err) {
          debugPrint('[HistoryViewModel] Ghi Supabase thất bại, dữ liệu đã lưu an toàn trong LocalStorage: $err');
        });
      }
    } catch (e) {
      debugPrint('[HistoryViewModel] Đồng bộ Supabase exception: $e');
    }
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
