// File: lib/core/call/call_signaling_service.dart
import 'dart:async';

import 'call_models.dart';

typedef VoidCallback = void Function();

/// Base ChangeNotifier class providing pure Dart listenable capabilities
/// compatible with Flutter widgets and pure Dart test environments.
abstract class ChangeNotifier {
  final List<VoidCallback> _listeners = [];
  bool _disposed = false;

  void addListener(VoidCallback listener) {
    if (!_disposed) _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    if (_disposed) return;
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}

/// Dịch vụ điều phối tín hiệu cuộc gọi thoại & video (Supabase Realtime Broadcast & StreamController)
/// Thiết kế Dual-mode (Lai): Tự động phát sóng qua Realtime khi kết nối,
/// đồng thời duy trì in-memory stream controllers cho vận hành Offline / Headless / Hermetic Tests.
class CallSignalingService extends ChangeNotifier {
  CallSignalingService._();

  /// Singleton instance
  static final CallSignalingService instance = CallSignalingService._();

  CallSessionModel? activeSession;
  final List<CallSessionModel> callHistory = [];

  final StreamController<CallSessionModel> _incomingCallController =
      StreamController<CallSessionModel>.broadcast();

  Stream<CallSessionModel> get incomingCallStream =>
      _incomingCallController.stream;

  Timer? _durationTimer;
  dynamic _realtimeChannel;

  // ===========================================================================
  // REALTIME BROADCAST KHỞI TẠO VÀ LẮNG NGHE (SUPABASE REALTIME)
  // ===========================================================================

  /// Gán kênh Realtime channel (khi kết nối với Supabase client)
  void attachRealtimeChannel(dynamic channel) {
    try {
      _realtimeChannel = channel;
      if (_realtimeChannel != null) {
        _realtimeChannel.onBroadcast(
          event: 'call_offer',
          callback: (payload) {
            try {
              final Map<String, dynamic> map = payload is Map<String, dynamic>
                  ? payload
                  : Map<String, dynamic>.from(payload as Map);
              final session = CallSessionModel.fromMap(map);
              if (activeSession == null || activeSession!.callId != session.callId) {
                activeSession = session;
                _incomingCallController.add(session);
                notifyListeners();
              }
            } catch (_) {}
          },
        );

        _realtimeChannel.onBroadcast(
          event: 'call_action',
          callback: (payload) {
            try {
              final Map<dynamic, dynamic> map = payload is Map ? payload : const {};
              final action = map['action'] as String?;
              final callId = map['call_id'] as String?;
              if (activeSession != null && activeSession!.callId == callId) {
                switch (action) {
                  case 'accept':
                    if (activeSession!.status == CallState.ringing) {
                      activeSession!.status = CallState.connected;
                      _startDurationTimer();
                      notifyListeners();
                    }
                    break;
                  case 'reject':
                    if (activeSession!.status == CallState.ringing ||
                        activeSession!.status == CallState.dialing) {
                      activeSession!.status = CallState.rejected;
                      activeSession!.areMediaTracksDisposed = true;
                      _stopDurationTimer();
                      if (!callHistory.contains(activeSession!)) {
                        callHistory.add(activeSession!);
                      }
                      notifyListeners();
                    }
                    break;
                  case 'cancel':
                    activeSession!.status = CallState.ended;
                    activeSession!.areMediaTracksDisposed = true;
                    _stopDurationTimer();
                    notifyListeners();
                    break;
                  case 'end':
                    if (activeSession!.status != CallState.ended) {
                      activeSession!.status = CallState.ended;
                      activeSession!.areMediaTracksDisposed = true;
                      _stopDurationTimer();
                      if (!callHistory.contains(activeSession!)) {
                        callHistory.add(activeSession!);
                      }
                      notifyListeners();
                    }
                    break;
                }
              }
            } catch (_) {}
          },
        );
      }
    } catch (_) {}
  }

  void _broadcastOffer(CallSessionModel session) {
    try {
      _realtimeChannel?.sendBroadcastMessage(
        event: 'call_offer',
        payload: session.toMap(),
      );
    } catch (_) {}
  }

  void _broadcastAction(String action, String callId) {
    try {
      _realtimeChannel?.sendBroadcastMessage(
        event: 'call_action',
        payload: {
          'action': action,
          'call_id': callId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  // ===========================================================================
  // CÁC HÀNH ĐỘNG ĐIỀU PHỐI CUỘC GỌI (CALL WORKFLOW ACTIONS)
  // ===========================================================================

  /// Khởi tạo cuộc gọi mới (Audio / Video)
  Future<CallSessionModel> startCall({
    required String callerId,
    required String callerName,
    required String calleeId,
    required String calleeName,
    required String callType,
    bool isCalleeOnline = true,
    bool isCalleeBusy = false,
  }) async {
    // Concurrent Call Collision Protection:
    // If an existing call is active (dialing, ringing, connected), cleanly end it first
    if (activeSession != null &&
        (activeSession!.status == CallState.dialing ||
            activeSession!.status == CallState.ringing ||
            activeSession!.status == CallState.connected)) {
      endCall(activeSession!.callId);
    }

    final session = CallSessionModel(
      callId: 'call_${DateTime.now().microsecondsSinceEpoch}',
      callerId: callerId,
      callerName: callerName,
      calleeId: calleeId,
      calleeName: calleeName,
      callType: callType,
      status: CallState.dialing,
    );

    // Xử lý trường hợp đối phương đang ngoại tuyến
    if (!isCalleeOnline) {
      session.status = CallState.failed;
      session.areMediaTracksDisposed = true;
      session.failureReason = 'Bác sĩ hiện đang ngoại tuyến, không thể thực hiện cuộc gọi $callType';
      activeSession = session;
      notifyListeners();
      return session;
    }

    // Xử lý trường hợp đối phương đang bận cuộc gọi / tư vấn khác
    if (isCalleeBusy) {
      session.status = CallState.busy;
      session.areMediaTracksDisposed = true;
      session.failureReason = 'Bác sĩ đang bận ca tư vấn khác';
      activeSession = session;
      notifyListeners();
      return session;
    }

    // Thiết lập trạng thái đổ chuông và phát sóng lời mời cuộc gọi
    activeSession = session;
    session.status = CallState.ringing;
    _broadcastOffer(session);
    _incomingCallController.add(session);
    notifyListeners();
    return session;
  }

  /// Chấp nhận cuộc gọi
  void acceptCall(String callId) {
    if (activeSession != null &&
        activeSession!.callId == callId &&
        activeSession!.status == CallState.ringing) {
      activeSession!.status = CallState.connected;
      _broadcastAction('accept', callId);
      _startDurationTimer();
      notifyListeners();
    }
  }

  /// Từ chối cuộc gọi
  void rejectCall(String callId) {
    if (activeSession != null &&
        activeSession!.callId == callId &&
        (activeSession!.status == CallState.ringing ||
            activeSession!.status == CallState.dialing)) {
      activeSession!.status = CallState.rejected;
      activeSession!.areMediaTracksDisposed = true;
      _stopDurationTimer();
      if (!callHistory.contains(activeSession!)) {
        callHistory.add(activeSession!);
      }
      _broadcastAction('reject', callId);
      notifyListeners();
    }
  }

  /// Hủy cuộc gọi đang quay số
  void cancelDialing(String callId) {
    if (activeSession != null && activeSession!.callId == callId) {
      activeSession!.status = CallState.ended;
      activeSession!.areMediaTracksDisposed = true;
      _stopDurationTimer();
      _broadcastAction('cancel', callId);
      notifyListeners();
    }
  }

  /// Kết thúc cuộc gọi
  void endCall(String callId) {
    if (activeSession != null && activeSession!.callId == callId) {
      if (activeSession!.status == CallState.ended) return; // Đảm bảo tính Idempotent
      activeSession!.status = CallState.ended;
      activeSession!.areMediaTracksDisposed = true;
      _stopDurationTimer();
      if (!callHistory.contains(activeSession!)) {
        callHistory.add(activeSession!);
      }
      _broadcastAction('end', callId);
      notifyListeners();
    }
  }

  /// Bật / Tắt Mic
  void toggleMic() {
    if (activeSession != null) {
      activeSession!.isMuted = !activeSession!.isMuted;
      notifyListeners();
    }
  }

  /// Bật / Tắt Camera
  void toggleCamera() {
    if (activeSession != null) {
      activeSession!.isCameraEnabled = !activeSession!.isCameraEnabled;
      notifyListeners();
    }
  }

  /// Lật camera trước / sau
  void flipCamera() {
    if (activeSession != null) {
      activeSession!.isUsingFrontCamera = !activeSession!.isUsingFrontCamera;
      notifyListeners();
    }
  }

  /// Tăng thời lượng đàm thoại trực tiếp (dùng cho tests & mô phỏng nhanh)
  void advanceCallDuration(int seconds) {
    if (activeSession != null && activeSession!.status == CallState.connected) {
      activeSession!.durationSeconds += seconds;
      notifyListeners();
    }
  }

  /// Mô phỏng đổ chuông quá giờ không trả lời (Missed call timeout)
  void simulateRingingTimeout(String callId) {
    if (activeSession != null && activeSession!.callId == callId && activeSession!.status == CallState.ringing) {
      activeSession!.status = CallState.missed;
      activeSession!.areMediaTracksDisposed = true;
      if (!callHistory.contains(activeSession!)) {
        callHistory.add(activeSession!);
      }
      _stopDurationTimer();
      notifyListeners();
    }
  }

  /// Xử lý trường hợp bị từ chối cấp quyền Mic / Camera từ hệ điều hành
  Future<CallSessionModel> handlePermissionDenied({
    required String callType,
    required String permissionName,
  }) async {
    final session = CallSessionModel(
      callId: 'call_denied_${DateTime.now().microsecondsSinceEpoch}',
      callerId: 'pat_01',
      callerName: 'Bệnh nhân',
      calleeId: 'doc_01',
      calleeName: 'Bác sĩ',
      callType: callType,
      status: CallState.failed,
      areMediaTracksDisposed: true,
      failureReason: 'Ứng dụng cần quyền $permissionName để thực hiện cuộc gọi $callType.',
    );
    activeSession = session;
    notifyListeners();
    return session;
  }

  /// Xử lý khi người dùng từ chối quyền truy cập Camera trong cuộc gọi
  void handleCameraPermissionDenied(String callId) {
    if (activeSession != null && activeSession!.callId == callId) {
      activeSession!.isCameraEnabled = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // QUẢN LÝ TIMER ĐẾM THỜI GIAN CUỘC GỌI
  // ===========================================================================

  void _startDurationTimer() {
    _stopDurationTimer();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (activeSession != null && activeSession!.status == CallState.connected) {
        activeSession!.durationSeconds++;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  /// Reset toàn bộ trạng thái dịch vụ
  void reset() {
    _stopDurationTimer();
    activeSession = null;
    callHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopDurationTimer();
    _incomingCallController.close();
    super.dispose();
  }
}
