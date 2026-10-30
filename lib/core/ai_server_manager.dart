import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Quản lý tiến trình AI Server ngầm
/// Tự động khởi động mô hình YOLO khi chạy ứng dụng Flutter (chạy ngầm 100%, không hiện cửa sổ terminal)
class AiServerManager {
  static const String serverUrl = 'http://127.0.0.1:8000';
  static Process? _serverProcess;

  /// Tự động kiểm tra và khởi động AI server ngầm nếu chưa chạy
  static Future<void> ensureServerRunning() async {
    // Chỉ chạy ngầm trên nền tảng Desktop (Windows, macOS, Linux)
    if (kIsWeb || (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
      return;
    }

    try {
      // 1. Kiểm tra xem server đã hoạt động từ trước hay chưa
      final isAlive = await checkServerHealth();
      if (isAlive) {
        debugPrint('[AiServerManager] AI Server đã hoạt động sẵn sàng tại $serverUrl.');
        return;
      }

      // 2. Tìm file server.py trong thư mục dự án
      final currentDir = Directory.current.path;
      final serverPath = '$currentDir/lib/AI_Model/server.py';

      if (!File(serverPath).existsSync()) {
        debugPrint('[AiServerManager] Không tìm thấy file $serverPath');
        return;
      }

      // 3. Ưu tiên sử dụng pythonw.exe (Windowed Python - KHÔNG HIỆN CỬA SỔ CONSOLE ĐEN)
      String pythonExecutable = 'pythonw';
      final venvPythonwWindows = '$currentDir\\.venv\\Scripts\\pythonw.exe';
      final venvPythonWindows = '$currentDir\\.venv\\Scripts\\python.exe';
      final venvPythonUnix = '$currentDir/.venv/bin/python';

      if (Platform.isWindows) {
        if (File(venvPythonwWindows).existsSync()) {
          // pythonw.exe là phiên bản GUI subsystem của Python trên Windows, không bao giờ mở cửa sổ console màu đen!
          pythonExecutable = venvPythonwWindows;
        } else if (File(venvPythonWindows).existsSync()) {
          pythonExecutable = venvPythonWindows;
        }
      } else if (File(venvPythonUnix).existsSync()) {
        pythonExecutable = venvPythonUnix;
      }

      debugPrint('[AiServerManager] Đang tự động khởi chạy YOLO AI Server ngầm bằng: $pythonExecutable ...');

      // 4. Khởi động tiến trình ngầm (detached) hoàn toàn không hiện cửa sổ
      _serverProcess = await Process.start(
        pythonExecutable,
        [serverPath],
        mode: ProcessStartMode.detached,
        workingDirectory: '$currentDir/lib/AI_Model',
      );

      debugPrint('[AiServerManager] Tiến trình AI Server ngầm đã tạo (PID: ${_serverProcess?.pid}).');

      // 5. Chờ 2 - 3 giây để server hoàn tất load model vào RAM
      for (int i = 0; i < 8; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await checkServerHealth()) {
          debugPrint('[AiServerManager] Kết nối AI Server thành công!');
          break;
        }
      }
    } catch (e) {
      debugPrint('[AiServerManager] Không thể tự động khởi động AI Server: $e');
    }
  }

  /// Kiểm tra endpoint GET /
  static Future<bool> checkServerHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/'))
          .timeout(const Duration(milliseconds: 700));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
