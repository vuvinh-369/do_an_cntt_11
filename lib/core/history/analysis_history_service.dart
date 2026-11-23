// File: lib/core/history/analysis_history_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../features/user/models/history_models.dart';
import '../storage/local_storage_service.dart';
import '../supabase/supabase_service.dart';

/// Dịch vụ Singleton quản lý Lịch sử quét & Phân tích chẩn đoán hình ảnh vết thương
/// Hỗ trợ cơ chế Kép (Dual-mode): Bộ nhớ đệm cục bộ LocalStorage (SharedPreferences)
/// kết hợp đồng bộ hai chiều thời gian thực với máy chủ Supabase PostgreSQL (Bảng 'analysis_history')
class AnalysisHistoryService extends ChangeNotifier {
  static final AnalysisHistoryService instance = AnalysisHistoryService._internal();

  AnalysisHistoryService._internal() {
    loadFromLocalStorage();
  }

  final List<AnalysisHistoryItemModel> _items = [];
  List<AnalysisHistoryItemModel> get items => List.unmodifiable(_items);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  // ===========================================================================
  // CÁC CHỈ SỐ THỐNG KÊ THỜI GIAN THỰC (TÍNH TỪ DỮ LIỆU ĐÃ NẠP)
  // ===========================================================================

  /// Tổng số ca quét đã thực hiện
  int get totalScans => _items.length;

  /// Độ tin cậy AI trung bình (%)
  double get averageConfidence {
    if (_items.isEmpty) return 0.0;
    final total = _items.fold<double>(
      0.0,
      (sum, item) => sum + (item.confidencePercent ?? 80).toDouble(),
    );
    return double.parse((total / _items.length).toStringAsFixed(1));
  }

  /// Số ca có mức độ nghiêm trọng (Nặng / Khẩn cấp)
  int get severeCount => _items
      .where((i) =>
          i.severityLevel.toLowerCase() == 'severe' ||
          i.severityLevel.toLowerCase() == 'nặng' ||
          i.severityLevel.toLowerCase() == 'nang')
      .length;

  /// Số ca mức độ trung bình (Vừa)
  int get moderateCount => _items
      .where((i) =>
          i.severityLevel.toLowerCase() == 'moderate' ||
          i.severityLevel.toLowerCase() == 'vừa' ||
          i.severityLevel.toLowerCase() == 'vua')
      .length;

  /// Số ca mức độ nhẹ
  int get mildCount => _items
      .where((i) =>
          i.severityLevel.toLowerCase() == 'mild' ||
          i.severityLevel.toLowerCase() == 'nhẹ' ||
          i.severityLevel.toLowerCase() == 'nhe')
      .length;

  /// Số người dùng riêng biệt đã quét
  int get uniqueUsersCount {
    final users = _items
        .map((i) => i.username?.trim().toLowerCase())
        .where((u) => u != null && u.isNotEmpty)
        .toSet();
    return users.length;
  }

  /// Thống kê phân bố theo từng nhóm loại vết thương
  Map<String, int> get injuryDistribution {
    final Map<String, int> counts = {};
    for (final item in _items) {
      final name = item.injuryType.trim();
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  /// Lọc các ca quét theo người dùng cụ thể (hoặc toàn bộ nếu là Quản trị viên/Khách)
  List<AnalysisHistoryItemModel> getItemsForUser(String? username) {
    if (username == null || username.trim().isEmpty) {
      return items;
    }
    final target = username.trim().toLowerCase();
    return _items.where((i) {
      final u = i.username?.trim().toLowerCase();
      return u == target || u == null;
    }).toList();
  }

  // ===========================================================================
  // BỘ NHỚ ĐỆM CỤC BỘ LOCAL STORAGE (PERSISTENCE)
  // ===========================================================================

  /// Nạp lịch sử từ LocalStorage ngay khi khởi động app
  Future<void> loadFromLocalStorage() async {
    try {
      final rawList = await LocalStorageService.instance.loadAnalysisHistory();
      if (rawList.isNotEmpty) {
        final loadedItems = rawList.map((m) => AnalysisHistoryItemModel.fromMap(m)).toList();
        final loadedIds = loadedItems.map((i) => i.id).toSet();
        final unsaved = _items.where((i) => !loadedIds.contains(i.id)).toList();
        _items.clear();
        _items.addAll(loadedItems);
        _items.addAll(unsaved);
        _items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        notifyListeners();
      } else if (_items.isEmpty) {
        // Nếu bộ nhớ đệm trống hoàn toàn, khởi tạo danh sách mẫu mặc định an toàn
        _initDefaultFallbackItems();
        await _persistToLocalStorage();
      }
    } catch (e) {
      debugPrint('[AnalysisHistoryService] Lỗi đọc bộ nhớ đệm LocalStorage: $e');
    }
  }

  /// Ghi toàn bộ danh sách hiện tại xuống LocalStorage
  Future<void> _persistToLocalStorage() async {
    try {
      final maps = _items.map((i) => i.toMap()).toList();
      await LocalStorageService.instance.saveAnalysisHistory(maps);
    } catch (e) {
      debugPrint('[AnalysisHistoryService] Lỗi ghi bộ nhớ đệm LocalStorage: $e');
    }
  }

  /// Khởi tạo dữ liệu mẫu ban đầu để giao diện không bị trống rỗng khi mới cài đặt
  void _initDefaultFallbackItems() {
    final now = DateTime.now();
    _items.clear();
    _items.addAll([
      AnalysisHistoryItemModel(
        id: 'hist_seed_001',
        username: 'admin',
        injuryType: 'Trầy xước ngoài da',
        confidencePercent: 93,
        severityLevel: 'mild',
        locationLabel: 'Cẳng tay phải',
        timestamp: '14:20 ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
        dateTime: now.subtract(const Duration(minutes: 35)),
        imageSourceName: 'assets/images/sample_abrasion.jpg',
        relatedTopicId: 'abrasion',
        symptoms: const ['Chảy máu rỉ rỉ', 'Rát bề mặt biểu bì', 'Bụi cát bám dính'],
        painLevel: 2,
        firstAidSummary: 'Rửa sạch bằng nước muối sinh lý 0.9%, sát khuẩn bằng Povidone-Iodine và dán gạc vô trùng thoáng.',
      ),
      AnalysisHistoryItemModel(
        id: 'hist_seed_002',
        username: 'benhnhan_01',
        injuryType: 'Vết cắt / rách da',
        confidencePercent: 88,
        severityLevel: 'severe',
        locationLabel: 'Ngón tay trỏ trái',
        timestamp: '11:45 ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
        dateTime: now.subtract(const Duration(hours: 3)),
        imageSourceName: 'assets/images/sample_cut.jpg',
        relatedTopicId: 'cut_laceration',
        symptoms: const ['Chảy máu nhiều', 'Vết rách sâu quá 0.5cm', 'Vết cắt kim loại sắc'],
        painLevel: 7,
        firstAidSummary: 'Ấn ép trực tiếp gạc vô trùng cầm máu khẩn cấp, nâng cao chi tổn thương và khẩn trương đến viện khâu vết thương.',
      ),
      AnalysisHistoryItemModel(
        id: 'hist_seed_003',
        username: 'benhnhan_02',
        injuryType: 'Bỏng nhiệt',
        confidencePercent: 85,
        severityLevel: 'moderate',
        locationLabel: 'Mu bàn tay phải',
        timestamp: '06:15 ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
        dateTime: now.subtract(const Duration(hours: 8)),
        imageSourceName: 'assets/images/sample_burn.jpg',
        relatedTopicId: 'burn',
        symptoms: const ['Da đỏ rát', 'Phồng rộp bọng nước', 'Bỏng nước sôi diện tích nhỏ'],
        painLevel: 5,
        firstAidSummary: 'Xả nước mát sạch (15-25°C) liên tục trong 15-20 phút. Tuyệt đối không chườm đá lạnh buốt hay chọc vỡ bọng nước.',
      ),
      AnalysisHistoryItemModel(
        id: 'hist_seed_004',
        username: null,
        injuryType: 'Bầm tím phần mềm',
        confidencePercent: 80,
        severityLevel: 'mild',
        locationLabel: 'Đầu gối trái',
        timestamp: '15:30 ${now.subtract(const Duration(days: 1)).day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
        dateTime: now.subtract(const Duration(days: 1)),
        imageSourceName: 'assets/images/sample_bruise.jpg',
        relatedTopicId: 'bruise',
        symptoms: const ['Tụ máu dưới da', 'Đổi màu xanh tím', 'Đau khi ấn vào'],
        painLevel: 3,
        firstAidSummary: 'Chườm lạnh gián tiếp qua khăn sạch 15 phút để co mạch giảm phù nề, nghỉ ngơi vùng va đập.',
      ),
    ]);
  }

  // ===========================================================================
  // CÁC HÀM TRUY VẤN VÀ ĐỒNG BỘ DỮ LIỆU VỚI SUPABASE
  // ===========================================================================

  /// Nạp toàn bộ lịch sử phân tích từ bảng 'analysis_history' trên Supabase
  Future<void> fetchHistoryFromSupabase({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final client = SupabaseService.instance.client;
      if (client == null) {
        // Khi chưa kết nối hoặc đang offline, giữ nguyên bộ nhớ đệm
        _lastError = 'Chưa kết nối máy chủ Supabase (Đang dùng dữ liệu lưu trữ cục bộ).';
        await loadFromLocalStorage();
        return;
      }

      final res = await client
          .from('analysis_history')
          .select()
          .order('created_at', ascending: false);

      if (res.isNotEmpty) {
        final remoteItems = <AnalysisHistoryItemModel>[];
        final remoteIds = <String>{};
        for (final row in res) {
          final item = AnalysisHistoryItemModel.fromMap(row);
          remoteItems.add(item);
          remoteIds.add(item.id);
        }

        // Giữ lại các bản ghi cục bộ chưa có trên máy chủ Supabase (quét offline / chưa sync)
        final localOnlyItems = _items.where((i) => !remoteIds.contains(i.id)).toList();

        _items.clear();
        _items.addAll(remoteItems);
        _items.addAll(localOnlyItems);
        // Sắp xếp theo dateTime giảm dần (mới nhất lên đầu)
        _items.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        _lastError = null;
        _lastSyncTime = DateTime.now();
        await _persistToLocalStorage();

        if (localOnlyItems.isNotEmpty) {
          unawaited(_syncLocalItemsToSupabase());
        }
      } else {
        // Nếu Supabase trả về rỗng (bảng mới tạo chưa seed), đồng bộ các bản ghi cục bộ lên
        if (_items.isNotEmpty) {
          unawaited(_syncLocalItemsToSupabase());
        }
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[AnalysisHistoryService] Tải lịch sử Supabase: $e');
      // Tải lại từ bộ nhớ đệm để đảm bảo không bị trống
      if (_items.isEmpty) {
        await loadFromLocalStorage();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Đồng bộ danh sách bản ghi cục bộ lên Supabase nếu máy chủ đang trống
  Future<void> _syncLocalItemsToSupabase() async {
    try {
      final client = SupabaseService.instance.client;
      if (client == null || _items.isEmpty) return;
      // Chỉ đồng bộ các bản ghi của tài khoản đã đăng nhập (tuân thủ khóa ngoại username)
      final validItems = _items
          .where((i) => i.username != null && i.username!.trim().isNotEmpty)
          .map((i) => i.toMap())
          .toList();
      if (validItems.isNotEmpty) {
        await client.from('analysis_history').upsert(validItems);
      }
    } catch (e) {
      debugPrint('[AnalysisHistoryService] Đồng bộ ngược lên Supabase: $e');
    }
  }

  /// Thêm trực tiếp một Model đã khởi tạo vào danh sách (dùng khi UserViewModel ghi nhận)
  Future<void> addDirectItem(AnalysisHistoryItemModel item) async {
    _items.removeWhere((i) => i.id == item.id);
    _items.insert(0, item);
    notifyListeners();
    await _persistToLocalStorage();
  }

  /// Ghi nhận một ca phân tích mới trực tiếp vào Supabase & LocalStorage
  Future<bool> recordAnalysis({
    String? username,
    required String injuryTypeId,
    required String injuryTypeName,
    required double confidenceScore,
    String severityLevel = 'moderate',
    String locationLabel = 'Chưa xác định',
    String? imageUrl,
    List<String> symptoms = const [],
    int painLevel = 0,
    String? firstAidSummary,
  }) async {
    final now = DateTime.now();
    final localId = 'hist_${now.millisecondsSinceEpoch}';

    final optimisticItem = AnalysisHistoryItemModel(
      id: localId,
      username: username,
      injuryType: injuryTypeName,
      confidencePercent: confidenceScore.round(),
      severityLevel: severityLevel,
      locationLabel: locationLabel,
      timestamp: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
      dateTime: now,
      imageSourceName: imageUrl,
      relatedTopicId: injuryTypeId,
      symptoms: symptoms,
      painLevel: painLevel,
      firstAidSummary: firstAidSummary,
    );

    // 1. Lưu ngay vào RAM và LocalStorage (Bền vững, không mất khi đóng app)
    _items.insert(0, optimisticItem);
    notifyListeners();
    await _persistToLocalStorage();

    // 2. Đồng bộ lên Supabase Cloud CHỈ KHI người dùng đã đăng nhập (username hợp lệ)
    // Người dùng khách vẫn quét và hỏi AI bình thường nhưng chỉ lưu cục bộ trên máy
    final cleanUsername = username?.trim();
    if (cleanUsername != null && cleanUsername.isNotEmpty) {
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          final inserted = await client.from('analysis_history').insert({
            'id': localId,
            'username': cleanUsername,
            'injury_type_id': injuryTypeId,
            'injury_type_name': injuryTypeName,
            'confidence_score': confidenceScore,
            'severity_level': severityLevel,
            'location_label': locationLabel,
            'image_url': imageUrl,
            'symptoms': symptoms,
            'pain_level': painLevel,
            'first_aid_summary': firstAidSummary,
            'created_at': now.toIso8601String(),
          }).select().maybeSingle();

          if (inserted != null && inserted['id'] != null) {
            final idx = _items.indexWhere((i) => i.id == localId);
            if (idx != -1) {
              _items[idx] = AnalysisHistoryItemModel.fromMap(inserted);
              await _persistToLocalStorage();
              notifyListeners();
            }
          }
          return true;
        }
      } catch (e) {
        debugPrint('[AnalysisHistoryService] Ghi nhận lịch sử Supabase lỗi: $e');
      }
    }
    return false;
  }

  /// Xóa một ca quét khỏi danh sách và Supabase
  Future<bool> deleteRecord(String id) async {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
    await _persistToLocalStorage();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('analysis_history').delete().eq('id', id);
        return true;
      }
    } catch (e) {
      debugPrint('[AnalysisHistoryService] Lỗi xóa bản ghi Supabase: $e');
    }
    return false;
  }

  /// Thêm dữ liệu mẫu thực tế vào Supabase (dành cho người quản trị muốn khởi tạo dữ liệu mẫu kiểm thử)
  Future<void> seedSampleDataToSupabase() async {
    _isLoading = true;
    notifyListeners();

    final samples = [
      {
        'username': 'admin',
        'injury_type_id': 'abrasion',
        'injury_type_name': 'Trầy xước ngoài da',
        'confidence_score': 92.5,
        'severity_level': 'mild',
        'location_label': 'Cẳng tay phải',
        'pain_level': 2,
        'symptoms': ['Chảy máu rỉ rỉ', 'Rát bề mặt biểu bì', 'Bụi cát bám dính'],
        'first_aid_summary': 'Rửa sạch bằng nước muối 0.9%, sát khuẩn bằng Povidone-Iodine và dán gạc vô trùng thoáng.',
        'created_at': DateTime.now().subtract(const Duration(minutes: 35)).toIso8601String(),
      },
      {
        'username': 'patient_test',
        'injury_type_id': 'cut_laceration',
        'injury_type_name': 'Vết cắt / rách da',
        'confidence_score': 88.0,
        'severity_level': 'severe',
        'location_label': 'Ngón tay trỏ trái',
        'pain_level': 7,
        'symptoms': ['Chảy máu nhiều', 'Vết rách sâu quá 0.5cm', 'Vết cắt kim loại sắc'],
        'first_aid_summary': 'Ấn ép trực tiếp gạc vô trùng cầm máu khẩn cấp, nâng cao chi tổn thương và khẩn trương đến viện khâu vết thương.',
        'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      },
      {
        'username': 'patient_test',
        'injury_type_id': 'burn',
        'injury_type_name': 'Bỏng nhiệt',
        'confidence_score': 85.0,
        'severity_level': 'moderate',
        'location_label': 'Mu bàn tay phải',
        'pain_level': 5,
        'symptoms': ['Da đỏ rát', 'Phồng rộp bọng nước', 'Bỏng nước sôi diện tích nhỏ'],
        'first_aid_summary': 'Xả nước mát sạch (15-25°C) liên tục trong 15-20 phút. Tuyệt đối không chườm đá lạnh buốt hay chọc vỡ bọng nước.',
        'created_at': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
      },
      {
        'username': 'default_user',
        'injury_type_id': 'bruise',
        'injury_type_name': 'Bầm tím phần mềm',
        'confidence_score': 79.5,
        'severity_level': 'mild',
        'location_label': 'Đầu gối trái',
        'pain_level': 3,
        'symptoms': ['Tụ máu dưới da', 'Đổi màu xanh tím', 'Đau khi ấn vào'],
        'first_aid_summary': 'Chườm lạnh gián tiếp qua khăn sạch 15 phút để co mạch giảm phù nề, nghỉ ngơi vùng va đập.',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('analysis_history').insert(samples);
        await fetchHistoryFromSupabase(silent: true);
      }
    } catch (e) {
      debugPrint('[AnalysisHistoryService] Lỗi tạo dữ liệu mẫu: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
