// File: lib/features/doctor/views/doctor_workspace_view.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../core/call/call_models.dart';
import '../../../core/call/call_signaling_service.dart';
import '../../../core/call/views/call_overlay_view.dart';
import '../../../core/call/views/incoming_call_dialog.dart';
import '../../../core/doctor_management/doctor_management_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../user/models/doctor_consultation_models.dart';
import '../../user/services/doctor_consultation_service.dart';

/// Không gian làm việc riêng biệt dành cho Bác sĩ trực tuyến (/doctor)
/// Cho phép tiếp nhận hàng đợi ca bệnh được phân công, tư vấn 2 chiều realtime,
/// gọi thoại/video khám bệnh từ xa, và quản lý trạng thái trực tuyến.
class DoctorWorkspaceView extends StatefulWidget {
  final DoctorProfile? initialDoctor;
  final VoidCallback? onLogout;

  const DoctorWorkspaceView({
    super.key,
    this.initialDoctor,
    this.onLogout,
  });

  @override
  State<DoctorWorkspaceView> createState() => _DoctorWorkspaceViewState();
}

class _DoctorWorkspaceViewState extends State<DoctorWorkspaceView> {
  // Hồ sơ bác sĩ đang đăng nhập
  late DoctorProfile _activeDoctor;

  // Cuộc trò chuyện đang chọn
  String? _selectedConversationId;

  // Controllers
  final TextEditingController _searchQueueCtrl = TextEditingController();
  final TextEditingController _msgInputCtrl = TextEditingController();
  final ScrollController _timelineScrollCtrl = ScrollController();

  // Tệp ảnh đính kèm đang chờ gửi
  ChatAttachment? _pendingAttachment;

  // Banner thông báo tin nhắn mới
  String? _activeBannerAlert;
  Timer? _bannerDismissTimer;
  StreamSubscription<String>? _bannerAlertSub;
  StreamSubscription<String>? _navRequestSub;
  StreamSubscription<CallSessionModel>? _incomingCallSub;

  // Chống nhấp đúp gửi trùng tin nhắn (Debounce)
  DateTime? _lastSendTime;
  bool _isSending = false;

  // Lọc hàng đợi: 'all' (Tất cả), 'waiting' (Đang chờ/chưa đọc), 'replied' (Đã phản hồi)
  String _queueFilter = 'all';

  // Mẫu câu phản hồi y tế lâm sàng nhanh (Canned Clinical Responses)
  static const List<DoctorQuickActionOption> _clinicalQuickReplies = [
    DoctorQuickActionOption(
      id: 'quick_hemostasis',
      title: '🩹 Ép gạc cầm máu',
      defaultText:
          'Bạn hãy dùng miếng gạc vô khuẩn (hoặc khăn sạch) ấn trực tiếp thật chặt lên vết thương trong 10-15 phút liên tục, không mở ra xem trước thời gian này. Nâng cao chi bị thương để giảm áp lực máu.',
      icon: Icons.healing_outlined,
    ),
    DoctorQuickActionOption(
      id: 'quick_burn',
      title: '💧 Sơ cứu bỏng',
      defaultText:
          'Hãy lập tức ngâm hoặc xả nhẹ vùng bỏng dưới vòi nước sạch mát (khoảng 15-25°C) liên tục trong 15-20 phút. Tuyệt đối không chườm đá lạnh trực tiếp, không bôi kem đánh răng hay dầu mỡ.',
      icon: Icons.water_drop_outlined,
    ),
    DoctorQuickActionOption(
      id: 'quick_photo',
      title: '📷 Yêu cầu chụp ảnh',
      defaultText:
          'Bạn vui lòng chụp rõ cận cảnh vết thương dưới ánh sáng tốt và gửi vào đây để tôi kiểm tra chi tiết bờ mép vết rách và mức độ tổn thương mô nhé.',
      icon: Icons.camera_alt_outlined,
    ),
    DoctorQuickActionOption(
      id: 'quick_splint',
      title: '🦴 Cố định nẹp',
      defaultText:
          'Hãy cố định nẹp tạm thời và tuyệt đối không cử động vùng chi bị đau. Chờ đội cấp cứu 115 đến hỗ trợ.',
      icon: Icons.medical_services_outlined,
    ),
    DoctorQuickActionOption(
      id: 'quick_tetanus',
      title: '💉 Tiêm phòng SAT',
      defaultText:
          'Do vết thương tiếp xúc dị vật bẩn/kim loại rỉ sét, bạn cần đến cơ sở y tế gần nhất trong vòng 24 giờ để được tiêm phòng huyết thanh kháng uốn ván (SAT).',
      icon: Icons.vaccines_outlined,
    ),
    DoctorQuickActionOption(
      id: 'quick_emergency',
      title: '🏥 Chuyển viện 115',
      defaultText:
          'Tình trạng tổn thương của bạn có dấu hiệu chuyển biến nguy hiểm (mất máu nhiều / choáng / sốc). Bạn cần gọi ngay cấp cứu 115 hoặc nhờ người nhà đưa đến khoa Cấp cứu bệnh viện gần nhất!',
      icon: Icons.local_hospital_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _resolveDoctorIdentity();

    // Đồng bộ và nạp hàng đợi hội thoại từ Supabase / LocalStorage (Yêu cầu R1 & R2)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await DoctorConsultationService.instance.getDoctorConversations(_activeDoctor.id);
      if (mounted) setState(() {});
    });

    _incomingCallSub =
        CallSignalingService.instance.incomingCallStream.listen((session) {
      if (mounted) {
        IncomingCallDialog.show(context, session);
      }
    });

    DoctorManagementService.instance.addListener(_onDoctorServiceChanged);
    DoctorConsultationService.instance.addListener(_onConsultationServiceChanged);

    // Lắng nghe yêu cầu điều hướng sâu từ thông báo nổi In-App
    _navRequestSub = DoctorConsultationService.instance.navigationRequestStream.listen((convId) {
      if (mounted && convId.isNotEmpty) {
        _selectConversation(convId);
      }
    });

    _listenToBannerAlerts();
  }

  @override
  void dispose() {
    _navRequestSub?.cancel();
    DoctorConsultationService.instance.currentViewingConversationId = null;
    _incomingCallSub?.cancel();
    DoctorManagementService.instance.removeListener(_onDoctorServiceChanged);
    DoctorConsultationService.instance.removeListener(_onConsultationServiceChanged);
    _bannerAlertSub?.cancel();
    _bannerDismissTimer?.cancel();
    _searchQueueCtrl.dispose();
    _msgInputCtrl.dispose();
    _timelineScrollCtrl.dispose();
    super.dispose();
  }

  void _resolveDoctorIdentity() {
    if (widget.initialDoctor != null) {
      _activeDoctor = widget.initialDoctor!;
      return;
    }

    final savedId = LocalStorageService.instance.getDoctorSavedId();
    final savedUsername = LocalStorageService.instance.getDoctorSavedUsername();

    if (savedId != null && savedId.isNotEmpty) {
      final doc = DoctorManagementService.instance.getDoctorById(savedId);
      if (doc != null) {
        _activeDoctor = doc;
        return;
      }
    }

    if (savedUsername != null && savedUsername.isNotEmpty) {
      final doc =
          DoctorManagementService.instance.getDoctorByUsername(savedUsername);
      if (doc != null) {
        _activeDoctor = doc;
        return;
      }
    }

    final allDocs = DoctorManagementService.instance.doctors;
    if (allDocs.isNotEmpty) {
      _activeDoctor = allDocs.first;
    } else {
      _activeDoctor = DoctorProfile.defaultDoctor;
    }
  }

  void _onDoctorServiceChanged() {
    if (!mounted) return;
    final updated =
        DoctorManagementService.instance.getDoctorById(_activeDoctor.id);
    if (updated != null) {
      setState(() {
        _activeDoctor = updated;
      });
    }
  }

  void _onConsultationServiceChanged() {
    if (!mounted) return;
    final externalConvId =
        DoctorConsultationService.instance.currentViewingConversationId;
    if (externalConvId != null && externalConvId != _selectedConversationId) {
      _selectConversation(externalConvId);
    } else {
      setState(() {});
    }
  }

  void _listenToBannerAlerts() {
    _bannerAlertSub =
        DoctorConsultationService.instance.bannerAlertStream.listen((alertText) {
      if (!mounted) return;

      if (_selectedConversationId != null &&
          alertText.contains(_selectedConversationId!)) {
        return;
      }

      setState(() {
        _activeBannerAlert = alertText;
      });

      _bannerDismissTimer?.cancel();
      _bannerDismissTimer = Timer(const Duration(seconds: 6), () {
        if (mounted && _activeBannerAlert == alertText) {
          setState(() {
            _activeBannerAlert = null;
          });
        }
      });
    });
  }

  void _selectConversation(String conversationId) {
    setState(() {
      _selectedConversationId = conversationId;
    });

    DoctorConsultationService.instance.currentViewingConversationId =
        conversationId;
    DoctorConsultationService.instance
        .markMessagesAsRead(conversationId, 'doctor');

    // Nạp lịch sử tin nhắn từ LocalStorage và Supabase khi chọn phòng chat (Yêu cầu R2)
    unawaited(DoctorConsultationService.instance.fetchMessages(conversationId));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_timelineScrollCtrl.hasClients) {
        _timelineScrollCtrl.animateTo(
          _timelineScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final text = _msgInputCtrl.text.trim();
    if (text.isEmpty && _pendingAttachment == null) return;

    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!).inMilliseconds < 400) {
      return;
    }
    if (_isSending || _selectedConversationId == null) return;

    _lastSendTime = now;
    _isSending = true;

    final convId = _selectedConversationId!;
    final attachment = _pendingAttachment;

    _msgInputCtrl.clear();
    setState(() {
      _pendingAttachment = null;
    });

    try {
      await DoctorConsultationService.instance.sendMessage(
        conversationId: convId,
        senderType: 'doctor',
        senderId: _activeDoctor.id,
        senderName: _activeDoctor.fullName,
        content: text,
        attachment: attachment,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_timelineScrollCtrl.hasClients) {
          _timelineScrollCtrl.animateTo(
            _timelineScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } finally {
      _isSending = false;
    }
  }

  Future<void> _pickAttachmentImage() async {
    // Mô phỏng tệp đính kèm ảnh lâm sàng/vết thương sạch không phụ thuộc native plugin
    setState(() {
      _pendingAttachment = ChatAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}',
        type: ChatAttachmentType.image,
        bytes: Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
          0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
          0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
          0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
          0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
          0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
          0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
          0x42, 0x60, 0x82
        ]),
        fileName: 'anh_vet_thuong_${DateTime.now().millisecondsSinceEpoch}.png',
      );
    });
  }

  void _toggleDoctorPresence(bool isOnline) {
    DoctorManagementService.instance
        .updateDoctorOnlineStatus(_activeDoctor.id, isOnline);
    setState(() {
      _activeDoctor = _activeDoctor.copyWith(
        isOnline: isOnline,
        statusText: isOnline
            ? 'Đang trực tuyến • Sẵn sàng hỗ trợ'
            : 'Tạm vắng • AI Bác sĩ hỗ trợ thay',
      );
    });
  }

  Future<void> _handleLogout() async {
    DoctorConsultationService.instance.currentViewingConversationId = null;
    await LocalStorageService.instance.clearDoctorSession();
    if (widget.onLogout != null) {
      widget.onLogout!();
    } else if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // ===========================================================================
  // ROOT BUILD WITH BOUNDED LAYOUT DEFENSE & SCAFFOLD WRAPPER (YÊU CẦU R2)
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : math.max(
                    680.0,
                    MediaQuery.sizeOf(context).height - (isMobile ? 80 : 100),
                  );

            return SizedBox(
              height: availableHeight,
              child: Container(
                color: const Color(0xFFF4F7FB),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 20,
                    vertical: isMobile ? 10 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header bar danh tính bác sĩ & trạng thái
                      _buildDoctorHeaderBar(isMobile),
                      const SizedBox(height: 12),

                      // 2. Banner thông báo tin nhắn mới
                      if (_activeBannerAlert != null) ...[
                        _buildInAppBannerAlert(),
                        const SizedBox(height: 10),
                      ],

                      // 3. Khung làm việc chính: Split view trên Desktop, Single view trên Mobile
                      Expanded(
                        child: isMobile ? _buildMobileBody() : _buildDesktopBody(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. DOCTOR IDENTITY & STATUS HEADER BAR
  // ===========================================================================
  Widget _buildDoctorHeaderBar(bool isMobile) {
    final myQueue =
        DoctorConsultationService.instance.getDoctorQueue(_activeDoctor.id);
    final unreadCount = myQueue.fold<int>(0, (sum, q) => sum + q.unreadCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x080D2B6B), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Doctor Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: _activeDoctor.avatarColor,
            child: Text(
              _activeDoctor.avatarInitials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Doctor Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _activeDoctor.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'Bác sĩ tư vấn',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_activeDoctor.specialty} • ${_activeDoctor.hospital}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Patient count badge
          if (!isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline_rounded,
                      size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    '${myQueue.length} ca trực',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B)),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
          ],

          // Online Presence Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _activeDoctor.isOnline
                      ? const Color(0xFF10B981)
                      : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 6),
              if (!isMobile)
                Text(
                  _activeDoctor.isOnline ? 'Trực tuyến' : 'Tạm vắng',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _activeDoctor.isOnline
                        ? const Color(0xFF059669)
                        : const Color(0xFF64748B),
                  ),
                ),
              Switch.adaptive(
                value: _activeDoctor.isOnline,
                activeTrackColor: const Color(0xFF10B981),
                onChanged: _toggleDoctorPresence,
              ),
            ],
          ),

          const SizedBox(width: 8),

          // Logout / Switch account button (Yêu cầu R2)
          IconButton(
            tooltip: 'Đăng xuất / Chuyển đổi tài khoản',
            icon: const Icon(Icons.logout_rounded,
                color: Color(0xFF64748B), size: 20),
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. BANNER ALERT NOTIFICATION
  // ===========================================================================
  Widget _buildInAppBannerAlert() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _activeBannerAlert!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A8A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
            onPressed: () => setState(() => _activeBannerAlert = null),
            tooltip: 'Đóng thông báo',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. WORKSPACE BODY (SPLIT VIEW ON DESKTOP, STACK ON MOBILE)
  // ===========================================================================
  Widget _buildDesktopBody() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0D2B6B), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left pane: Patient Queue (350px)
          SizedBox(
            width: 350,
            child: _buildPatientQueuePane(isMobile: false),
          ),
          const VerticalDivider(
              width: 1, thickness: 1, color: Color(0xFFE8EEF5)),
          // Right pane: Interactive Consultation Room
          Expanded(
            child: _selectedConversationId == null
                ? _buildEmptySelectPlaceholder()
                : _buildChatTimelinePane(isMobile: false),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody() {
    if (_selectedConversationId == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: _buildPatientQueuePane(isMobile: true),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE8EEF5))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Color(0xFF2563EB)),
                  onPressed: () {
                    DoctorConsultationService
                        .instance.currentViewingConversationId = null;
                    setState(() => _selectedConversationId = null);
                  },
                ),
                const Text(
                  'Quay lại Hàng đợi bệnh nhân',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildChatTimelinePane(isMobile: true)),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. PATIENT QUEUE PANE (LEFT)
  // ===========================================================================
  Widget _buildPatientQueuePane({required bool isMobile}) {
    final rawQueue =
        DoctorConsultationService.instance.getDoctorQueue(_activeDoctor.id);

    final sortedQueue = List<ConversationQueueItem>.from(rawQueue)
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    final query = _searchQueueCtrl.text.trim().toLowerCase();
    final filtered = sortedQueue.where((item) {
      final matchQuery = query.isEmpty ||
          item.patientName.toLowerCase().contains(query) ||
          item.lastMessageContent.toLowerCase().contains(query);

      final matchTab = _queueFilter == 'all' ||
          (_queueFilter == 'waiting' && item.unreadCount > 0) ||
          (_queueFilter == 'replied' && item.unreadCount == 0);

      return matchQuery && matchTab;
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchQueueCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tìm bệnh nhân, nội dung...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ),

        // Filter chips: Tất cả, Đang chờ, Đã phản hồi
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildFilterChip('all', 'Tất cả (${sortedQueue.length})'),
              const SizedBox(width: 6),
              _buildFilterChip('waiting', 'Đang chờ'),
              const SizedBox(width: 6),
              _buildFilterChip('replied', 'Đã phản hồi'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFFE8EEF5)),

        // Queue list
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyQueuePlaceholder()
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isSelected =
                        item.conversationId == _selectedConversationId;

                    return InkWell(
                      onTap: () => _selectConversation(item.conversationId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        color: isSelected
                            ? const Color(0xFFEFF6FF)
                            : Colors.transparent,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFDBEAFE),
                              child: Text(
                                item.patientName.isNotEmpty
                                    ? item.patientName[0].toUpperCase()
                                    : 'BN',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.patientName,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: item.unreadCount > 0
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        _formatTime(item.lastMessageTime),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.lastMessageContent,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: item.unreadCount > 0
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: item.unreadCount > 0
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (item.hasAiFallbackResponse)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF5FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFFDDD6FE)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome,
                                              size: 11,
                                              color: Color(0xFF7C3AED)),
                                          SizedBox(width: 4),
                                          Text(
                                            'AI đã hỗ trợ',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF7C3AED),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (item.unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  item.unreadCount > 99
                                      ? '99+'
                                      : item.unreadCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _queueFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _queueFilter = filterKey),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. CHAT TIMELINE PANE (RIGHT)
  // ===========================================================================
  Widget _buildChatTimelinePane({required bool isMobile}) {
    final convId = _selectedConversationId!;

    return Column(
      children: [
        // Room Header
        _buildConversationTopBar(convId),
        const Divider(height: 1, color: Color(0xFFE8EEF5)),

        // Message List
        Expanded(
          child: StreamBuilder<List<DoctorChatMessage>>(
            stream: DoctorConsultationService.instance.getMessagesStream(convId),
            initialData:
                DoctorConsultationService.instance.getStoredMessages(convId),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return _buildEmptyChatPlaceholder();
              }

              return ListView.builder(
                controller: _timelineScrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return _buildMessageBubble(msg);
                },
              );
            },
          ),
        ),

        // Pending Attachment Preview
        if (_pendingAttachment != null) _buildPendingAttachmentPreview(),

        // Clinical Quick-Reply chips
        _buildQuickRepliesBar(),

        // Message input bar
        _buildMessageInputBar(),
      ],
    );
  }

  Widget _buildConversationTopBar(String convId) {
    final queue =
        DoctorConsultationService.instance.getDoctorQueue(_activeDoctor.id);
    final convItem = queue.firstWhere(
      (q) => q.conversationId == convId,
      orElse: () => ConversationQueueItem(
        conversationId: convId,
        patientId: 'pat_unknown',
        patientName: 'Bệnh nhân',
        lastMessageContent: '',
        lastMessageTime: DateTime.now(),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFDBEAFE),
            child: Text(
              convItem.patientName.isNotEmpty
                  ? convItem.patientName[0].toUpperCase()
                  : 'B',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E40AF),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      convItem.patientName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (convItem.patientPhone != null &&
                        convItem.patientPhone!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${convItem.patientPhone})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
                const Text(
                  'Đang kết nối trực tuyến • Hỗ trợ sơ cứu lâm sàng',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),

          // Audio Call Button
          IconButton(
            key: const ValueKey('doctor_call_audio_button'),
            icon: const Icon(Icons.phone_outlined,
                color: Color(0xFF2563EB), size: 20),
            tooltip: 'Gọi thoại với bệnh nhân',
            onPressed: () => _initiateCall(convItem, 'audio'),
          ),

          // Video Call Button
          IconButton(
            key: const ValueKey('doctor_call_video_button'),
            icon: const Icon(Icons.videocam_outlined,
                color: Color(0xFF2563EB), size: 22),
            tooltip: 'Gọi video khám trực tuyến',
            onPressed: () => _initiateCall(convItem, 'video'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateCall(
      ConversationQueueItem convItem, String callType) async {
    final session = await CallSignalingService.instance.startCall(
      callerId: _activeDoctor.id,
      callerName: _activeDoctor.fullName,
      calleeId: convItem.patientId,
      calleeName: convItem.patientName,
      callType: callType,
      isCalleeOnline: true,
    );
    if (!mounted) return;
    if (session.status == CallState.failed ||
        session.status == CallState.busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(session.failureReason ?? 'Không thể thực hiện cuộc gọi.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }
    CallOverlayView.show(context, session: session);
  }

  Widget _buildMessageBubble(DoctorChatMessage msg) {
    if (msg.isPatient) {
      return _buildPatientBubble(msg);
    } else if (msg.isDoctor) {
      return _buildDoctorBubble(msg);
    } else {
      return _buildAiAssistantBubble(msg);
    }
  }

  Widget _buildPatientBubble(DoctorChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x060D2B6B),
                  blurRadius: 6,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.senderName ?? 'Bệnh nhân',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              if (msg.isEmergencyWarning)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text(
                        'Cảnh báo cấp cứu khẩn',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              if (msg.hasAttachment)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildAttachmentDisplay(msg),
                ),
              SelectableText(
                msg.content,
                style: const TextStyle(
                    fontSize: 13.5, color: Color(0xFF1E293B), height: 1.35),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  msg.formattedTime,
                  style:
                      const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorBubble(DoctorChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF2563EB),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.hasAttachment)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildAttachmentDisplay(msg),
                ),
              SelectableText(
                msg.content,
                style: const TextStyle(
                    fontSize: 13.5, color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    msg.formattedTime,
                    style:
                        const TextStyle(fontSize: 10.5, color: Colors.white70),
                  ),
                  const SizedBox(width: 4),
                  _buildDeliveryStatusIcon(msg.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiAssistantBubble(DoctorChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7C3AED)),
                  SizedBox(width: 6),
                  Text(
                    'AI Bác sĩ Trợ lý (Tự động hỗ trợ)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText(
                msg.content,
                style: const TextStyle(
                    fontSize: 13.5, color: Color(0xFF1E293B), height: 1.35),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  msg.formattedTime,
                  style:
                      const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentDisplay(DoctorChatMessage msg) {
    final att = msg.attachment;
    if (att != null && att.bytes != null && att.bytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          att.bytes!,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildBrokenImagePlaceholder(),
        ),
      );
    } else if (msg.attachmentUrl != null && msg.attachmentUrl!.isNotEmpty) {
      final url = msg.attachmentUrl!;
      if (url.startsWith('data:image')) {
        try {
          final commaIdx = url.indexOf(',');
          if (commaIdx != -1) {
            final decoded = base64Decode(url.substring(commaIdx + 1));
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                decoded,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildBrokenImagePlaceholder(),
              ),
            );
          }
        } catch (_) {
          return _buildBrokenImagePlaceholder();
        }
      } else if (url.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildBrokenImagePlaceholder(),
          ),
        );
      }
    }
    return _buildBrokenImagePlaceholder();
  }

  Widget _buildBrokenImagePlaceholder() {
    return Container(
      height: 70,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined,
              color: Color(0xFF64748B), size: 24),
          SizedBox(width: 8),
          Text(
            'Ảnh không khả dụng hoặc tệp bị hỏng',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryStatusIcon(MessageDeliveryStatus status) {
    switch (status) {
      case MessageDeliveryStatus.sending:
        return const Icon(Icons.access_time_rounded,
            size: 12, color: Colors.white70);
      case MessageDeliveryStatus.sent:
        return const Icon(Icons.check_rounded, size: 13, color: Colors.white70);
      case MessageDeliveryStatus.delivered:
        return const Icon(Icons.done_all_rounded,
            size: 13, color: Colors.white70);
      case MessageDeliveryStatus.read:
        return const Icon(Icons.done_all_rounded,
            size: 13, color: Color(0xFF67E8F9));
      case MessageDeliveryStatus.failed:
        return const Icon(Icons.error_outline_rounded,
            size: 13, color: Colors.yellowAccent);
    }
  }

  // ===========================================================================
  // 6. QUICK REPLIES & MESSAGE INPUT BAR
  // ===========================================================================
  Widget _buildPendingAttachmentPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _pendingAttachment!.bytes != null
                ? Image.memory(
                    _pendingAttachment!.bytes!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image,
                        size: 40, color: Color(0xFF94A3B8)),
                  )
                : const Icon(Icons.image, size: 40, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _pendingAttachment!.fileName ?? 'Ảnh chụp đính kèm',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFF64748B)),
            onPressed: () => setState(() => _pendingAttachment = null),
            tooltip: 'Hủy đính kèm',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRepliesBar() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFD),
        border: Border(top: BorderSide(color: Color(0xFFE8EEF5))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: _clinicalQuickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final quick = _clinicalQuickReplies[index];
          return ActionChip(
            avatar: quick.icon != null
                ? Icon(quick.icon, size: 13, color: const Color(0xFF2563EB))
                : null,
            label: Text(
              quick.title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D4ED8),
              ),
            ),
            backgroundColor: const Color(0xFFEFF6FF),
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () {
              _msgInputCtrl.text = quick.defaultText;
              _msgInputCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _msgInputCtrl.text.length),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EEF5))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image_outlined,
                color: Color(0xFF2563EB), size: 22),
            tooltip: 'Đính kèm ảnh',
            onPressed: _pickAttachmentImage,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _msgInputCtrl,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSendMessage(),
              decoration: const InputDecoration(
                hintText:
                    'Nhập tin nhắn phản hồi cho bệnh nhân... (Enter để gửi)',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF2563EB),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _handleSendMessage,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send_rounded, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. PLACEHOLDERS
  // ===========================================================================
  Widget _buildEmptySelectPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medical_information_rounded,
                size: 52, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Không gian làm việc Bác sĩ',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chọn một bệnh nhân từ danh sách hàng đợi bên trái để bắt đầu buổi tư vấn.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyQueuePlaceholder() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Color(0xFFCBD5E1)),
            SizedBox(height: 8),
            Text(
              'Không có bệnh nhân chờ',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatPlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 10),
          Text(
            'Phòng tư vấn sẵn sàng',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Bạn có thể gửi câu chào hoặc dùng câu trả lời mẫu ở bên dưới.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.day == time.day &&
        now.month == time.month &&
        now.year == time.year) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${time.day}/${time.month}';
  }
}
