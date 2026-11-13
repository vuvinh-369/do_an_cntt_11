import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Loại đối tượng gửi tin nhắn trong phòng tư vấn bác sĩ
enum ChatSenderType {
  patient,
  doctor,
  system,
  ai, // Added for Milestone 2 & 3 AI doctor fallback
}

/// Trạng thái gửi và chuyển giao tin nhắn theo chuẩn Zalo
enum MessageDeliveryStatus {
  sending, // Đang gửi (đồng hồ cát / mờ)
  sent, // Đã gửi lên máy chủ (1 dấu tích xám)
  delivered, // Đã nhận trên máy bác sĩ (2 dấu tích xám)
  read, // Bác sĩ đã đọc tin nhắn ("Đã xem" / 2 dấu tích xanh)
  failed, // Gửi thất bại
}

/// Loại tệp hoặc dữ liệu đính kèm
enum ChatAttachmentType {
  none,
  image,
  document,
  woundScanSummary,
}

/// Dữ liệu tệp đính kèm trong tin nhắn tư vấn
class ChatAttachment {
  final String id;
  final ChatAttachmentType type;
  final String? localPath;
  final Uint8List? bytes;
  final String? fileName;
  final Map<String, dynamic>? metadata;

  const ChatAttachment({
    required this.id,
    required this.type,
    this.localPath,
    this.bytes,
    this.fileName,
    this.metadata,
  });

  bool get hasImage => bytes != null && bytes!.isNotEmpty;
}

/// Hồ sơ bác sĩ chuyên khoa tư vấn trực tuyến
class DoctorProfile {
  final String id;
  final String fullName;
  final String title;
  final String specialty;
  final String hospital;
  final String phoneNumber;       // Yêu cầu R1: Số điện thoại liên hệ
  final String workplaceAddress;  // Yêu cầu R1: Nơi công tác / địa chỉ bệnh viện
  final String avatarInitials;
  final Color avatarColor;
  final String? avatarUrl;        // Ảnh đại diện tùy chọn
  final double rating;
  final int consultationCount;
  final bool isOnline;
  final String statusText;
  final bool isVerified;
  final int experienceYears;
  final String consultationFee;
  final String? accountUsername;  // Tên tài khoản đăng nhập liên kết
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DoctorProfile({
    required this.id,
    required this.fullName,
    required this.title,
    required this.specialty,
    required this.hospital,
    this.phoneNumber = '0901234567',
    this.workplaceAddress = '201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
    this.avatarInitials = 'BS',
    this.avatarColor = const Color(0xFF2563EB),
    this.avatarUrl,
    this.rating = 4.9,
    this.consultationCount = 1420,
    this.isOnline = true,
    this.statusText = 'Đang trực tuyến • Phản hồi trong 1-2 phút',
    this.isVerified = true,
    this.experienceYears = 12,
    this.consultationFee = 'Tư vấn sơ cứu miễn phí',
    this.accountUsername,
    this.createdAt,
    this.updatedAt,
  });

  /// Kiểm tra xem hồ sơ bác sĩ đã được cấp tài khoản đăng nhập hay chưa
  bool get hasAccount => accountUsername != null && accountUsername!.trim().isNotEmpty;

  /// Bác sĩ trực cấp cứu & ngoại chấn thương mặc định (Tương thích ngược 100%)
  static const DoctorProfile defaultDoctor = DoctorProfile(
    id: 'doc_an_nguyen',
    fullName: 'BS. CKI Nguyễn Văn An',
    title: 'Bác sĩ Chuyên khoa I',
    specialty: 'Ngoại Chấn thương & Xử trí Vết thương cấp',
    hospital: 'Bệnh viện Đa khoa Trung ương',
    phoneNumber: '0912345678',
    workplaceAddress: 'Bệnh viện Chợ Rẫy, 201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
    avatarInitials: 'AN',
    avatarColor: Color(0xFF1D4ED8),
    avatarUrl: null,
    rating: 4.95,
    consultationCount: 2180,
    isOnline: true,
    statusText: 'Đang trực tuyến • Sẵn sàng hỗ trợ sơ cứu',
    isVerified: true,
    experienceYears: 14,
    consultationFee: 'Hỗ trợ sơ cấp cứu miễn phí',
    accountUsername: 'bs_an',
  );

  /// Chuyển đổi sang Map để lưu trữ trên Supabase / CSDL
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'title': title,
      'specialty': specialty,
      'hospital': hospital,
      'phone_number': phoneNumber,
      'workplace_address': workplaceAddress,
      'avatar_initials': avatarInitials,
      'avatar_color': '#${avatarColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'rating': rating,
      'consultation_count': consultationCount,
      'is_online': isOnline,
      'status_text': statusText,
      'is_verified': isVerified,
      'experience_years': experienceYears,
      'consultation_fee': consultationFee,
      if (accountUsername != null) 'account_username': accountUsername,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Chuyển đổi sang Map an toàn cho bảng doctor_profiles trên Supabase Cloud
  /// (Loại bỏ cột account_username không tồn tại trên bảng để ngăn mã lỗi PostgREST 400 - PGRST204)
  Map<String, dynamic> toSupabaseMap() {
    final map = toMap();
    map.remove('account_username');
    return map;
  }

  /// Khởi tạo đối tượng từ Map (Hỗ trợ cả snake_case của Supabase và camelCase của Dart)
  factory DoctorProfile.fromMap(Map<String, dynamic> map) {
    return DoctorProfile(
      id: (map['id'] ?? '').toString(),
      fullName: (map['full_name'] ?? map['fullName'] ?? '').toString(),
      title: (map['title'] ?? 'Bác sĩ Chuyên khoa').toString(),
      specialty: (map['specialty'] ?? 'Đa khoa').toString(),
      hospital: (map['hospital'] ?? '').toString(),
      phoneNumber: (map['phone_number'] ?? map['phoneNumber'] ?? '0901234567').toString(),
      workplaceAddress: (map['workplace_address'] ?? map['workplaceAddress'] ?? '').toString(),
      avatarInitials: (map['avatar_initials'] ?? map['avatarInitials'] ?? 'BS').toString(),
      avatarColor: _parseColor(map['avatar_color'] ?? map['avatarColor']),
      avatarUrl: (map['avatar_url'] ?? map['avatarUrl'])?.toString(),
      rating: (map['rating'] as num?)?.toDouble() ?? 4.9,
      consultationCount: (map['consultation_count'] ?? map['consultationCount'] as num?)?.toInt() ?? 0,
      isOnline: map['is_online'] == true || map['isOnline'] == true,
      statusText: (map['status_text'] ?? map['statusText'] ?? 'Đang trực tuyến').toString(),
      isVerified: map['is_verified'] != false && map['isVerified'] != false,
      experienceYears: (map['experience_years'] ?? map['experienceYears'] as num?)?.toInt() ?? 5,
      consultationFee: (map['consultation_fee'] ?? map['consultationFee'] ?? 'Tư vấn miễn phí').toString(),
      accountUsername: (map['account_username'] ?? map['accountUsername'])?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  DoctorProfile copyWith({
    String? id,
    String? fullName,
    String? title,
    String? specialty,
    String? hospital,
    String? phoneNumber,
    String? workplaceAddress,
    String? avatarInitials,
    Color? avatarColor,
    String? avatarUrl,
    double? rating,
    int? consultationCount,
    bool? isOnline,
    String? statusText,
    bool? isVerified,
    int? experienceYears,
    String? consultationFee,
    String? accountUsername,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      title: title ?? this.title,
      specialty: specialty ?? this.specialty,
      hospital: hospital ?? this.hospital,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      workplaceAddress: workplaceAddress ?? this.workplaceAddress,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      consultationCount: consultationCount ?? this.consultationCount,
      isOnline: isOnline ?? this.isOnline,
      statusText: statusText ?? this.statusText,
      isVerified: isVerified ?? this.isVerified,
      experienceYears: experienceYears ?? this.experienceYears,
      consultationFee: consultationFee ?? this.consultationFee,
      accountUsername: accountUsername ?? this.accountUsername,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Bộ phân tích mã màu an toàn (Hỗ trợ Hex string, Int hoặc Color)
  static Color _parseColor(dynamic raw) {
    if (raw == null) return const Color(0xFF2563EB);
    if (raw is Color) return raw;
    if (raw is int) return Color(raw);
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return const Color(0xFF2563EB);
      try {
        var hex = s;
        if (hex.startsWith('#')) {
          hex = hex.substring(1);
        } else if (hex.startsWith('0x') || hex.startsWith('0X')) {
          hex = hex.substring(2);
        }
        if (hex.length == 6) {
          hex = 'FF$hex';
        }
        return Color(int.parse(hex, radix: 16));
      } catch (_) {
        return const Color(0xFF2563EB);
      }
    }
    return const Color(0xFF2563EB);
  }

  /// Kiểm tra định dạng số điện thoại Việt Nam hợp lệ
  static bool isValidPhoneNumber(String? phone) {
    if (phone == null) return false;
    final clean = phone.trim();
    final regex = RegExp(r'^(0|\+84)[0-9]{9}$');
    return regex.hasMatch(clean);
  }

  /// Kiểm tra địa chỉ nơi công tác hợp lệ (tối thiểu 5 ký tự)
  static bool isValidWorkplaceAddress(String? address) {
    if (address == null) return false;
    return address.trim().length >= 5;
  }

  /// Kiểm tra họ tên bác sĩ hợp lệ (tối thiểu 3 ký tự)
  static bool isValidFullName(String? name) {
    if (name == null) return false;
    return name.trim().length >= 3;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoctorProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Tùy chọn gợi ý phản hồi nhanh (Quick Action / Quick Reply)
class DoctorQuickActionOption {
  final String id;
  final String title;
  final String defaultText;
  final IconData? icon;
  final String? category;

  const DoctorQuickActionOption({
    required this.id,
    required this.title,
    required this.defaultText,
    this.icon,
    this.category,
  });
}

/// Mô hình thực thể tin nhắn trong cuộc trò chuyện 2 chiều kiểu Zalo
class DoctorChatMessage {
  final String id;
  final String conversationId;
  final ChatSenderType senderType;
  final String senderId;
  final String? senderName;
  final String content;
  final String? attachmentUrl;
  final ChatAttachmentType attachmentType;
  final DateTime timestamp;
  final MessageDeliveryStatus status;
  final ChatAttachment? attachment;
  final List<DoctorQuickActionOption> quickReplies;
  final bool isEmergencyWarning;
  final String? doctorNote;

  const DoctorChatMessage({
    required this.id,
    this.conversationId = 'conv_default',
    required this.senderType,
    this.senderId = '',
    this.senderName,
    required this.content,
    this.attachmentUrl,
    this.attachmentType = ChatAttachmentType.none,
    required this.timestamp,
    this.status = MessageDeliveryStatus.sent,
    this.attachment,
    this.quickReplies = const [],
    this.isEmergencyWarning = false,
    this.doctorNote,
  });

  bool get isPatient => senderType == ChatSenderType.patient;
  bool get isDoctor => senderType == ChatSenderType.doctor;
  bool get isSystem => senderType == ChatSenderType.system;
  bool get isAi => senderType == ChatSenderType.ai;

  DateTime get createdAt => timestamp;
  bool get hasAttachment =>
      attachment != null || (attachmentUrl != null && attachmentUrl!.isNotEmpty);

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_type': senderType.name,
      'sender_id': senderId.isNotEmpty ? senderId : (isPatient ? 'patient' : 'doctor'),
      if (senderName != null) 'sender_name': senderName,
      'content': content,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      'attachment_type': attachmentType.name,
      'status': status.name,
      'is_emergency_warning': isEmergencyWarning,
      if (doctorNote != null) 'doctor_note': doctorNote,
      'created_at': timestamp.toIso8601String(),
    };
  }

  factory DoctorChatMessage.fromMap(Map<String, dynamic> map) {
    final senderRaw = (map['sender_type'] ?? map['senderType'] ?? 'patient').toString();
    final sender = ChatSenderType.values.firstWhere(
      (e) => e.name.toLowerCase() == senderRaw.toLowerCase(),
      orElse: () => ChatSenderType.patient,
    );

    final statusRaw = (map['status'] ?? 'sent').toString();
    final status = MessageDeliveryStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusRaw.toLowerCase(),
      orElse: () => MessageDeliveryStatus.sent,
    );

    final attachTypeRaw = (map['attachment_type'] ?? map['attachmentType'] ?? 'none').toString();
    final attachType = ChatAttachmentType.values.firstWhere(
      (e) => e.name.toLowerCase() == attachTypeRaw.toLowerCase(),
      orElse: () => ChatAttachmentType.none,
    );

    final rawAttachUrl = (map['attachment_url'] ?? map['attachmentUrl'])?.toString();
    ChatAttachment? synthAttachment;
    if (rawAttachUrl != null && rawAttachUrl.isNotEmpty) {
      Uint8List? synthBytes;
      if (rawAttachUrl.startsWith('data:image')) {
        try {
          final commaIdx = rawAttachUrl.indexOf(',');
          if (commaIdx != -1) {
            synthBytes = base64Decode(rawAttachUrl.substring(commaIdx + 1));
          }
        } catch (_) {}
      }

      synthAttachment = ChatAttachment(
        id: 'attach_${map['id']}',
        type: attachType,
        bytes: synthBytes,
        localPath: rawAttachUrl,
        fileName: rawAttachUrl.split('/').last,
      );
    }

    final createdAtRaw = map['created_at'] ?? map['createdAt'] ?? map['timestamp'];
    final parsedTime = createdAtRaw != null
        ? (DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now())
        : DateTime.now();

    return DoctorChatMessage(
      id: (map['id'] ?? '').toString(),
      conversationId: (map['conversation_id'] ?? map['conversationId'] ?? 'conv_default').toString(),
      senderType: sender,
      senderId: (map['sender_id'] ?? map['senderId'] ?? '').toString(),
      senderName: (map['sender_name'] ?? map['senderName'])?.toString(),
      content: (map['content'] ?? '').toString(),
      attachmentUrl: rawAttachUrl,
      attachmentType: attachType,
      timestamp: parsedTime,
      status: status,
      attachment: synthAttachment,
      isEmergencyWarning: map['is_emergency_warning'] == true ||
          map['isEmergencyWarning'] == true ||
          map['is_emergency'] == true,
      doctorNote: (map['doctor_note'] ?? map['doctorNote'])?.toString(),
    );
  }

  DoctorChatMessage copyWith({
    String? id,
    String? conversationId,
    ChatSenderType? senderType,
    String? senderId,
    String? senderName,
    String? content,
    String? attachmentUrl,
    ChatAttachmentType? attachmentType,
    DateTime? timestamp,
    MessageDeliveryStatus? status,
    ChatAttachment? attachment,
    List<DoctorQuickActionOption>? quickReplies,
    bool? isEmergencyWarning,
    String? doctorNote,
  }) {
    return DoctorChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderType: senderType ?? this.senderType,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      attachment: attachment ?? this.attachment,
      quickReplies: quickReplies ?? this.quickReplies,
      isEmergencyWarning: isEmergencyWarning ?? this.isEmergencyWarning,
      doctorNote: doctorNote ?? this.doctorNote,
    );
  }
}

/// Mô hình mục trong hàng đợi bệnh nhân chờ tư vấn tại cổng Admin Bác sĩ
class ConversationQueueItem {
  final String conversationId;
  final String patientId;
  final String patientName;
  final String? patientPhone;
  final String doctorId;
  final String doctorName;
  final String lastMessageContent;
  final DateTime lastMessageTime;
  int unreadCount;
  bool hasAiFallbackResponse;
  final String status;

  ConversationQueueItem({
    required this.conversationId,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.doctorId = 'doc_an_nguyen',
    this.doctorName = 'BS. CKI Nguyễn Văn An',
    required this.lastMessageContent,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.hasAiFallbackResponse = false,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': conversationId,
      'patient_id': patientId,
      'patient_name': patientName,
      if (patientPhone != null) 'patient_phone': patientPhone,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'last_message_content': lastMessageContent,
      'last_message_time': lastMessageTime.toIso8601String(),
      'unread_doctor_count': unreadCount,
      'has_ai_fallback_response': hasAiFallbackResponse,
      'status': status,
    };
  }

  factory ConversationQueueItem.fromMap(Map<String, dynamic> map) {
    final timeRaw = map['last_message_time'] ?? map['lastMessageTime'];
    final time = timeRaw != null
        ? (DateTime.tryParse(timeRaw.toString()) ?? DateTime.now())
        : DateTime.now();

    return ConversationQueueItem(
      conversationId: (map['id'] ?? map['conversation_id'] ?? map['conversationId'] ?? '').toString(),
      patientId: (map['patient_id'] ?? map['patientId'] ?? '').toString(),
      patientName: (map['patient_name'] ?? map['patientName'] ?? 'Bệnh nhân').toString(),
      patientPhone: (map['patient_phone'] ?? map['patientPhone'])?.toString(),
      doctorId: (map['doctor_id'] ?? map['doctorId'] ?? 'doc_an_nguyen').toString(),
      doctorName: (map['doctor_name'] ?? map['doctorName'] ?? 'Bác sĩ').toString(),
      lastMessageContent: (map['last_message_content'] ?? map['lastMessageContent'] ?? '').toString(),
      lastMessageTime: time,
      unreadCount: (map['unread_doctor_count'] ?? map['unreadCount'] as num?)?.toInt() ?? 0,
      hasAiFallbackResponse: map['has_ai_fallback_response'] == true || map['hasAiFallbackResponse'] == true,
      status: (map['status'] ?? 'active').toString(),
    );
  }

  ConversationQueueItem copyWith({
    String? conversationId,
    String? patientId,
    String? patientName,
    String? patientPhone,
    String? doctorId,
    String? doctorName,
    String? lastMessageContent,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? hasAiFallbackResponse,
    String? status,
  }) {
    return ConversationQueueItem(
      conversationId: conversationId ?? this.conversationId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      hasAiFallbackResponse: hasAiFallbackResponse ?? this.hasAiFallbackResponse,
      status: status ?? this.status,
    );
  }
}

/// Thực thể cuộc tư vấn tương ứng bảng `conversations` trong cơ sở dữ liệu Supabase
class ConsultationConversation {
  final String id;
  final String patientId;
  final String patientName;
  final String? patientPhone;
  final String doctorId;
  final String doctorName;
  final String status;
  final int unreadDoctorCount;
  final int unreadPatientCount;
  final String lastMessageContent;
  final DateTime lastMessageTime;
  final bool hasAiFallbackResponse;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConsultationConversation({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    required this.doctorId,
    required this.doctorName,
    this.status = 'active',
    this.unreadDoctorCount = 0,
    this.unreadPatientCount = 0,
    this.lastMessageContent = '',
    required this.lastMessageTime,
    this.hasAiFallbackResponse = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'patient_name': patientName,
      if (patientPhone != null) 'patient_phone': patientPhone,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'status': status,
      'unread_doctor_count': unreadDoctorCount,
      'unread_patient_count': unreadPatientCount,
      'last_message_content': lastMessageContent,
      'last_message_time': lastMessageTime.toIso8601String(),
      'has_ai_fallback_response': hasAiFallbackResponse,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ConsultationConversation.fromMap(Map<String, dynamic> map) {
    return ConsultationConversation(
      id: (map['id'] ?? '').toString(),
      patientId: (map['patient_id'] ?? '').toString(),
      patientName: (map['patient_name'] ?? 'Bệnh nhân').toString(),
      patientPhone: map['patient_phone']?.toString(),
      doctorId: (map['doctor_id'] ?? '').toString(),
      doctorName: (map['doctor_name'] ?? 'Bác sĩ').toString(),
      status: (map['status'] ?? 'active').toString(),
      unreadDoctorCount: (map['unread_doctor_count'] as num?)?.toInt() ?? 0,
      unreadPatientCount: (map['unread_patient_count'] as num?)?.toInt() ?? 0,
      lastMessageContent: (map['last_message_content'] ?? '').toString(),
      lastMessageTime: map['last_message_time'] != null
          ? (DateTime.tryParse(map['last_message_time'].toString()) ?? DateTime.now())
          : DateTime.now(),
      hasAiFallbackResponse: map['has_ai_fallback_response'] == true,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Vai trò người nhận thông báo nổi trong ứng dụng (Milestone M4 - R4)
enum NotificationTargetRole {
  doctor,
  patient,
}

/// Mô hình mục thông báo nổi hai chiều theo thời gian thực (Milestone M4 - R4)
class InAppNotificationItem {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final NotificationTargetRole targetRole;
  final DateTime timestamp;
  final String? doctorId;
  final String? patientId;

  const InAppNotificationItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.targetRole,
    required this.timestamp,
    this.doctorId,
    this.patientId,
  });

  bool get isTargetDoctor => targetRole == NotificationTargetRole.doctor;
  bool get isTargetPatient => targetRole == NotificationTargetRole.patient;

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'target_role': targetRole.name,
      'timestamp': timestamp.toIso8601String(),
      if (doctorId != null) 'doctor_id': doctorId,
      if (patientId != null) 'patient_id': patientId,
    };
  }

  factory InAppNotificationItem.fromMap(Map<String, dynamic> map) {
    final roleStr = (map['target_role'] ?? map['targetRole'] ?? 'doctor').toString().toLowerCase();
    final role = NotificationTargetRole.values.firstWhere(
      (r) => r.name.toLowerCase() == roleStr,
      orElse: () => NotificationTargetRole.doctor,
    );

    final rawTime = map['timestamp'] ?? map['created_at'] ?? map['createdAt'];
    final time = rawTime != null
        ? (DateTime.tryParse(rawTime.toString()) ?? DateTime.now())
        : DateTime.now();

    return InAppNotificationItem(
      id: (map['id'] ?? '').toString(),
      conversationId: (map['conversation_id'] ?? map['conversationId'] ?? '').toString(),
      senderId: (map['sender_id'] ?? map['senderId'] ?? '').toString(),
      senderName: (map['sender_name'] ?? map['senderName'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      targetRole: role,
      timestamp: time,
      doctorId: (map['doctor_id'] ?? map['doctorId'])?.toString(),
      patientId: (map['patient_id'] ?? map['patientId'])?.toString(),
    );
  }

  InAppNotificationItem copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? content,
    NotificationTargetRole? targetRole,
    DateTime? timestamp,
    String? doctorId,
    String? patientId,
  }) {
    return InAppNotificationItem(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      targetRole: targetRole ?? this.targetRole,
      timestamp: timestamp ?? this.timestamp,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InAppNotificationItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'InAppNotificationItem(id: $id, conv: $conversationId, target: ${targetRole.name}, sender: $senderName)';
}
