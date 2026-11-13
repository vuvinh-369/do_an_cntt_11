// File: lib/core/storage/local_storage_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dịch vụ lưu trữ cục bộ SharedPreferences (Hỗ trợ 100% cả Windows Desktop và Flutter Web)
/// Quản lý ghi nhớ đăng nhập cho cả Quản trị viên (/admin) và Người dùng
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  // Keys cho Admin
  static const String _keyAdminRemember = 'auth_admin_remember_me';
  static const String _keyAdminUsername = 'auth_admin_saved_username';
  static const String _keyAdminPassword = 'auth_admin_saved_password';
  static const String _keyAdminIsLoggedIn = 'auth_admin_is_logged_in';

  // Keys cho Người dùng
  static const String _keyUserRemember = 'auth_user_remember_me';
  static const String _keyUserUsername = 'auth_user_saved_username';
  static const String _keyUserPassword = 'auth_user_saved_password';
  static const String _keyUserIsLoggedIn = 'auth_user_is_logged_in';

  // Keys cho Bác sĩ (Doctor Portal / Workspace)
  static const String _keyDoctorUsername = 'auth_doctor_saved_username';
  static const String _keyDoctorId = 'auth_doctor_saved_id';
  static const String _keyDoctorIsLoggedIn = 'auth_doctor_is_logged_in';

  // Keys cho lưu trữ bền vững tài khoản Bác sĩ & Liên kết hồ sơ (Yêu cầu R1)
  static const String _keyProvisionedDoctorAccounts = 'auth_provisioned_doctor_accounts_json';
  static const String _keyDoctorAccountLinks = 'auth_doctor_account_links_json';

  // Keys cho lưu trữ lịch sử tin nhắn & danh sách hội thoại trình duyệt (Yêu cầu R2)
  static const String _keyChatMessagesPrefix = 'chat_messages_';
  static const String _keyConversationsQueue = 'chat_conversations_queue';
  static const String _keyGuestSessionId = 'auth_guest_session_id';

  SharedPreferences? _cachedPrefs;
  String? _cachedDoctorUsername;
  String? _cachedDoctorId;
  bool _cachedDoctorIsLoggedIn = false;
  List<Map<String, dynamic>>? _cachedProvisionedAccounts;
  Map<String, String>? _cachedDoctorAccountLinks;
  String? _cachedGuestSessionId;

  // ===========================================================================
  // QUẢN LÝ GHI NHỚ ĐĂNG NHẬP ADMIN (/admin)
  // ===========================================================================

  /// Lưu thông tin tài khoản Admin khi đăng nhập thành công
  Future<void> saveAdminCredentials({
    required bool rememberMe,
    required String username,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAdminRemember, rememberMe);
      if (rememberMe) {
        await prefs.setString(_keyAdminUsername, username);
        await prefs.setString(_keyAdminPassword, password);
        await prefs.setBool(_keyAdminIsLoggedIn, true);
        debugPrint('[LocalStorage] Đã ghi nhớ tài khoản Admin: $username');
      } else {
        await prefs.remove(_keyAdminUsername);
        await prefs.remove(_keyAdminPassword);
        await prefs.setBool(_keyAdminIsLoggedIn, false);
        debugPrint('[LocalStorage] Đã xóa ghi nhớ tài khoản Admin');
      }
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi lưu thông tin Admin: $e');
    }
  }

  /// Nạp thông tin tài khoản Admin đã ghi nhớ (dùng để tự điền form)
  Future<Map<String, dynamic>> loadAdminCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyAdminRemember) ?? true;
      final username = prefs.getString(_keyAdminUsername) ?? '';
      final password = prefs.getString(_keyAdminPassword) ?? '';
      final isLoggedIn = prefs.getBool(_keyAdminIsLoggedIn) ?? false;

      return {
        'rememberMe': rememberMe,
        'username': username,
        'password': password,
        'isLoggedIn': isLoggedIn,
      };
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi đọc thông tin Admin: $e');
      return {
        'rememberMe': true,
        'username': '',
        'password': '',
        'isLoggedIn': false,
      };
    }
  }

  /// Đăng xuất và xóa phiên đăng nhập Admin
  Future<void> clearAdminSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAdminIsLoggedIn, false);
      // Giữ lại username/password nếu rememberMe đang bật, hoặc xóa hẳn nếu uncheck
      final rememberMe = prefs.getBool(_keyAdminRemember) ?? false;
      if (!rememberMe) {
        await prefs.remove(_keyAdminUsername);
        await prefs.remove(_keyAdminPassword);
      }
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi xóa phiên Admin: $e');
    }
  }

  // ===========================================================================
  // QUẢN LÝ GHI NHỚ ĐĂNG NHẬP NGƯỜI DÙNG (USER APP)
  // ===========================================================================

  /// Lưu thông tin tài khoản Người dùng khi đăng nhập
  Future<void> saveUserCredentials({
    required bool rememberMe,
    required String username,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyUserRemember, rememberMe);
      if (rememberMe) {
        await prefs.setString(_keyUserUsername, username);
        await prefs.setString(_keyUserPassword, password);
        await prefs.setBool(_keyUserIsLoggedIn, true);
        debugPrint('[LocalStorage] Đã ghi nhớ tài khoản người dùng: $username');
      } else {
        await prefs.remove(_keyUserUsername);
        await prefs.remove(_keyUserPassword);
        await prefs.setBool(_keyUserIsLoggedIn, false);
        debugPrint('[LocalStorage] Đã xóa ghi nhớ tài khoản người dùng');
      }
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi lưu thông tin người dùng: $e');
    }
  }

  /// Nạp thông tin tài khoản Người dùng đã ghi nhớ
  Future<Map<String, dynamic>> loadUserCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyUserRemember) ?? true;
      final username = prefs.getString(_keyUserUsername) ?? '';
      final password = prefs.getString(_keyUserPassword) ?? '';
      final isLoggedIn = prefs.getBool(_keyUserIsLoggedIn) ?? false;

      return {
        'rememberMe': rememberMe,
        'username': username,
        'password': password,
        'isLoggedIn': isLoggedIn,
      };
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi đọc thông tin người dùng: $e');
      return {
        'rememberMe': true,
        'username': '',
        'password': '',
        'isLoggedIn': false,
      };
    }
  }

  /// Đăng xuất tài khoản người dùng
  Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyUserIsLoggedIn, false);
      final rememberMe = prefs.getBool(_keyUserRemember) ?? false;
      if (!rememberMe) {
        await prefs.remove(_keyUserUsername);
        await prefs.remove(_keyUserPassword);
      }
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi xóa phiên người dùng: $e');
    }
  }

  // ===========================================================================
  // QUẢN LÝ PHIÊN ĐĂNG NHẬP BÁC SĨ (DOCTOR SESSION)
  // ===========================================================================

  /// Lưu phiên đăng nhập Bác sĩ khi xác thực thành công
  Future<void> saveDoctorSession({
    required String username,
    required String doctorId,
  }) async {
    _cachedDoctorUsername = username;
    _cachedDoctorId = doctorId;
    _cachedDoctorIsLoggedIn = true;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setString(_keyDoctorUsername, username);
      await prefs.setString(_keyDoctorId, doctorId);
      await prefs.setBool(_keyDoctorIsLoggedIn, true);
      debugPrint('[LocalStorage] Đã lưu phiên Bác sĩ: @$username (ID: $doctorId)');
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi lưu phiên Bác sĩ: $e');
    }
  }

  /// Tải thông tin phiên đăng nhập Bác sĩ đã lưu từ SharedPreferences
  Future<void> loadDoctorSession() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      _cachedDoctorUsername = prefs.getString(_keyDoctorUsername);
      _cachedDoctorId = prefs.getString(_keyDoctorId);
      _cachedDoctorIsLoggedIn = prefs.getBool(_keyDoctorIsLoggedIn) ?? false;
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi đọc phiên Bác sĩ: $e');
    }
  }

  /// Lấy username Bác sĩ đã lưu/đang đăng nhập
  String? getDoctorSavedUsername() {
    return _cachedDoctorUsername ?? _cachedPrefs?.getString(_keyDoctorUsername);
  }

  /// Lấy ID hồ sơ Bác sĩ đã lưu/đang đăng nhập
  String? getDoctorSavedId() {
    return _cachedDoctorId ?? _cachedPrefs?.getString(_keyDoctorId);
  }

  /// Kiểm tra xem Bác sĩ có đang trong trạng thái đăng nhập hay không
  bool isDoctorLoggedIn() {
    return _cachedDoctorIsLoggedIn || (_cachedPrefs?.getBool(_keyDoctorIsLoggedIn) ?? false);
  }

  /// Đăng xuất và xóa phiên làm việc của Bác sĩ
  Future<void> clearDoctorSession() async {
    _cachedDoctorUsername = null;
    _cachedDoctorId = null;
    _cachedDoctorIsLoggedIn = false;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setBool(_keyDoctorIsLoggedIn, false);
      await prefs.remove(_keyDoctorUsername);
      await prefs.remove(_keyDoctorId);
      debugPrint('[LocalStorage] Đã xóa phiên đăng nhập Bác sĩ');
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi xóa phiên Bác sĩ: $e');
    }
  }

  // ===========================================================================
  // LƯU TRỮ BỀN VỮNG TÀI KHOẢN BÁC SĨ & ÁNH XẠ LIÊN KẾT (YÊU CẦU R1)
  // ===========================================================================

  /// Lưu danh sách toàn bộ tài khoản bác sĩ đã cấp phát vào SharedPreferences
  Future<void> saveProvisionedDoctorAccounts(
    List<Map<String, dynamic>> accountsMap,
  ) async {
    _cachedProvisionedAccounts = List<Map<String, dynamic>>.from(accountsMap);
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final jsonStr = jsonEncode(accountsMap);
      await prefs.setString(_keyProvisionedDoctorAccounts, jsonStr);
      debugPrint(
        '[LocalStorage] Đã lưu bền vững ${accountsMap.length} tài khoản Bác sĩ.',
      );
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi lưu provisioned doctor accounts: $e');
    }
  }

  /// Lưu hoặc cập nhật một tài khoản bác sĩ vào SharedPreferences
  Future<void> saveDoctorAccount(Map<String, dynamic> accountMap) async {
    final currentList = await loadProvisionedDoctorAccounts();
    final username = (accountMap['username'] as String? ?? '').trim().toLowerCase();
    final idx = currentList.indexWhere(
      (acc) => (acc['username'] as String? ?? '').trim().toLowerCase() == username,
    );
    if (idx != -1) {
      currentList[idx] = Map<String, dynamic>.from(accountMap);
    } else {
      currentList.insert(0, Map<String, dynamic>.from(accountMap));
    }
    await saveProvisionedDoctorAccounts(currentList);
  }

  /// Nạp danh sách tài khoản bác sĩ đã cấp phát từ SharedPreferences
  Future<List<Map<String, dynamic>>> loadProvisionedDoctorAccounts() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final raw = prefs.getString(_keyProvisionedDoctorAccounts);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final list = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _cachedProvisionedAccounts = list;
          return list;
        }
      }
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi nạp provisioned doctor accounts: $e');
    }
    return _cachedProvisionedAccounts ?? [];
  }

  /// Lấy danh sách tài khoản bác sĩ từ bộ nhớ đệm
  List<Map<String, dynamic>>? getCachedProvisionedDoctorAccounts() {
    return _cachedProvisionedAccounts;
  }

  /// Lưu bảng ánh xạ liên kết doctorId -> username vào SharedPreferences
  Future<void> saveDoctorAccountLinks(Map<String, String> linksMap) async {
    _cachedDoctorAccountLinks = Map<String, String>.from(linksMap);
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final jsonStr = jsonEncode(linksMap);
      await prefs.setString(_keyDoctorAccountLinks, jsonStr);
      debugPrint(
        '[LocalStorage] Đã lưu bền vững ${linksMap.length} liên kết tài khoản bác sĩ.',
      );
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi lưu doctor account links: $e');
    }
  }

  /// Lưu hoặc cập nhật một liên kết doctorId -> username vào SharedPreferences
  Future<void> saveDoctorAccountLink(String doctorId, String username) async {
    final currentLinks = await loadDoctorAccountLinks();
    currentLinks[doctorId] = username.trim();
    await saveDoctorAccountLinks(currentLinks);
  }

  /// Nạp bảng ánh xạ liên kết doctorId -> username từ SharedPreferences
  Future<Map<String, String>> loadDoctorAccountLinks() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final raw = prefs.getString(_keyDoctorAccountLinks);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = <String, String>{};
          decoded.forEach((key, value) {
            if (key != null && value != null) {
              map[key.toString()] = value.toString();
            }
          });
          _cachedDoctorAccountLinks = map;
          return map;
        }
      }
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi nạp doctor account links: $e');
    }
    return _cachedDoctorAccountLinks ?? {};
  }

  /// Lấy bảng ánh xạ liên kết từ bộ nhớ đệm
  Map<String, String>? getCachedDoctorAccountLinks() {
    return _cachedDoctorAccountLinks;
  }

  /// Xóa toàn bộ dữ liệu tài khoản bác sĩ đã lưu (phục vụ test hoặc reset)
  Future<void> clearProvisionedDoctorData() async {
    _cachedProvisionedAccounts = null;
    _cachedDoctorAccountLinks = null;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.remove(_keyProvisionedDoctorAccounts);
      await prefs.remove(_keyDoctorAccountLinks);
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi xóa dữ liệu provisioned doctor: $e');
    }
  }

  // ===========================================================================
  // QUẢN LÝ LƯU TRỮ TRÌNH DUYỆT: TIN NHẮN, DANH SÁCH HỘI THOẠI & PHIÊN KHÁCH (YÊU CẦU R2)
  // ===========================================================================

  /// Lấy hoặc khởi tạo ID phiên bền vững cho khách vãng lai (Guest UUID)
  Future<String> getOrCreateGuestSessionId() async {
    if (_cachedGuestSessionId != null && _cachedGuestSessionId!.isNotEmpty) {
      return _cachedGuestSessionId!;
    }
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      String? guestId = prefs.getString(_keyGuestSessionId);
      if (guestId == null || guestId.trim().isEmpty) {
        final randNum = math.Random().nextInt(900000) + 100000;
        guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}_$randNum';
        await prefs.setString(_keyGuestSessionId, guestId);
        debugPrint('[LocalStorage] Đã tạo phiên khách vãng lai mới: $guestId');
      }
      _cachedGuestSessionId = guestId;
      return guestId;
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi tạo phiên khách: $e');
      final fallbackId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      _cachedGuestSessionId = fallbackId;
      return fallbackId;
    }
  }

  /// Lấy nhanh ID phiên khách vãng lai từ bộ nhớ cache nếu đã nạp
  String? getCachedGuestSessionId() {
    return _cachedGuestSessionId ?? _cachedPrefs?.getString(_keyGuestSessionId);
  }

  /// Lưu lịch sử tin nhắn của một cuộc hội thoại vào SharedPreferences (giới hạn 100 tin gần nhất)
  Future<void> saveConversationMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      // Giới hạn 100 tin nhắn gần nhất để tối ưu dung lượng LocalStorage trình duyệt (5MB quota)
      final truncated = messages.length > 100
          ? messages.sublist(messages.length - 100)
          : messages;
      final jsonStr = jsonEncode(truncated);
      await prefs.setString('$_keyChatMessagesPrefix$conversationId', jsonStr);
      debugPrint('[LocalStorage] Đã lưu ${truncated.length} tin nhắn cho hội thoại $conversationId');
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi lưu tin nhắn hội thoại $conversationId: $e');
    }
  }

  /// Nạp lịch sử tin nhắn của một cuộc hội thoại từ SharedPreferences
  Future<List<Map<String, dynamic>>> loadConversationMessages(
    String conversationId,
  ) async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final raw = prefs.getString('$_keyChatMessagesPrefix$conversationId');
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi nạp tin nhắn hội thoại $conversationId: $e');
    }
    return [];
  }

  /// Lưu danh sách các cuộc hội thoại trong hàng đợi bác sĩ / người dùng vào SharedPreferences
  Future<void> saveConversationQueue(
    List<Map<String, dynamic>> queueList,
  ) async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final jsonStr = jsonEncode(queueList);
      await prefs.setString(_keyConversationsQueue, jsonStr);
      debugPrint('[LocalStorage] Đã lưu ${queueList.length} cuộc hội thoại vào queue cache');
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi lưu queue hội thoại: $e');
    }
  }

  /// Nạp danh sách các cuộc hội thoại trong hàng đợi từ SharedPreferences
  Future<List<Map<String, dynamic>>> loadConversationQueue() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final raw = prefs.getString(_keyConversationsQueue);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi nạp queue hội thoại: $e');
    }
    return [];
  }

  /// Xóa bộ nhớ đệm tin nhắn và hàng đợi hội thoại (phục vụ test hoặc dọn dẹp)
  Future<void> clearChatCache() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.remove(_keyConversationsQueue);
      final keys = prefs.getKeys().where((k) => k.startsWith(_keyChatMessagesPrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
      debugPrint('[LocalStorage] Đã dọn dẹp bộ nhớ đệm chat cache');
    } catch (e) {
      debugPrint('[LocalStorage] Lỗi dọn dẹp chat cache: $e');
    }
  }
}
