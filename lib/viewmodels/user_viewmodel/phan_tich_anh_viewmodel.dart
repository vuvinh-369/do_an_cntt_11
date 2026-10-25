import '../../models/user_model.dart';
import 'dieu_huong_co_so_viewmodel.dart';

mixin PhanTichAnhViewModel on DieuHuongCoSoViewModel {
  // Cấu hình văn bản chuẩn theo thiết kế màn hình "Phân tích hình ảnh tổn thương" (Màn hình 2)
  final AiUploadSpecModel uploadSpec = const AiUploadSpecModel(
    screenTitle: 'Phân tích hình ảnh tổn thương',
    dropzonePrefixText: 'Kéo thả ảnh vào đây hoặc ',
    dropzoneActionText: 'chọn ảnh',
    supportedFormatsText: 'Hỗ trợ: JPG, PNG, WEBP (tối đa 10MB)',
    selectButtonLabel: 'Chọn ảnh',
    dividerText: 'Hoặc chụp ảnh',
    cameraButtonLabel: 'Chụp ảnh bằng camera',
    noticeBoldText:
        'Lưu ý: Hệ thống chỉ hỗ trợ phân tích các vết thương ngoài da.',
    noticeDetailText: 'Nếu kết quả không đủ độ tin cậy, chúng tôi sẽ không tự động đưa ra hướng dẫn sơ cứu.',
  );

  void onSelectImageFromFilePressed() {
    navigateToAnalysisResult(imageSourceName: 'selected_arm_abrasion.jpg');
  }

  void onCaptureFromCameraPressed() {
    navigateToAnalysisResult(imageSourceName: 'camera_capture_abrasion.jpg');
  }
}
