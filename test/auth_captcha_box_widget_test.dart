import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:do_an_cntt_11/core/security/auth_brute_force_service.dart';
import 'package:do_an_cntt_11/core/security/widgets/auth_captcha_box.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthBruteForceService.instance.resetForTest();
  });

  group('AuthCaptchaBox & Distorted Alphanumeric CAPTCHA Tests', () {
    testWidgets('1. AuthCaptchaBox is completely invisible (SizedBox.shrink) on 0 to 4 failed attempts', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthCaptchaBox(
              scope: AuthBruteForceService.scopeUser,
              controller: controller,
            ),
          ),
        ),
      );

      // 0 failures: hidden
      expect(find.byType(DistortedCaptchaView), findsNothing);
      expect(find.text('Xác thực chống spam bot (Bắt buộc)'), findsNothing);

      // 1 to 4 failures: MUST stay hidden!
      for (int i = 1; i <= 4; i++) {
        AuthBruteForceService.instance.recordFailedAttempt(AuthBruteForceService.scopeUser);
        await tester.pump();
        expect(find.byType(DistortedCaptchaView), findsNothing, reason: 'Must NOT show on attempt $i');
        expect(find.text('Xác thực chống spam bot (Bắt buộc)'), findsNothing);
      }
    });

    testWidgets('2. AuthCaptchaBox activates on the 5th consecutive failure and displays alphanumeric distorted CAPTCHA', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthCaptchaBox(
              scope: AuthBruteForceService.scopeUser,
              controller: controller,
            ),
          ),
        ),
      );

      // Trigger 5th consecutive failure
      for (int i = 1; i <= 5; i++) {
        AuthBruteForceService.instance.recordFailedAttempt(AuthBruteForceService.scopeUser);
      }
      await tester.pumpAndSettle();

      // Now it must be visible!
      expect(find.text('Xác thực chống spam bot (Bắt buộc)'), findsOneWidget);
      expect(find.text('Phát hiện đăng nhập sai nhiều lần!'), findsOneWidget);
      expect(find.byType(DistortedCaptchaView), findsOneWidget);
      expect(find.text('Nhập mã gồm 5 chữ và số ở trên...'), findsOneWidget);

      final challenge = AuthBruteForceService.instance.getOrGenerateChallenge(AuthBruteForceService.scopeUser);
      expect(challenge.code.length, 5);
      expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(challenge.code), isTrue);
    });

    testWidgets('3. DistortedCaptchaView renders custom painted canvas and refresh button works', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      for (int i = 1; i <= 5; i++) {
        AuthBruteForceService.instance.recordFailedAttempt(AuthBruteForceService.scopeAdmin);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthCaptchaBox(
              scope: AuthBruteForceService.scopeAdmin,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstChallenge = AuthBruteForceService.instance.getOrGenerateChallenge(AuthBruteForceService.scopeAdmin);
      expect(firstChallenge.code.length, 5);

      // Verify custom painter is present
      expect(find.byType(CustomPaint), findsWidgets);

      // Tap refresh icon to generate a new challenge
      await tester.tap(find.byIcon(Icons.refresh_rounded).first);
      await tester.pump();

      final secondChallenge = AuthBruteForceService.instance.getOrGenerateChallenge(AuthBruteForceService.scopeAdmin);
      expect(secondChallenge.code.length, 5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. AuthCaptchaBox does not overflow when rendered in narrow dialog width (350px)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      for (int i = 1; i <= 5; i++) {
        AuthBruteForceService.instance.recordFailedAttempt(AuthBruteForceService.scopeUser);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                child: AuthCaptchaBox(
                  scope: AuthBruteForceService.scopeUser,
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Xác thực chống spam bot (Bắt buộc)'), findsOneWidget);
      expect(find.text('Không phân biệt hoa/thường'), findsOneWidget);
    });
  });
}
