import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:do_an_cntt_11/core/serper/serper_config_service.dart';
import 'package:do_an_cntt_11/features/admin/viewmodels/admin_viewmodel.dart';
import 'package:do_an_cntt_11/features/admin/views/admin_settings_view.dart';

void main() {
  test('SerperConfigService.testApiKey handles success, 400 credits, and 401', () async {
    final service = SerperConfigService.instance;

    final emptyResult = await service.testApiKey('   ');
    expect(emptyResult.isSuccess, isFalse);

    final okClient = MockClient((request) async {
      expect(request.url.toString(), 'https://google.serper.dev/maps');
      expect(request.headers['X-API-KEY'], 'good-serper-key');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'places': [
              {'title': 'Bệnh viện A'},
              {'title': 'Bệnh viện B'},
            ],
            'credits': 3,
          }),
        ),
        200,
      );
    });

    final okResult = await service.testApiKey('good-serper-key', client: okClient);
    expect(okResult.isSuccess, isTrue);
    expect(okResult.statusCode, 200);
    expect(okResult.sampleCount, 2);
    expect(okResult.credits, 3);
    expect(okResult.message, contains('2 địa điểm mẫu'));

    final outOfCreditsClient = MockClient(
      (_) async => http.Response(
        jsonEncode({'message': 'Not enough credits'}),
        400,
      ),
    );
    final creditResult = await service.testApiKey(
      'empty-credit-key',
      client: outOfCreditsClient,
    );
    expect(creditResult.isSuccess, isFalse);
    expect(creditResult.statusCode, 400);
    expect(creditResult.message, contains('hết credit'));
    expect(creditResult.message, contains('Not enough credits'));

    final unauthorizedClient = MockClient(
      (_) async => http.Response(
        jsonEncode({'message': 'Unauthorized'}),
        401,
      ),
    );
    final unauthResult = await service.testApiKey(
      'bad-key',
      client: unauthorizedClient,
    );
    expect(unauthResult.isSuccess, isFalse);
    expect(unauthResult.statusCode, 401);
    expect(unauthResult.message, contains('không hợp lệ'));
  });

  testWidgets('AdminSettingsView renders Serper card and updates key status pill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<AdminViewModel>(
        create: (_) => AdminViewModel(),
        child: const MaterialApp(
          home: Scaffold(body: AdminSettingsView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2. Cấu hình Google Maps (Serper.dev API)'), findsOneWidget);
    expect(find.text('Key mặc định'), findsOneWidget);
    expect(find.text('Kiểm tra kết nối Serper'), findsOneWidget);
    expect(find.text('Lưu & Áp dụng ngay'), findsOneWidget);
    expect(find.text('Dán nhanh'), findsOneWidget);
    expect(find.text('Tải từ Supabase'), findsOneWidget);
    expect(find.text('Khôi phục key mặc định'), findsOneWidget);

    final serperField = find.widgetWithText(
      TextField,
      kDefaultSerperApiKey,
    );
    expect(serperField, findsOneWidget);

    await tester.enterText(serperField, 'custom-serper-key-123');
    await tester.pump();

    expect(find.text('Key tùy chỉnh (Supabase)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
