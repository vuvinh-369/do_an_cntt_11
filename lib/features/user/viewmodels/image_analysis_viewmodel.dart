import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../core/ai_server_manager.dart';
import '../models/image_analysis_models.dart';
import 'analysis_result_viewmodel.dart';
import 'user_navigation_viewmodel.dart';

mixin PhanTichAnhViewModel
    on DieuHuongCoSoViewModel, KetQuaPhanTichViewModel {
  // Cấu hình văn bản chuẩn theo giao diện
  final AiUploadSpecModel uploadSpec = const AiUploadSpecModel(
    screenTitle: 'Phân tích hình ảnh tổn thương',
    dropzonePrefixText: 'Kéo thả ảnh vào đây, ',
    dropzoneActionText: 'chọn ảnh hoặc dán ảnh (Ctrl+V)',
    supportedFormatsText: 'Hỗ trợ: JPG, PNG, WEBP (tối đa 10MB)',
    selectButtonLabel: 'Chọn ảnh từ máy',
    dividerText: 'Hoặc chụp ảnh trực tiếp',
    cameraButtonLabel: 'Chụp ảnh bằng Camera',
    noticeBoldText:
        'Lưu ý: Hệ thống chỉ hỗ trợ phân tích các vết thương ngoài da.',
    noticeDetailText:
        'Model YOLO AI sẽ quét và tự động nhận diện: Trầy xước, Vết cắt, Bỏng, Bầm tím.',
  );

  // Trạng thái ảnh đang được nạp chờ quét (Staged image)
  Uint8List? _stagedImageBytes;
  Uint8List? get stagedImageBytes => _stagedImageBytes;

  String? _stagedImageName;
  String? get stagedImageName => _stagedImageName;

  bool get hasStagedImage => _stagedImageBytes != null && _stagedImageBytes!.isNotEmpty;

  // Trạng thái đang quét AI & tiến trình Progress bar
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  double _analysisProgress = 0.0;
  double get analysisProgress => _analysisProgress;

  String _analysisStatusMessage = 'Đang chuẩn bị...';
  String get analysisStatusMessage => _analysisStatusMessage;

  // Hệ số độ tương phản hiện tại (1.0 là gốc)
  double _appliedContrast = 1.0;
  double get appliedContrast => _appliedContrast;

  // 3 Checkbox tình trạng quan sát kèm theo khi quét vết thương:
  bool _hasForeignBody = false; // Có dị vật cắm vào vết thương
  bool get hasForeignBody => _hasForeignBody;

  bool _isBleeding = false; // Đang chảy máu nhiều / liên tục
  bool get isBleeding => _isBleeding;

  bool _hasPusOrInfection = false; // Chảy mủ / Sưng đỏ tấy (nhiễm trùng)
  bool get hasPusOrInfection => _hasPusOrInfection;

  void toggleHasForeignBody(bool? val) {
    _hasForeignBody = val ?? false;
    notifyListeners();
  }

  void toggleIsBleeding(bool? val) {
    _isBleeding = val ?? false;
    notifyListeners();
  }

  void toggleHasPusOrInfection(bool? val) {
    _hasPusOrInfection = val ?? false;
    notifyListeners();
  }

  void resetWoundCheckboxes() {
    _hasForeignBody = false;
    _isBleeding = false;
    _hasPusOrInfection = false;
    notifyListeners();
  }

  // Ảnh thực tế lần quét gần nhất
  Uint8List? _lastSelectedImageBytes;
  Uint8List? get lastSelectedImageBytes => _lastSelectedImageBytes;

  String? _lastSelectedImageName;
  String? get lastSelectedImageName => _lastSelectedImageName;

  /// Địa chỉ Backend AI FastAPI (mặc định localhost cổng 8000)
  static const String aiServerUrl = 'http://127.0.0.1:8000';

  /// Mở hộp thoại chọn ảnh từ thiết bị (chỉ nạp ảnh vào trạng thái chờ, chưa quét ngay)
  Future<void> pickAndStageImage(BuildContext context) async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );

      if (files.isEmpty) {
        return;
      }

      final file = files.first;
      Uint8List? imageBytes;
      if (file.path != null && file.path!.isNotEmpty) {
        final f = File(file.path!);
        if (await f.exists()) {
          imageBytes = await f.readAsBytes();
        }
      }
      imageBytes ??= await file.readAsBytes();
      final fileName = file.name;

      if (imageBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể đọc dữ liệu từ tệp ảnh này.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      _stagedImageBytes = imageBytes;
      _stagedImageName = fileName;
      _lastSelectedImageBytes = imageBytes;
      _lastSelectedImageName = fileName;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Đã nạp ảnh "$fileName". Nhấn "Bắt đầu quét AI" để phân tích!')),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xảy ra lỗi khi chọn ảnh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Dán ảnh trực tiếp từ Clipboard (hỗ trợ cả sao chép pixel ảnh và sao chép file ảnh từ File Explorer)
  Future<void> pasteAndStageImage(BuildContext context) async {
    try {
      Uint8List? imageBytes = await Pasteboard.image;
      String fileName = 'clipboard_${DateTime.now().millisecondsSinceEpoch}.png';

      // Nếu không có pixel ảnh trực tiếp, kiểm tra xem người dùng có sao chép tệp ảnh từ Windows Explorer không
      if (imageBytes == null || imageBytes.isEmpty) {
        try {
          final files = await Pasteboard.files();
          if (files.isNotEmpty) {
            final firstFilePath = files.first;
            final ext = firstFilePath.split('.').last.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext)) {
              final f = File(firstFilePath);
              if (await f.exists()) {
                imageBytes = await f.readAsBytes();
                fileName = firstFilePath.split(RegExp(r'[\\/]')).last;
              }
            }
          }
        } catch (_) {}
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clipboard chưa có hình ảnh. Bạn có thể sao chép (Copy) ảnh hoặc file ảnh rồi nhấn Ctrl+V để dán!',
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFFD97706),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Xác định định dạng thật của ảnh từ magic bytes
      if (imageBytes.length >= 4) {
        if (imageBytes[0] == 0x42 && imageBytes[1] == 0x4D && !fileName.toLowerCase().endsWith('.bmp')) {
          fileName = 'clipboard_${DateTime.now().millisecondsSinceEpoch}.bmp';
        } else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8 && !fileName.toLowerCase().endsWith('.jpg') && !fileName.toLowerCase().endsWith('.jpeg')) {
          fileName = 'clipboard_${DateTime.now().millisecondsSinceEpoch}.jpg';
        } else if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50 && !fileName.toLowerCase().endsWith('.png')) {
          fileName = 'clipboard_${DateTime.now().millisecondsSinceEpoch}.png';
        }
      }

      _stagedImageBytes = imageBytes;
      _stagedImageName = fileName;
      _lastSelectedImageBytes = imageBytes;
      _lastSelectedImageName = fileName;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Đã dán ảnh "$fileName" thành công! Nhấn "Bắt đầu quét AI" để phân tích.')),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi đọc ảnh từ Clipboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Chụp ảnh hoặc chọn ảnh trực tiếp từ Camera thiết bị (tối ưu cho Web mobile, Android, iOS)
  Future<void> captureImageFromCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 92,
      );

      if (photo == null) {
        return;
      }

      final imageBytes = await photo.readAsBytes();
      if (imageBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể đọc dữ liệu ảnh từ Camera.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final fileName = photo.name.isNotEmpty
          ? photo.name
          : 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';

      _stagedImageBytes = imageBytes;
      _stagedImageName = fileName;
      _lastSelectedImageBytes = imageBytes;
      _lastSelectedImageName = fileName;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Đã chụp ảnh từ Camera thành công! Nhấn "Bắt đầu quét AI" để phân tích.')),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở camera trên thiết bị này: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Hủy ảnh đang chờ quét để chọn ảnh khác
  void clearStagedImage() {
    _stagedImageBytes = null;
    _stagedImageName = null;
    resetWoundCheckboxes();
    notifyListeners();
  }

  /// Bắt đầu quét phân tích ảnh bằng mô hình YOLO, kèm thanh tiến trình chạy mượt mà
  Future<void> startAnalysis(
    BuildContext context, {
    double contrast = 1.0,
  }) async {
    final imageBytes = _stagedImageBytes ?? _lastSelectedImageBytes;
    final fileName = _stagedImageName ?? _lastSelectedImageName ?? 'image.jpg';

    if (imageBytes == null || imageBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn hoặc dán ảnh trước khi bắt đầu quét!'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    _lastSelectedImageBytes = imageBytes;
    _lastSelectedImageName = fileName;
    _appliedContrast = contrast;

    // 1. Kích hoạt trạng thái quét và bắt đầu progress bar
    _isAnalyzing = true;
    _analysisProgress = 0.10;
    _analysisStatusMessage = contrast != 1.0
        ? 'Đang chuẩn bị quét lại (Độ tương phản x${contrast.toStringAsFixed(1)})...'
        : 'Đang kiểm tra kết nối mô hình YOLO AI...';
    notifyListeners();

    Timer? progressTimer;
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!_isAnalyzing) {
        timer.cancel();
        return;
      }
      if (_analysisProgress < 0.85) {
        _analysisProgress += 0.08;
        if (_analysisProgress >= 0.35 && _analysisProgress < 0.65) {
          _analysisStatusMessage = contrast != 1.0
              ? 'Đang áp dụng bộ lọc tăng cường tương phản x${contrast.toStringAsFixed(1)}...'
              : 'Đang tải dữ liệu ảnh lên mô hình AI...';
        } else if (_analysisProgress >= 0.65) {
          _analysisStatusMessage = 'Mô hình YOLO đang nhận diện và khoanh vùng tổn thương...';
        }
        notifyListeners();
      }
    });

    try {
      // 2. Tự động kiểm tra / khởi động AI Server ngầm nếu chưa bật
      if (!await AiServerManager.checkServerHealth()) {
        _analysisStatusMessage = 'Đang tự khởi động mô hình AI YOLO ngầm...';
        notifyListeners();
        await AiServerManager.ensureServerRunning();
      }

      // Xác định định dạng ảnh và MediaType chuẩn xác
      String ext = 'jpg';
      MediaType mimeType = MediaType('image', 'jpeg');
      if (imageBytes.length >= 4) {
        if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50 && imageBytes[2] == 0x4E && imageBytes[3] == 0x47) {
          ext = 'png';
          mimeType = MediaType('image', 'png');
        } else if (imageBytes[0] == 0x42 && imageBytes[1] == 0x4D) {
          ext = 'bmp';
          mimeType = MediaType('image', 'bmp');
        } else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
          ext = 'jpg';
          mimeType = MediaType('image', 'jpeg');
        } else if (imageBytes.length >= 12 &&
            imageBytes[0] == 0x52 && imageBytes[1] == 0x49 && imageBytes[2] == 0x46 && imageBytes[3] == 0x46) {
          ext = 'webp';
          mimeType = MediaType('image', 'webp');
        }
      }

      final String safeUploadFileName = fileName.contains('.') ? fileName : '$fileName.$ext';

      // 3. Gửi Multipart Request lên Python FastAPI Server
      final predictUri = Uri.parse('$aiServerUrl/predict');
      final request = http.MultipartRequest('POST', predictUri)
        ..fields['contrast'] = contrast.toString()
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename: safeUploadFileName,
            contentType: mimeType,
          ),
        );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
      );

      final responseBody = await streamedResponse.stream.bytesToString();
      progressTimer.cancel();

      if (streamedResponse.statusCode == 200) {
        _analysisProgress = 1.0;
        _analysisStatusMessage = 'Phân tích hoàn tất!';
        notifyListeners();

        // 4. Phân tích kết quả thực tế từ model YOLO trả về
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final bool isDetected = data['detected'] as bool? ?? false;
        final String injuryType = data['injury_type'] as String? ?? 'Chưa xác định';
        final int confidence = (data['confidence_percent'] as num?)?.toInt() ?? 0;
        final String topicId = data['topic_id'] as String? ?? 'abrasion';
        final String message = data['message'] as String? ?? '';

        List<double>? boxCoords;
        if (data['box'] != null && data['box'] is List) {
          boxCoords = (data['box'] as List).map((e) => (e as num).toDouble()).toList();
        }

        final double? imgW = (data['image_width'] as num?)?.toDouble();
        final double? imgH = (data['image_height'] as num?)?.toDouble();

        // 5. Cập nhật Model Kết quả phân tích thật
        final realResult = AiAnalysisResultModel(
          bannerTitle: isDetected
              ? (contrast != 1.0 ? 'Kết quả quét lại (Tương phản x${contrast.toStringAsFixed(1)})' : 'Kết quả phân tích AI')
              : 'Không tìm thấy tổn thương rõ ràng',
          confidencePercent: confidence,
          injuryType: injuryType,
          boundingBoxLabel: isDetected ? '$injuryType $confidence%' : 'Không có vết thương',
          infoCardTitle: 'Thông tin nhận diện AI',
          injuryTypeLabel: 'Loại tổn thương:',
          confidenceRowLabel: 'Độ tin cậy:',
          locationRowLabel: 'Vị trí:',
          bottomNoticeText: isDetected
              ? 'Mô hình YOLO đã nhận diện thành công vết thương trên ảnh. Bạn có thể chọn vị trí cơ thể và xem hướng dẫn sơ cứu.'
              : 'Mô hình YOLO không phát hiện thấy vết thương ngoài da rõ ràng. Nếu bạn đang đau, hãy xem các mục sơ cứu khẩn cấp hoặc chọn thủ công bên dưới.',
          primaryActionLabel: isDetected ? 'Xem hướng dẫn sơ cứu' : 'Tra cứu sơ cứu chung',
          rawImageBytes: imageBytes,
          imageFileName: fileName,
          detectedTopicId: topicId,
          isDetected: isDetected,
          boundingBox: boxCoords,
          originalImageWidth: imgW,
          originalImageHeight: imgH,
          detectionMessage: message,
          appliedContrast: contrast,
        );

        setAnalysisResult(realResult);

        // Chờ 300ms để người dùng thấy progress đạt 100%
        await Future.delayed(const Duration(milliseconds: 300));
        _isAnalyzing = false;
        _stagedImageBytes = null; // Reset staging sau khi phân tích xong
        _stagedImageName = null;
        notifyListeners();

        // Ghi lại lịch sử phân tích trong RAM
        onNewAnalysisRecorded(
          imageSourceName: fileName,
          injuryType: isDetected ? injuryType : 'Không phát hiện tổn thương rõ ràng',
          confidencePercent: isDetected ? confidence : null,
          locationLabel: 'Cánh tay',
          topicId: topicId,
          rawImageBytes: imageBytes,
        );

        // Đồng bộ 3 checkbox lâm sàng sang Rule Engine
        updateInjuryContext(
          topicId: topicId,
          injuryTypeName: injuryType,
          locationId: 'arm',
          confidencePercent: confidence,
        );
        toggleWarningSymptom(
          hasDeepWoundOrForeignBody: _hasForeignBody,
          isBleedingHeavy: _isBleeding,
          hasSignsOfInfection: _hasPusOrInfection,
        );

        // Chuyển sang màn hình Kết quả phân tích
        navigateToAnalysisResult(imageSourceName: fileName);
      } else {
        _isAnalyzing = false;
        notifyListeners();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi từ AI Server (${streamedResponse.statusCode}): $responseBody'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (networkError) {
      progressTimer.cancel();
      _isAnalyzing = false;
      notifyListeners();

      if (context.mounted) {
        _showServerUnavailableDialog(context, fileName, imageBytes);
      }
    }
  }

  /// Quét lại hình ảnh với độ tương phản thay đổi (contrast enhancement)
  Future<void> reScanWithContrast(BuildContext context, {double newContrast = 1.35}) async {
    await startAnalysis(context, contrast: newContrast);
  }

  /// Hiển thị hộp thoại hướng dẫn nếu người dùng chưa kết nối Python AI Server
  void _showServerUnavailableDialog(
    BuildContext context,
    String fileName,
    Uint8List imageBytes,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 28),
            SizedBox(width: 10),
            Text('Chưa kết nối AI Server'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ứng dụng đã nhận được ảnh thật của bạn, nhưng chưa thể kết nối tới server AI cục bộ tại:',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'http://127.0.0.1:8000/predict',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tiến trình ngầm đang khởi động lại. Bạn cũng có thể mở terminal và chạy lệnh:\n',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'python lib/AI_Model/server.py',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final fallbackResult = AiAnalysisResultModel(
                bannerTitle: 'Ảnh đã chọn (Chưa có kết nối AI)',
                confidencePercent: 0,
                injuryType: 'Chưa phân tích (Server offline)',
                boundingBoxLabel: 'Chờ bật server',
                infoCardTitle: 'Thông tin tệp ảnh',
                injuryTypeLabel: 'Trạng thái:',
                confidenceRowLabel: 'Kết nối:',
                bottomNoticeText:
                    'Vui lòng khởi động backend python lib/AI_Model/server.py để mô hình YOLO quét nhận diện vết thương trên bức ảnh này.',
                primaryActionLabel: 'Tra cứu sơ cứu',
                rawImageBytes: imageBytes,
                imageFileName: fileName,
                detectedTopicId: 'abrasion',
                isDetected: false,
              );
              setAnalysisResult(fallbackResult);
              navigateToAnalysisResult(imageSourceName: fileName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xem ảnh đã chọn'),
          ),
        ],
      ),
    );
  }

  void onSelectImageFromFilePressed(BuildContext context) {
    pickAndStageImage(context);
  }

  void onCaptureFromCameraPressed(BuildContext context) {
    captureImageFromCamera(context);
  }

  void onPasteImagePressed(BuildContext context) {
    pasteAndStageImage(context);
  }
}
