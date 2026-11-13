import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/call/call_models.dart';
import '../../../core/call/call_signaling_service.dart';
import '../../../core/call/views/call_overlay_view.dart';
import '../../../core/call/views/incoming_call_dialog.dart';
import '../../../core/doctor_management/doctor_management_service.dart';
import '../models/doctor_consultation_models.dart';
import '../services/doctor_consultation_service.dart';
import '../viewmodels/user_viewmodel.dart';

/// Màn hình phòng tư vấn Bác sĩ chuyên khoa trực tuyến theo phong cách Zalo
/// Hỗ trợ tương tác 2 chiều mượt mà, đồng bộ và responsive trên cả Web/Desktop & Mobile
class DoctorConsultationView extends StatefulWidget {
  const DoctorConsultationView({super.key});

  @override
  State<DoctorConsultationView> createState() => _DoctorConsultationViewState();
}

class _DoctorConsultationViewState extends State<DoctorConsultationView> {
  StreamSubscription<CallSessionModel>? _callSubscription;

  @override
  void initState() {
    super.initState();

    // Lắng nghe tín hiệu cuộc gọi đến từ Bác sĩ (Milestone 4) - chỉ hiển thị khi trạng thái đang đổ chuông
    _callSubscription = CallSignalingService.instance.incomingCallStream.listen((session) {
      if (mounted && session.status == CallState.ringing) {
        IncomingCallDialog.show(context, session);
      }
    });

    // Đặt phòng xem mặc định để chặn thông báo nổi khi bệnh nhân đang ở trong phòng tư vấn (R4)
    DoctorConsultationService.instance.patientViewingConversationId =
        'conv_patient_default_doc_an_nguyen';

    // Khởi tạo phòng tư vấn sau khung hình đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final vm = context.read<UserViewModel>();
        vm.initDoctorConsultationIfNeeded();
        DoctorConsultationService.instance.patientViewingConversationId =
            vm.activeConversationId;
      }
    });
  }

  @override
  void dispose() {
    DoctorConsultationService.instance.patientViewingConversationId = null;
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 768;

    return Container(
      color: const Color(0xFFF4F7FB),
      child: isDesktop
          ? _buildDesktopLayout(context, viewModel)
          : _buildMobileLayout(context, viewModel),
    );
  }

  // ===========================================================================
  // LAYOUT DESKTOP / WEB (>= 768px)
  // ===========================================================================

  Widget _buildDesktopLayout(BuildContext context, UserViewModel viewModel) {
    final doctor = viewModel.activeDoctorProfile;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : math.max(650.0, MediaQuery.sizeOf(context).height - 130);

        return SizedBox(
          height: availableHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cột chính: Khung trò chuyện 2 chiều
              Expanded(
                flex: 70,
                child: Column(
                  children: [
                    _buildDoctorHeader(context, doctor, isDesktop: true, viewModel: viewModel),
                    _buildRetentionNoticeBanner(isDesktop: true),
                    Expanded(child: _buildChatTimeline(context, viewModel, isDesktop: true)),
                    if (viewModel.pendingAttachment != null)
                      _buildPendingAttachmentBar(viewModel),
                    _buildQuickActionCarousel(viewModel),
                    _buildInputBar(context, viewModel, isDesktop: true),
                  ],
                ),
              ),

              // Cột phụ bên phải: Hồ sơ bác sĩ & Thông tin hỗ trợ y tế
              Container(
                width: 320,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: Color(0xFFE8EEF5), width: 1)),
                ),
                child: _buildDoctorSidebarProfile(context, doctor, viewModel),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // LAYOUT MOBILE (< 768px)
  // ===========================================================================

  Widget _buildMobileLayout(BuildContext context, UserViewModel viewModel) {
    final doctor = viewModel.activeDoctorProfile;

    return SafeArea(
      top: false,
      bottom: true,
      child: Column(
        children: [
          _buildDoctorHeader(context, doctor, isDesktop: false, viewModel: viewModel),
          _buildRetentionNoticeBanner(isDesktop: false),
          Expanded(child: _buildChatTimeline(context, viewModel, isDesktop: false)),
          if (viewModel.pendingAttachment != null)
            _buildPendingAttachmentBar(viewModel),
          _buildQuickActionCarousel(viewModel),
          _buildInputBar(context, viewModel, isDesktop: false),
        ],
      ),
    );
  }

  // ===========================================================================
  // HEADER BÁC SĨ (CHUẨN ZALO VỚI CHẤM ONLINE & VERIFIED BADGE)
  // ===========================================================================

  Widget _buildDoctorHeader(
    BuildContext context,
    DoctorProfile doctor, {
    required bool isDesktop,
    required UserViewModel viewModel,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 12,
        vertical: isDesktop ? 12 : 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EEF5), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x060D2B6B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: Color(0xFF1E293B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => viewModel.navigateBack(),
              tooltip: 'Quay lại',
            ),
          if (!isDesktop) const SizedBox(width: 8),

          // Avatar Bác sĩ có chấm xanh online (Pulse Dot)
          Stack(
            children: [
              CircleAvatar(
                radius: isDesktop ? 24 : 20,
                backgroundColor: doctor.avatarColor,
                child: Text(
                  doctor.avatarInitials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: isDesktop ? 16 : 14,
                  ),
                ),
              ),
              if (doctor.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: isDesktop ? 13 : 11,
                    height: isDesktop ? 13 : 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Tên Bác sĩ, chuyên khoa & tình trạng trực tuyến
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        doctor.fullName,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D2B6B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Color(0xFF0068FF),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  doctor.statusText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF16A34A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Nút gọi thoại (Audio Call - M4)
          IconButton(
            key: const ValueKey('patient_call_audio_button'),
            icon: const Icon(Icons.phone_rounded, size: 21, color: Color(0xFF2563EB)),
            tooltip: 'Gọi thoại với Bác sĩ',
            onPressed: () => _handleCall(context, doctor, 'audio'),
          ),

          // Nút gọi video (Video Call - M4)
          IconButton(
            key: const ValueKey('patient_call_video_button'),
            icon: const Icon(Icons.videocam_rounded, size: 23, color: Color(0xFF2563EB)),
            tooltip: 'Gọi video khám trực tuyến',
            onPressed: () => _handleCall(context, doctor, 'video'),
          ),

          // Nút hành động nhanh: Đổi bác sĩ, Làm mới & Thông tin
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, size: 22, color: Color(0xFF2563EB)),
            tooltip: 'Đổi Bác sĩ tư vấn',
            onPressed: () => _showDoctorSwitcherDialog(context, viewModel),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 21, color: Color(0xFF64748B)),
            tooltip: 'Làm mới cuộc trò chuyện',
            onPressed: () => _confirmResetConsultation(context, viewModel),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 21, color: Color(0xFF2563EB)),
            tooltip: 'Thông tin bác sĩ',
            onPressed: () => _showDoctorBioModal(context, doctor),
          ),
        ],
      ),
    );
  }

  /// Banner thông báo chính sách tự động xóa tin nhắn sau 1 ngày (24 giờ)
  Widget _buildRetentionNoticeBanner({required bool isDesktop}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 12,
        6,
        isDesktop ? 24 : 12,
        4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.auto_delete_outlined,
              size: 15,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lịch sử tư vấn tự động làm mới sau 1 ngày (24 giờ) để bảo mật thông tin y tế và tối ưu hiệu năng.',
              style: TextStyle(
                fontSize: isDesktop ? 12 : 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TIMELINE TRÒ CHUYỆN 2 CHIỀU (BONG BÓNG ZALO, TÍCH XANH & TYPING INDICATOR)
  // ===========================================================================

  Widget _buildChatTimeline(
    BuildContext context,
    UserViewModel viewModel, {
    required bool isDesktop,
  }) {
    final messages = viewModel.doctorChatMessages;

    return ListView.builder(
      controller: viewModel.doctorChatScrollController,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 14,
        vertical: 16,
      ),
      itemCount: messages.length + (viewModel.isDoctorTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && viewModel.isDoctorTyping) {
          return _buildDoctorTypingBubble(viewModel.activeDoctorProfile, isDesktop: isDesktop);
        }

        final message = messages[index];
        return _buildMessageItem(context, message, viewModel.activeDoctorProfile, isDesktop: isDesktop);
      },
    );
  }

  Widget _buildMessageItem(
    BuildContext context,
    DoctorChatMessage message,
    DoctorProfile doctor, {
    required bool isDesktop,
  }) {
    if (message.isPatient) {
      return _buildPatientBubble(message, isDesktop: isDesktop);
    } else {
      return _buildDoctorBubble(message, doctor, isDesktop: isDesktop);
    }
  }

  // ===========================================================================
  // BONG BÓNG BỆNH NHÂN (PHÍA PHẢI - MÀU XANH ZALO / DỰ ÁN)
  // ===========================================================================

  Widget _buildPatientBubble(DoctorChatMessage message, {required bool isDesktop}) {
    final maxBubbleWidth = isDesktop ? 540.0 : MediaQuery.sizeOf(context).width * 0.78;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB), // Xanh chủ đạo chuẩn dự án & Zalo
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4), // Đuôi bong bóng Zalo
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x182563EB),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Huy hiệu hồ sơ chẩn đoán vết thương AI (nếu có)
                  if (message.attachmentType == ChatAttachmentType.woundScanSummary ||
                      message.attachment?.type == ChatAttachmentType.woundScanSummary)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Hồ sơ chẩn đoán vết thương AI',
                            style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                  // Tệp ảnh đính kèm (nếu có)
                  if (message.hasAttachment)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildPatientAttachmentDisplay(message),
                    ),

                  // Nội dung tin nhắn văn bản
                  Text(
                    message.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Thời gian & Chỉ báo trạng thái gửi kiểu Zalo (đang gửi, đã nhận, đã xem)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.formattedTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildDeliveryStatusIndicator(message.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildPatientAttachmentDisplay(DoctorChatMessage message) {
    final att = message.attachment;
    if (att != null && att.bytes != null && att.bytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          att.bytes!,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 120,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 32),
          ),
        ),
      );
    } else if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
      final url = message.attachmentUrl!;
      if (url.startsWith('data:image')) {
        try {
          final commaIdx = url.indexOf(',');
          if (commaIdx != -1) {
            final decoded = base64Decode(url.substring(commaIdx + 1));
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                decoded,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 32),
                ),
              ),
            );
          }
        } catch (_) {}
      } else if (url.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 120,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 32),
            ),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  // ===========================================================================
  // BONG BÓNG BÁC SĨ (PHÍA TRÁI - CARD TRẮNG CÓ AVATAR & HUY HIỆU BÁC SĨ)
  // ===========================================================================

  Widget _buildDoctorBubble(
    DoctorChatMessage message,
    DoctorProfile doctor, {
    required bool isDesktop,
  }) {
    final horizontalPadding = isDesktop ? 48.0 : 28.0;
    final avatarAndSpacing = 34.0 + 8.0;
    final maxBubbleWidth = isDesktop ? 540.0 : (MediaQuery.sizeOf(context).width - horizontalPadding - avatarAndSpacing);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: doctor.avatarColor,
            child: Text(
              doctor.avatarInitials,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),

          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4), // Đuôi bong bóng bên trái
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(
                  color: message.isEmergencyWarning
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFE2E8F0),
                  width: message.isEmergencyWarning ? 1.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080D2B6B),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên bác sĩ + Huy hiệu
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        message.isAi ? 'AI Bác sĩ Trợ lý (MedGemma / Gemini)' : doctor.fullName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: message.isAi ? const Color(0xFF7C3AED) : const Color(0xFF1D4ED8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: message.isAi ? const Color(0xFFFAF5FF) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                          border: message.isAi ? Border.all(color: const Color(0xFFDDD6FE)) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.isAi) ...[
                              const Icon(Icons.auto_awesome, size: 10, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              message.isAi ? 'AI Trực phòng' : 'Bác sĩ phụ trách',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: message.isAi ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Cảnh báo khẩn cấp (nếu có)
                  if (message.isEmergencyWarning)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF87171)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'CẢNH BÁO LÂM SÀNG CẤP',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Nội dung tin nhắn y khoa
                  Text(
                    message.content,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  // Ghi chú lâm sàng / Triage
                  if (message.doctorNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        message.doctorNote!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),

                  // Timestamp
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      message.formattedTime,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
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
  // CHỈ BÁO TRẠNG THÁI GỬI (ĐỒNG HỒ CÁT, 1 TÍCH, 2 TÍCH XÁM, "ĐÃ XEM")
  // ===========================================================================

  Widget _buildDeliveryStatusIndicator(MessageDeliveryStatus status) {
    switch (status) {
      case MessageDeliveryStatus.sending:
        return const Icon(Icons.access_time_rounded, size: 12, color: Colors.white70);
      case MessageDeliveryStatus.sent:
        return const Icon(Icons.check_rounded, size: 13, color: Colors.white70);
      case MessageDeliveryStatus.delivered:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 13, color: Colors.white70),
            SizedBox(width: 1),
            Icon(Icons.check_rounded, size: 13, color: Colors.white70),
          ],
        );
      case MessageDeliveryStatus.read:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Đã xem',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(width: 2),
              Icon(Icons.done_all_rounded, size: 12, color: Colors.white),
            ],
          ),
        );
      case MessageDeliveryStatus.failed:
        return const Icon(Icons.error_outline_rounded, size: 12, color: Color(0xFFFCA5A5));
    }
  }

  // ===========================================================================
  // HIỆU ỨNG BÁC SĨ ĐANG SOẠN TIN (ANIMATED TYPING INDICATOR BUBBLE)
  // ===========================================================================

  Widget _buildDoctorTypingBubble(DoctorProfile doctor, {required bool isDesktop}) {
    return DoctorTypingBubble(doctor: doctor, isDesktop: isDesktop);
  }

  // ===========================================================================
  // CAROUSEL GỢI Ý PHẢN HỒI NHANH (QUICK ACTION CHIPS CAROUSEL)
  // ===========================================================================

  Widget _buildQuickActionCarousel(UserViewModel viewModel) {
    final messages = viewModel.doctorChatMessages;
    List<DoctorQuickActionOption> quickReplies = const [];

    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].quickReplies.isNotEmpty) {
        quickReplies = messages[i].quickReplies;
        break;
      }
    }

    if (quickReplies.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = quickReplies[index];
          return ActionChip(
            avatar: option.icon != null
                ? Icon(option.icon, size: 14, color: const Color(0xFF1D4ED8))
                : null,
            label: Text(
              option.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D4ED8),
              ),
            ),
            backgroundColor: const Color(0xFFEFF6FF),
            side: const BorderSide(color: Color(0xFFBFDBFE), width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () => viewModel.selectDoctorQuickReply(option),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // THANH ĐÍNH KÈM ĐANG CHỜ (PENDING ATTACHMENT BAR)
  // ===========================================================================

  Widget _buildPendingAttachmentBar(UserViewModel viewModel) {
    final attachment = viewModel.pendingAttachment;
    if (attachment == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (attachment.hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                attachment.bytes!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFFE2E8F0),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 20),
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.fileName ?? 'Ảnh chụp vết thương',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Sẵn sàng gửi kèm cùng tin nhắn',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
            onPressed: () => viewModel.removePendingAttachment(),
            tooltip: 'Hủy đính kèm',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // THANH NHẬP LIỆU CHUẨN ZALO (ROUNDED CAPSULE INPUT BAR & SEND BUTTON)
  // ===========================================================================

  Widget _buildInputBar(
    BuildContext context,
    UserViewModel viewModel, {
    required bool isDesktop,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16 : 8,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          // Nút đính kèm ảnh từ thư viện
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, size: 22, color: Color(0xFF2563EB)),
            tooltip: 'Chọn ảnh từ thư viện',
            onPressed: () => viewModel.pickAndAttachImage(context),
          ),

          // Nút chụp ảnh từ camera
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, size: 22, color: Color(0xFF64748B)),
            tooltip: 'Chụp ảnh từ camera',
            onPressed: () => viewModel.captureAndAttachImage(context),
          ),

          // Ô nhập văn bản hình viên thuốc bo tròn (Zalo Capsule)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
              ),
              child: TextField(
                controller: viewModel.doctorChatInputController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => viewModel.sendDoctorChatMessage(),
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn tư vấn cho bác sĩ...',
                  hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Nút gửi tin nhắn hình tròn xanh nổi bật
          Material(
            color: const Color(0xFF2563EB),
            shape: const CircleBorder(),
            elevation: 1,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => viewModel.sendDoctorChatMessage(),
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
  // SIDEBAR HỒ SƠ BÁC SĨ (CHO DESKTOP / WEB)
  // ===========================================================================

  Widget _buildDoctorSidebarProfile(
    BuildContext context,
    DoctorProfile doctor,
    UserViewModel viewModel,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: doctor.avatarColor,
            child: Text(
              doctor.avatarInitials,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            doctor.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B)),
          ),
          const SizedBox(height: 4),
          Text(
            doctor.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 6),
          Text(
            doctor.hospital,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Thống kê: Đánh giá, lượt tư vấn, năm kinh nghiệm
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: _buildStatColumn('${doctor.rating} ⭐', 'Đánh giá')),
                _buildStatDivider(),
                Expanded(child: _buildStatColumn('${doctor.consultationCount}+', 'Lượt tư vấn')),
                _buildStatDivider(),
                Expanded(child: _buildStatColumn('${doctor.experienceYears} năm', 'Kinh nghiệm')),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Thẻ thông tin y tế khẩn cấp
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tư vấn sơ cứu miễn phí',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Hỗ trợ sơ cứu kịp thời và phân loại nguy cơ trước khi chuyển viện.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Nút đổi bác sĩ tư vấn
          OutlinedButton.icon(
            onPressed: () => _showDoctorSwitcherDialog(context, viewModel),
            icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF2563EB)),
            label: const Text('Đổi Bác sĩ tư vấn', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size.fromHeight(40),
            ),
          ),
          const SizedBox(height: 10),

          // Nút gọi cấp cứu khẩn cấp 115
          OutlinedButton.icon(
            onPressed: () => _call115(context),
            icon: const Icon(Icons.phone_in_talk, size: 16, color: Color(0xFFDC2626)),
            label: const Text(
              'Cấp cứu SOS 115',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size.fromHeight(42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B)),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 26, color: const Color(0xFFCBD5E1));
  }

  static Future<void> _call115(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: '115'),
        webOnlyWindowName: '_top',
      );
      if (opened) return;
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hãy dùng điện thoại để gọi cấp cứu 115.')),
    );
  }

  void _confirmResetConsultation(BuildContext context, UserViewModel viewModel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Làm mới phòng tư vấn?'),
        content: const Text('Lịch sử tin nhắn hiện tại sẽ được khởi tạo lại về tin chào ban đầu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              viewModel.clearDoctorChatHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _showDoctorBioModal(BuildContext context, DoctorProfile doctor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: doctor.avatarColor,
                  child: Text(doctor.avatarInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B))),
                      Text(doctor.title, style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB))),
                      Text(doctor.hospital, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Text('• Chuyên khoa: ${doctor.specialty}', style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 6),
            Text('• Cơ sở y tế: ${doctor.hospital}', style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 6),
            Text('• Địa chỉ công tác: ${doctor.workplaceAddress}', style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 6),
            Text('• Số điện thoại: ${doctor.phoneNumber}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
            const SizedBox(height: 6),
            Text('• Thâm niên công tác: ${doctor.experienceYears} năm kinh nghiệm cấp cứu ngoại viện', style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 6),
            Text('• Lượt phản hồi & tư vấn: ${doctor.consultationCount}+ ca bệnh thành công', style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 6),
            Text('• Chi phí: ${doctor.consultationFee}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCall(BuildContext context, DoctorProfile doctor, String callType) async {
    final session = await CallSignalingService.instance.startCall(
      callerId: 'patient_current',
      callerName: 'Bệnh nhân',
      calleeId: doctor.id,
      calleeName: doctor.fullName,
      callType: callType,
      isCalleeOnline: doctor.isOnline,
    );
    if (!mounted) return;
    if (session.status == CallState.failed || session.status == CallState.busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session.failureReason ?? 'Không thể thực hiện cuộc gọi.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }
    CallOverlayView.show(context, session: session);
  }

  void _showDoctorSwitcherDialog(BuildContext context, UserViewModel viewModel) {
    final doctors = DoctorManagementService.instance.doctors;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Chọn Bác sĩ phụ trách tư vấn',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bệnh nhân có thể đổi bác sĩ chuyên khoa phù hợp với tình trạng tổn thương.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: doctors.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final doc = doctors[idx];
                      final isSelected = viewModel.activeDoctorProfile.id == doc.id;
                      final unread = DoctorConsultationService.instance.getUnreadCount(
                        'conv_${viewModel.currentPatientId}_${doc.id}',
                        'patient',
                      );

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: doc.avatarColor,
                          child: Text(doc.avatarInitials, style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(doc.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${doc.title} • ${doc.specialty}\n${doc.workplaceAddress}'),
                        isThreeLine: true,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (unread > 0)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        unread > 99 ? '99+' : unread.toString(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                        onTap: () {
                          viewModel.switchDoctor(doc);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đã chuyển phòng khám sang ${doc.fullName}.')),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Widget hiển thị bong bóng "Bác sĩ đang phản hồi..." với hoạt ảnh 3 chấm độc lập
/// Tự quản lý vòng đời AnimationController, đảm bảo build() của màn hình cha là hàm thuần túy
class DoctorTypingBubble extends StatefulWidget {
  final DoctorProfile doctor;
  final bool isDesktop;

  const DoctorTypingBubble({
    super.key,
    required this.doctor,
    required this.isDesktop,
  });

  @override
  State<DoctorTypingBubble> createState() => _DoctorTypingBubbleState();
}

class _DoctorTypingBubbleState extends State<DoctorTypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: doctor.avatarColor,
            child: Text(
              doctor.avatarInitials,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x060D2B6B),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAnimatedDots(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${doctor.fullName} đang phản hồi...',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final double value = math.sin((_dotsController.value * 2 * math.pi) - (i * 0.7));
            final double offset = (value * 3).clamp(-3.0, 3.0);

            return Transform.translate(
              offset: Offset(0, offset),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
