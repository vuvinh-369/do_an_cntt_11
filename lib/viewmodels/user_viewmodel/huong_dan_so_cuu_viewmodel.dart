import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import 'dieu_huong_co_so_viewmodel.dart';

mixin HuongDanSoCuuViewModel on DieuHuongCoSoViewModel {
  // Từ điển dữ liệu Hướng dẫn sơ cứu (Màn hình 4) tương ứng với từng vết thương
  @override
  final Map<String, FirstAidGuideModel> firstAidGuidesByTopic = const {
    'abrasion': FirstAidGuideModel(
      topicId: 'abrasion',
      screenTitle: 'Hướng dẫn sơ cứu – Trầy xước',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Trầy xước nhẹ',
      safetyNoteText: 'Không có dấu hiệu nguy hiểm',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'wash_hands',
          title: 'Rửa tay sạch',
          description: 'Đảm bảo vệ sinh trước khi xử lý vết thương.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'clean_wound',
          title: 'Làm sạch vết thương',
          description: 'Dùng nước sạch hoặc dung dịch sát khuẩn nhẹ.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Sát trùng',
          description: 'Dùng dung dịch sát khuẩn (như povidone-iodine).',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Băng vết thương',
          description: 'Dùng gạc sạch và băng cố định nhẹ.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Vết thương sâu, chảy máu nhiều.',
        'Có dấu hiệu nhiễm trùng (sưng, đỏ, nóng, đau).',
        'Không cầm máu sau 15 phút.',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
    'cut_laceration': FirstAidGuideModel(
      topicId: 'cut_laceration',
      screenTitle: 'Hướng dẫn sơ cứu – Vết cắt / Vết rách',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Vết cắt / Vết rách ngoài da',
      safetyNoteText: 'Cần cầm máu và sát trùng đúng cách',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'wash_hands',
          title: 'Rửa tay sạch & Cầm máu',
          description:
              'Dùng gạc sạch ấn nhẹ trực tiếp lên vết thương để cầm máu.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'clean_wound',
          title: 'Làm sạch vết thương',
          description: 'Rửa nhẹ nhàng bằng nước muối sinh lý hoặc nước sạch.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Sát trùng',
          description: 'Thoa dung dịch sát khuẩn quanh mép vết cắt.',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Băng vết thương',
          description:
              'Đặt gạc vô trùng và băng kín vừa phải để bảo vệ vết thương.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Vết thương sâu, bờ vết rách hở rộng hoặc chảy máu nhiều.',
        'Có dấu hiệu nhiễm trùng (sưng, đỏ, nóng, đau).',
        'Không cầm máu sau 15 phút ấn trực tiếp.',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
    'burn': FirstAidGuideModel(
      topicId: 'burn',
      screenTitle: 'Hướng dẫn sơ cứu – Bỏng',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Bỏng bề mặt ngoài da',
      safetyNoteText: 'Cần làm mát vùng bỏng ngay lập tức',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'clean_wound',
          title: 'Làm mát vết bỏng',
          description:
              'Xả nước mát sạch nhẹ nhàng lên vùng bỏng từ 15 – 20 phút.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'wash_hands',
          title: 'Tháo bỏ vật dụng gây chèn ép',
          description:
              'Nhẹ nhàng tháo nhẫn, đồng hồ, vòng tay trước khi vùng da sưng.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Giữ sạch vùng da bỏng',
          description:
              'Không chọc vỡ bóng nước, không bôi kem đánh răng hoặc nước mắm.',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Che phủ vết bỏng',
          description:
              'Dùng gạc vô trùng không dính che nhẹ lên vùng da bị bỏng.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Vết bỏng diện rộng, phồng rộp lớn hoặc bỏng ở mặt, bàn tay, khớp.',
        'Bỏng do hóa chất, điện giật hoặc có dấu hiệu nhiễm trùng.',
        'Người bị bỏng sốt cao, đau rát dữ dội hoặc choáng váng.',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
    'bruise': FirstAidGuideModel(
      topicId: 'bruise',
      screenTitle: 'Hướng dẫn sơ cứu – Bầm',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Bầm tím phần mềm dưới da',
      safetyNoteText: 'Không có dấu hiệu rách da hở',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'clean_wound',
          title: 'Chườm lạnh sớm',
          description:
              'Bọc túi đá trong khăn sạch và chườm lên vùng bầm 15 – 20 phút.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'wash_hands',
          title: 'Nghỉ ngơi và hạn chế vận động mạnh',
          description:
              'Tránh va đập thêm hoặc xoa bóp dầu nóng trong 24 giờ đầu.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Kê cao vùng bị thương',
          description:
              'Nếu có thể, kê cao vùng tay/chân bị bầm để giảm sưng nề.',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Theo dõi sự thay đổi màu sắc',
          description: 'Sau 48 giờ có thể chườm ấm nhẹ để hỗ trợ tan máu bầm.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Vùng bầm sưng to nhanh, đau nhức dữ dội hoặc nghi ngờ gãy xương.',
        'Không thể cử động khớp hoặc chi tại vùng bị chấn thương.',
        'Vết bầm không giảm sau 2 tuần hoặc xuất hiện tự nhiên không rõ nguyên nhân.',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
    'foreign_body': FirstAidGuideModel(
      topicId: 'foreign_body',
      screenTitle: 'Hướng dẫn sơ cứu – Dị vật',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Dị vật ngoài da',
      safetyNoteText: 'Thận trọng, không tự ý rút dị vật đâm sâu',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'wash_hands',
          title: 'Rửa tay sạch và đánh giá dị vật',
          description: 'Quan sát kỹ vị trí, kích thước và độ sâu của dị vật.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'clean_wound',
          title: 'Xử lý dị vật nhỏ nông trên bề mặt',
          description:
              'Dùng nhíp đã khử trùng cồn nhẹ nhàng gắp dằm/dị vật nhỏ nông.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Làm sạch và sát trùng',
          description:
              'Rửa bằng nước muối sinh lý và thoa dung dịch povidone-iodine.',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Cố định và băng bảo vệ',
          description: 'Nếu dị vật lớn đâm sâu, giữ nguyên và chèn gạc cố định quanh dị vật.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Dị vật đâm sâu, kích thước lớn hoặc nằm gần mắt, mạch máu lớn.',
        'Có dấu hiệu nhiễm trùng (sưng, đỏ, nóng, đau, chảy mủ).',
        'Dị vật là mảnh kim loại rỉ sét, thủy tinh vỡ hoặc không lấy ra hết được.',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
    'poisoning': FirstAidGuideModel(
      topicId: 'poisoning',
      screenTitle: 'Hướng dẫn sơ cứu – Ngộ độc',
      statusBoxTitle: 'Tình trạng tổn thương',
      severityText: 'Nghi ngờ ngộ độc thực phẩm / tiếp xúc',
      safetyNoteText: 'Theo dõi sát dấu hiệu sinh tồn của người bệnh',
      stepsSectionTitle: 'Các bước sơ cứu',
      steps: [
        FirstAidStepModel(
          stepNumber: 1,
          id: 'wash_hands',
          title: 'Ngừng ngay tiếp xúc với tác nhân gây độc',
          description: 'Ngưng ăn uống thực phẩm nghi ngờ hoặc đưa nạn nhân ra nơi thoáng khí.',
          fallbackIcon: Icons.clean_hands_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 2,
          id: 'clean_wound',
          title: 'Bù nước và điện giải đúng cách',
          description: 'Cho uống từng ngụm nhỏ dung dịch Oresol hoặc nước ấm nếu còn tỉnh táo.',
          fallbackIcon: Icons.water_drop_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 3,
          id: 'antiseptic',
          title: 'Giữ lại mẫu thực phẩm hoặc nhãn chất độc',
          description: 'Lưu giữ mẫu vật để nhân viên y tế xác định chính xác nguyên nhân.',
          fallbackIcon: Icons.medication_liquid_outlined,
        ),
        FirstAidStepModel(
          stepNumber: 4,
          id: 'bandage_wound',
          title: 'Đặt nằm nghỉ ở tư thế an toàn',
          description: 'Cho người bệnh nằm đầu thấp, nghiêng mặt sang một bên nếu buồn nôn.',
          fallbackIcon: Icons.healing_outlined,
        ),
      ],
      redWarningTitle: 'Khi nào cần đi khám ngay?',
      redWarningBullets: [
        'Nôn ói liên tục, tiêu chảy nhiều lần, sốt cao hoặc đau bụng dữ dội.',
        'Có dấu hiệu mất nước nặng, môi khô, mạch nhanh, lơ mơ hoặc co giật.',
        'Ngộ độc hóa chất, thuốc trừ sâu, nấm lạ (tuyệt đối không tự gây nôn nếu lơ mơ).',
      ],
      backButtonLabel: 'Quay lại phân tích ảnh',
    ),
  };

  /// Lấy dữ liệu Hướng dẫn sơ cứu hiện tại để hiển thị trên Màn hình 4
  FirstAidGuideModel get firstAidGuide {
    return firstAidGuidesByTopic[selectedGuideTopicId] ??
        firstAidGuidesByTopic['abrasion']!;
  }

  void onViewFirstAidGuidePressed() {
    navigateToFirstAidGuide(topicId: 'abrasion');
  }

  void onBackToImageAnalysisPressed() {
    navigateToAiAnalysis();
  }
}
