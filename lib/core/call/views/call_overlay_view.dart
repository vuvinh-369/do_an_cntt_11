// File: lib/core/call/views/call_overlay_view.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../call_models.dart';
import '../call_signaling_service.dart';

/// Màn hình / Lớp phủ cuộc gọi trực tiếp (Active Call Overlay View)
/// Hỗ trợ cả Cuộc gọi thoại (Audio Call) và Cuộc gọi video (Video Call)
/// Cho phép bật/tắt Mic, bật/tắt Camera, đổi camera trước/sau và kết thúc cuộc gọi.
class CallOverlayView extends StatefulWidget {
  final CallSessionModel session;

  const CallOverlayView({
    super.key,
    required this.session,
  });

  /// Hiển thị toàn màn hình lớp phủ cuộc gọi
  static Future<void> show(
    BuildContext context, {
    required CallSessionModel session,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (ctx, anim1, anim2) => CallOverlayView(session: session),
        transitionsBuilder: (ctx, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
      ),
    );
  }

  @override
  State<CallOverlayView> createState() => _CallOverlayViewState();
}

class _CallOverlayViewState extends State<CallOverlayView> {
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    CallSignalingService.instance.addListener(_onCallStateChanged);
  }

  void _onCallStateChanged() {
    if (!mounted) return;
    setState(() {});

    final session = CallSignalingService.instance.activeSession;
    if (session == null ||
        session.status == CallState.ended ||
        session.status == CallState.rejected ||
        session.status == CallState.busy ||
        session.status == CallState.failed) {
      _scheduleAutoClose();
    }
  }

  void _scheduleAutoClose() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    CallSignalingService.instance.removeListener(_onCallStateChanged);
    super.dispose();
  }

  void _handleEndCall(CallSessionModel currentSession) {
    CallSignalingService.instance.endCall(currentSession.callId);
    if (mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = CallSignalingService.instance.activeSession ?? widget.session;
    final isVideo = active.callType == 'video';
    final targetName = active.calleeName.isNotEmpty ? active.calleeName : active.callerName;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Nếu là Cuộc gọi video và đã kết nối -> Hiển thị khung hình Video
            if (isVideo)
              _buildVideoBackground(active)
            else
              _buildAudioBackground(active, targetName),

            // 2. Thanh thông tin trên cùng (Top Bar)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                          size: 15,
                          color: const Color(0xFF60A5FA),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isVideo ? 'Tư vấn Video Y tế' : 'Tư vấn Thoại Y tế',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Nút thu nhỏ / đóng nhanh
                  IconButton(
                    key: const ValueKey('call_overlay_close_button'),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                    onPressed: () => _handleEndCall(active),
                    tooltip: 'Đóng cuộc gọi',
                  ),
                ],
              ),
            ),

            // 3. Thanh điều khiển cuộc gọi dưới cùng (Bottom Control Bar)
            Positioned(
              bottom: 36,
              left: 20,
              right: 20,
              child: _buildCallControls(active, isVideo),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // KHUNG NỀN CHO CUỘC GỌI VIDEO
  // ===========================================================================

  Widget _buildVideoBackground(CallSessionModel session) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0B132B),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video từ đối phương (Remote Video Stream Feed)
            if (!session.isCameraEnabled)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.videocam_off_rounded,
                        size: 54,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera đã tắt',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(
                          session.calleeName.isNotEmpty ? session.calleeName[0].toUpperCase() : 'B',
                          style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        session.calleeName,
                        style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _buildCallStatusText(session),
                        key: const ValueKey('call_overlay_status_text'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: session.status == CallState.connected
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Cửa sổ nhỏ góc trên (Local Video Preview: Camera trước / Camera sau)
            if (session.status == CallState.connected)
              Positioned(
                top: 80,
                right: 20,
                child: Container(
                  width: 100,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!session.isCameraEnabled)
                        const Icon(Icons.videocam_off, color: Colors.white54, size: 24)
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              session.isUsingFrontCamera
                                  ? Icons.person_rounded
                                  : Icons.photo_camera_back_rounded,
                              color: const Color(0xFF60A5FA),
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              session.isUsingFrontCamera ? 'Cam trước' : 'Cam sau',
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // KHUNG NỀN CHO CUỘC GỌI THOẠI (AUDIO CALL)
  // ===========================================================================

  Widget _buildAudioBackground(CallSessionModel session, String targetName) {
    return Positioned.fill(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            CircleAvatar(
              radius: 56,
              backgroundColor: const Color(0xFF2563EB),
              child: Text(
                targetName.isNotEmpty ? targetName[0].toUpperCase() : 'B',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tên người nhận
            Text(
              targetName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Trạng thái cuộc gọi / thời lượng
            Text(
              _buildCallStatusText(session),
              key: const ValueKey('call_overlay_status_text'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: session.status == CallState.connected
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildCallStatusText(CallSessionModel session) {
    switch (session.status) {
      case CallState.dialing:
        return 'Đang kết nối...';
      case CallState.ringing:
        return 'Đang đổ chuông...';
      case CallState.connected:
        return session.formattedDuration;
      case CallState.ended:
        return 'Cuộc gọi đã kết thúc';
      case CallState.rejected:
        return 'Cuộc gọi bị từ chối';
      case CallState.busy:
        return session.failureReason ?? 'Người nhận đang bận';
      case CallState.missed:
        return 'Cuộc gọi nhỡ';
      case CallState.failed:
        return session.failureReason ?? 'Kết nối thất bại';
      case CallState.idle:
        return '';
    }
  }

  // ===========================================================================
  // THANH ĐIỀU KHIỂN NÚT BẤM (BOTTOM CONTROLS)
  // ===========================================================================

  Widget _buildCallControls(CallSessionModel session, bool isVideo) {
    final service = CallSignalingService.instance;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white12, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Nút bật/tắt Micro
          _buildControlButton(
            key: const ValueKey('call_toggle_mic_button'),
            icon: session.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: session.isMuted ? 'Mở Mic' : 'Tắt Mic',
            isActive: session.isMuted,
            activeColor: const Color(0xFFEF4444),
            onTap: () => service.toggleMic(),
          ),

          // Các nút camera nếu là video call
          if (isVideo) ...[
            _buildControlButton(
              key: const ValueKey('call_toggle_camera_button'),
              icon: session.isCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: session.isCameraEnabled ? 'Tắt Cam' : 'Bật Cam',
              isActive: !session.isCameraEnabled,
              activeColor: const Color(0xFFEF4444),
              onTap: () => service.toggleCamera(),
            ),
            _buildControlButton(
              key: const ValueKey('call_flip_camera_button'),
              icon: Icons.cameraswitch_rounded,
              label: 'Đổi Cam',
              isActive: false,
              onTap: () => service.flipCamera(),
            ),
          ],

          // Nút Kết thúc cuộc gọi (Màu đỏ nổi bật)
          InkWell(
            key: const ValueKey('call_end_button'),
            onTap: () => _handleEndCall(session),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 58,
              height: 58,
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
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required Key key,
    required IconData icon,
    required String label,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final bgColor = isActive
        ? (activeColor ?? const Color(0xFFEF4444))
        : Colors.white.withValues(alpha: 0.12);

    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
