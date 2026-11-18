import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/gemini/gemini_config_model.dart';
import '../../../core/gemini/gemini_service.dart';
import '../../../core/serper/serper_config_service.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/supabase/supabase_otp_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/url_launcher_helper.dart';
import '../viewmodels/admin_viewmodel.dart';

// =============================================================================
// 6. VIEW CẤU HÌNH HỆ THỐNG (Settings & Google Gemini API)
// =============================================================================
class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  late TextEditingController _apiKeyController;
  late TextEditingController _promptController;
  late TextEditingController _maxTokensController;
  late bool _geminiEnabled;
  bool _obscureApiKey = true;

  bool _isTestingGemini = false;
  late TextEditingController _serperKeyController;
  bool _obscureSerperKey = true;
  bool _serperKeyEdited = false;
  bool _isTestingSerper = false;
  bool _isSavingSerper = false;
  bool _isRefreshingSerper = false;
  SerperTestResult? _serperTestResult;
  SerperSaveResult? _serperSaveResult;
  bool _isPingingSupabase = false;
  String? _supabasePingMessage;
  bool? _supabasePingSuccess;

  Future<void> _pingSupabase() async {
    setState(() {
      _isPingingSupabase = true;
      _supabasePingMessage = null;
    });

    final res = await SupabaseService.instance.pingConnection();

    if (mounted) {
      setState(() {
        _isPingingSupabase = false;
        _supabasePingSuccess = res['success'] == true;
        _supabasePingMessage = res['message'] as String?;
      });
    }
  }
  GeminiTestResult? _geminiTestResult;

  @override
  void initState() {
    super.initState();
    final config = GeminiService.instance.config;
    _apiKeyController = TextEditingController(text: config.apiKey);
    _promptController = TextEditingController(text: config.systemInstruction);
    _maxTokensController = TextEditingController(text: config.maxTokens.toString());
    _geminiEnabled = config.isEnabled;

    _serperKeyController = TextEditingController(
      text: SerperConfigService.instance.apiKey,
    );
    _syncSerperFromSupabase(silent: true);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _promptController.dispose();
    _maxTokensController.dispose();
    _serperKeyController.dispose();
    super.dispose();
  }

  Future<void> _pasteKeyFromClipboard(
    TextEditingController controller, {
    VoidCallback? onPasted,
  }) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        controller.text = data.text!.trim();
        onPasted?.call();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã dán API Key từ bộ nhớ tạm thành công!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bộ nhớ tạm (Clipboard) không có văn bản!'),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _syncSerperFromSupabase({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isRefreshingSerper = true;
      });
    }
    final ok = await SerperConfigService.instance.fetchConfigFromSupabase();
    if (!mounted) return;
    setState(() {
      _isRefreshingSerper = false;
      if (!_serperKeyEdited || !silent) {
        _serperKeyController.text = SerperConfigService.instance.apiKey;
        _serperKeyEdited = false;
      }
    });
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Đã tải Serper API Key mới nhất từ Supabase!'
                : 'Không thể đọc cấu hình từ Supabase (đang dùng key hiện tại).',
          ),
          backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copySerperKey() async {
    final cleanKey = _serperKeyController.text.trim();
    if (cleanKey.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: cleanKey));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép Serper API Key vào Clipboard.'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _testSerperConnection(AdminViewModel viewModel) async {
    final cleanKey = _serperKeyController.text.trim();
    if (cleanKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập Serper API Key trước khi kiểm tra!'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isTestingSerper = true;
      _serperTestResult = null;
    });

    final result = await viewModel.testSerperConnection(cleanKey);
    if (!mounted) return;
    setState(() {
      _isTestingSerper = false;
      _serperTestResult = result;
    });
  }

  Future<void> _saveSerperConfiguration(AdminViewModel viewModel) async {
    final cleanKey = _serperKeyController.text.trim();
    if (cleanKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Serper API Key không được để trống. Hãy dán key mới hoặc nhấn Khôi phục key mặc định.',
          ),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isSavingSerper = true;
      _serperSaveResult = null;
    });

    final result = await viewModel.updateSerperApiKey(cleanKey);
    if (!mounted) return;
    setState(() {
      _isSavingSerper = false;
      _serperKeyEdited = false;
      _serperSaveResult = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.syncedToSupabase
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _resetSerperKey(AdminViewModel viewModel) async {
    setState(() {
      _isSavingSerper = true;
      _serperTestResult = null;
      _serperSaveResult = null;
    });

    final result = await viewModel.resetSerperApiKeyToDefault();
    if (!mounted) return;
    setState(() {
      _isSavingSerper = false;
      _serperKeyEdited = false;
      _serperKeyController.text = SerperConfigService.instance.apiKey;
      _serperSaveResult = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.syncedToSupabase
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resetSystemPromptToStandard() {
    setState(() {
      _promptController.text = defaultWoundCareSystemInstruction;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã khôi phục System Prompt chuẩn y khoa cho 4 nhóm vết thương!'),
          backgroundColor: Color(0xFF2563EB),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testGeminiConnection(AdminViewModel viewModel) async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập API Key trước khi kiểm tra kết nối!'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isTestingGemini = true;
      _geminiTestResult = null;
    });

    final result = await viewModel.testGeminiConnection(
      apiKey: apiKey,
      model: 'gemini-3.8-flash',
    );

    if (!mounted) return;
    setState(() {
      _isTestingGemini = false;
      _geminiTestResult = result;
    });
  }

  void _saveGeminiConfiguration(AdminViewModel viewModel) {
    final maxTok = int.tryParse(_maxTokensController.text.trim()) ?? 1024;
    final newConfig = GeminiConfigModel(
      isEnabled: _geminiEnabled,
      apiKey: _apiKeyController.text.trim(),
      selectedModel: 'gemini-3.8-flash',
      systemInstruction: _promptController.text.trim().isEmpty
          ? defaultWoundCareSystemInstruction
          : _promptController.text.trim(),
      temperature: 0.4,
      maxTokens: maxTok,
    );

    viewModel.updateGeminiConfig(newConfig);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Đã lưu cấu hình Google Gemini API thành công!'),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildFeaturePill({
    required double width,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTestSupabaseOtpDialog() {
    final testCtrl = TextEditingController(text: 'bacsi.cuuho@gmail.com');
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.mark_email_read_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 10),
              Text('Kiểm tra gửi OTP qua Supabase', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Phát lệnh gửi mã OTP khôi phục mật khẩu thông qua API Supabase Auth tới email chỉ định.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: testCtrl,
                enabled: !isTesting,
                decoration: InputDecoration(
                  labelText: 'Địa chỉ Email người nhận',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isTesting ? null : () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      final email = testCtrl.text.trim();
                      if (email.isEmpty) return;
                      setDialogState(() => isTesting = true);
                      try {
                        final res = await SupabaseOtpService.instance.sendPasswordResetOtp(email: email);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        final isSuccess = res['success'] == true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(res['message'] as String? ?? '')),
                              ],
                            ),
                            backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } finally {
                        if (ctx.mounted) setDialogState(() => isTesting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: isTesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Gửi ngay'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminViewModel>();

    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cấu hình hệ thống & Trợ lý AI',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2B6B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Quản lý các thiết lập vận hành của Google Gemini API, Google Maps (Serper.dev) và dịch vụ Email khôi phục mật khẩu',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          // ===================================================================
          // ===================================================================
          // CARD: CƠ SỞ DỮ LIỆU SUPABASE CLOUD (POSTGRESQL & REST API)
          // ===================================================================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6EE7B7)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0810B981),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Icon(Icons.storage_rounded, color: Color(0xFF059669), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Cơ sở dữ liệu Supabase Cloud',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: const Text(
                                  'Sẵn sàng kết nối',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Lưu trữ đồng bộ đám mây cho tài khoản, bài viết sơ cứu, lịch sử quét và phản hồi AI.',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 150,
                      child: Text(
                        'Project Endpoint:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        SupabaseConfig.url,
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 150,
                      child: Text(
                        'Publishable Key:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        '${SupabaseConfig.anonKey.substring(0, math.min(24, SupabaseConfig.anonKey.length))}••••••••••••••••',
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                if (_supabasePingMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _supabasePingSuccess == true ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _supabasePingSuccess == true ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _supabasePingSuccess == true ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: _supabasePingSuccess == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _supabasePingMessage!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _supabasePingSuccess == true ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isPingingSupabase ? null : _pingSupabase,
                      icon: _isPingingSupabase
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                            )
                          : const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF059669)),
                      label: Text(_isPingingSupabase ? 'Đang kiểm tra...' : 'Kiểm tra kết nối Supabase'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF059669)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => UrlLauncherHelper.launchWebUrl(
                        context,
                        'https://supabase.com/dashboard/project/oageskffhndqypwuuaij',
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Mở Supabase Dashboard'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // CARD 1: CẤU HÌNH CHATBOX GOOGLE GEMINI API
          // ===================================================================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x082563EB),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '1. Cấu hình ChatBox Gemini',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0D2B6B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _geminiEnabled && _apiKeyController.text.trim().isNotEmpty
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _geminiEnabled && _apiKeyController.text.trim().isNotEmpty
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Text(
                                  _geminiEnabled && _apiKeyController.text.trim().isNotEmpty
                                      ? 'Đang hoạt động'
                                      : (_geminiEnabled ? 'Chờ API Key' : 'Đã tắt'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _geminiEnabled && _apiKeyController.text.trim().isNotEmpty
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Gọi trực tiếp Gemini API để giải đáp thắc mắc và tư vấn sơ cứu chuyên sâu theo ngôn ngữ tự nhiên.',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _geminiEnabled,
                      activeTrackColor: const Color(0xFF2563EB),
                      onChanged: (val) {
                        setState(() {
                          _geminiEnabled = val;
                        });
                      },
                    ),
                  ],
                ),
                const Divider(height: 28),

                // 4.1 Khóa Gemini API Key
                Row(
                  children: [
                    const Text(
                      'Khóa API Key của Google Gemini:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => UrlLauncherHelper.launchWebUrl(
                        context,
                        'https://aistudio.google.com/app/apikey',
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Lấy API Key miễn phí tại Google AI Studio',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureApiKey,
                        decoration: InputDecoration(
                          hintText: 'Dán khóa API Key của bạn (Bắt đầu bằng AIzaSy...)',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF64748B), size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureApiKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF64748B),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureApiKey = !_obscureApiKey;
                              });
                            },
                            tooltip: _obscureApiKey ? 'Hiện khóa API' : 'Ẩn khóa API',
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _pasteKeyFromClipboard(_apiKeyController),
                      icon: const Icon(Icons.paste_rounded, size: 17),
                      label: const Text('Dán từ Clipboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF1E293B),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2.2 Thông tin mô hình Gemini & Nhiệt độ y khoa chuẩn
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 20, color: Color(0xFF2563EB)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mô hình AI: Google Gemini Flash (Mới nhất)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Hệ thống tự động sử dụng phiên bản Flash mới nhất với nhiệt độ 0.4 (chuẩn độ chính xác y khoa).',
                              style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 4.3 System Instruction (Prompt định hướng y tế cho 4 loại vết thương)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lời nhắc hệ thống (System Prompt) cho vết thương:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    TextButton.icon(
                      onPressed: _resetSystemPromptToStandard,
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('Khôi phục mẫu chuẩn y tế', style: TextStyle(fontSize: 12.5)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _promptController,
                  maxLines: 7,
                  minLines: 4,
                  style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', height: 1.4, color: Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: 'Nhập lời nhắc định hướng phản hồi của Gemini...',
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mẫu prompt này được thiết kế để Gemini bám sát 4 phạm trù: Trầy xước, Vết cắt/rách, Bỏng, Bầm tím, tự động cảnh báo khẩn cấp đi viện khi nguy kịch và nhắc nhở tiêm uốn ván.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Hiển thị kết quả Test Connection nếu có
                if (_geminiTestResult != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _geminiTestResult!.isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _geminiTestResult!.isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _geminiTestResult!.isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: _geminiTestResult!.isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _geminiTestResult!.isSuccess ? 'Kiểm tra thành công!' : 'Kiểm tra thất bại:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _geminiTestResult!.isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _geminiTestResult!.message,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _geminiTestResult!.isSuccess ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4.4 Các nút hành động: Kiểm tra kết nối & Lưu cấu hình
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isTestingGemini ? null : () => _testGeminiConnection(viewModel),
                      icon: _isTestingGemini
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                            )
                          : const Icon(Icons.network_check_rounded, size: 18),
                      label: Text(_isTestingGemini ? 'Đang kiểm tra...' : 'Kiểm tra kết nối Gemini'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _saveGeminiConfiguration(viewModel),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Lưu cấu hình Gemini'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ===================================================================
          // CARD 2: CẤU HÌNH GOOGLE MAPS (SERPER.DEV API)
          // ===================================================================
          _buildSerperSettingsCard(viewModel),
          const SizedBox(height: 24),

          // ===================================================================
          // CARD 3: DỊCH VỤ XÁC THỰC & GỬI MÃ OTP QUA EMAIL (SUPABASE AUTH BUILT-IN)
          // ===================================================================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x082563EB),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              const Text(
                                '3. Dịch vụ Xác thực & Gửi mã OTP qua Email (Supabase Auth)',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0D2B6B),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF15803D)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Supabase Auth Cloud',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Hạ tầng gửi OTP và xác thực email tích hợp trực tiếp từ Supabase Auth, bảo mật cao và không cần cấu hình SMTP thủ công.',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Banner thông báo đã chuyển đổi
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đã chuyển đổi sang Dịch vụ OTP có sẵn trong Supabase',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF166534),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Ứng dụng đã loại bỏ hoàn toàn cơ chế cấu hình SMTP thủ công (loại bỏ rủi ro lộ mật khẩu ứng dụng Gmail/SMTP trên client). Mọi yêu cầu quên mật khẩu, xác thực tài khoản và phát sinh mã OTP 6 chữ số đều do Supabase Auth xử lý trực tiếp.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF14532D), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Danh sách tính năng bảo mật tích hợp
                const Text(
                  'Các ưu điểm & cơ chế bảo vệ của Supabase Auth OTP:',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildFeaturePill(
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2,
                          icon: Icons.pin_outlined,
                          title: 'Mã OTP 6 số ngẫu nhiên',
                          description: 'Phát sinh bảo mật với thuật toán mã hóa mật mã học, chỉ dùng được 1 lần duy nhất.',
                        ),
                        _buildFeaturePill(
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2,
                          icon: Icons.shield_outlined,
                          title: 'Rate Limiting & Chống Brute-force',
                          description: 'Tự động khóa và giới hạn tần suất gửi email theo IP/Email, ngăn chặn bot spam.',
                        ),
                        _buildFeaturePill(
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2,
                          icon: Icons.mark_email_unread_outlined,
                          title: 'Mẫu Email tùy biến (Templates)',
                          description: 'Quản trị viên tùy chỉnh giao diện thư và tiêu đề trực tiếp từ Supabase Dashboard.',
                        ),
                        _buildFeaturePill(
                          width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2,
                          icon: Icons.tune_rounded,
                          title: 'Hỗ trợ Custom SMTP',
                          description: 'Có thể liên kết với Resend, SendGrid, Amazon SES hoặc Gmail SMTP qua Supabase.',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),

                // Nút hành động
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showTestSupabaseOtpDialog,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Kiểm tra gửi OTP thử nghiệm (Supabase)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        UrlLauncherHelper.launchWebUrl(
                          context,
                          'https://supabase.com/dashboard/project/oageskffhndqypwuuaij/auth/templates',
                        );
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Mở Supabase Auth Dashboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSerperSettingsCard(AdminViewModel viewModel) {
    final isUsingDefault = _serperKeyController.text.trim() == kDefaultSerperApiKey;
    final hasKey = _serperKeyController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x082563EB),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.map_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        const Text(
                          '2. Cấu hình Google Maps (Serper.dev API)',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D2B6B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: !hasKey
                                ? const Color(0xFFFEE2E2)
                                : (isUsingDefault
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFFDCFCE7)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: !hasKey
                                  ? const Color(0xFFFCA5A5)
                                  : (isUsingDefault
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF86EFAC)),
                            ),
                          ),
                          child: Text(
                            !hasKey
                                ? 'Chưa có key'
                                : (isUsingDefault
                                      ? 'Key mặc định'
                                      : 'Key tùy chỉnh (Supabase)'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: !hasKey
                                  ? const Color(0xFFB91C1C)
                                  : (isUsingDefault
                                        ? const Color(0xFF475569)
                                        : const Color(0xFF15803D)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Quản lý khóa API Serper.dev dùng cho tính năng tìm Bệnh viện & Nhà thuốc gần nhất (Đồng bộ Supabase Cloud).',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đồng bộ Supabase: Lưu trên cột "serper_api_key" của bảng "system_configurations". Khi key gần hết 2.500 credit miễn phí, bạn chỉ cần dán key mới rồi bấm "Lưu & Áp dụng ngay" — cả Chrome Web lẫn Windows App sẽ tự cập nhật mà không cần sửa code.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF075985), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              const Text(
                'Khóa API Key của Serper.dev:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              InkWell(
                onTap: () => UrlLauncherHelper.launchWebUrl(
                  context,
                  'https://serper.dev/api-key',
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lấy API Key miễn phí tại Serper.dev',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serperKeyController,
                  obscureText: _obscureSerperKey,
                  onChanged: (_) {
                    if (!_serperKeyEdited) {
                      setState(() => _serperKeyEdited = true);
                    } else {
                      setState(() {});
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Dán Serper API Key mới (ví dụ: 49caf79f...)',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF64748B), size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 18),
                          onPressed: _copySerperKey,
                          tooltip: 'Sao chép key',
                        ),
                        IconButton(
                          icon: Icon(
                            _obscureSerperKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureSerperKey = !_obscureSerperKey;
                            });
                          },
                          tooltip: _obscureSerperKey ? 'Hiện khóa API' : 'Ẩn khóa API',
                        ),
                      ],
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _pasteKeyFromClipboard(
                  _serperKeyController,
                  onPasted: () {
                    _serperKeyEdited = true;
                    _serperTestResult = null;
                  },
                ),
                icon: const Icon(Icons.paste_rounded, size: 17),
                label: const Text('Dán nhanh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          if (_serperTestResult != null) ...[
            const SizedBox(height: 14),
            _buildStatusAlertBox(
              isSuccess: _serperTestResult!.isSuccess,
              title: _serperTestResult!.isSuccess
                  ? 'Kiểm tra Serper thành công!'
                  : 'Kiểm tra Serper thất bại:',
              message: _serperTestResult!.message,
            ),
          ],

          if (_serperSaveResult != null) ...[
            const SizedBox(height: 12),
            _buildStatusAlertBox(
              isSuccess: _serperSaveResult!.syncedToSupabase,
              isWarning: _serperSaveResult!.isSuccess && !_serperSaveResult!.syncedToSupabase,
              title: _serperSaveResult!.syncedToSupabase
                  ? 'Đã đồng bộ lên Supabase:'
                  : 'Chưa lưu lên Supabase:',
              message: _serperSaveResult!.message,
            ),
          ],

          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _isTestingSerper ? null : () => _testSerperConnection(viewModel),
                icon: _isTestingSerper
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                      )
                    : const Icon(Icons.network_check_rounded, size: 18),
                label: Text(_isTestingSerper ? 'Đang kiểm tra...' : 'Kiểm tra kết nối Serper'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isSavingSerper ? null : () => _saveSerperConfiguration(viewModel),
                icon: _isSavingSerper
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isSavingSerper ? 'Đang lưu...' : 'Lưu & Áp dụng ngay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
              TextButton.icon(
                onPressed: _isRefreshingSerper ? null : () => _syncSerperFromSupabase(),
                icon: const Icon(Icons.cloud_download_outlined, size: 17),
                label: Text(_isRefreshingSerper ? 'Đang tải...' : 'Tải từ Supabase'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              TextButton.icon(
                onPressed: _isSavingSerper ? null : () => _resetSerperKey(viewModel),
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: const Text('Khôi phục key mặc định'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAlertBox({
    required bool isSuccess,
    bool isWarning = false,
    required String title,
    required String message,
  }) {
    final bgColor = isWarning
        ? const Color(0xFFFFFBEB)
        : (isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2));
    final borderColor = isWarning
        ? const Color(0xFFFDE68A)
        : (isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA));
    final iconColor = isWarning
        ? const Color(0xFFD97706)
        : (isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626));
    final titleColor = isWarning
        ? const Color(0xFF92400E)
        : (isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B));
    final textColor = isWarning
        ? const Color(0xFFB45309)
        : (isSuccess ? const Color(0xFF047857) : const Color(0xFFB91C1C));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning
                ? Icons.warning_amber_rounded
                : (isSuccess ? Icons.check_circle_rounded : Icons.error_rounded),
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 12.5, color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


