import 'package:flutter/material.dart';

import '../models/image_analysis_models.dart';
import 'user_navigation_viewmodel.dart';

mixin KetQuaPhanTichViewModel on DieuHuongCoSoViewModel {
  // Trạng thái vị trí tổn thương đang được chọn trên Màn hình 3 (Mặc định: 'arm' -> 'Cánh tay')
  String _selectedLocationId = 'arm';
  String get selectedLocationId => _selectedLocationId;

  // Cấu hình dữ liệu chuẩn theo thiết kế Màn hình 3: "Kết quả phân tích (Người dùng)"
  final AiAnalysisResultModel analysisResult = const AiAnalysisResultModel(
    bannerTitle: 'Kết quả phân tích',
    confidenceLabelPrefix: 'Độ tin cậy:',
    confidencePercent: 92,
    injuryType: 'Trầy xước',
    boundingBoxLabel: 'Trầy xước 92%',
    infoCardTitle: 'Thông tin nhận diện',
    injuryTypeLabel: 'Loại tổn thương:',
    confidenceRowLabel: 'Độ tin cậy:',
    locationRowLabel: 'Vị trí:',
    locationSectionTitle: 'Chọn vị trí tổn thương',
    bottomNoticeText: 'Hệ thống đã nhận diện được tổn thương. Vui lòng chọn vị trí cụ thể để xem hướng dẫn sơ cứu phù hợp.',
    primaryActionLabel: 'Xem hướng dẫn sơ cứu',
  );

  // Danh sách 5 vị trí tổn thương trên Màn hình 3
  final List<InjuryLocationOptionModel> injuryLocations = const [
    InjuryLocationOptionModel(
      id: 'arm',
      label: 'Cánh tay',
      fallbackIcon: Icons.front_hand_outlined,
    ),
    InjuryLocationOptionModel(
      id: 'leg',
      label: 'Chân',
      fallbackIcon: Icons.directions_walk_outlined,
    ),
    InjuryLocationOptionModel(
      id: 'head',
      label: 'Đầu',
      fallbackIcon: Icons.face_outlined,
    ),
    InjuryLocationOptionModel(
      id: 'back',
      label: 'Lưng',
      fallbackIcon: Icons.accessibility_new_outlined,
    ),
    InjuryLocationOptionModel(
      id: 'other',
      label: 'Khác',
      fallbackIcon: Icons.open_with_outlined,
    ),
  ];

  /// Lấy nhãn tên vị trí tổn thương đang được chọn để hiển thị trong thẻ "Thông tin nhận diện"
  String get selectedLocationLabel {
    for (final option in injuryLocations) {
      if (option.id == _selectedLocationId) {
        return option.label;
      }
    }
    return injuryLocations.first.label;
  }

  /// Cập nhật vị trí tổn thương khi người dùng chọn 1 trong 5 vị trí trên Màn hình 3
  void selectInjuryLocation(String locationId) {
    if (_selectedLocationId == locationId) return;
    _selectedLocationId = locationId;
    notifyListeners();
  }
}
