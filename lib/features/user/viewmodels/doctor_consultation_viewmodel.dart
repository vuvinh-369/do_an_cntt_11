import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/doctor_consultation_models.dart';
import '../models/image_analysis_models.dart';
import '../services/doctor_ai_fallback_service.dart';
import '../services/doctor_consultation_service.dart';
import '../services/doctor_response_simulator.dart';
import '../../../core/storage/local_storage_service.dart';
import 'analysis_result_viewmodel.dart';
import 'image_analysis_viewmodel.dart';
import 'user_navigation_viewmodel.dart';

/// ViewModel Mixin quản lý nghiệp vụ phòng tư vấn trực tuyến với Bác sĩ (chuẩn Zalo)
mixin BacSiTuVanViewModel on DieuHuongCoSoViewModel {
  // Bác sĩ chuyên khoa đang phụ trách ca tư vấn
  DoctorProfile _activeDoctorProfile = DoctorProfile.defaultDoctor;
  DoctorProfile get activeDoctorProfile => _activeDoctorProfile;

  // Lịch sử tin nhắn trao đổi 2 chiều
  final List<DoctorChatMessage> _doctorChatMessages = [];
  List<DoctorChatMessage> get doctorChatMessages => List.unmodifiable(_doctorChatMessages);

  // Trạng thái Bác sĩ đang soạn phản hồi
  bool _isDoctorTyping = false;
  bool get isDoctorTyping => _isDoctorTyping;

  // Controller nhập tin nhắn văn bản
  final TextEditingController doctorChatInputController = TextEditingController();

  // Controller cuộn khung trò chuyện
  final ScrollController doctorChatScrollController = ScrollController();

  // Tệp đính kèm đang chờ gửi (ảnh chụp vết thương / phiếu tóm tắt)
  ChatAttachment? _pendingAttachment;
  ChatAttachment? get pendingAttachment => _pendingAttachment;

  // Bộ máy mô phỏng phản hồi lâm sàng
  DoctorResponseSimulator _simulator = const DoctorResponseSimulator();

  StreamSubscription<List<DoctorChatMessage>>? _chatSubscription;
  bool _isInitialized = false;
  bool _isDisposed = false;
  static int _messageSeq = 0;

  String? _cachedGuestSessionId;

  /// Định danh bệnh nhân hiện tại: sử dụng tài khoản đăng nhập hoặc mã phiên khách bền vững
  String get currentPatientId {
    if (currentUser != null && currentUser!.username.trim().isNotEmpty) {
      return 'usr_${currentUser!.username.trim().toLowerCase()}';
    }
    final guestId = _cachedGuestSessionId ?? LocalStorageService.instance.getCachedGuestSessionId();
    return guestId ?? 'guest_default';
  }

  /// Tên hiển thị của bệnh nhân: tên đầy đủ / username nếu đã đăng nhập hoặc Khách vãng lai
  String get currentPatientDisplayName {
    if (currentUser != null) {
      if (currentUser!.fullName.trim().isNotEmpty) {
        return currentUser!.fullName.trim();
      }
      return '@${currentUser!.username.trim()}';
    }
    final guestId = _cachedGuestSessionId ?? LocalStorageService.instance.getCachedGuestSessionId();
    if (guestId != null && guestId.length >= 10) {
      final suffix = guestId.substring(guestId.length - 4);
      return 'Khách (#$suffix)';
    }
    return 'Khách (Vãng lai)';
  }

  /// ID cuộc trò chuyện 2 chiều giữa bệnh nhân và bác sĩ đang chọn
  String get activeConversationId => 'conv_${currentPatientId}_${_activeDoctorProfile.id}';

  /// Cho phép gán simulator tốc độ cao phục vụ kiểm thử đơn vị & widget
  @visibleForTesting
  void setSimulatorForTesting(DoctorResponseSimulator testSimulator) {
    _simulator = testSimulator;
  }

  /// Khởi tạo phòng tư vấn với tin nhắn chào mừng và triage ban đầu
  void initDoctorConsultationIfNeeded() {
    if (_isInitialized) return;
    _isInitialized = true;
    _resolveGuestSession();
    _connectConversationStream();
  }

  Future<void> _resolveGuestSession() async {
    if (_cachedGuestSessionId == null) {
      _cachedGuestSessionId = await LocalStorageService.instance.getOrCreateGuestSessionId();
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// Chuyển đổi bác sĩ phụ trách ca tư vấn trực tuyến (Yêu cầu R1)
  void switchDoctor(DoctorProfile doctor) {
    if (_activeDoctorProfile.id == doctor.id) return;
    _activeDoctorProfile = doctor;
    _isInitialized = true;
    DoctorConsultationService.instance.patientViewingConversationId = activeConversationId;
    _connectConversationStream();
    notifyListeners();
  }

  void _connectConversationStream() {
    _chatSubscription?.cancel();
    DoctorConsultationService.instance.patientViewingConversationId = activeConversationId;

    final stored = DoctorConsultationService.instance.getStoredMessages(activeConversationId);
    _doctorChatMessages.clear();
    if (stored.isNotEmpty) {
      _doctorChatMessages.addAll(stored);
    } else {
      _setupInitialDoctorWelcome();
    }
    notifyListeners();

    // Tự động nạp tin nhắn từ LocalStorage / Supabase nếu có lịch sử trước đó
    unawaited(DoctorConsultationService.instance.fetchMessages(activeConversationId).then((loaded) {
      if (!_isDisposed && loaded.isNotEmpty) {
        _doctorChatMessages.clear();
        _doctorChatMessages.addAll(loaded);
        notifyListeners();
        _scrollToBottom();
      }
    }));

    _chatSubscription = DoctorConsultationService.instance
        .getMessagesStream(activeConversationId)
        .listen((updatedList) {
      if (_isDisposed) return;
      if (updatedList.isNotEmpty) {
        _doctorChatMessages.clear();
        _doctorChatMessages.addAll(updatedList);
        final hasDoctorReply = updatedList.any((m) => m.senderType == ChatSenderType.doctor);
        if (hasDoctorReply) {
          DoctorAiFallbackService.instance.onDoctorReplyReceived(activeConversationId);
        }
        // CHỈ gọi markMessagesAsRead nếu có tin nhắn từ Bác sĩ chưa được đánh dấu đã đọc
        final hasUnreadDoctorMsg = updatedList.any(
          (m) => m.senderType == ChatSenderType.doctor && m.status != MessageDeliveryStatus.read,
        );
        if (hasUnreadDoctorMsg) {
          DoctorConsultationService.instance.markMessagesAsRead(activeConversationId, 'patient');
        }
        notifyListeners();
        _scrollToBottom();
      }
    });
  }

  void _setupInitialDoctorWelcome() {
    _doctorChatMessages.clear();
    final welcomeMessage = DoctorChatMessage(
      id: 'welcome_doctor_${_activeDoctorProfile.id}_01',
      conversationId: activeConversationId,
      senderType: ChatSenderType.doctor,
      senderId: _activeDoctorProfile.id,
      senderName: _activeDoctorProfile.fullName,
      content:
          'Xin chào, tôi là ${_activeDoctorProfile.fullName} (${_activeDoctorProfile.specialty} - ${_activeDoctorProfile.hospital}).\n\n'
          'Tôi đang trực tiếp tiếp nhận phòng khám tư vấn sơ cứu ban đầu. Bạn đang gặp phải tổn thương hay tình huống khẩn cấp nào? Hãy gửi mô tả hoặc ảnh chụp vết thương để tôi hỗ trợ ngay nhé!',
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      status: MessageDeliveryStatus.read,
      quickReplies: const [
        DoctorQuickActionOption(
          id: 'quick_bleeding',
          title: 'Vết thương chảy máu',
          defaultText: 'Tôi bị vết rách da đang chảy máu, cần hướng dẫn cách cầm máu an toàn.',
          icon: Icons.water_drop_outlined,
        ),
        DoctorQuickActionOption(
          id: 'quick_burn',
          title: 'Bỏng nước sôi / nhiệt',
          defaultText: 'Tôi bị bỏng nước sôi ở cánh tay, da đang rát đỏ khó chịu.',
          icon: Icons.local_fire_department_outlined,
        ),
        DoctorQuickActionOption(
          id: 'quick_wound_photo',
          title: 'Gửi ảnh vết thương',
          defaultText: 'Tôi muốn gửi ảnh chụp vết thương để bác sĩ xem giúp tôi.',
          icon: Icons.add_photo_alternate_outlined,
        ),
        DoctorQuickActionOption(
          id: 'quick_tetanus',
          title: 'Có cần tiêm uốn ván?',
          defaultText: 'Vết thương bị cứa bởi kim loại gỉ sét, tôi có cần đi tiêm SAT không bác sĩ?',
          icon: Icons.vaccines_outlined,
        ),
      ],
    );
    _doctorChatMessages.add(welcomeMessage);

    // Đồng bộ tin nhắn chào và các chip gợi ý vào DoctorConsultationService để không bị xoá bởi Stream
    DoctorConsultationService.instance.seedInitialConversationMessages(
      activeConversationId,
      [welcomeMessage],
    );
  }

  /// Gửi tin nhắn từ phía bệnh nhân vào phòng tư vấn
  Future<void> sendDoctorChatMessage({
    String? text,
    ChatAttachment? attachment,
    Map<String, dynamic>? clinicalContext,
  }) async {
    final rawText = (text ?? doctorChatInputController.text).trim();
    final effectiveAttachment = attachment ?? _pendingAttachment;

    // Không gửi tin rỗng nếu không có đính kèm
    if (rawText.isEmpty && effectiveAttachment == null) return;

    final patientMsgId = 'pat_msg_${DateTime.now().microsecondsSinceEpoch}_${++_messageSeq}';
    String? attachmentUrl;
    if (effectiveAttachment != null && effectiveAttachment.hasImage) {
      attachmentUrl = 'data:image/jpeg;base64,${base64Encode(effectiveAttachment.bytes!)}';
    }

    final patientMessage = DoctorChatMessage(
      id: patientMsgId,
      conversationId: activeConversationId,
      senderType: ChatSenderType.patient,
      senderId: currentPatientId,
      senderName: currentPatientDisplayName,
      content: rawText.isNotEmpty ? rawText : 'Đã gửi một hình ảnh đính kèm',
      attachmentUrl: attachmentUrl,
      attachmentType: effectiveAttachment != null ? effectiveAttachment.type : ChatAttachmentType.none,
      timestamp: DateTime.now(),
      status: MessageDeliveryStatus.sent,
      attachment: effectiveAttachment,
    );

    _doctorChatMessages.add(patientMessage);
    doctorChatInputController.clear();
    _pendingAttachment = null;
    notifyListeners();
    _scrollToBottom();

    // Đồng bộ lên DoctorConsultationService & Supabase
    await DoctorConsultationService.instance.sendMessage(
      conversationId: activeConversationId,
      senderType: 'patient',
      senderId: currentPatientId,
      senderName: currentPatientDisplayName,
      patientName: currentPatientDisplayName,
      doctorId: _activeDoctorProfile.id,
      doctorName: _activeDoctorProfile.fullName,
      content: patientMessage.content,
      attachment: effectiveAttachment,
      attachmentUrl: attachmentUrl,
      attachmentType: patientMessage.attachmentType.name,
      localMessageId: patientMsgId,
    );

    // Kích hoạt cơ chế AI Bác sĩ dự phòng (R3: Kiểm tra offline / đếm ngược timeout 30-60s)
    DoctorAiFallbackService.instance.onPatientMessageSent(
      conversationId: activeConversationId,
      message: patientMessage.content,
      isDoctorOnline: _activeDoctorProfile.isOnline,
      doctor: _activeDoctorProfile,
      woundContext: clinicalContext != null ? clinicalContext.toString() : null,
    );

    // CHỈ chạy bộ mô phỏng nếu đang ở chế độ FastMode phục vụ kiểm thử đơn vị
    if (_simulator.fastMode) {
      // 1. Chạy chuỗi trạng thái chuyển giao theo chuẩn Zalo (sending -> sent -> delivered -> read)
      await _simulator.simulateMessageDeliveryLifecycle(
        message: patientMessage,
        onStatusChanged: (newStatus) {
          if (_isDisposed) return;
          final index = _doctorChatMessages.indexWhere((m) => m.id == patientMsgId);
          if (index != -1) {
            _doctorChatMessages[index] = _doctorChatMessages[index].copyWith(status: newStatus);
            DoctorConsultationService.instance.updateDeliveryStatus(activeConversationId, patientMsgId, newStatus);
            notifyListeners();
          }
        },
        onStartTyping: () {
          if (_isDisposed) return;
          _isDoctorTyping = true;
          DoctorAiFallbackService.instance.onDoctorTyping(activeConversationId);
          notifyListeners();
          _scrollToBottom();
        },
      );

      // 2. Tạo phản hồi lâm sàng từ Bác sĩ
      final doctorReply = await _simulator.generateDoctorResponse(
        patientMessage: rawText,
        doctor: _activeDoctorProfile,
        attachment: effectiveAttachment,
        clinicalContext: clinicalContext,
      );

      if (_isDisposed) return;

      _isDoctorTyping = false;
      DoctorAiFallbackService.instance.onDoctorReplyReceived(activeConversationId);
      _doctorChatMessages.add(doctorReply);
      await DoctorConsultationService.instance.sendMessage(
        conversationId: activeConversationId,
        senderType: 'doctor',
        senderId: _activeDoctorProfile.id,
        senderName: _activeDoctorProfile.fullName,
        doctorName: _activeDoctorProfile.fullName,
        doctorId: _activeDoctorProfile.id,
        patientId: currentPatientId,
        patientName: currentPatientDisplayName,
        content: doctorReply.content,
        attachment: doctorReply.attachment,
        isEmergency: doctorReply.isEmergencyWarning,
      );
      notifyListeners();
      _scrollToBottom();
    }
  }

  /// Bệnh nhân chọn 1 chip gợi ý nhanh (Quick Action Reply)
  void selectDoctorQuickReply(DoctorQuickActionOption option) {
    unawaited(sendDoctorChatMessage(text: option.defaultText));
  }

  /// Đính kèm ảnh từ máy / thư viện vào tin nhắn
  Future<void> pickAndAttachImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (_isDisposed) return;
        _pendingAttachment = ChatAttachment(
          id: 'attach_${DateTime.now().microsecondsSinceEpoch}_${++_messageSeq}',
          type: ChatAttachmentType.image,
          fileName: picked.name,
          bytes: bytes,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[BacSiTuVanViewModel] Lỗi chọn ảnh: $e');
    }
  }

  /// Chụp ảnh trực tiếp từ camera
  Future<void> captureAndAttachImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (_isDisposed) return;
        _pendingAttachment = ChatAttachment(
          id: 'attach_cam_${DateTime.now().microsecondsSinceEpoch}_${++_messageSeq}',
          type: ChatAttachmentType.image,
          fileName: picked.name,
          bytes: bytes,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[BacSiTuVanViewModel] Lỗi chụp ảnh camera: $e');
    }
  }

  /// Gỡ bỏ tệp đính kèm đang chờ gửi
  void removePendingAttachment() {
    _pendingAttachment = null;
    notifyListeners();
  }

  /// Xóa lịch sử và khôi phục về trạng thái ban đầu
  void clearDoctorChatHistory() {
    _doctorChatMessages.clear();
    _isDoctorTyping = false;
    _pendingAttachment = null;
    doctorChatInputController.clear();
    _setupInitialDoctorWelcome();
    notifyListeners();
  }

  /// Chuyển tiếp và bàn giao toàn bộ kết quả phân tích tổn thương từ Màn hình 3 sang Bác sĩ
  void consultDoctorWithCurrentAnalysis() {
    initDoctorConsultationIfNeeded();

    String injuryType = 'Tổn thương ngoài da';
    int confidence = 90;
    String location = 'Cánh tay';
    bool isBleeding = false;
    bool hasInfection = false;
    bool hasForeign = false;
    Uint8List? rawBytes;
    String? fileName;

    // Trích xuất dữ liệu từ các mixin liên quan nếu có
    if (this is KetQuaPhanTichViewModel) {
      final res = (this as KetQuaPhanTichViewModel).analysisResult;
      injuryType = res.injuryType;
      confidence = res.confidencePercent;
      location = (this as KetQuaPhanTichViewModel).selectedLocationLabel;
      rawBytes = res.rawImageBytes;
      fileName = res.imageFileName;
    }

    if (this is PhanTichAnhViewModel) {
      final photoVm = this as PhanTichAnhViewModel;
      isBleeding = photoVm.isBleeding;
      hasInfection = photoVm.hasPusOrInfection;
      hasForeign = photoVm.hasForeignBody;
      rawBytes ??= photoVm.stagedImageBytes;
      fileName ??= photoVm.stagedImageName;
    }

    ChatAttachment? handoverAttachment;
    if (rawBytes != null && rawBytes.isNotEmpty) {
      handoverAttachment = ChatAttachment(
        id: 'handover_${DateTime.now().millisecondsSinceEpoch}',
        type: ChatAttachmentType.woundScanSummary,
        fileName: fileName ?? 'wound_scan.jpg',
        bytes: rawBytes,
        metadata: {
          'injuryType': injuryType,
          'confidence': confidence,
          'location': location,
        },
      );
    }

    final handoverText =
        'Chào Bác sĩ, tôi vừa phân tích ảnh tổn thương qua hệ thống AI:\n'
        '• Loại vết thương: $injuryType (Độ tin cậy: $confidence%)\n'
        '• Vị trí: $location'
        '${isBleeding ? "\n• Đang có biểu hiện chảy máu" : ""}'
        '${hasForeign ? "\n• Có nghi ngờ dị vật găm vào" : ""}'
        '${hasInfection ? "\n• Có sưng tấy / rỉ dịch" : ""}\n'
        'Nhờ Bác sĩ xem hình ảnh và tư vấn hướng xử trí giúp tôi!';

    final clinicalMap = {
      'injuryType': injuryType,
      'confidence': confidence,
      'location': location,
      'isBleeding': isBleeding,
      'hasInfection': hasInfection,
      'hasForeignBody': hasForeign,
    };

    navigateToDoctorConsultation();

    unawaited(
      sendDoctorChatMessage(
        text: handoverText,
        attachment: handoverAttachment,
        clinicalContext: clinicalMap,
      ),
    );
  }

  void _scrollToBottom() {
    if (_isDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed &&
          doctorChatScrollController.hasClients &&
          doctorChatScrollController.position.hasContentDimensions) {
        doctorChatScrollController.animateTo(
          doctorChatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void disposeDoctorConsultation() {
    _isDisposed = true;
    _chatSubscription?.cancel();
    _chatSubscription = null;
    doctorChatInputController.dispose();
    doctorChatScrollController.dispose();
  }
}

