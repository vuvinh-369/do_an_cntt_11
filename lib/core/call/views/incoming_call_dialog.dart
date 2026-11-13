// File: lib/core/call/views/incoming_call_dialog.dart
import 'package:flutter/material.dart';

import '../call_models.dart';
import '../call_signaling_service.dart';
import 'call_overlay_view.dart';

/// Hộp thoại thông báo cuộc gọi đến (Incoming Call Modal Dialog)
/// Hiển thị thông tin người gọi, loại cuộc gọi (thoại/video), hiệu ứng đổ chuông,
/// nút Từ chối (đỏ) và nút Trả lời (xanh).
class IncomingCallDialog extends StatefulWidget {
  final CallSessionModel session;

  const IncomingCallDialog({
    super.key,
    required this.session,
  });

  /// Hàm tiện ích hiển thị hộp thoại cuộc gọi đến
  static Future<void> show(BuildContext context, CallSessionModel session) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingCallDialog(session: session),
    );
  }

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Lắng nghe trạng thái cuộc gọi để tự đóng nếu cuộc gọi bị hủy/kết thúc từ đầu dây bên kia
    CallSignalingService.instance.addListener(_handleCallStateChange);
  }

  void _handleCallStateChange() {
    final active = CallSignalingService.instance.activeSession;
    if (active == null ||
        active.callId != widget.session.callId ||
        active.status == CallState.ended ||
        active.status == CallState.rejected ||
        active.status == CallState.missed ||
        active.status == CallState.failed) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    }
  }

  @override
  void dispose() {
    CallSignalingService.instance.removeListener(_handleCallStateChange);
    _pulseController.dispose();
    super.dispose();
  }

  void _rejectCall() {
    CallSignalingService.instance.rejectCall(widget.session.callId);
    if (mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  void _acceptCall() {
    CallSignalingService.instance.acceptCall(widget.session.callId);
    if (mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
      // Mở màn hình đàm thoại trực tiếp
      CallOverlayView.show(context, session: widget.session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.session.callType == 'video';
    final callTypeLabel = isVideo ? 'Cuộc gọi video đến...' : 'Cuộc gọi thoại đến...';
    final callerName = widget.session.callerName.isNotEmpty
        ? widget.session.callerName
        : 'Người gọi';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loại cuộc gọi badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isVideo
                      ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                      : const Color(0xFF16A34A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isVideo
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                        : const Color(0xFF22C55E).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.phone_in_talk_rounded,
                      size: 16,
                      color: isVideo ? const Color(0xFF60A5FA) : const Color(0xFF4ADE80),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      callTypeLabel,
                      style: TextStyle(
                        color: isVideo ? const Color(0xFF93C5FD) : const Color(0xFF86EFAC),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Ringing Avatar với hiệu ứng Pulse Animation
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isVideo ? const Color(0xFF2563EB) : const Color(0xFF10B981))
                        .withValues(alpha: 0.15),
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: isVideo
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF0D9488),
                    child: Text(
                      callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tên người gọi
              Text(
                callerName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Trạng thái đổ chuông
              const Text(
                'Đang đổ chuông...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 36),

              // Nút hành động: Từ chối (Đỏ) và Trả lời (Xanh)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Nút Từ chối
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        key: const ValueKey('incoming_call_reject_button'),
                        onTap: _rejectCall,
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x66EF4444),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Từ chối',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Nút Trả lời
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        key: const ValueKey('incoming_call_accept_button'),
                        onTap: _acceptCall,
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x6622C55E),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Trả lời',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
