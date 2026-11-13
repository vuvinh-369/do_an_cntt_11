// File: lib/core/call/call_models.dart

/// Trạng thái phiên cuộc gọi viễn thông y tế (Requirement R4)
enum CallState {
  idle,
  dialing,
  ringing,
  connected,
  ended,
  rejected,
  busy,
  missed,
  failed,
}

/// Mô hình phiên cuộc gọi thoại / video giữa Bệnh nhân và Bác sĩ
class CallSessionModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String calleeId;
  final String calleeName;
  final String callType; // 'audio' | 'video'
  CallState status;
  bool isMuted;
  bool isCameraEnabled;
  bool isUsingFrontCamera;
  int durationSeconds;
  bool areMediaTracksDisposed;
  String? failureReason;

  CallSessionModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.calleeId,
    required this.calleeName,
    required this.callType,
    this.status = CallState.dialing,
    this.isMuted = false,
    this.isCameraEnabled = true,
    this.isUsingFrontCamera = true,
    this.durationSeconds = 0,
    this.areMediaTracksDisposed = false,
    this.failureReason,
  });

  /// Định dạng thời gian cuộc gọi hiển thị chuẩn HH:MM:SS (nếu >= 1 giờ) hoặc MM:SS
  String get formattedDuration {
    final h = (durationSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((durationSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    if (durationSeconds >= 3600) {
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  /// Chuyển đổi sang Map để lưu trữ hoặc truyền qua Supabase Realtime Broadcast
  Map<String, dynamic> toMap() {
    return {
      'call_id': callId,
      'caller_id': callerId,
      'caller_name': callerName,
      'callee_id': calleeId,
      'callee_name': calleeName,
      'call_type': callType,
      'status': status.name,
      'is_muted': isMuted,
      'is_camera_enabled': isCameraEnabled,
      'is_using_front_camera': isUsingFrontCamera,
      'duration_seconds': durationSeconds,
      'are_media_tracks_disposed': areMediaTracksDisposed,
      'failure_reason': failureReason,
    };
  }

  /// Khởi tạo phiên gọi từ Map (tương thích cả snake_case và camelCase)
  factory CallSessionModel.fromMap(Map<String, dynamic> map) {
    return CallSessionModel(
      callId: (map['call_id'] ?? map['callId'] ?? '') as String,
      callerId: (map['caller_id'] ?? map['callerId'] ?? '') as String,
      callerName: (map['caller_name'] ?? map['callerName'] ?? '') as String,
      calleeId: (map['callee_id'] ?? map['calleeId'] ?? '') as String,
      calleeName: (map['callee_name'] ?? map['calleeName'] ?? '') as String,
      callType: (map['call_type'] ?? map['callType'] ?? 'audio') as String,
      status: CallState.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'dialing'),
        orElse: () => CallState.dialing,
      ),
      isMuted: (map['is_muted'] ?? map['isMuted'] ?? false) as bool,
      isCameraEnabled: (map['is_camera_enabled'] ?? map['isCameraEnabled'] ?? true) as bool,
      isUsingFrontCamera: (map['is_using_front_camera'] ?? map['isUsingFrontCamera'] ?? true) as bool,
      durationSeconds: ((map['duration_seconds'] ?? map['durationSeconds'] ?? 0) as num).toInt(),
      areMediaTracksDisposed: (map['are_media_tracks_disposed'] ?? map['areMediaTracksDisposed'] ?? false) as bool,
      failureReason: (map['failure_reason'] ?? map['failureReason']) as String?,
    );
  }

  /// Tạo bản sao với các thuộc tính được cập nhật
  CallSessionModel copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? calleeId,
    String? calleeName,
    String? callType,
    CallState? status,
    bool? isMuted,
    bool? isCameraEnabled,
    bool? isUsingFrontCamera,
    int? durationSeconds,
    bool? areMediaTracksDisposed,
    String? failureReason,
  }) {
    return CallSessionModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      calleeId: calleeId ?? this.calleeId,
      calleeName: calleeName ?? this.calleeName,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      isMuted: isMuted ?? this.isMuted,
      isCameraEnabled: isCameraEnabled ?? this.isCameraEnabled,
      isUsingFrontCamera: isUsingFrontCamera ?? this.isUsingFrontCamera,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      areMediaTracksDisposed: areMediaTracksDisposed ?? this.areMediaTracksDisposed,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  @override
  String toString() {
    return 'CallSessionModel(callId: $callId, type: $callType, status: ${status.name}, duration: $formattedDuration, caller: $callerName, callee: $calleeName)';
  }
}
