// File: lib/features/user/services/doctor_consultation_service.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../models/doctor_consultation_models.dart';

/// Dịch vụ Singleton quản lý trò chuyện thời gian thực 2 chiều giữa Bệnh nhân và Bác sĩ,
/// tích hợp Supabase Realtime Channel với kiến trúc bộ nhớ đệm Dual-Mode Fail-Safe (0 Crash).
class DoctorConsultationService extends ChangeNotifier {
  DoctorConsultationService._() {
    _initSeedData();
    cleanupOldChatHistory();
    subscribeRealtime();
    _startPeriodicCleanup();
  }

  static final DoctorConsultationService instance = DoctorConsultationService._();

  /// Thời hạn tự động xóa tin nhắn chat với bác sĩ (1 ngày / 24 giờ)
  static const Duration chatRetentionPeriod = Duration(hours: 24);
  Timer? _periodicCleanupTimer;

  void _startPeriodicCleanup() {
    _periodicCleanupTimer?.cancel();
    final isRunningTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isRunningTest) return;

    _periodicCleanupTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      cleanupOldChatHistory();
    });
  }

  /// Tắt bộ đếm định kỳ phục vụ kiểm thử đơn vị
  @visibleForTesting
  void stopPeriodicCleanup() {
    _periodicCleanupTimer?.cancel();
    _periodicCleanupTimer = null;
  }

  // In-Memory Data Store (Fail-Safe Local Storage)
  final Map<String, List<DoctorChatMessage>> _messagesStore = {};
  final Map<String, StreamController<List<DoctorChatMessage>>> _messageControllers = {};
  final List<ConversationQueueItem> _queue = [];
  final StreamController<List<ConversationQueueItem>> _queueController =
      StreamController<List<ConversationQueueItem>>.broadcast();
  final StreamController<String> _inAppBannerAlerts =
      StreamController<String>.broadcast();
  final StreamController<InAppNotificationItem> _inAppNotificationController =
      StreamController<InAppNotificationItem>.broadcast();
  final StreamController<String> _navigationRequests =
      StreamController<String>.broadcast();

  // Active viewing context (used to suppress unread increment and notifications if user/doctor is in that chat)
  String? currentViewingConversationId; // Bác sĩ đang xem phòng nào
  String? patientViewingConversationId; // Bệnh nhân đang xem phòng nào

  // Realtime subscription channels
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _conversationsChannel;
  bool _isRealtimeSubscribed = false;
  bool get isRealtimeSubscribed => _isRealtimeSubscribed;
  bool get isRealtimeConnected => _isRealtimeSubscribed;

  // Streams for UI consumption
  Stream<String> get bannerAlertStream => _inAppBannerAlerts.stream;
  Stream<InAppNotificationItem> get inAppNotificationStream =>
      _inAppNotificationController.stream;
  Stream<String> get navigationRequestStream => _navigationRequests.stream;
  List<ConversationQueueItem> get queue => List.unmodifiable(_queue);

  /// Yêu cầu điều hướng sâu vào phòng chat cụ thể khi người dùng/bác sĩ chạm vào thông báo nổi
  void requestNavigationToConversation(String conversationId) {
    currentViewingConversationId = conversationId;
    if (!_navigationRequests.isClosed) {
      _navigationRequests.add(conversationId);
    }
    notifyListeners();
  }

  int get totalDoctorUnreadCount =>
      _queue.fold(0, (sum, item) => sum + item.unreadCount);

  // ===========================================================================
  // SEED INITIALIZATION & FAIL-SAFE RESET
  // ===========================================================================
  void _initSeedData() {
    if (_queue.isNotEmpty) return;

    const defaultConvId = 'conv_an_nguyen_01';
    _queue.add(
      ConversationQueueItem(
        conversationId: defaultConvId,
        patientId: 'pat_default_01',
        patientName: 'Nguyễn Văn Bình',
        patientPhone: '0912345678',
        doctorId: 'doc_an_nguyen',
        doctorName: 'BS. CKI Nguyễn Văn An',
        lastMessageContent: 'Chào bác sĩ, vết rách ở chân tôi chảy máu nhiều',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 1,
      ),
    );

    const secondConvId = 'conv_mai_huong_01';
    _queue.add(
      ConversationQueueItem(
        conversationId: secondConvId,
        patientId: 'pat_default_02',
        patientName: 'Trần Thị Hoa',
        patientPhone: '0987654321',
        doctorId: 'doc_mai_huong',
        doctorName: 'ThS. BS Trần Mai Hương',
        lastMessageContent: 'Em bị bỏng nước sôi ở mu bàn tay, đã xả nước mát',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 2)),
        unreadCount: 1,
      ),
    );

    _messagesStore[defaultConvId] = [
      DoctorChatMessage(
        id: 'msg_seed_01',
        conversationId: defaultConvId,
        senderType: ChatSenderType.doctor,
        senderId: 'doc_an_nguyen',
        senderName: 'BS. CKI Nguyễn Văn An',
        content: 'Xin chào, tôi là BS. CKI Nguyễn Văn An. Hãy gửi mô tả hoặc ảnh vết thương để tôi hỗ trợ ngay nhé!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        status: MessageDeliveryStatus.read,
      ),
      DoctorChatMessage(
        id: 'msg_seed_02',
        conversationId: defaultConvId,
        senderType: ChatSenderType.patient,
        senderId: 'pat_default_01',
        senderName: 'Nguyễn Văn Bình',
        content: 'Chào bác sĩ, vết rách ở chân tôi chảy máu nhiều',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        status: MessageDeliveryStatus.delivered,
      ),
    ];

    _messagesStore[secondConvId] = [
      DoctorChatMessage(
        id: 'msg_seed_03',
        conversationId: secondConvId,
        senderType: ChatSenderType.doctor,
        senderId: 'doc_mai_huong',
        senderName: 'ThS. BS Trần Mai Hương',
        content: 'Chào bạn, hãy tiếp tục ngâm nước mát 15 phút và gửi ảnh tổn thương nhé.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
        status: MessageDeliveryStatus.read,
      ),
      DoctorChatMessage(
        id: 'msg_seed_04',
        conversationId: secondConvId,
        senderType: ChatSenderType.patient,
        senderId: 'pat_default_02',
        senderName: 'Trần Thị Hoa',
        content: 'Em bị bỏng nước sôi ở mu bàn tay, đã xả nước mát',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        status: MessageDeliveryStatus.delivered,
      ),
    ];
  }

  void resetToDefaultSeed() {
    _messagesStore.clear();
    _queue.clear();
    _initSeedData();
    for (final entry in _messagesStore.entries) {
      _messageControllers[entry.key]?.add(List.unmodifiable(entry.value));
    }
    _queueController.add(List.unmodifiable(_queue));
    notifyListeners();
  }

  /// Nạp tin nhắn khởi tạo (welcome message, quick replies) vào cache cục bộ
  /// để khi stream phát ra không bị xoá mất hoặc trống dữ liệu.
  void seedInitialConversationMessages(String conversationId, List<DoctorChatMessage> messages) {
    if (messages.isEmpty) return;
    final existing = _messagesStore[conversationId];
    if (existing == null || existing.isEmpty) {
      _messagesStore[conversationId] = List.from(messages);
      _messageControllers[conversationId]?.add(List.unmodifiable(_messagesStore[conversationId]!));
    }
  }

  /// Helper tương thích để seed 1 tin nhắn chào ban đầu
  void seedInitialMessage(String conversationId, DoctorChatMessage message) {
    seedInitialConversationMessages(conversationId, [message]);
  }

  // ===========================================================================
  // REALTIME 2-WAY MESSAGE STREAMS & QUERIES
  // ===========================================================================

  Stream<List<DoctorChatMessage>> getMessagesStream(String conversationId) {
    final controller = _messageControllers.putIfAbsent(
      conversationId,
      () => StreamController<List<DoctorChatMessage>>.broadcast(),
    );
    _messagesStore.putIfAbsent(conversationId, () => []);

    // Emit current messages immediately asynchronously
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(List.unmodifiable(_messagesStore[conversationId]!));
      }
    });

    return controller.stream;
  }

  List<DoctorChatMessage> getStoredMessages(String conversationId) {
    return List.unmodifiable(_messagesStore[conversationId] ?? []);
  }

  List<DoctorChatMessage> getMessages(String conversationId) {
    return getStoredMessages(conversationId);
  }

  List<ConversationQueueItem> getDoctorQueue(String doctorId) {
    if (doctorId.isEmpty || doctorId == 'all') {
      return List.unmodifiable(_queue);
    }
    final filtered = _queue.where((item) => item.doctorId == doctorId).toList();
    return List.unmodifiable(filtered);
  }

  Stream<List<ConversationQueueItem>> getDoctorConversationsStream(String doctorId) {
    scheduleMicrotask(() {
      if (!_queueController.isClosed) {
        _queueController.add(List.unmodifiable(_queue));
      }
    });
    return _queueController.stream;
  }

  /// Tự động xóa lịch sử chat cũ hơn 1 ngày (24 giờ) trên cả RAM, LocalStorage và Supabase Cloud
  Future<int> cleanupOldChatHistory({
    Duration retention = chatRetentionPeriod,
    bool syncRemote = true,
  }) async {
    final threshold = DateTime.now().subtract(retention);
    int removedMessagesCount = 0;
    bool hasQueueChanged = false;

    // 1. Dọn dẹp trong bộ nhớ RAM (_messagesStore)
    final convKeys = _messagesStore.keys.toList();
    for (final convId in convKeys) {
      final messages = _messagesStore[convId];
      if (messages != null && messages.isNotEmpty) {
        final remaining = messages.where((m) => m.timestamp.isAfter(threshold)).toList();
        final prunedCount = messages.length - remaining.length;
        if (prunedCount > 0) {
          removedMessagesCount += prunedCount;
          if (remaining.isEmpty) {
            _messagesStore.remove(convId);
            _messageControllers[convId]?.add(const []);
          } else {
            _messagesStore[convId] = remaining;
            _messageControllers[convId]?.add(List.unmodifiable(remaining));
          }
        }
      }
    }

    // 2. Dọn dẹp hàng đợi cuộc trò chuyện (_queue)
    final initialQueueLen = _queue.length;
    _queue.removeWhere((item) {
      final isStaleTime = item.lastMessageTime.isBefore(threshold);
      final hasNoMessages = !_messagesStore.containsKey(item.conversationId) ||
          (_messagesStore[item.conversationId]?.isEmpty ?? true);
      return isStaleTime && hasNoMessages;
    });
    if (_queue.length != initialQueueLen) {
      hasQueueChanged = true;
      _queueController.add(List.unmodifiable(_queue));
    }

    if (removedMessagesCount > 0 || hasQueueChanged) {
      notifyListeners();
    }

    // 3. Dọn dẹp bộ nhớ đệm LocalStorage
    try {
      await LocalStorageService.instance.cleanExpiredChatMessages(retention: retention);
    } catch (e) {
      debugPrint('[DoctorConsultationService] LocalStorage cleanExpiredChatMessages error: $e');
    }

    // 4. Đồng bộ xóa các tin nhắn cũ hơn 1 ngày trên Supabase Cloud
    if (syncRemote) {
      final client = SupabaseService.instance.client;
      if (client != null) {
        try {
          final thresholdIso = threshold.toIso8601String();
          await client
              .from('doctor_chat_messages')
              .delete()
              .lt('created_at', thresholdIso);

          await client
              .from('conversations')
              .delete()
              .lt('last_message_time', thresholdIso);

          debugPrint('[DoctorConsultationService] Đã đồng bộ xóa tin nhắn cũ hơn 1 ngày trên Supabase Cloud.');
        } catch (e) {
          debugPrint('[DoctorConsultationService] Supabase remote cleanup fallback: $e');
        }
      }
    }

    return removedMessagesCount;
  }

  Future<List<ConversationQueueItem>> getDoctorConversations(String doctorId) async {
    final threshold = DateTime.now().subtract(chatRetentionPeriod);

    // 1. Nạp từ LocalStorage cache trước (Fail-safe khi tải lại trang web)
    try {
      final cachedQueueMaps = await LocalStorageService.instance.loadConversationQueue(
        retention: chatRetentionPeriod,
      );
      if (cachedQueueMaps.isNotEmpty) {
        for (final map in cachedQueueMaps) {
          final item = ConversationQueueItem.fromMap(map);
          if (item.lastMessageTime.isAfter(threshold)) {
            final idx = _queue.indexWhere((q) => q.conversationId == item.conversationId);
            if (idx == -1) {
              _queue.add(item);
            } else {
              _queue[idx] = item;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DoctorConsultationService] LocalStorage load queue fallback: $e');
    }

    // 2. Đồng bộ từ Supabase nếu có kết nối
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        var query = client.from('conversations').select();
        if (doctorId.isNotEmpty && doctorId != 'all') {
          query = query.eq('doctor_id', doctorId);
        }
        query = query.gte('last_message_time', threshold.toIso8601String());
        final res = await query.order('last_message_time', ascending: false);

        if (res.isNotEmpty) {
          final items = res
              .whereType<Map>()
              .map((m) => ConversationQueueItem.fromMap(Map<String, dynamic>.from(m)))
              .where((item) => item.lastMessageTime.isAfter(threshold))
              .toList();

          for (final rItem in items) {
            final idx = _queue.indexWhere((q) => q.conversationId == rItem.conversationId);
            if (idx == -1) {
              _queue.insert(0, rItem);
            } else {
              _queue[idx] = rItem;
            }
          }
          _queue.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        }
      } catch (e) {
        debugPrint('[DoctorConsultationService] Supabase fetch conversations fallback: $e');
      }
    }

    // 3. Cập nhật LocalStorage với hàng đợi đã hợp nhất
    try {
      unawaited(LocalStorageService.instance.saveConversationQueue(
        _queue.map((q) => q.toMap()).toList(),
      ));
    } catch (_) {}

    _queueController.add(List.unmodifiable(_queue));
    notifyListeners();

    if (doctorId.isEmpty || doctorId == 'all') {
      return List.unmodifiable(_queue);
    }
    return List.unmodifiable(_queue.where((item) => item.doctorId == doctorId).toList());
  }

  /// Nạp tin nhắn của một cuộc hội thoại từ bộ nhớ đệm LocalStorage (tức thời)
  /// và sau đó đồng bộ delta từ Supabase Cloud (tự động loại bỏ tin nhắn cũ hơn 1 ngày)
  Future<List<DoctorChatMessage>> fetchMessages(String conversationId) async {
    final threshold = DateTime.now().subtract(chatRetentionPeriod);

    // 1. Nạp tức thời từ LocalStorage nếu RAM chưa có hoặc trống
    if (_messagesStore[conversationId] == null || _messagesStore[conversationId]!.isEmpty) {
      try {
        final cachedMaps = await LocalStorageService.instance.loadConversationMessages(
          conversationId,
          retention: chatRetentionPeriod,
        );
        if (cachedMaps.isNotEmpty) {
          final cachedList = cachedMaps
              .map((m) => DoctorChatMessage.fromMap(m))
              .where((m) => m.timestamp.isAfter(threshold))
              .toList();
          if (cachedList.isNotEmpty) {
            _messagesStore[conversationId] = cachedList;
            final controller = _messageControllers.putIfAbsent(
              conversationId,
              () => StreamController<List<DoctorChatMessage>>.broadcast(),
            );
            controller.add(List.unmodifiable(cachedList));
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('[DoctorConsultationService] LocalStorage load messages fallback: $e');
      }
    }

    // 2. Đồng bộ các tin nhắn từ xa trên Supabase Cloud (chỉ lấy tin nhắn trong vòng 1 ngày)
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        final res = await client
            .from('doctor_chat_messages')
            .select()
            .eq('conversation_id', conversationId)
            .gte('created_at', threshold.toIso8601String())
            .order('created_at', ascending: true);

        if (res.isNotEmpty) {
          final remoteList = res
              .whereType<Map>()
              .map((m) => DoctorChatMessage.fromMap(Map<String, dynamic>.from(m)))
              .where((m) => m.timestamp.isAfter(threshold))
              .toList();

          if (remoteList.isNotEmpty) {
            _messagesStore[conversationId] = remoteList;
            final controller = _messageControllers.putIfAbsent(
              conversationId,
              () => StreamController<List<DoctorChatMessage>>.broadcast(),
            );
            controller.add(List.unmodifiable(remoteList));

            // Cập nhật bộ nhớ đệm LocalStorage
            unawaited(LocalStorageService.instance.saveConversationMessages(
              conversationId,
              remoteList.map((m) => m.toMap()).toList(),
            ));

            notifyListeners();
            return List.unmodifiable(remoteList);
          }
        }
      } catch (e) {
        debugPrint('[DoctorConsultationService] Supabase fetchMessages fallback: $e');
      }
    }

    return List.unmodifiable(_messagesStore[conversationId] ?? []);
  }

  // ===========================================================================
  // SEND MESSAGE (PATIENT -> DOCTOR & DOCTOR -> PATIENT)
  // ===========================================================================

  Future<DoctorChatMessage> sendMessage({
    required String conversationId,
    required String senderType, // 'patient', 'doctor', 'ai', 'system'
    required String senderId,
    String? senderName,
    required String content,
    String? attachmentUrl,
    String attachmentType = 'none',
    ChatAttachment? attachment,
    bool isEmergency = false,
    String patientName = 'Bệnh nhân',
    String? doctorId,
    String? doctorName,
    String? patientId,
    String? localMessageId,
  }) async {
    if (content.trim().isEmpty && attachment == null && (attachmentUrl == null || attachmentUrl.isEmpty)) {
      throw ArgumentError('Nội dung tin nhắn hoặc tệp đính kèm không được để trống.');
    }

    final type = ChatSenderType.values.firstWhere(
      (e) => e.name.toLowerCase() == senderType.toLowerCase(),
      orElse: () => ChatSenderType.patient,
    );

    final attachType = ChatAttachmentType.values.firstWhere(
      (e) => e.name.toLowerCase() == attachmentType.toLowerCase(),
      orElse: () => (attachment != null ? attachment.type : ChatAttachmentType.none),
    );

    final msgId = localMessageId ?? 'msg_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();

    final message = DoctorChatMessage(
      id: msgId,
      conversationId: conversationId,
      senderType: type,
      senderId: senderId,
      senderName: senderName ?? (type == ChatSenderType.patient ? patientName : (doctorName ?? 'Bác sĩ')),
      content: content.isNotEmpty ? content : 'Đã gửi tệp đính kèm',
      attachmentUrl: attachmentUrl ?? attachment?.localPath,
      attachmentType: attachType,
      timestamp: now,
      status: MessageDeliveryStatus.sent,
      attachment: attachment,
      isEmergencyWarning: isEmergency,
    );

    // 1. Optimistic Local In-Memory Store Update
    _messagesStore.putIfAbsent(conversationId, () => []);
    _messagesStore[conversationId]!.add(message);
    _messageControllers[conversationId]?.add(List.unmodifiable(_messagesStore[conversationId]!));

    // 2. Update Queue & Unread Logic
    final isDoctorInactive = currentViewingConversationId != conversationId;
    final isPatientInactive = patientViewingConversationId != conversationId;
    final unreadInc = (type == ChatSenderType.patient && isDoctorInactive) ? 1 : 0;

    final resolvedDoctorId = (type == ChatSenderType.doctor ? senderId : doctorId) ?? 'doc_an_nguyen';
    final resolvedDoctorName = (type == ChatSenderType.doctor ? (senderName ?? doctorName) : doctorName) ?? 'BS. CKI Nguyễn Văn An';
    final resolvedPatientId = (type == ChatSenderType.patient ? senderId : patientId) ?? 'pat_$conversationId';
    final resolvedPatientName = type == ChatSenderType.patient ? (senderName ?? patientName) : patientName;

    final qIdx = _queue.indexWhere((q) => q.conversationId == conversationId);
    ConversationQueueItem currentItem;
    if (qIdx != -1) {
      final existing = _queue.removeAt(qIdx);
      currentItem = existing.copyWith(
        doctorId: doctorId ?? existing.doctorId,
        doctorName: doctorName ?? existing.doctorName,
        patientId: patientId ?? existing.patientId,
        patientName: (type == ChatSenderType.patient && senderName != null) ? senderName : existing.patientName,
        lastMessageContent: message.content,
        lastMessageTime: now,
        unreadCount: existing.unreadCount + unreadInc,
        hasAiFallbackResponse: type == ChatSenderType.ai || existing.hasAiFallbackResponse,
      );
      _queue.insert(0, currentItem); // Re-order with most recent at top
    } else {
      currentItem = ConversationQueueItem(
        conversationId: conversationId,
        patientId: resolvedPatientId,
        patientName: resolvedPatientName,
        doctorId: resolvedDoctorId,
        doctorName: resolvedDoctorName,
        lastMessageContent: message.content,
        lastMessageTime: now,
        unreadCount: unreadInc,
        hasAiFallbackResponse: type == ChatSenderType.ai,
      );
      _queue.insert(0, currentItem);
    }
    _queueController.add(List.unmodifiable(_queue));

    // 3. Bidirectional In-App Floating Notification Dispatch with Active Room Suppression (R4)
    final finalDoctorId = doctorId ?? currentItem.doctorId;
    final finalPatientId = patientId ?? currentItem.patientId;

    if (type == ChatSenderType.patient) {
      // Patient -> Doctor: Dispatch notification only if doctor is NOT viewing this room
      if (isDoctorInactive) {
        final notif = InAppNotificationItem(
          id: 'notif_${message.id}',
          conversationId: conversationId,
          senderId: senderId,
          senderName: message.senderName ?? patientName,
          content: message.content,
          targetRole: NotificationTargetRole.doctor,
          timestamp: now,
          doctorId: finalDoctorId,
          patientId: finalPatientId,
        );
        _inAppNotificationController.add(notif);
        _inAppBannerAlerts.add('${message.senderName ?? patientName}: ${message.content}');
      }
    } else if (type == ChatSenderType.doctor || type == ChatSenderType.ai) {
      // Doctor -> Patient: Dispatch notification only if patient is NOT viewing this room
      if (isPatientInactive) {
        final defaultSender = type == ChatSenderType.ai ? 'AI Bác sĩ' : 'Bác sĩ';
        final notif = InAppNotificationItem(
          id: 'notif_${message.id}',
          conversationId: conversationId,
          senderId: senderId,
          senderName: message.senderName ?? defaultSender,
          content: message.content,
          targetRole: NotificationTargetRole.patient,
          timestamp: now,
          doctorId: finalDoctorId,
          patientId: finalPatientId,
        );
        _inAppNotificationController.add(notif);
        _inAppBannerAlerts.add('${message.senderName ?? defaultSender}: ${message.content}');
      }
    }

    notifyListeners();

    // 4. Asynchronous Push to Supabase Cloud: Upsert conversations BEFORE doctor_chat_messages to satisfy FK constraint
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        // Step 4.1: Ensure parent conversation exists in Supabase
        await client.from('conversations').upsert({
          'id': conversationId,
          'patient_id': currentItem.patientId,
          'patient_name': currentItem.patientName,
          'doctor_id': currentItem.doctorId,
          'doctor_name': currentItem.doctorName,
          'status': currentItem.status,
          'last_message_content': message.content,
          'last_message_time': now.toIso8601String(),
          'unread_doctor_count': currentItem.unreadCount,
          'updated_at': now.toIso8601String(),
        }, onConflict: 'id');

        // Step 4.2: Safe upsert into doctor_chat_messages
        await client.from('doctor_chat_messages').upsert(message.toMap(), onConflict: 'id');
      } catch (e) {
        debugPrint('[DoctorConsultationService] Supabase insert message fallback: $e');
      }
    }

    // 5. Persist to LocalStorage browser cache
    try {
      unawaited(LocalStorageService.instance.saveConversationMessages(
        conversationId,
        _messagesStore[conversationId]!.map((m) => m.toMap()).toList(),
      ));
      unawaited(LocalStorageService.instance.saveConversationQueue(
        _queue.map((q) => q.toMap()).toList(),
      ));
    } catch (e) {
      debugPrint('[DoctorConsultationService] LocalStorage persist fallback: $e');
    }

    return message;
  }

  // ===========================================================================
  // MARK READ & DELIVERY STATUS UPDATE
  // ===========================================================================

  Future<void> markMessagesAsRead(String conversationId, [String readerType = 'doctor']) async {
    final list = _messagesStore[conversationId];
    bool hasStatusChanged = false;

    if (list != null) {
      for (var i = 0; i < list.length; i++) {
        // Chỉ đánh dấu đã đọc đối với các tin nhắn gửi từ phía đối phương chưa ở trạng thái 'read'
        final isFromOpposite = readerType.toLowerCase() == 'patient'
            ? list[i].senderType != ChatSenderType.patient
            : list[i].senderType != ChatSenderType.doctor;

        if (isFromOpposite && list[i].status != MessageDeliveryStatus.read) {
          list[i] = list[i].copyWith(status: MessageDeliveryStatus.read);
          hasStatusChanged = true;
        }
      }
      // CHỈ đẩy vào StreamController nếu có sự thay đổi trạng thái thực sự
      if (hasStatusChanged) {
        _messageControllers[conversationId]?.add(List.unmodifiable(list));
      }
    }

    final qIdx = _queue.indexWhere((q) => q.conversationId == conversationId);
    if (qIdx != -1 && _queue[qIdx].unreadCount > 0) {
      _queue[qIdx].unreadCount = 0;
      _queueController.add(List.unmodifiable(_queue));
      hasStatusChanged = true;
    }

    // CHỈ thông báo listeners và cập nhật Supabase khi thực sự có thay đổi
    if (hasStatusChanged) {
      notifyListeners();

      try {
        if (_messagesStore[conversationId] != null) {
          unawaited(LocalStorageService.instance.saveConversationMessages(
            conversationId,
            _messagesStore[conversationId]!.map((m) => m.toMap()).toList(),
          ));
        }
        unawaited(LocalStorageService.instance.saveConversationQueue(
          _queue.map((q) => q.toMap()).toList(),
        ));
      } catch (_) {}

      final client = SupabaseService.instance.client;
      if (client != null) {
        try {
          await client
              .from('doctor_chat_messages')
              .update({'status': 'read'})
              .eq('conversation_id', conversationId)
              .neq('sender_type', readerType);

          await client
              .from('conversations')
              .update({'unread_doctor_count': 0})
              .eq('id', conversationId);
        } catch (e) {
          debugPrint('[DoctorConsultationService] Supabase mark read fallback: $e');
        }
      }
    }
  }

  void updateDeliveryStatus(String conversationId, String messageId, MessageDeliveryStatus newStatus) {
    final list = _messagesStore[conversationId];
    if (list != null) {
      final mIdx = list.indexWhere((m) => m.id == messageId);
      if (mIdx != -1) {
        list[mIdx] = list[mIdx].copyWith(status: newStatus);
        _messageControllers[conversationId]?.add(List.unmodifiable(list));
        notifyListeners();
      }
    }
  }

  int getUnreadCount(String conversationId, [String readerType = 'doctor']) {
    final item = _queue.firstWhere(
      (q) => q.conversationId == conversationId,
      orElse: () => ConversationQueueItem(
        conversationId: conversationId,
        patientId: '',
        patientName: '',
        lastMessageContent: '',
        lastMessageTime: DateTime.now(),
      ),
    );
    return item.unreadCount;
  }

  // ===========================================================================
  // SUPABASE REALTIME CHANNEL SUBSCRIPTION
  // ===========================================================================

  void subscribeRealtime() {
    if (_isRealtimeSubscribed) return;

    try {
      final client = SupabaseService.instance.client;
      if (client == null) return;

      _messagesChannel = client.channel('public:doctor_chat_messages');
      _messagesChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'doctor_chat_messages',
            callback: (PostgresChangePayload payload) {
              _handleMessageRealtimePayload(payload);
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              _isRealtimeSubscribed = true;
              debugPrint('[DoctorConsultationService] Realtime channel connected for messages');
            }
          });

      _conversationsChannel = client.channel('public:conversations');
      _conversationsChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            callback: (PostgresChangePayload payload) {
              _handleConversationRealtimePayload(payload);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[DoctorConsultationService] Realtime subscription init error: $e');
    }
  }

  void _handleMessageRealtimePayload(PostgresChangePayload payload) {
    try {
      if (payload.eventType == PostgresChangeEvent.insert) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final msg = DoctorChatMessage.fromMap(newRecord);
          final convId = msg.conversationId;

          _messagesStore.putIfAbsent(convId, () => []);
          final exists = _messagesStore[convId]!.any((m) => m.id == msg.id);
          if (!exists) {
            _messagesStore[convId]!.add(msg);
            _messageControllers[convId]?.add(List.unmodifiable(_messagesStore[convId]!));

            // Unread & Bidirectional In-App Notification Trigger (R4)
            if (msg.senderType == ChatSenderType.patient && currentViewingConversationId != convId) {
              final qIdx = _queue.indexWhere((q) => q.conversationId == convId);
              if (qIdx != -1) {
                _queue[qIdx].unreadCount++;
              }
              _inAppBannerAlerts.add('${msg.senderName ?? 'Bệnh nhân'}: ${msg.content}');
              _inAppNotificationController.add(
                InAppNotificationItem(
                  id: 'notif_${msg.id}',
                  conversationId: convId,
                  senderId: msg.senderId,
                  senderName: msg.senderName ?? 'Bệnh nhân',
                  content: msg.content,
                  targetRole: NotificationTargetRole.doctor,
                  timestamp: msg.timestamp,
                ),
              );
            } else if ((msg.senderType == ChatSenderType.doctor || msg.senderType == ChatSenderType.ai) &&
                patientViewingConversationId != convId) {
              final defaultSender = msg.senderType == ChatSenderType.ai ? 'AI Bác sĩ' : 'Bác sĩ';
              _inAppBannerAlerts.add('${msg.senderName ?? defaultSender}: ${msg.content}');
              _inAppNotificationController.add(
                InAppNotificationItem(
                  id: 'notif_${msg.id}',
                  conversationId: convId,
                  senderId: msg.senderId,
                  senderName: msg.senderName ?? defaultSender,
                  content: msg.content,
                  targetRole: NotificationTargetRole.patient,
                  timestamp: msg.timestamp,
                ),
              );
            }
            _queueController.add(List.unmodifiable(_queue));
            notifyListeners();

            try {
              unawaited(LocalStorageService.instance.saveConversationMessages(
                convId,
                _messagesStore[convId]!.map((m) => m.toMap()).toList(),
              ));
              unawaited(LocalStorageService.instance.saveConversationQueue(
                _queue.map((q) => q.toMap()).toList(),
              ));
            } catch (_) {}
          }
        }
      } else if (payload.eventType == PostgresChangeEvent.update) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final msg = DoctorChatMessage.fromMap(newRecord);
          final list = _messagesStore[msg.conversationId];
          if (list != null) {
            final idx = list.indexWhere((m) => m.id == msg.id);
            if (idx != -1) {
              list[idx] = msg;
              _messageControllers[msg.conversationId]?.add(List.unmodifiable(list));
              notifyListeners();

              try {
                unawaited(LocalStorageService.instance.saveConversationMessages(
                  msg.conversationId,
                  list.map((m) => m.toMap()).toList(),
                ));
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DoctorConsultationService] Message realtime payload handling error: $e');
    }
  }

  void _handleConversationRealtimePayload(PostgresChangePayload payload) {
    try {
      if (payload.eventType == PostgresChangeEvent.insert || payload.eventType == PostgresChangeEvent.update) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final updatedItem = ConversationQueueItem.fromMap(newRecord);
          final idx = _queue.indexWhere((q) => q.conversationId == updatedItem.conversationId);
          if (idx != -1) {
            _queue[idx] = updatedItem;
          } else {
            _queue.insert(0, updatedItem);
          }
          _queueController.add(List.unmodifiable(_queue));
          notifyListeners();

          try {
            unawaited(LocalStorageService.instance.saveConversationQueue(
              _queue.map((q) => q.toMap()).toList(),
            ));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[DoctorConsultationService] Conversation realtime payload handling error: $e');
    }
  }

  void unsubscribeRealtime() {
    final client = SupabaseService.instance.client;
    if (_messagesChannel != null) {
      client?.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
    if (_conversationsChannel != null) {
      client?.removeChannel(_conversationsChannel!);
      _conversationsChannel = null;
    }
    _isRealtimeSubscribed = false;
  }

  @override
  void dispose() {
    _periodicCleanupTimer?.cancel();
    unsubscribeRealtime();
    for (final c in _messageControllers.values) {
      c.close();
    }
    _queueController.close();
    _inAppBannerAlerts.close();
    _inAppNotificationController.close();
    _navigationRequests.close();
    super.dispose();
  }
}
