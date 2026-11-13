// File: test/auth_brute_force_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:do_an_cntt_11/core/security/auth_brute_force_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthBruteForceService Tests', () {
    late AuthBruteForceService service;

    setUp(() {
      service = AuthBruteForceService.instance;
      service.resetForTest();
    });

    test('Initial state: zero failures, no challenge, no delay', () {
      expect(service.getFailedAttempts(AuthBruteForceService.scopeAdmin), 0);
      expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), false);
      expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), false);
      expect(service.getRemainingDelaySeconds(AuthBruteForceService.scopeAdmin), 0);
    });

    test('Attempts 1-4 do not require challenge or enforce delay', () {
      for (int i = 1; i <= 4; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
        expect(service.getFailedAttempts(AuthBruteForceService.scopeAdmin), i);
        expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), false);
        expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), false);
      }
    });

    test('5th failure activates CAPTCHA requirement and >= 5s progressive delay', () {
      for (int i = 1; i <= 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      expect(service.getFailedAttempts(AuthBruteForceService.scopeAdmin), 5);
      expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), true);
      expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), true);
      expect(service.getRemainingDelaySeconds(AuthBruteForceService.scopeAdmin), inInclusiveRange(4, 5));
    });

    test('Delay formula calculation increases consecutively', () {
      expect(service.calculateDelaySeconds(4), 0);
      expect(service.calculateDelaySeconds(5), 5);
      expect(service.calculateDelaySeconds(6), 10);
      expect(service.calculateDelaySeconds(7), 15);
      expect(service.calculateDelaySeconds(8), 20);
    });

    test('Challenge validation approves correct answer and rejects invalid', () {
      for (int i = 1; i <= 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      final challenge = service.getOrGenerateChallenge(AuthBruteForceService.scopeAdmin);
      expect(challenge.question.isNotEmpty, true);
      expect(challenge.answer.isNotEmpty, true);

      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, 'wrong'), false);
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, ''), false);
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, null), false);
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, challenge.answer), true);
    });

    test('Successful login resets all counters, delays, and challenges', () {
      for (int i = 1; i <= 6; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeDoctor);
      }
      expect(service.isChallengeRequired(AuthBruteForceService.scopeDoctor), true);
      expect(service.isDelayActive(AuthBruteForceService.scopeDoctor), true);

      service.recordSuccessfulLogin(AuthBruteForceService.scopeDoctor);
      expect(service.getFailedAttempts(AuthBruteForceService.scopeDoctor), 0);
      expect(service.isChallengeRequired(AuthBruteForceService.scopeDoctor), false);
      expect(service.isDelayActive(AuthBruteForceService.scopeDoctor), false);
      expect(service.getRemainingDelaySeconds(AuthBruteForceService.scopeDoctor), 0);
    });

    test('Portal scopes are completely isolated', () {
      for (int i = 1; i <= 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeUser);
      }
      expect(service.isChallengeRequired(AuthBruteForceService.scopeUser), true);
      expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), false);
      expect(service.isChallengeRequired(AuthBruteForceService.scopeDoctor), false);
    });
  });
}
