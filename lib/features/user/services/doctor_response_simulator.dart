import 'dart:async';
import 'package:flutter/material.dart';
import '../models/doctor_consultation_models.dart';

/// Bộ máy mô phỏng phản hồi lâm sàng thông minh của Bác sĩ chuyên khoa
/// Cung cấp luồng tương tác 2 chiều chân thực theo chuẩn hội chẩn từ xa:
/// 1. Cập nhật chuỗi trạng thái tin nhắn (sending -> sent -> delivered -> read)
/// 2. Bật trạng thái Bác sĩ đang soạn tin (Doctor Typing Indicator)
/// 3. Phân tích lâm sàng cây quyết định (Clinical Triage Decision Tree)
/// 4. Tạo phản hồi y khoa đồng cảm, chính xác kèm câu hỏi gợi ý nhanh (Quick Replies)
class DoctorResponseSimulator {
  final bool fastMode;
  static int _doctorSeq = 0;

  const DoctorResponseSimulator({this.fastMode = false});

  Duration get _sentDelay => fastMode ? const Duration(milliseconds: 20) : const Duration(milliseconds: 280);
  Duration get _deliveredDelay => fastMode ? const Duration(milliseconds: 40) : const Duration(milliseconds: 550);
  Duration get _readDelay => fastMode ? const Duration(milliseconds: 60) : const Duration(milliseconds: 850);
  Duration get _typingDelay => fastMode ? const Duration(milliseconds: 100) : const Duration(milliseconds: 1400);

  /// Chạy quy trình chuyển tiếp trạng thái tin nhắn của bệnh nhân
  /// Thông báo callback sau mỗi bước chuyển: sent -> delivered -> read
  Future<void> simulateMessageDeliveryLifecycle({
    required DoctorChatMessage message,
    required void Function(MessageDeliveryStatus status) onStatusChanged,
    required VoidCallback onStartTyping,
  }) async {
    // 1. Máy chủ xác nhận đã nhận tin
    await Future.delayed(_sentDelay);
    onStatusChanged(MessageDeliveryStatus.sent);

    // 2. Chuyển phát đến thiết bị bác sĩ
    await Future.delayed(_deliveredDelay);
    onStatusChanged(MessageDeliveryStatus.delivered);

    // 3. Bác sĩ mở tin nhắn xem
    await Future.delayed(_readDelay);
    onStatusChanged(MessageDeliveryStatus.read);

    // 4. Kích hoạt trạng thái bác sĩ bắt đầu gõ phản hồi
    onStartTyping();
  }

  /// Tạo phản hồi lâm sàng của Bác sĩ dựa trên nội dung tin nhắn, tệp đính kèm và dữ liệu bệnh án
  Future<DoctorChatMessage> generateDoctorResponse({
    required String patientMessage,
    required DoctorProfile doctor,
    ChatAttachment? attachment,
    Map<String, dynamic>? clinicalContext,
  }) async {
    // Chờ thời gian bác sĩ suy nghĩ và gõ tin
    await Future.delayed(_typingDelay);

    final normalized = patientMessage.toLowerCase().trim();
    final responsePayload = _triageClinicalResponse(normalized, attachment, clinicalContext, doctor);

    return DoctorChatMessage(
      id: 'doc_msg_${DateTime.now().microsecondsSinceEpoch}_${++_doctorSeq}',
      senderType: ChatSenderType.doctor,
      content: responsePayload.message,
      timestamp: DateTime.now(),
      status: MessageDeliveryStatus.read,
      quickReplies: responsePayload.quickReplies,
      isEmergencyWarning: responsePayload.isEmergency,
      doctorNote: responsePayload.clinicalNote,
    );
  }

  /// Phân tích lâm sàng theo cây quyết định (Medical Decision Tree)
  _TriageResult _triageClinicalResponse(
    String query,
    ChatAttachment? attachment,
    Map<String, dynamic>? clinicalContext,
    DoctorProfile doctor,
  ) {
    // 1. Trường hợp có tệp đính kèm tóm tắt kết quả phân tích tổn thương từ ảnh
    if (attachment?.type == ChatAttachmentType.woundScanSummary ||
        (attachment?.hasImage == true && query.contains('kết quả')) ||
        query.contains('phân tích vết thương')) {
      return _buildWoundScanResponse(query, clinicalContext);
    }

    // 2. Cấp cứu: Chảy máu ồ ạt / Động mạch / Không cầm được
    if (_containsAny(query, ['chảy máu nhiều', 'máu phun', 'máu xối xả', 'không cầm được máu', 'băng ướt đẫm', 'máu tuôn'])) {
      return _TriageResult(
        message:
            '⚠️ BÁC SĨ CẢNH BÁO CẤP CỨU:\n'
            'Tình trạng chảy máu lượng nhiều cần can thiệp cầm máu khẩn cấp ngay:\n\n'
            '1. Dùng gạc sạch hoặc khăn sạch ép TRỰC TIẾP và LIÊN TỤC lên miệng vết thương trong 10-15 phút. Tuyệt đối không mở ra xem giữa chừng.\n'
            '2. Nâng cao vị trí tổn thương cao hơn tầm tim nếu không nghi ngờ gãy xương.\n'
            '3. Nếu sau 15 phút ép chặt máu vẫn thấm đẫm hoặc phun thành tia, hãy gọi ngay Cấp cứu 115 hoặc nhờ người thân chuyển đến bệnh viện gần nhất!\n\n'
            'Bác sĩ đang túc trực, bạn đã thực hiện ép băng chưa?',
        isEmergency: true,
        clinicalNote: 'Triage: Đỏ (Khẩn cấp) - Xuất huyết chưa kiểm soát.',
        quickReplies: const [
          DoctorQuickActionOption(
            id: 'bleeding_controlled',
            title: 'Máu đã giảm/cầm',
            defaultText: 'Tôi đã ép gạc và máu đã bắt đầu cầm lại rồi bác sĩ.',
            icon: Icons.check_circle_outline,
          ),
          DoctorQuickActionOption(
            id: 'bleeding_heavy',
            title: 'Máu vẫn chảy mạnh',
            defaultText: 'Tôi đã ép chặt nhưng máu vẫn thấm ướt đẫm gạc, tôi phải làm sao?',
            icon: Icons.warning_amber_rounded,
          ),
          DoctorQuickActionOption(
            id: 'call_115',
            title: 'Cần hỗ trợ 115',
            defaultText: 'Xin bác sĩ hỗ trợ kết nối cấp cứu 115 khẩn cấp.',
            icon: Icons.phone_in_talk_rounded,
          ),
        ],
      );
    }

    // 3. Tổn thương Bỏng nhiệt / Hóa chất / Nước sôi
    if (_containsAny(query, ['bỏng', 'nước sôi', 'phỏng', 'dầu sôi', 'cháy da', 'rộp nước'])) {
      return _TriageResult(
        message:
            'Chào bạn, về tổn thương bỏng, bác sĩ hướng dẫn các bước xử trí chuẩn:\n\n'
            '1. Làm mát NGAY LẬP TỨC vùng bỏng dưới vòi nước sạch chảy nhẹ trong 15 - 20 phút. Việc này giúp hạ nhiệt mô sâu và giảm đau rõ rệt.\n'
            '2. TUYỆT ĐỐI KHÔNG: Bôi kem đánh răng, mỡ trăn, nước mắm hay chườm đá lạnh trực tiếp lên vết bỏng vì dễ gây hoại tử lạnh và nhiễm trùng.\n'
            '3. Nếu xuất hiện nốt phỏng rộp nước, giữ nguyên không tự ý chọc vỡ.\n'
            '4. Che nhẹ bằng gạc mỡ vô khuẩn hoặc gạc sạch ẩm.\n\n'
            'Vết bỏng của bạn diện tích khoảng bao nhiêu và có nổi bóng nước chưa?',
        isEmergency: false,
        clinicalNote: 'Triage: Vàng - Bỏng cấp, cần làm mát bằng nước sạch.',
        quickReplies: const [
          DoctorQuickActionOption(
            id: 'burn_blister',
            title: 'Có nốt phỏng nước',
            defaultText: 'Vết bỏng của tôi đã nổi bóng nước to bằng ngón tay rồi bác sĩ.',
            icon: Icons.water_drop_outlined,
          ),
          DoctorQuickActionOption(
            id: 'burn_cooled',
            title: 'Đã xả nước 15p',
            defaultText: 'Tôi đã ngâm xả nước mát được 20 phút rồi, giờ bôi thuốc gì được?',
            icon: Icons.timer_outlined,
          ),
          DoctorQuickActionOption(
            id: 'burn_medicine',
            title: 'Thuốc mỡ bôi bỏng',
            defaultText: 'Bác sĩ có thể gợi ý loại băng gạc hoặc kem bôi bỏng y tế không?',
            icon: Icons.medication_outlined,
          ),
        ],
      );
    }

    // 4. Vết cắt, rách da, nguy cơ khâu & tiêm uốn ván (SAT)
    if (_containsAny(query, ['vết cắt', 'vết rách', 'đứt tay', 'rách da', 'kính cứa', 'dao lam', 'khâu', 'uốn ván', 'sat'])) {
      return _TriageResult(
        message:
            'Chào bạn, với vết rách da sắc gọn hoặc trầy xước sâu:\n\n'
            '1. Rửa sạch vết thương dưới vòi nước muối sinh lý NaCl 0.9% hoặc nước sạch để trôi sạch dị vật, bụi bẩn.\n'
            '2. Đánh giá miệng vết rách: Nếu mép vết thương há rộng (> 1cm), sâu thấy lớp mỡ vàng hoặc cơ, bạn cần đến phòng khám ngoại khoa để khâu đóng vết thương trong thời gian vàng 6 - 8 giờ đầu nhằm tránh sẹo lồi và nhiễm khuẩn.\n'
            '3. Tiêm phòng uốn ván (SAT): Nếu vết cắt do kim loại gỉ sét, đinh gai hoặc dính bùn đất mà trong 5 năm qua bạn chưa tiêm phòng, cần đi tiêm huyết thanh kháng uốn ván trong vòng 24 giờ.\n\n'
            'Vết thương của bạn bị từ khi nào và nguyên nhân do đâu?',
        isEmergency: false,
        clinicalNote: 'Triage: Vàng - Vết rách hở, cần đánh giá chỉ định khâu & tiêm SAT.',
        quickReplies: const [
          DoctorQuickActionOption(
            id: 'need_stitch',
            title: 'Có cần khâu không?',
            defaultText: 'Vết cắt dài tầm 2cm, mép há rộng, trường hợp này có bắt buộc phải khâu không bác sĩ?',
            icon: Icons.content_cut_outlined,
          ),
          DoctorQuickActionOption(
            id: 'tetanus_check',
            title: 'Hỏi về tiêm uốn ván',
            defaultText: 'Vết thương do vật gỉ sét cứa vào, tôi chưa từng tiêm uốn ván thì cần tiêm loại nào?',
            icon: Icons.vaccines_outlined,
          ),
          DoctorQuickActionOption(
            id: 'wound_dressing',
            title: 'Cách thay băng tại nhà',
            defaultText: 'Bác sĩ hướng dẫn cách sát trùng và thay băng sạch tại nhà giúp tôi.',
            icon: Icons.healing_outlined,
          ),
        ],
      );
    }

    // 5. Dấu hiệu nhiễm trùng (Sưng, nóng, đỏ, đau, chảy mủ, sốt)
    if (_containsAny(query, ['nhiễm trùng', 'chảy mủ', 'sưng đỏ', 'mưng mủ', 'nóng rát', 'hôi', 'sốt'])) {
      return _TriageResult(
        message:
            'Bác sĩ lưu ý: Các dấu hiệu bạn mô tả (sưng đỏ tấy, chảy dịch mủ vàng/xanh, nóng rát, sốt) là triệu chứng điển hình của NHIỄM TRÙNG NGOẠI KHOA.\n\n'
            '• Không tự ý nặn mủ hoặc đắp lá dân gian lên vết thương vì vi khuẩn có thể xâm nhập sâu vào bao gân, khớp hoặc máu.\n'
            '• Bạn nên đến cơ sở y tế gần nhất để bác sĩ thăm khám trực tiếp, làm sạch ổ nhiễm và kê đơn kháng sinh phù hợp.\n'
            '• Nếu sốt cao > 38.5°C hoặc vệt đỏ lan nhanh dọc chi, hãy đi cấp cứu ngay.',
        isEmergency: true,
        clinicalNote: 'Triage: Cam - Dấu hiệu viêm mô tế bào / nhiễm trùng mưng mủ.',
        quickReplies: const [
          DoctorQuickActionOption(
            id: 'infection_facility',
            title: 'Tìm cơ sở y tế gần đây',
            defaultText: 'Nhờ hệ thống định vị cơ sở y tế hoặc bệnh viện gần tôi nhất.',
            icon: Icons.local_hospital_outlined,
          ),
          DoctorQuickActionOption(
            id: 'infection_clean',
            title: 'Sát khuẩn tạm thời',
            defaultText: 'Trong lúc chờ đi khám, tôi nên dùng dung dịch gì để rửa tạm?',
            icon: Icons.sanitizer_outlined,
          ),
        ],
      );
    }

    // 6. Trầy xước, té xe, đụng dập bầm tím
    if (_containsAny(query, ['trầy xước', 'té xe', 'ngã xe', 'chà xát', 'bầm tím', 'đụng dập', 'sưng u'])) {
      return _TriageResult(
        message:
            'Chào bạn, với tổn thương trầy xước da hoặc va đập do té ngã:\n\n'
            '1. Với vết trầy xước: Rửa sạch cát bụi bằng nước muối sinh lý hoặc xà phòng dịu nhẹ. Sát khuẩn nhẹ bằng Povidone Iodine 10% pha loãng hoặc nước muối. Giữ bề mặt vết thương thoáng sạch, bôi lớp mỏng mỡ kháng sinh nếu cần để tránh dính gạc.\n'
            '2. Với vết bầm tím / đụng dập: Chườm túi đá lạnh bọc trong khăn sạch (15 phút/lần) trong 48 giờ đầu để co mạch, giảm sưng phù và xuất huyết dưới da. KHÔNG xoa dầu nóng hay rượu thuốc lên vết bầm mới.\n\n'
            'Hiện tại bạn có cử động khớp bình thường và có bị đau nhói trong xương không?',
        isEmergency: false,
        clinicalNote: 'Triage: Xanh lá - Chấn thương phần mềm mức độ nhẹ/vừa.',
        quickReplies: const [
          DoctorQuickActionOption(
            id: 'bruise_ice',
            title: 'Chườm đá bao lâu?',
            defaultText: 'Tôi nên chườm đá mấy lần trong ngày và khi nào thì chuyển sang chườm ấm?',
            icon: Icons.ac_unit_outlined,
          ),
          DoctorQuickActionOption(
            id: 'abrasion_dry',
            title: 'Có nên để vết trầy hở?',
            defaultText: 'Vết trầy có nên để hở cho mau khô mày hay cần băng lại bác sĩ?',
            icon: Icons.wb_sunny_outlined,
          ),
        ],
      );
    }

    // 7. Lời chào, hỏi chung ban đầu
    if (_containsAny(query, ['xin chào', 'chào bác sĩ', 'alo', 'bác sĩ ơi', 'tư vấn', 'giúp tôi', 'bác sĩ có đó không'])) {
      return _TriageResult(
        message:
            'Chào bạn, tôi là ${doctor.fullName} (${doctor.specialty} - ${doctor.hospital}).\n\n'
            'Bác sĩ đang trực tuyến và tiếp nhận ca tư vấn của bạn. Bạn hãy mô tả chi tiết:\n'
            '1. Vết thương xảy ra ở vị trí nào trên cơ thể?\n'
            '2. Nguyên nhân và diễn ra được bao lâu rồi?\n'
            '3. Bạn có thể chụp hoặc gửi ảnh vết thương để bác sĩ quan sát mức độ tổn thương chính xác nhất.',
        isEmergency: false,
        clinicalNote: 'Tiếp nhận ca tư vấn mới.',
        quickReplies: const [
          DoctorQuickActionOption(
            id: 'send_photo',
            title: 'Gửi ảnh vết thương',
            defaultText: 'Tôi muốn gửi ảnh chụp vết thương để bác sĩ xem giúp tôi.',
            icon: Icons.add_photo_alternate_outlined,
          ),
          DoctorQuickActionOption(
            id: 'cut_issue',
            title: 'Vết cắt chảy máu',
            defaultText: 'Tôi bị vật sắc nhọn cứa vào tay đang chảy máu.',
            icon: Icons.content_cut_outlined,
          ),
          DoctorQuickActionOption(
            id: 'burn_issue',
            title: 'Bị bỏng nhiệt',
            defaultText: 'Tôi bị bỏng nước sôi ở cánh tay, da đang rát đỏ.',
            icon: Icons.local_fire_department_outlined,
          ),
        ],
      );
    }

    // 8. Phản hồi chung hỗ trợ lâm sàng
    return _TriageResult(
      message:
          'Bác sĩ đã nắm được thông tin bạn cung cấp. '
          'Để đưa ra lời khuyên y khoa chuẩn xác và an toàn nhất, bạn vui lòng cho bác sĩ biết thêm:\n\n'
          '• Mức độ đau hiện tại của bạn (nhẹ, vừa hay rất dữ dội)?\n'
          '• Vết thương có đang rỉ dịch, chảy máu hay sưng nề nhiều không?\n'
          '• Bạn có tiền sử bệnh lý nền nào như tiểu đường, rối loạn đông máu hay dị ứng thuốc không?',
      isEmergency: false,
      clinicalNote: 'Khai thác thêm bệnh sử & triệu chứng cơ năng.',
      quickReplies: const [
        DoctorQuickActionOption(
          id: 'mild_pain',
          title: 'Đau nhẹ, ổn định',
          defaultText: 'Vết thương chỉ đau rát nhẹ, không chảy máu thêm.',
          icon: Icons.sentiment_satisfied_alt_outlined,
        ),
        DoctorQuickActionOption(
          id: 'severe_pain',
          title: 'Đau dữ dội',
          defaultText: 'Vết thương đau nhức nhiều, sưng to và khó chịu.',
          icon: Icons.sentiment_very_dissatisfied_outlined,
        ),
        DoctorQuickActionOption(
          id: 'need_prescription',
          title: 'Thuốc giảm đau sát khuẩn',
          defaultText: 'Bác sĩ có thể tư vấn thuốc giảm đau và dung dịch rửa vết thương an toàn không?',
          icon: Icons.medication_liquid_outlined,
        ),
      ],
    );
  }

  /// Xử lý ca tư vấn bàn giao trực tiếp từ kết quả quét AI mô hình YOLO
  _TriageResult _buildWoundScanResponse(String query, Map<String, dynamic>? clinicalContext) {
    final injuryType = clinicalContext?['injuryType']?.toString() ?? 'Tổn thương ngoài da';
    final rawConfidence = clinicalContext?['confidence'];
    final confidence = rawConfidence is num
        ? rawConfidence.toInt()
        : int.tryParse('$rawConfidence'.replaceAll('%', '').trim()) ?? 90;
    final location = clinicalContext?['location']?.toString() ?? 'vùng cơ thể';
    final hasBleeding = clinicalContext?['isBleeding'] == true;
    final hasInfection = clinicalContext?['hasInfection'] == true;
    final hasForeign = clinicalContext?['hasForeignBody'] == true;

    final buffer = StringBuffer();
    buffer.writeln('Bác sĩ đã nhận được hình ảnh và bản tóm tắt phân tích tổn thương của bạn.');
    buffer.writeln('• Nhận diện sơ bộ: $injuryType (Độ tin cậy $confidence%) tại $location.');

    if (hasBleeding) {
      buffer.writeln('• Ghi nhận có dấu hiệu CHẢY MÁU: Bạn ưu tiên dùng gạc vô khuẩn ép trực tiếp để cầm máu.');
    }
    if (hasForeign) {
      buffer.writeln('• CẢNH BÁO DỊ VẬT: Nếu có mảnh thủy tinh hoặc dằm sâu, KHÔNG tự ý dùng nhíp bới sâu để tránh tổn thương mạch máu.');
    }
    if (hasInfection) {
      buffer.writeln('• Ghi nhận có dấu hiệu DỊCH/VIÊM: Cần vệ sinh sạch bằng dung dịch sát khuẩn y tế.');
    }

    buffer.writeln('\nBác sĩ nhận định bước đầu đây là tổn thương cần được vệ sinh và bảo vệ cẩn thận để tránh nhiễm khuẩn. Bạn đã rửa sạch vùng này chưa?');

    return _TriageResult(
      message: buffer.toString(),
      isEmergency: hasBleeding || hasForeign,
      clinicalNote: 'Hội chẩn bàn giao từ AI Model YOLO: $injuryType ($location)',
      quickReplies: const [
        DoctorQuickActionOption(
          id: 'washed_saline',
          title: 'Đã rửa nước muối',
          defaultText: 'Tôi đã rửa sạch bằng nước muối sinh lý rồi bác sĩ, bước tiếp theo nên làm gì?',
          icon: Icons.water_drop_outlined,
        ),
        DoctorQuickActionOption(
          id: 'need_dressing',
          title: 'Cách băng vết thương',
          defaultText: 'Nhờ bác sĩ hướng dẫn cách băng ép hoặc dán gạc bảo vệ đúng kỹ thuật.',
          icon: Icons.healing_outlined,
        ),
        DoctorQuickActionOption(
          id: 'hospital_referral',
          title: 'Khi nào cần đi viện?',
          defaultText: 'Với vết thương như thế này, khi nào tôi cần đến bệnh viện khám trực tiếp?',
          icon: Icons.local_hospital_outlined,
        ),
      ],
    );
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }
}

class _TriageResult {
  final String message;
  final bool isEmergency;
  final String clinicalNote;
  final List<DoctorQuickActionOption> quickReplies;

  const _TriageResult({
    required this.message,
    required this.isEmergency,
    required this.clinicalNote,
    required this.quickReplies,
  });
}
