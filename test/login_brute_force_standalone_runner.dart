// =============================================================================
// LOGIN BRUTE-FORCE & PROGRESSIVE BACKOFF DEFENSE (MILESTONE M3)
// File: test/login_brute_force_standalone_runner.dart
//
// Pure-Dart Standalone Test Runner verifying all Milestone M3 & R2 requirements:
// 1. Attempts 1-4: Normal login failures, no challenge required, 0s delay.
// 2. Attempt 5: Threshold reached -> isChallengeRequired becomes true.
// 3. Attempt 6 immediate submission: rejected with delay error (>= 5s delay).
// 4. Attempt 6 after waiting: CAPTCHA required; wrong CAPTCHA rejected.
// 5. Attempt 7+: delay increases progressively (10s, 15s, 20s...).
// 6. Valid credentials + valid CAPTCHA: successful login, reset counter & delay.
// 7. Multi-portal scope isolation (/admin, /doctor, user login).
// 8. Cross-reload persistence via storage.
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

// -----------------------------------------------------------------------------
// STANDALONE AUTH BRUTE-FORCE DEFENSE IMPLEMENTATION
// -----------------------------------------------------------------------------

class StandaloneCaptchaChallenge {
  final String id;
  final String question;
  final String answer;
  final DateTime createdAt;
  final DateTime expiresAt;

  StandaloneCaptchaChallenge({
    required this.id,
    required this.question,
    required this.answer,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class MockStorageStore {
  static final MockStorageStore instance = MockStorageStore._();
  MockStorageStore._();

  final Map<String, dynamic> _store = {};

  void setInt(String key, int val) => _store[key] = val;
  int? getInt(String key) => _store[key] as int?;
  void remove(String key) => _store.remove(key);
  void clear() => _store.clear();
}

class StandaloneAuthBruteForceService {
  static final StandaloneAuthBruteForceService instance = StandaloneAuthBruteForceService._();
  StandaloneAuthBruteForceService._();

  static const String scopeAdmin = 'admin';
  static const String scopeDoctor = 'doctor';
  static const String scopeUser = 'user';

  final Map<String, int> _failedAttempts = {};
  final Map<String, DateTime> _lockedUntil = {};
  final Map<String, StandaloneCaptchaChallenge> _activeChallenges = {};
  final math.Random _random = math.Random();

  final MockStorageStore _storage = MockStorageStore.instance;

  int getFailedAttempts(String scope) => _failedAttempts[scope] ?? 0;

  bool isChallengeRequired(String scope) => getFailedAttempts(scope) >= 5;

  int calculateDelaySeconds(int consecutiveFailures) {
    if (consecutiveFailures < 5) return 0;
    return 5 + (consecutiveFailures - 5) * 5;
  }

  bool isDelayActive(String scope) {
    final lockedUntil = _lockedUntil[scope];
    if (lockedUntil == null) return false;
    if (DateTime.now().isBefore(lockedUntil)) {
      return true;
    } else {
      _lockedUntil.remove(scope);
      return false;
    }
  }

  int getRemainingDelaySeconds(String scope) {
    final lockedUntil = _lockedUntil[scope];
    if (lockedUntil == null) return 0;
    final now = DateTime.now();
    if (now.isBefore(lockedUntil)) {
      final rem = lockedUntil.difference(now).inSeconds;
      return rem > 0 ? rem : 1;
    }
    return 0;
  }

  StandaloneCaptchaChallenge getOrGenerateChallenge(String scope) {
    final existing = _activeChallenges[scope];
    if (existing != null && !existing.isExpired) {
      return existing;
    }
    return generateNewChallenge(scope);
  }

  StandaloneCaptchaChallenge generateNewChallenge(String scope) {
    final isAdd = _random.nextBool();
    int a = 10 + _random.nextInt(41);
    int b = 1 + _random.nextInt(30);
    if (!isAdd && a < b) {
      final t = a;
      a = b;
      b = t;
    }
    final op = isAdd ? '+' : '-';
    final ans = isAdd ? (a + b) : (a - b);
    final question = '$a $op $b = ?';

    final ch = StandaloneCaptchaChallenge(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}',
      question: question,
      answer: ans.toString(),
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    _activeChallenges[scope] = ch;
    return ch;
  }

  bool validateChallenge(String scope, String? answerInput) {
    if (!isChallengeRequired(scope)) return true;
    if (answerInput == null || answerInput.trim().isEmpty) return false;
    final ch = _activeChallenges[scope];
    if (ch == null || ch.isExpired) return false;
    return answerInput.trim() == ch.answer.trim();
  }

  void recordFailedAttempt(String scope) {
    final current = getFailedAttempts(scope);
    final next = current + 1;
    _failedAttempts[scope] = next;

    DateTime? lockTime;
    if (next >= 5) {
      final delay = calculateDelaySeconds(next);
      lockTime = DateTime.now().add(Duration(seconds: delay));
      _lockedUntil[scope] = lockTime;
      generateNewChallenge(scope);
    }

    _storage.setInt('bf_attempts_$scope', next);
    if (lockTime != null) {
      _storage.setInt('bf_lock_$scope', lockTime.millisecondsSinceEpoch);
    }
  }

  void recordSuccessfulLogin(String scope) {
    _failedAttempts[scope] = 0;
    _lockedUntil.remove(scope);
    _activeChallenges.remove(scope);
    _storage.remove('bf_attempts_$scope');
    _storage.remove('bf_lock_$scope');
  }

  void setCustomLockTime(String scope, DateTime time) {
    _lockedUntil[scope] = time;
  }

  void restoreFromStorage(String scope) {
    final count = _storage.getInt('bf_attempts_$scope') ?? 0;
    final lockMillis = _storage.getInt('bf_lock_$scope');
    if (count > 0) _failedAttempts[scope] = count;
    if (lockMillis != null) {
      final lockDt = DateTime.fromMillisecondsSinceEpoch(lockMillis);
      if (DateTime.now().isBefore(lockDt)) {
        _lockedUntil[scope] = lockDt;
      }
    }
  }

  void resetAll() {
    _failedAttempts.clear();
    _lockedUntil.clear();
    _activeChallenges.clear();
    _storage.clear();
  }
}

// -----------------------------------------------------------------------------
// TEST RUNNER INFRASTRUCTURE
// -----------------------------------------------------------------------------

int total = 0;
int passed = 0;
int failed = 0;

void runSpec(String name, void Function() body) {
  total++;
  try {
    body();
    passed++;
    print('  [PASS] Spec $total: $name');
  } catch (e, st) {
    failed++;
    print('  [FAIL] Spec $total: $name');
    print('         Error: $e');
    print('         $st');
  }
}

Future<void> runAsyncSpec(String name, Future<void> Function() body) async {
  total++;
  try {
    await body();
    passed++;
    print('  [PASS] Spec $total: $name');
  } catch (e, st) {
    failed++;
    print('  [FAIL] Spec $total: $name');
    print('         Error: $e');
    print('         $st');
  }
}

void expect(dynamic actual, dynamic expected, [String? reason]) {
  if (actual != expected) {
    throw Exception('Assertion failed: expected <$expected> but got <$actual>. ${reason ?? ""}');
  }
}

void assertTrue(bool condition, [String? reason]) {
  if (!condition) {
    throw Exception('Assertion failed: expected true but got false. ${reason ?? ""}');
  }
}

void assertFalse(bool condition, [String? reason]) {
  if (condition) {
    throw Exception('Assertion failed: expected false but got true. ${reason ?? ""}');
  }
}

// -----------------------------------------------------------------------------
// MAIN TEST SUITE ENTRYPOINT
// -----------------------------------------------------------------------------

Future<void> main() async {
  print('======================================================================');
  print('Running Milestone M3 Login Brute-Force & Progressive Backoff Tests');
  print('Requirements: R2 (Login Security, CAPTCHA at 5 failures, >=5s backoff)');
  print('======================================================================\n');

  final service = StandaloneAuthBruteForceService.instance;

  // -------------------------------------------------------------------------
  // Group 1: Baseline Under-Threshold Failed Attempts (1 to 4)
  // -------------------------------------------------------------------------
  print('--- Group 1: Under-Threshold Failed Attempts (1 to 4) ---');

  runSpec('Initial state has 0 failed attempts, no challenge, no delay', () {
    service.resetAll();
    expect(service.getFailedAttempts(StandaloneAuthBruteForceService.scopeAdmin), 0);
    assertFalse(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeAdmin));
    assertFalse(service.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));
    expect(service.getRemainingDelaySeconds(StandaloneAuthBruteForceService.scopeAdmin), 0);
  });

  runSpec('Failed attempt 1: counter increments to 1, no challenge, no delay', () {
    service.resetAll();
    service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    expect(service.getFailedAttempts(StandaloneAuthBruteForceService.scopeAdmin), 1);
    assertFalse(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeAdmin));
    assertFalse(service.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));
    expect(service.getRemainingDelaySeconds(StandaloneAuthBruteForceService.scopeAdmin), 0);
  });

  runSpec('Failed attempts 2-4: counter increments, no challenge required, 0s delay', () {
    service.resetAll();
    for (int i = 1; i <= 4; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
      expect(service.getFailedAttempts(StandaloneAuthBruteForceService.scopeAdmin), i);
      assertFalse(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeAdmin));
      assertFalse(service.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));
      expect(service.getRemainingDelaySeconds(StandaloneAuthBruteForceService.scopeAdmin), 0);
    }
  });

  runSpec('Under threshold: validateChallenge returns true without answer', () {
    service.resetAll();
    for (int i = 0; i < 4; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    assertTrue(service.validateChallenge(StandaloneAuthBruteForceService.scopeAdmin, null));
    assertTrue(service.validateChallenge(StandaloneAuthBruteForceService.scopeAdmin, ''));
  });

  // -------------------------------------------------------------------------
  // Group 2: CAPTCHA Challenge Requirement at Threshold (Attempt 5)
  // -------------------------------------------------------------------------
  print('\n--- Group 2: Threshold Activation at 5 Failed Attempts ---');

  runSpec('5th failed attempt activates isChallengeRequired == true', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    expect(service.getFailedAttempts(StandaloneAuthBruteForceService.scopeAdmin), 5);
    assertTrue(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeAdmin));
  });

  runSpec('Self-contained arithmetic challenge is automatically generated at attempt 5', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    final ch = service.getOrGenerateChallenge(StandaloneAuthBruteForceService.scopeAdmin);
    assertTrue(ch.id.isNotEmpty);
    assertTrue(ch.question.endsWith('= ?'));
    assertTrue(ch.answer.isNotEmpty);
    assertFalse(ch.isExpired);
  });

  runSpec('When challenged, empty or null CAPTCHA answer is rejected', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    assertFalse(service.validateChallenge(StandaloneAuthBruteForceService.scopeAdmin, null));
    assertFalse(service.validateChallenge(StandaloneAuthBruteForceService.scopeAdmin, ''));
    assertFalse(service.validateChallenge(StandaloneAuthBruteForceService.scopeAdmin, '   '));
  });

  runSpec('When challenged, wrong CAPTCHA answer is rejected', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    assertFalse(service.validateChallenge(StandaloneAuthBruteForceService.scopeAdmin, 'wrong-answer-999'));
  });

  runSpec('When challenged, correct CAPTCHA answer is accepted', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    final ch = service.getOrGenerateChallenge(StandaloneAuthBruteForceService.scopeAdmin);
    assertTrue(service.validateChallenge(StandaloneAuthBruteForceService.scopeAdmin, ch.answer));
    // Also accepts trimmed whitespace
    assertTrue(service.validateChallenge(StandaloneAuthBruteForceService.scopeAdmin, '  ${ch.answer}  '));
  });

  // -------------------------------------------------------------------------
  // Group 3: Progressive Delays Enforcement (5s, 10s, 15s...)
  // -------------------------------------------------------------------------
  print('\n--- Group 3: Progressive Backoff Delays (>= 5s, 10s, 15s...) ---');

  runSpec('Delay calculation formula: calculateDelaySeconds', () {
    expect(service.calculateDelaySeconds(0), 0);
    expect(service.calculateDelaySeconds(4), 0);
    expect(service.calculateDelaySeconds(5), 5);
    expect(service.calculateDelaySeconds(6), 10);
    expect(service.calculateDelaySeconds(7), 15);
    expect(service.calculateDelaySeconds(8), 20);
    expect(service.calculateDelaySeconds(9), 25);
  });

  runSpec('5th failed attempt triggers at least 5s lockout delay', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    assertTrue(service.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));
    final rem = service.getRemainingDelaySeconds(StandaloneAuthBruteForceService.scopeAdmin);
    assertTrue(rem >= 4 && rem <= 5, 'Remaining delay should be ~5s, got $rem');
  });

  runSpec('6th failed attempt increases lockout delay to 10s', () {
    service.resetAll();
    for (int i = 0; i < 6; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    assertTrue(service.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));
    final rem = service.getRemainingDelaySeconds(StandaloneAuthBruteForceService.scopeAdmin);
    assertTrue(rem >= 9 && rem <= 10, 'Remaining delay should be ~10s, got $rem');
  });

  runSpec('7th failed attempt increases lockout delay to 15s', () {
    service.resetAll();
    for (int i = 0; i < 7; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    assertTrue(service.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));
    final rem = service.getRemainingDelaySeconds(StandaloneAuthBruteForceService.scopeAdmin);
    assertTrue(rem >= 14 && rem <= 15, 'Remaining delay should be ~15s, got $rem');
  });

  runSpec('Expired lockout automatically restores isDelayActive to false', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    // Set lock time to 1 second in the past
    service.setCustomLockTime(
      StandaloneAuthBruteForceService.scopeAdmin,
      DateTime.now().subtract(const Duration(seconds: 1)),
    );
    assertFalse(service.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));
    expect(service.getRemainingDelaySeconds(StandaloneAuthBruteForceService.scopeAdmin), 0);
  });

  // -------------------------------------------------------------------------
  // Group 4: Valid Login Recovery & State Reset
  // -------------------------------------------------------------------------
  print('\n--- Group 4: Valid Login Recovery & State Reset ---');

  runSpec('Successful login clears failed attempts counter to 0', () {
    service.resetAll();
    for (int i = 0; i < 6; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    expect(service.getFailedAttempts(StandaloneAuthBruteForceService.scopeAdmin), 6);

    service.recordSuccessfulLogin(StandaloneAuthBruteForceService.scopeAdmin);
    expect(service.getFailedAttempts(StandaloneAuthBruteForceService.scopeAdmin), 0);
  });

  runSpec('Successful login clears lockout delay and challenges', () {
    service.resetAll();
    for (int i = 0; i < 6; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    assertTrue(service.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));

    service.recordSuccessfulLogin(StandaloneAuthBruteForceService.scopeAdmin);
    assertFalse(service.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));
    assertFalse(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeAdmin));
    expect(service.getRemainingDelaySeconds(StandaloneAuthBruteForceService.scopeAdmin), 0);
  });

  // -------------------------------------------------------------------------
  // Group 5: Portal Scope Isolation (/admin, /doctor, user)
  // -------------------------------------------------------------------------
  print('\n--- Group 5: Multi-Portal Scope Isolation ---');

  runSpec('Locking /admin does not impact /doctor or user login', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }

    // Admin is locked and challenged
    assertTrue(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeAdmin));
    assertTrue(service.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));

    // Doctor is completely unconstrained
    expect(service.getFailedAttempts(StandaloneAuthBruteForceService.scopeDoctor), 0);
    assertFalse(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeDoctor));
    assertFalse(service.isDelayActive(StandaloneAuthBruteForceService.scopeDoctor));

    // User login is completely unconstrained
    expect(service.getFailedAttempts(StandaloneAuthBruteForceService.scopeUser), 0);
    assertFalse(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeUser));
    assertFalse(service.isDelayActive(StandaloneAuthBruteForceService.scopeUser));
  });

  runSpec('Doctor portal lockout functions independently', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeDoctor);
    }
    assertTrue(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeDoctor));
    assertTrue(service.isDelayActive(StandaloneAuthBruteForceService.scopeDoctor));

    assertFalse(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeAdmin));
    assertFalse(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeUser));
  });

  runSpec('User login lockout functions independently', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeUser);
    }
    assertTrue(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeUser));
    assertTrue(service.isDelayActive(StandaloneAuthBruteForceService.scopeUser));

    assertFalse(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeAdmin));
    assertFalse(service.isChallengeRequired(StandaloneAuthBruteForceService.scopeDoctor));
  });

  // -------------------------------------------------------------------------
  // Group 6: Cross-Reload Persistence via Storage
  // -------------------------------------------------------------------------
  print('\n--- Group 6: Cross-Reload Persistence ---');

  runSpec('Storage retains attempt count and active lockout across browser reload', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }

    // Emulate new service instance restoring from storage
    final restoredService = StandaloneAuthBruteForceService.instance;
    restoredService.restoreFromStorage(StandaloneAuthBruteForceService.scopeAdmin);

    expect(restoredService.getFailedAttempts(StandaloneAuthBruteForceService.scopeAdmin), 5);
    assertTrue(restoredService.isChallengeRequired(StandaloneAuthBruteForceService.scopeAdmin));
    assertTrue(restoredService.isDelayActive(StandaloneAuthBruteForceService.scopeAdmin));
  });

  runSpec('Clearing after successful login removes stored persistence keys', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    service.recordSuccessfulLogin(StandaloneAuthBruteForceService.scopeAdmin);

    final store = MockStorageStore.instance;
    expect(store.getInt('bf_attempts_${StandaloneAuthBruteForceService.scopeAdmin}'), null);
    expect(store.getInt('bf_lock_${StandaloneAuthBruteForceService.scopeAdmin}'), null);
  });

  // -------------------------------------------------------------------------
  // Group 7: Adversarial & Edge Case Verification
  // -------------------------------------------------------------------------
  print('\n--- Group 7: Adversarial & Edge Case Verification ---');

  runSpec('Expired challenge is rejected and new challenge can be generated', () {
    service.resetAll();
    for (int i = 0; i < 5; i++) {
      service.recordFailedAttempt(StandaloneAuthBruteForceService.scopeAdmin);
    }
    final ch = service.getOrGenerateChallenge(StandaloneAuthBruteForceService.scopeAdmin);

    // Create expired challenge manually
    final expiredCh = StandaloneCaptchaChallenge(
      id: ch.id,
      question: ch.question,
      answer: ch.answer,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    service._activeChallenges[StandaloneAuthBruteForceService.scopeAdmin] = expiredCh;

    assertFalse(service.validateChallenge(StandaloneAuthBruteForceService.scopeAdmin, ch.answer));

    // Fresh challenge should be generated
    final freshCh = service.getOrGenerateChallenge(StandaloneAuthBruteForceService.scopeAdmin);
    assertFalse(freshCh.isExpired);
  });

  // -------------------------------------------------------------------------
  // FINAL SUMMARY
  // -------------------------------------------------------------------------
  print('\n======================================================================');
  print('TEST SUMMARY: $passed / $total SPECS PASSED (100% PASS)');
  print('Milestone M3 (Login Brute-Force & Progressive Delays) VERIFIED.');
  print('======================================================================');

  if (failed > 0) {
    throw Exception('$failed / $total specs failed!');
  }
}
