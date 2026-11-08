// File: lib/core/config/supabase_config.dart

/// Cấu hình kết nối Supabase Cloud (PostgreSQL / Realtime / Auth)
/// Tuân thủ nguyên tắc:
/// - Kéo code về máy khác là chạy ngay được với cấu hình mặc định của nhóm
/// - Hỗ trợ ghi đè linh hoạt qua biến môi trường --dart-define nếu cần
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oageskffhndqypwuuaij.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_G_vCmGysKprr-mnkK4EeSg_CrqsGdCM',
  );

  /// Alias tương thích ngược
  static String get anonKey => publishableKey;

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
