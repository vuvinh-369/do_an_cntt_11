// File: lib/core/widgets/in_app_notification_host.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/user/models/doctor_consultation_models.dart';
import '../../features/user/services/doctor_consultation_service.dart';
import '../../features/user/viewmodels/user_viewmodel.dart';
import '../doctor_management/doctor_management_service.dart';

/// Widget quản lý và hiển thị thông báo nổi hai chiều (In-App Floating Banner)
/// Được gắn tại MaterialApp.builder để hiển thị toàn cục trên tất cả các màn hình (Milestone M4 - R4).
class InAppNotificationHost extends StatefulWidget {
  final Widget child;
  final void Function(InAppNotificationItem item)? onNotificationTap;
  final Duration autoDismissDuration;

  const InAppNotificationHost({
    super.key,
    required this.child,
    this.onNotificationTap,
    this.autoDismissDuration = const Duration(seconds: 4),
  });

  @override
  State<InAppNotificationHost> createState() => _InAppNotificationHostState();
}

class _InAppNotificationHostState extends State<InAppNotificationHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  StreamSubscription<InAppNotificationItem>? _notificationSubscription;
  InAppNotificationItem? _activeNotification;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    // Lắng nghe luồng thông báo nổi từ DoctorConsultationService
    _notificationSubscription = DoctorConsultationService
        .instance.inAppNotificationStream
        .listen(_handleIncomingNotification);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _handleIncomingNotification(InAppNotificationItem item) {
    if (!mounted) return;

    _dismissTimer?.cancel();
    setState(() {
      _activeNotification = item;
    });

    _animController.forward(from: 0.0);

    _dismissTimer = Timer(widget.autoDismissDuration, () {
      _dismissNotification();
    });
  }

  void _dismissNotification() {
    if (!mounted || _activeNotification == null) return;
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _activeNotification = null;
        });
      }
    });
  }

  void _handleTapNotification(InAppNotificationItem item) {
    _dismissTimer?.cancel();
    _dismissNotification();

    if (widget.onNotificationTap != null) {
      widget.onNotificationTap!(item);
      return;
    }

    // Cơ chế điều hướng sâu mặc định (Click-to-chat Deep Navigation)
    _performDefaultDeepNavigation(item);
  }

  void _performDefaultDeepNavigation(InAppNotificationItem item) {
    try {
      if (item.targetRole == NotificationTargetRole.patient) {
        // Đối tượng nhận là Bệnh nhân: Mở phòng tư vấn trên giao diện người dùng
        final userVm = context.read<UserViewModel>();
        userVm.navigateToDoctorConsultation();

        if (item.doctorId != null && item.doctorId!.isNotEmpty) {
          final doc = DoctorManagementService.instance.getDoctorById(item.doctorId!);
          if (doc != null) {
            userVm.switchDoctor(doc);
          }
        }
      } else {
        // Đối tượng nhận là Bác sĩ: Chuyển active room trong DoctorWorkspaceView
        DoctorConsultationService.instance.currentViewingConversationId =
            item.conversationId;
        DoctorConsultationService.instance
            .requestNavigationToConversation(item.conversationId);
      }
    } catch (e) {
      debugPrint('[InAppNotificationHost] Lỗi điều hướng sâu click-to-chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        // Toàn bộ ứng dụng bên dưới
        widget.child,

        // Floating Banner Overlay ở đỉnh màn hình
        if (_activeNotification != null)
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildBannerCard(_activeNotification!),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBannerCard(InAppNotificationItem item) {
    final isDoctorTarget = item.targetRole == NotificationTargetRole.doctor;
    final primaryColor = isDoctorTarget
        ? const Color(0xFF2563EB) // Blue cho Bác sĩ nhận thông báo
        : const Color(0xFF0D9488); // Teal/Emerald cho Bệnh nhân nhận phản hồi từ Bác sĩ

    final headerTitle = isDoctorTarget
        ? 'Bệnh nhân: ${item.senderName}'
        : 'Bác sĩ: ${item.senderName}';

    final categoryBadge = isDoctorTarget
        ? 'Ca tư vấn mới'
        : 'Phản hồi y tế';

    return Dismissible(
      key: ValueKey('banner_${item.id}_${item.timestamp.millisecondsSinceEpoch}'),
      direction: DismissDirection.up,
      onDismissed: (_) {
        _dismissTimer?.cancel();
        setState(() {
          _activeNotification = null;
        });
      },
      child: Material(
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: InkWell(
          onTap: () => _handleTapNotification(item),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withValues(alpha: 0.28), width: 1.2),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  primaryColor.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar / Icon biểu trưng
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.24),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isDoctorTarget
                          ? Icons.person_pin_rounded
                          : Icons.health_and_safety_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nội dung tin nhắn
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryBadge,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              headerTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            item.formattedTime,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.content,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Nút Đóng & Icon chuyển tiếp
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        _dismissTimer?.cancel();
                        _dismissNotification();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
