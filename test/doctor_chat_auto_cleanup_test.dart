// File: test/doctor_chat_auto_cleanup_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:do_an_cntt_11/core/storage/local_storage_service.dart';
import 'package:do_an_cntt_11/features/user/models/doctor_consultation_models.dart';
import 'package:do_an_cntt_11/features/user/services/doctor_consultation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. DoctorChatMessage Expiry & Retention Helper Tests', () {
    test('isExpired returns true for messages older than 24 hours', () {
      final oldMessage = DoctorChatMessage(
        id: 'msg_old',
        conversationId: 'conv_test',
        senderType: ChatSenderType.patient,
        senderId: 'pat_01',
        content: 'Tin nhắn cũ từ hôm qua',
        timestamp: DateTime.now().subtract(const Duration(hours: 25)),
      );

      expect(oldMessage.isExpired, isTrue);
      expect(oldMessage.isOlderThan(const Duration(hours: 24)), isTrue);
    });

    test('isExpired returns false for messages within 24 hours', () {
      final recentMessage = DoctorChatMessage(
        id: 'msg_recent',
        conversationId: 'conv_test',
        senderType: ChatSenderType.patient,
        senderId: 'pat_01',
        content: 'Tin nhắn vừa mới gửi 2 giờ trước',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(recentMessage.isExpired, isFalse);
      expect(recentMessage.isOlderThan(const Duration(hours: 24)), isFalse);
    });
  });

  group('2. LocalStorageService Auto-Cleanup (1-Day Retention) Tests', () {
    test('loadConversationMessages filters out messages older than 24h', () async {
      final storage = LocalStorageService.instance;
      const convId = 'conv_retention_storage_test';

      final oldMsg = DoctorChatMessage(
        id: 'msg_expired',
        conversationId: convId,
        senderType: ChatSenderType.patient,
        senderId: 'pat_01',
        content: 'Tin nhắn 30 tiếng trước',
        timestamp: DateTime.now().subtract(const Duration(hours: 30)),
      );

      final newMsg = DoctorChatMessage(
        id: 'msg_valid',
        conversationId: convId,
        senderType: ChatSenderType.doctor,
        senderId: 'doc_01',
        content: 'Tin nhắn 1 tiếng trước',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await storage.saveConversationMessages(convId, [oldMsg.toMap(), newMsg.toMap()]);

      final loaded = await storage.loadConversationMessages(convId);
      expect(loaded.length, equals(1));
      expect(loaded.first['id'], equals('msg_valid'));
    });

    test('cleanExpiredChatMessages removes expired message entries and cleans queue', () async {
      final storage = LocalStorageService.instance;
      const convId = 'conv_bulk_clean_test';

      final expiredMsg1 = DoctorChatMessage(
        id: 'msg_exp_1',
        conversationId: convId,
        senderType: ChatSenderType.patient,
        senderId: 'pat_01',
        content: 'Tin nhắn ngày hôm trước',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      );

      await storage.saveConversationMessages(convId, [expiredMsg1.toMap()]);
      await storage.saveConversationQueue([
        {
          'conversation_id': convId,
          'doctor_id': 'doc_01',
          'doctor_name': 'BS. An',
          'patient_id': 'pat_01',
          'patient_name': 'Bình',
          'last_message_content': 'Tin nhắn ngày hôm trước',
          'last_message_time': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          'unread_count': 0,
        }
      ]);

      final removed = await storage.cleanExpiredChatMessages();
      expect(removed, greaterThanOrEqualTo(1));

      // After cleanup, the conversation messages should be completely empty/removed
      final remainingMessages = await storage.loadConversationMessages(convId);
      expect(remainingMessages, isEmpty);

      // And queue item should be pruned
      final remainingQueue = await storage.loadConversationQueue();
      expect(remainingQueue.any((q) => q['conversation_id'] == convId), isFalse);
    });
  });

  group('3. DoctorConsultationService In-Memory & Stream Auto-Cleanup Tests', () {
    test('cleanupOldChatHistory purges messages older than 24 hours from RAM store and updates stream', () async {
      final service = DoctorConsultationService.instance;
      const convId = 'conv_mem_clean_test';

      final oldMessage = DoctorChatMessage(
        id: 'msg_mem_old',
        conversationId: convId,
        senderType: ChatSenderType.patient,
        senderId: 'pat_01',
        content: 'Tin nhắn RAM 26 tiếng trước',
        timestamp: DateTime.now().subtract(const Duration(hours: 26)),
      );

      final recentMessage = DoctorChatMessage(
        id: 'msg_mem_recent',
        conversationId: convId,
        senderType: ChatSenderType.doctor,
        senderId: 'doc_01',
        content: 'Tin nhắn RAM 30 phút trước',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      service.seedInitialConversationMessages(convId, [oldMessage, recentMessage]);
      expect(service.getStoredMessages(convId).length, equals(2));

      // Run cleanup without remote Supabase sync in unit test
      final purgedCount = await service.cleanupOldChatHistory(syncRemote: false);
      expect(purgedCount, greaterThanOrEqualTo(1));

      final storedAfter = service.getStoredMessages(convId);
      expect(storedAfter.length, equals(1));
      expect(storedAfter.first.id, equals('msg_mem_recent'));
    });
  });
}
