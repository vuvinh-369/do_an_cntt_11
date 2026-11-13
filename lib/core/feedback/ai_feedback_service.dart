// File: lib/core/feedback/ai_feedback_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../supabase/supabase_service.dart';
import 'ai_feedback_model.dart';

/// Dịch vụ quản lý phản hồi & đánh giá AI từ người dùng (User Feedback Loop)
/// Hỗ trợ kiến trúc Dual-Mode: Đồng bộ trực tiếp với Supabase Cloud ('ai_feedbacks')
/// kèm bộ nhớ đệm LocalStorage (SharedPreferences) chống mất dữ liệu khi tắt app.
class AiFeedbackService extends ChangeNotifier {
  static final AiFeedbackService instance = AiFeedbackService._internal();

  static const String _keyLocalCache = 'ai_feedbacks_cache_v1';

  AiFeedbackService._internal() {
    _initData();
  }

  final List<AiFeedbackModel> _feedbacks = [];
  bool _isInitialized = false;

  List<AiFeedbackModel> get feedbacks => List.unmodifiable(_feedbacks);

  int get totalCount => _feedbacks.length;

  int get inaccurateCount =>
      _feedbacks.where((f) => f.feedbackType == AiFeedbackType.inaccurate).length;

  int get helpfulCount =>
      _feedbacks.where((f) => f.feedbackType == AiFeedbackType.helpful).length;

  double get accuracyRate =>
      totalCount > 0 ? (helpfulCount / totalCount * 100.0) : 100.0;

  Future<void> _initData() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadFromLocalStorage();
    await fetchFeedbacksFromSupabase();
  }

  /// Nạp danh sách đánh giá từ LocalStorage (bộ nhớ máy)
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyLocalCache);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final list = decoded
              .whereType<Map>()
              .map((m) => AiFeedbackModel.fromMap(Map<String, dynamic>.from(m)))
              .toList();
          if (list.isNotEmpty && _feedbacks.isEmpty) {
            _feedbacks.addAll(list);
            notifyListeners();
            debugPrint('[AiFeedbackService] Đã nạp ${list.length} đánh giá từ LocalStorage cache.');
          }
        }
      }
    } catch (e) {
      debugPrint('[AiFeedbackService] Lỗi nạp LocalStorage: $e');
    }
  }

  /// Lưu bộ nhớ đệm danh sách đánh giá vào LocalStorage
  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _feedbacks.map((f) => f.toMap()).toList();
      await prefs.setString(_keyLocalCache, jsonEncode(list));
    } catch (e) {
      debugPrint('[AiFeedbackService] Lỗi lưu LocalStorage: $e');
    }
  }

  /// Tải danh sách đánh giá từ Supabase Cloud
  Future<void> fetchFeedbacksFromSupabase() async {
    try {
      final client = SupabaseService.instance.client;
      if (client == null) {
        debugPrint('[AiFeedbackService] Supabase client chưa sẵn sàng, giữ cache cục bộ.');
        return;
      }

      final res = await client
          .from('ai_feedbacks')
          .select()
          .order('created_at', ascending: false);

      if (res.isNotEmpty) {
        _feedbacks.clear();
        for (final row in res) {
          _feedbacks.add(AiFeedbackModel.fromMap(Map<String, dynamic>.from(row)));
        }
        await _saveToLocalStorage();
        notifyListeners();
        debugPrint('[AiFeedbackService] Đã đồng bộ ${_feedbacks.length} đánh giá từ Supabase Cloud.');
      } else if (_feedbacks.isNotEmpty) {
        // Nếu trên Supabase chưa có nhưng máy có, có thể đang ở giai đoạn đồng bộ
        debugPrint('[AiFeedbackService] Supabase trả về rỗng, giữ ${_feedbacks.length} bản ghi cache.');
      }
    } catch (e) {
      debugPrint('[AiFeedbackService] Lỗi tải feedbacks từ Supabase: $e');
      // Khi Supabase chưa có bảng hoặc offline, fallback sang LocalStorage
      if (_feedbacks.isEmpty) {
        await _loadFromLocalStorage();
      }
    }
  }

  /// Người dùng gửi đánh giá đúng / sai về kết quả AI
  Future<void> submitFeedback(AiFeedbackModel feedback) async {
    // 1. Cập nhật tức thời vào RAM để UI phản hồi ngay lập tức
    _feedbacks.insert(0, feedback);
    notifyListeners();

    // 2. Lưu bền vững vào LocalStorage để không bao giờ mất khi tắt app
    await _saveToLocalStorage();

    // 3. Đẩy lên Supabase Cloud
    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('ai_feedbacks').insert(feedback.toMap());
        debugPrint('[AiFeedbackService] ✅ Đã lưu đánh giá ${feedback.id} vào Supabase Cloud thành công.');
      } else {
        debugPrint('[AiFeedbackService] ⚠️ Supabase client chưa kết nối, đánh giá đã được lưu trong LocalStorage.');
      }
    } catch (e) {
      debugPrint('[AiFeedbackService] ❌ Gặp lỗi khi gửi đánh giá lên Supabase: $e');
    }
  }

  /// Xóa phản hồi
  Future<void> deleteFeedback(String id) async {
    _feedbacks.removeWhere((f) => f.id == id);
    notifyListeners();
    await _saveToLocalStorage();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('ai_feedbacks').delete().eq('id', id);
        debugPrint('[AiFeedbackService] Đã xóa đánh giá $id trên Supabase.');
      }
    } catch (e) {
      debugPrint('[AiFeedbackService] Xóa feedback trên Supabase: $e');
    }
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

  /// Nạp danh sách phản hồi từ cơ sở dữ liệu (Supabase/PostgreSQL)
  void setFeedbacks(List<AiFeedbackModel> items) {
    _feedbacks.clear();
    _feedbacks.addAll(items);
    _saveToLocalStorage();
    notifyListeners();
  }
}
