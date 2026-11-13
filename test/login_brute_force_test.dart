// File: test/login_brute_force_test.dart
// Automated Verification Suite for Login Brute-Force & Progressive Backoff Defense
// Requirements: R2 (Threshold 5 failed attempts, CAPTCHA challenge, >= 5s delays, login recovery)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:do_an_cntt_11/core/security/auth_brute_force_service.dart';
import 'package:do_an_cntt_11/core/storage/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthBruteForceService.instance.resetForTest();
  });

  group('1. Under-Threshold Login Attempts (< 5 failures)', () {
    test('1.1 Initial state has 0 failures, no challenge required, 0s delay', () {
      final service = AuthBruteForceService.instance;
      expect(service.getFailedAttempts(AuthBruteForceService.scopeAdmin), equals(0));
      expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), isFalse);
      expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), isFalse);
      expect(service.getRemainingDelaySeconds(AuthBruteForceService.scopeAdmin), equals(0));
    });

    test('1.2 Failed attempts 1-4 increment counter without requiring CAPTCHA or delay', () {
      final service = AuthBruteForceService.instance;
      for (int i = 1; i <= 4; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
        expect(service.getFailedAttempts(AuthBruteForceService.scopeAdmin), equals(i));
        expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), isFalse);
        expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), isFalse);
        expect(service.getRemainingDelaySeconds(AuthBruteForceService.scopeAdmin), equals(0));
      }
    });

    test('1.3 validateChallenge returns true when failed attempts < 5 even without challenge answer', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 4; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, null), isTrue);
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, ''), isTrue);
    });
  });

  group('2. CAPTCHA Challenge Requirement at Threshold (5 Failed Attempts)', () {
    test('2.1 Exactly 5 failed attempts triggers isChallengeRequired == true', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      expect(service.getFailedAttempts(AuthBruteForceService.scopeAdmin), equals(5));
      expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), isTrue);
    });

    test('2.2 Generates self-contained arithmetic challenge upon reaching 5 failures', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      final challenge = service.getOrGenerateChallenge(AuthBruteForceService.scopeAdmin);
      expect(challenge.id, isNotEmpty);
      expect(challenge.question, contains('= ?'));
      expect(challenge.answer, isNotEmpty);
      expect(challenge.isExpired, isFalse);
    });

    test('2.3 Rejects missing or empty CAPTCHA submission when challenged', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, null), isFalse);
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, ''), isFalse);
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, '   '), isFalse);
    });

    test('2.4 Rejects incorrect CAPTCHA answer', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, 'wrong-999'), isFalse);
    });

    test('2.5 Accepts correct CAPTCHA answer', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      final challenge = service.getOrGenerateChallenge(AuthBruteForceService.scopeAdmin);
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, challenge.answer), isTrue);
      expect(service.validateChallenge(AuthBruteForceService.scopeAdmin, '  ${challenge.answer}  '), isTrue);
    });
  });

  group('3. Progressive Delays Enforcement (5s, 10s, 15s...)', () {
    test('3.1 calculateDelaySeconds adheres strictly to progressive backoff formula', () {
      final service = AuthBruteForceService.instance;
      expect(service.calculateDelaySeconds(0), equals(0));
      expect(service.calculateDelaySeconds(4), equals(0));
      expect(service.calculateDelaySeconds(5), equals(5));
      expect(service.calculateDelaySeconds(6), equals(10));
      expect(service.calculateDelaySeconds(7), equals(15));
      expect(service.calculateDelaySeconds(8), equals(20));
      expect(service.calculateDelaySeconds(9), equals(25));
    });

    test('3.2 5th failure activates lockout delay of at least 5 seconds', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), isTrue);
      final remaining = service.getRemainingDelaySeconds(AuthBruteForceService.scopeAdmin);
      expect(remaining, greaterThanOrEqualTo(4));
      expect(remaining, lessThanOrEqualTo(5));
    });

    test('3.3 6th failure increases lockout delay to 10 seconds', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 6; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), isTrue);
      final remaining = service.getRemainingDelaySeconds(AuthBruteForceService.scopeAdmin);
      expect(remaining, greaterThanOrEqualTo(9));
      expect(remaining, lessThanOrEqualTo(10));
    });

    test('3.4 7th failure increases lockout delay to 15 seconds', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 7; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), isTrue);
      final remaining = service.getRemainingDelaySeconds(AuthBruteForceService.scopeAdmin);
      expect(remaining, greaterThanOrEqualTo(14));
      expect(remaining, lessThanOrEqualTo(15));
    });
  });

  group('4. Valid Login Recovery & State Reset', () {
    test('4.1 recordSuccessfulLogin clears failed attempts count to 0', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 6; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      expect(service.getFailedAttempts(AuthBruteForceService.scopeAdmin), equals(6));

      service.recordSuccessfulLogin(AuthBruteForceService.scopeAdmin);
      expect(service.getFailedAttempts(AuthBruteForceService.scopeAdmin), equals(0));
    });

    test('4.2 recordSuccessfulLogin clears lockout delays and challenge requirement', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 6; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }
      expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), isTrue);

      service.recordSuccessfulLogin(AuthBruteForceService.scopeAdmin);
      expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), isFalse);
      expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), isFalse);
      expect(service.getRemainingDelaySeconds(AuthBruteForceService.scopeAdmin), equals(0));
    });
  });

  group('5. Multi-Portal Scope Isolation (/admin, /doctor, user)', () {
    test('5.1 Locking /admin does not impact /doctor or user login portals', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }

      // Admin is challenged and locked
      expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), isTrue);
      expect(service.isDelayActive(AuthBruteForceService.scopeAdmin), isTrue);

      // Doctor is unaffected
      expect(service.getFailedAttempts(AuthBruteForceService.scopeDoctor), equals(0));
      expect(service.isChallengeRequired(AuthBruteForceService.scopeDoctor), isFalse);
      expect(service.isDelayActive(AuthBruteForceService.scopeDoctor), isFalse);

      // User login is unaffected
      expect(service.getFailedAttempts(AuthBruteForceService.scopeUser), equals(0));
      expect(service.isChallengeRequired(AuthBruteForceService.scopeUser), isFalse);
      expect(service.isDelayActive(AuthBruteForceService.scopeUser), isFalse);
    });

    test('5.2 Doctor portal lockout operates independently', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeDoctor);
      }
      expect(service.isChallengeRequired(AuthBruteForceService.scopeDoctor), isTrue);
      expect(service.isDelayActive(AuthBruteForceService.scopeDoctor), isTrue);

      expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), isFalse);
      expect(service.isChallengeRequired(AuthBruteForceService.scopeUser), isFalse);
    });

    test('5.3 User portal lockout operates independently', () {
      final service = AuthBruteForceService.instance;
      for (int i = 0; i < 5; i++) {
        service.recordFailedAttempt(AuthBruteForceService.scopeUser);
      }
      expect(service.isChallengeRequired(AuthBruteForceService.scopeUser), isTrue);
      expect(service.isDelayActive(AuthBruteForceService.scopeUser), isTrue);

      expect(service.isChallengeRequired(AuthBruteForceService.scopeAdmin), isFalse);
      expect(service.isChallengeRequired(AuthBruteForceService.scopeDoctor), isFalse);
    });
  });

  group('6. Cross-Reload Persistence via LocalStorage', () {
    test('6.1 saveFailedLoginAttempts and loadFailedLoginAttempts round-trip', () async {
      final storage = LocalStorageService.instance;
      final lockTime = DateTime.now().add(const Duration(seconds: 10));

      await storage.saveFailedLoginAttempts(AuthBruteForceService.scopeAdmin, 6, lockTime);

      final loaded = await storage.loadFailedLoginAttempts(AuthBruteForceService.scopeAdmin);
      expect(loaded['count'], equals(6));
      expect(loaded['lockedUntil'], isNotNull);
      final loadedDt = loaded['lockedUntil'] as DateTime;
      expect(loadedDt.difference(lockTime).inSeconds.abs(), lessThanOrEqualTo(1));
    });

    test('6.2 clearFailedLoginAttempts removes stored keys from LocalStorage', () async {
      final storage = LocalStorageService.instance;
      final lockTime = DateTime.now().add(const Duration(seconds: 5));

      await storage.saveFailedLoginAttempts(AuthBruteForceService.scopeAdmin, 5, lockTime);
      await storage.clearFailedLoginAttempts(AuthBruteForceService.scopeAdmin);

      final loaded = await storage.loadFailedLoginAttempts(AuthBruteForceService.scopeAdmin);
      expect(loaded['count'], equals(0));
      expect(loaded['lockedUntil'], isNull);
    });
  });
}
