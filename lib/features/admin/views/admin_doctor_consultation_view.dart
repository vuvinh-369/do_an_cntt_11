// File: lib/features/admin/views/admin_doctor_consultation_view.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/call/call_models.dart';
import '../../../core/call/call_signaling_service.dart';
import '../../../core/call/views/call_overlay_view.dart';
import '../../../core/call/views/incoming_call_dialog.dart';
import '../../../core/doctor_management/doctor_management_service.dart';
import '../../user/models/doctor_consultation_models.dart';
import '../../user/services/doctor_consultation_service.dart';

/// Trung tâm Giám sát & Điều phối Tư vấn Telehealth Toàn Bệnh viện (Admin Oversight Dashboard)
/// Cho phép Admin theo dõi tổng thể KPIs, lọc giám sát theo từng bác sĩ hoặc toàn viện,
/// thanh tra toàn bộ tiến trình hội thoại giữa bác sĩ và bệnh nhân, kiểm toán AI fallback và gửi chỉ đạo hỗ trợ.
class AdminDoctorConsultationView extends StatefulWidget {
  const AdminDoctorConsultationView({super.key});

  @override
  State<AdminDoctorConsultationView> createState() =>
      _AdminDoctorConsultationViewState();
}

class _AdminDoctorConsultationViewState
    extends State<AdminDoctorConsultationView> {
  // Bộ lọc bác sĩ: null hoặc 'all' nghĩa là giám sát toàn viện, hoặc bác sĩ cụ thể
  DoctorProfile? _selectedSupervisedDoctor;

  // Cuộc trò chuyện đang chọn để thanh tra
  String? _selectedConversationId;

  // Controllers
  final TextEditingController _searchQueueCtrl = TextEditingController();
  final TextEditingController _adminNoteCtrl = TextEditingController();
  final ScrollController _timelineScrollCtrl = ScrollController();

  // Banner thông báo realtime
  String? _activeBannerAlert;
  Timer? _bannerDismissTimer;
  StreamSubscription<String>? _bannerAlertSub;
  StreamSubscription<CallSessionModel>? _incomingCallSub;

  // Lọc hàng đợi: 'all', 'unread', 'ai_assisted', 'emergency'
  String _queueFilter = 'all';

  @override
  void initState() {
    super.initState();

    _incomingCallSub =
        CallSignalingService.instance.incomingCallStream.listen((session) {
      if (mounted) {
        IncomingCallDialog.show(context, session);
      }
    });

    DoctorManagementService.instance.addListener(_onServiceChanged);
    DoctorConsultationService.instance.addListener(_onServiceChanged);

    _listenToBannerAlerts();
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    DoctorManagementService.instance.removeListener(_onServiceChanged);
    DoctorConsultationService.instance.removeListener(_onServiceChanged);
    _bannerAlertSub?.cancel();
    _bannerDismissTimer?.cancel();
    _searchQueueCtrl.dispose();
    _adminNoteCtrl.dispose();
    _timelineScrollCtrl.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _listenToBannerAlerts() {
    _bannerAlertSub =
        DoctorConsultationService.instance.bannerAlertStream.listen((alertText) {
      if (!mounted) return;

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

  Future<void> _handleSendAdminSupportMessage() async {
    final text = _adminNoteCtrl.text.trim();
    if (text.isEmpty || _selectedConversationId == null) return;

    final convId = _selectedConversationId!;
    _adminNoteCtrl.clear();

    await DoctorConsultationService.instance.sendMessage(
      conversationId: convId,
      senderType: 'system',
      senderId: 'admin_supervisor',
      senderName: 'Ban Giám sát Bệnh viện (Admin)',
      content: '📌 [ĐIỀU PHỐI QUẢN TRỊ]: $text',
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
  }

  // ===========================================================================
  // ROOT BUILD WITH BOUNDED LAYOUT DEFENSE
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : math.max(
                680.0,
                MediaQuery.sizeOf(context).height - (isMobile ? 140 : 160),
              );

        return SizedBox(
          height: availableHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 20,
              vertical: isMobile ? 10 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. KPI Overview Cards
                _buildKpiOverviewRow(isMobile),
                const SizedBox(height: 12),

                // 2. Doctor Filter & Supervision Bar
                _buildSupervisionFilterBar(isMobile),
                const SizedBox(height: 10),

                // 3. Banner Alert (if any)
                if (_activeBannerAlert != null) ...[
                  _buildInAppBannerAlert(),
                  const SizedBox(height: 10),
                ],

                // 4. Main Body: Split view on Desktop, Stack on Mobile
                Expanded(
                  child: isMobile ? _buildMobileBody() : _buildDesktopBody(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. TOP KPI OVERVIEW CARDS
  // ===========================================================================
  Widget _buildKpiOverviewRow(bool isMobile) {
    final allQueue = DoctorConsultationService.instance.queue;
    final totalSessions = allQueue.length;
    final waitingSessions =
        allQueue.where((item) => item.unreadCount > 0).length;
    final onlineDoctors =
        DoctorManagementService.instance.doctors.where((d) => d.isOnline).length;
    final totalDoctors = DoctorManagementService.instance.doctors.length;
    final aiAssistedCount =
        allQueue.where((item) => item.hasAiFallbackResponse).length;

    final cards = [
      _buildKpiCard(
        title: 'Tổng phiên tư vấn',
        value: '$totalSessions',
        subtitle: 'Toàn viện',
        icon: Icons.forum_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
      _buildKpiCard(
        title: 'Bệnh nhân chờ',
        value: '$waitingSessions',
        subtitle: waitingSessions > 0 ? 'Cần phản hồi' : 'Đã phản hồi',
        icon: Icons.hourglass_top_rounded,
        color: waitingSessions > 0
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        bgColor: waitingSessions > 0
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFECFDF5),
      ),
      _buildKpiCard(
        title: 'Bác sĩ trực tuyến',
        value: '$onlineDoctors / $totalDoctors',
        subtitle: 'Sẵn sàng tư vấn',
        icon: Icons.verified_user_rounded,
        color: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
      ),
      _buildKpiCard(
        title: 'AI tự động hỗ trợ',
        value: '$aiAssistedCount',
        subtitle: totalSessions > 0
            ? '${((aiAssistedCount / totalSessions) * 100).toStringAsFixed(0)}% ca trực'
            : '0%',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFFAF5FF),
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => SizedBox(width: 175, child: cards[index]),
        ),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: c,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x050D2B6B), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. DOCTOR FILTER & SUPERVISION BAR
  // ===========================================================================
  Widget _buildSupervisionFilterBar(bool isMobile) {
    final allDoctors = DoctorManagementService.instance.doctors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                size: 20, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          const Text(
            'Giám sát:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 8),

          // Dropdown Doctor Filter
          Flexible(
            child: PopupMenuButton<DoctorProfile?>(
              tooltip: 'Lọc bác sĩ giám sát',
              initialValue: _selectedSupervisedDoctor,
              onSelected: (doc) {
                setState(() {
                  _selectedSupervisedDoctor = doc;
                  _selectedConversationId = null;
                });
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem<DoctorProfile?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.domain_rounded,
                            size: 18, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text(
                          'Tất cả bác sĩ (Toàn bệnh viện)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  ...allDoctors.map((doc) {
                    return PopupMenuItem<DoctorProfile?>(
                      value: doc,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: doc.avatarColor,
                            child: Text(
                              doc.avatarInitials,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${doc.fullName} (${doc.specialty})',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: doc.isOnline
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ];
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedSupervisedDoctor == null) ...[
                      const Icon(Icons.domain_rounded,
                          size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Toàn bệnh viện (Tất cả bác sĩ)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      CircleAvatar(
                        radius: 10,
                        backgroundColor:
                            _selectedSupervisedDoctor!.avatarColor,
                        child: Text(
                          _selectedSupervisedDoctor!.avatarInitials,
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _selectedSupervisedDoctor!.fullName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const Icon(Icons.arrow_drop_down,
                        size: 18, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. IN-APP BANNER ALERT
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
  // 4. MAIN BODY (SPLIT VIEW ON DESKTOP, STACK ON MOBILE)
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
          // Left pane: Patient queue (370px)
          SizedBox(
            width: 370,
            child: _buildPatientQueuePane(isMobile: false),
          ),
          const VerticalDivider(
              width: 1, thickness: 1, color: Color(0xFFE8EEF5)),
          // Right pane: Inspector
          Expanded(
            child: _selectedConversationId == null
                ? _buildEmptySelectPlaceholder()
                : _buildChatInspectorPane(isMobile: false),
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
                  'Quay lại Hàng đợi giám sát',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildChatInspectorPane(isMobile: true)),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. PATIENT QUEUE PANE (LEFT)
  // ===========================================================================
  Widget _buildPatientQueuePane({required bool isMobile}) {
    // Lấy queue theo bộ lọc bác sĩ: nếu null hoặc 'all', truyền 'all' để lấy toàn viện
    final doctorIdFilter = _selectedSupervisedDoctor?.id ?? 'all';
    final rawQueue =
        DoctorConsultationService.instance.getDoctorQueue(doctorIdFilter);

    final sortedQueue = List<ConversationQueueItem>.from(rawQueue)
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    final query = _searchQueueCtrl.text.trim().toLowerCase();
    final filtered = sortedQueue.where((item) {
      final matchQuery = query.isEmpty ||
          item.patientName.toLowerCase().contains(query) ||
          item.lastMessageContent.toLowerCase().contains(query) ||
          (item.patientPhone != null && item.patientPhone!.contains(query));

      final matchTab = _queueFilter == 'all' ||
          (_queueFilter == 'unread' && item.unreadCount > 0) ||
          (_queueFilter == 'ai_assisted' && item.hasAiFallbackResponse) ||
          (_queueFilter == 'emergency' &&
              (item.lastMessageContent.toLowerCase().contains('cấp cứu') ||
                  item.lastMessageContent.toLowerCase().contains('chảy máu')));

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
              hintText: 'Tìm theo bệnh nhân, SĐT, nội dung...',
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

        // Tabs lọc nhanh
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả (${sortedQueue.length})'),
                const SizedBox(width: 5),
                _buildFilterChip('unread', 'Chờ xử lý'),
                const SizedBox(width: 5),
                _buildFilterChip('ai_assisted', 'AI hỗ trợ'),
                const SizedBox(width: 5),
                _buildFilterChip('emergency', 'Cấp cứu'),
              ],
            ),
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

                                  // Badge bác sĩ phụ trách
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_pin_rounded,
                                            size: 11,
                                            color: Color(0xFF475569)),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            item.doctorName.isNotEmpty
                                                ? item.doctorName
                                                : 'Bác sĩ phụ trách',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF334155),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 4),
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

                                  // Badges
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      if (item.hasAiFallbackResponse)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFAF5FF),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: const Color(0xFFDDD6FE)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.auto_awesome,
                                                  size: 10,
                                                  color: Color(0xFF7C3AED)),
                                              SizedBox(width: 3),
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
  // 6. CHAT INSPECTOR PANE (RIGHT)
  // ===========================================================================
  Widget _buildChatInspectorPane({required bool isMobile}) {
    final convId = _selectedConversationId!;

    return Column(
      children: [
        // Inspector Top Header
        _buildInspectorTopBar(convId),
        const Divider(height: 1, color: Color(0xFFE8EEF5)),
        Container(
          width: double.infinity,
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_delete_outlined, size: 14, color: Color(0xFF64748B)),
              SizedBox(width: 6),
              Text(
                'Lịch sử chat tự động dọn dẹp sau 1 ngày (24 giờ) để tối ưu lưu trữ hệ thống.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        // Message List Stream
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

        // Admin Support / Coordination Bar
        _buildAdminSupportBar(),
      ],
    );
  }

  Widget _buildInspectorTopBar(String convId) {
    final allQueue = DoctorConsultationService.instance.queue;
    final convItem = allQueue.firstWhere(
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'Phụ trách: ${convItem.doctorName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  '🛡️ Chế độ Giám sát Telehealth Toàn Viện • Kiểm toán minh bạch 2 chiều',
                  style: TextStyle(fontSize: 11, color: Color(0xFF059669)),
                ),
              ],
            ),
          ),

          // Action Call buttons preserved for supervisor assistance
          IconButton(
            key: const ValueKey('admin_call_audio_button'),
            icon: const Icon(Icons.phone_outlined,
                color: Color(0xFF2563EB), size: 20),
            tooltip: 'Giám sát âm thanh',
            onPressed: () => _initiateCall(convItem, 'audio'),
          ),
          IconButton(
            key: const ValueKey('admin_call_video_button'),
            icon: const Icon(Icons.videocam_outlined,
                color: Color(0xFF2563EB), size: 22),
            tooltip: 'Giám sát video',
            onPressed: () => _initiateCall(convItem, 'video'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateCall(
      ConversationQueueItem convItem, String callType) async {
    final session = await CallSignalingService.instance.startCall(
      callerId: 'admin_supervisor',
      callerName: 'Giám sát Viện',
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
              Text(session.failureReason ?? 'Không thể kết nối giám sát.'),
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
    } else if (msg.isSystem) {
      return _buildSystemBubble(msg);
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    'Bệnh nhân (${msg.senderName ?? "Ẩn danh"})',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
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
                        'Cảnh báo cấp cứu khẩn cấp',
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.medical_services_outlined,
                      size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    msg.senderName ?? 'Bác sĩ trực',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
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

  Widget _buildSystemBubble(DoctorChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Flexible(
                child: SelectableText(
                  msg.content,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
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
                    'AI Bác sĩ Trợ lý (Tự động hỗ trợ khi bác sĩ vắng)',
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
          errorBuilder: (_, __, ___) => _buildBrokenImagePlaceholder(),
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
                errorBuilder: (_, __, ___) => _buildBrokenImagePlaceholder(),
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
            errorBuilder: (_, __, ___) => _buildBrokenImagePlaceholder(),
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

  Widget _buildAdminSupportBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EEF5))),
      ),
      child: Row(
        children: [
          const Icon(Icons.security_rounded,
              color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _adminNoteCtrl,
              minLines: 1,
              maxLines: 2,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSendAdminSupportMessage(),
              decoration: const InputDecoration(
                hintText: 'Gửi tin nhắn chỉ đạo / hỗ trợ từ Ban Giám Sát...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Gửi chỉ đạo',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            onPressed: _handleSendAdminSupportMessage,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. PLACEHOLDERS
  // ===========================================================================
  Widget _buildEmptySelectPlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.policy_outlined, size: 54, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text(
            'Chọn một ca tư vấn để giám sát',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Chọn một phiên hội thoại từ danh sách bên trái để thanh tra tiến trình và nội dung.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
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
              'Không có ca tư vấn nào theo bộ lọc này',
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
            'Chưa có tin nhắn trong phiên tư vấn này',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
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
