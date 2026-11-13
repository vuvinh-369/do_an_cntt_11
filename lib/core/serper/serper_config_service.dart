import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../medgemma_chat_api.dart';
import '../supabase/supabase_service.dart';

const String kDefaultSerperApiKey = String.fromEnvironment(
  'SERPER_API_KEY',
  defaultValue: '49caf79f7b022cf65297a103605d463725678d62',
);

/// Kết quả lưu cấu hình Serper API Key lên Supabase và local backend.
class SerperSaveResult {
  final bool isSuccess;
  final bool syncedToSupabase;
  final String message;

  const SerperSaveResult({
    required this.isSuccess,
    required this.syncedToSupabase,
    required this.message,
  });
}

/// Kết quả kiểm tra kết nối và credit của Serper.dev API Key.
class SerperTestResult {
  final bool isSuccess;
  final String message;
  final int? statusCode;
  final int? latencyMs;
  final int? sampleCount;
  final int? credits;

  const SerperTestResult({
    required this.isSuccess,
    required this.message,
    this.statusCode,
    this.latencyMs,
    this.sampleCount,
    this.credits,
  });
}

/// Quản lý Serper.dev API Key (Google Maps) và đồng bộ với bảng
/// `system_configurations` trên Supabase (`serper_api_key`).
class SerperConfigService extends ChangeNotifier {
  SerperConfigService._internal();

  static final SerperConfigService instance = SerperConfigService._internal();

  static final Uri _serperMapsUri = Uri.parse('https://google.serper.dev/maps');
  static const Duration _staleThreshold = Duration(seconds: 30);

  String _apiKey = kDefaultSerperApiKey;
  int _configVersion = 0;
  DateTime? _lastFetchedAt;
  String? _lastSupabaseUpdatedAt;
  Future<bool>? _inFlightFetch;

  String get apiKey {
    final trimmed = _apiKey.trim();
    return trimmed.isNotEmpty ? trimmed : kDefaultSerperApiKey;
  }

  bool get isUsingDefaultKey => apiKey == kDefaultSerperApiKey;

  int get configVersion => _configVersion;

  DateTime? get lastFetchedAt => _lastFetchedAt;

  String? get lastSupabaseUpdatedAt => _lastSupabaseUpdatedAt;

  /// Nạp `serper_api_key` mới nhất từ bảng `system_configurations` (`id='app_settings'`).
  Future<bool> fetchConfigFromSupabase({
    Duration timeout = const Duration(seconds: 4),
  }) {
    final pending = _inFlightFetch;
    if (pending != null) return pending;

    final task = _fetchInternal(timeout: timeout);
    _inFlightFetch = task.whenComplete(() => _inFlightFetch = null);
    return _inFlightFetch!;
  }

  Future<bool> _fetchInternal({required Duration timeout}) async {
    try {
      final client = SupabaseService.instance.client;
      if (client == null) return false;

      final data = await client
          .from('system_configurations')
          .select()
          .eq('id', 'app_settings')
          .maybeSingle()
          .timeout(timeout);

      _lastFetchedAt = DateTime.now();
      if (data == null) return true;

      final remoteUpdatedAt = data['updated_at'] as String?;
      if (remoteUpdatedAt != null && remoteUpdatedAt.isNotEmpty) {
        _lastSupabaseUpdatedAt = remoteUpdatedAt;
      }

      final remoteKey = (data['serper_api_key'] as String?)?.trim() ?? '';
      if (remoteKey.isNotEmpty && remoteKey != _apiKey.trim()) {
        _apiKey = remoteKey;
        _configVersion++;
        notifyListeners();
      }
      return true;
    } on Object catch (e) {
      debugPrint('[SerperConfigService] Nạp cấu hình Serper từ Supabase: $e');
      return false;
    }
  }

  /// Làm mới key nếu chưa từng tải từ Supabase hoặc đã quá 30 giây.
  Future<void> refreshIfStale() async {
    if (!SupabaseService.instance.isInitialized) return;
    final last = _lastFetchedAt;
    if (last != null && DateTime.now().difference(last) <= _staleThreshold) {
      return;
    }
    await fetchConfigFromSupabase(timeout: const Duration(milliseconds: 1500));
  }

  /// Cập nhật key đang dùng, đồng bộ lên Supabase (`serper_api_key`) và báo local server (nếu chạy).
  Future<SerperSaveResult> updateApiKey(
    String rawKey, {
    Uri? localApiBaseUrl,
  }) async {
    final cleanKey = rawKey.trim();
    if (cleanKey.isEmpty) {
      return const SerperSaveResult(
        isSuccess: false,
        syncedToSupabase: false,
        message: 'Serper API Key không được để trống.',
      );
    }

    if (cleanKey != _apiKey.trim()) {
      _apiKey = cleanKey;
      _configVersion++;
      notifyListeners();
    } else {
      _apiKey = cleanKey;
    }

    final nowIso = DateTime.now().toIso8601String();
    var syncedToSupabase = false;
    String? supabaseError;

    try {
      final client = SupabaseService.instance.client;
      if (client == null) {
        supabaseError = 'Supabase chưa sẵn sàng trên thiết bị.';
      } else {
        final updated = await client
            .from('system_configurations')
            .update({
              'serper_api_key': cleanKey,
              'updated_at': nowIso,
            })
            .eq('id', 'app_settings')
            .select('id');

        if ((updated as List).isEmpty) {
          await client.from('system_configurations').upsert({
            'id': 'app_settings',
            'serper_api_key': cleanKey,
            'updated_at': nowIso,
          });
        }
        _lastFetchedAt = DateTime.now();
        _lastSupabaseUpdatedAt = nowIso;
        syncedToSupabase = true;
      }
    } on Object catch (e) {
      supabaseError = _formatSupabaseError(e);
      debugPrint('[SerperConfigService] Lỗi đồng bộ Serper Key lên Supabase: $e');
    }

    unawaited(notifyLocalBackendRefresh(baseUrl: localApiBaseUrl));

    if (syncedToSupabase) {
      return const SerperSaveResult(
        isSuccess: true,
        syncedToSupabase: true,
        message:
            'Đã lưu Serper API Key mới lên Supabase và áp dụng ngay cho bản đồ!',
      );
    }

    return SerperSaveResult(
      isSuccess: true,
      syncedToSupabase: false,
      message:
          'Đã áp dụng key trong phiên hiện tại nhưng chưa lưu được lên Supabase: '
          '$supabaseError',
    );
  }

  /// Khôi phục về key mặc định của dự án và lưu đồng bộ lên Supabase.
  Future<SerperSaveResult> resetToDefault({Uri? localApiBaseUrl}) {
    return updateApiKey(kDefaultSerperApiKey, localApiBaseUrl: localApiBaseUrl);
  }

  /// Báo cho local server `127.0.0.1:8765` (nếu đang chạy) tải lại key và xóa cache.
  Future<void> notifyLocalBackendRefresh({
    Uri? baseUrl,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final target = (baseUrl ?? MedGemmaChatApi.defaultBaseUrl()).resolve(
      'api/serper-refresh',
    );
    try {
      await httpClient
          .post(
            target,
            headers: const {'Content-Type': 'application/json'},
            body: '{}',
          )
          .timeout(const Duration(milliseconds: 900));
    } on Object {
      // Local backend may not be running (e.g., direct Desktop mode); ignore cleanly.
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Kiểm tra kết nối và credit bằng một truy vấn Google Maps mẫu tới Serper.dev.
  /// Trên Web (`kIsWeb`), gọi qua local server `/api/serper-test` để tránh CORS.
  Future<SerperTestResult> testApiKey(
    String rawKey, {
    http.Client? client,
    Uri? localApiBaseUrl,
  }) async {
    final cleanKey = rawKey.trim();
    if (cleanKey.isEmpty) {
      return const SerperTestResult(
        isSuccess: false,
        message: 'Vui lòng nhập hoặc dán Serper API Key trước khi kiểm tra.',
      );
    }

    final httpClient = client ?? http.Client();
    final watch = Stopwatch()..start();
    try {
      if (kIsWeb && client == null) {
        final target = (localApiBaseUrl ?? MedGemmaChatApi.defaultBaseUrl())
            .resolve('api/serper-test');
        final response = await httpClient
            .post(
              target,
              headers: const {
                'Content-Type': 'application/json; charset=utf-8',
                'Accept': 'application/json',
              },
              body: jsonEncode({'api_key': cleanKey}),
            )
            .timeout(const Duration(seconds: 14));
        watch.stop();
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
        if (decoded is Map<String, dynamic>) {
          return SerperTestResult(
            isSuccess: decoded['is_success'] == true,
            statusCode: (decoded['status_code'] as num?)?.toInt() ??
                response.statusCode,
            latencyMs: (decoded['latency_ms'] as num?)?.toInt() ??
                watch.elapsedMilliseconds,
            sampleCount: (decoded['sample_count'] as num?)?.toInt(),
            credits: (decoded['credits'] as num?)?.toInt(),
            message: (decoded['message'] as String?) ??
                'Đã nhận phản hồi từ máy chủ kiểm tra.',
          );
        }
        return SerperTestResult(
          isSuccess: false,
          statusCode: response.statusCode,
          message: 'Phản hồi từ local server không hợp lệ.',
        );
      }

      final response = await httpClient
          .post(
            _serperMapsUri,
            headers: {
              'X-API-KEY': cleanKey,
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'q': 'bệnh viện',
              'll': '@10.772500,106.698000,14z',
              'gl': 'vn',
              'hl': 'vi',
            }),
          )
          .timeout(const Duration(seconds: 12));
      watch.stop();

      final rawBody = utf8.decode(response.bodyBytes, allowMalformed: true);
      Map<String, dynamic>? decoded;
      try {
        final parsed = jsonDecode(rawBody);
        if (parsed is Map<String, dynamic>) {
          decoded = parsed;
        }
      } on Object {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final places = decoded?['places'];
        final count = places is List ? places.length : 0;
        final credits = (decoded?['credits'] as num?)?.toInt();
        final creditText = credits != null ? ' · Tốn/còn credit: $credits' : '';
        return SerperTestResult(
          isSuccess: true,
          statusCode: response.statusCode,
          latencyMs: watch.elapsedMilliseconds,
          sampleCount: count,
          credits: credits,
          message:
              'Kết nối thành công tới Serper Google Maps! Độ trễ ${watch.elapsedMilliseconds}ms · tìm thấy $count địa điểm mẫu$creditText.',
        );
      }

      final apiError = (decoded?['message'] as String?)?.trim() ?? '';
      if (response.statusCode == 401 || response.statusCode == 403) {
        return SerperTestResult(
          isSuccess: false,
          statusCode: response.statusCode,
          latencyMs: watch.elapsedMilliseconds,
          message:
              'API Key không hợp lệ hoặc đã bị thu hồi (HTTP ${response.statusCode}). '
              '${apiError.isNotEmpty ? apiError : 'Hãy kiểm tra lại key trên serper.dev.'}',
        );
      }

      if (response.statusCode == 400 ||
          response.statusCode == 402 ||
          response.statusCode == 429) {
        return SerperTestResult(
          isSuccess: false,
          statusCode: response.statusCode,
          latencyMs: watch.elapsedMilliseconds,
          message:
              'Key có thể đã hết credit hoặc vượt giới hạn (HTTP ${response.statusCode})'
              '${apiError.isNotEmpty ? ': $apiError' : '.'}',
        );
      }

      return SerperTestResult(
        isSuccess: false,
        statusCode: response.statusCode,
        latencyMs: watch.elapsedMilliseconds,
        message:
            'Serper trả về HTTP ${response.statusCode}'
            '${apiError.isNotEmpty ? ': $apiError' : '.'}',
      );
    } on TimeoutException {
      return const SerperTestResult(
        isSuccess: false,
        message: 'Hết thời gian chờ phản hồi từ Serper.dev (12 giây).',
      );
    } on Object catch (e) {
      return SerperTestResult(
        isSuccess: false,
        message: 'Lỗi kết nối tới Serper.dev: $e',
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  static String _formatSupabaseError(Object error) {
    final text = error.toString();
    if (text.contains('serper_api_key')) {
      return 'Cột "serper_api_key" chưa có trong bảng system_configurations. Hãy chạy lệnh SQL ALTER TABLE trên Supabase.';
    }
    return text;
  }
}
