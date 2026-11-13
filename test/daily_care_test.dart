import 'package:do_an_cntt_11/features/user/models/daily_care_lesson.dart';
import 'package:do_an_cntt_11/features/user/viewmodels/user_viewmodel.dart';
import 'package:do_an_cntt_11/features/user/views/daily_care_view.dart';
import 'package:do_an_cntt_11/features/user/views/user_shell_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

DailyCareLesson _lesson(String slug, String frequency, String title) =>
    DailyCareLesson.fromRow({
      'slug': slug,
      'frequency': frequency,
      'topic': 'movement',
      'title': title,
      'summary': 'Bắt đầu với mức phù hợp.',
      'steps': ['Chọn thời gian đi bộ.'],
      'source_name': 'WHO',
      'source_url':
          'https://www.who.int/initiatives/behealthy/physical-activity',
    });

void main() {
  for (final (width, entry) in [
    (390.0, 'Chăm sóc\nhằng ngày'),
    (1200.0, 'Chăm sóc sức khỏe hằng ngày'),
  ]) {
    testWidgets('opens daily care from home at width $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1100);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => UserViewModel(),
          child: const MaterialApp(home: UserShellView()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(entry));
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();

      expect(find.byType(DailyCareView), findsOneWidget);
      expect(find.text('Hằng ngày'), findsOneWidget);
      expect(find.text('Theo tuần'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retry, filter by week, and expand the lesson with source', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyCareView(
              loadLessons: () async {
                if (++requests == 1) throw StateError('offline');
                return [
                  _lesson('di-bo', 'daily', 'Vận động buổi sáng'),
                  _lesson('lap-lich', 'weekly', 'Lên lịch vận động'),
                ];
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa tải được bài học. Vui lòng thử lại.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Vận động buổi sáng'), findsOneWidget);
    expect(find.text('Lên lịch vận động'), findsNothing);

    await tester.tap(find.text('Theo tuần'));
    await tester.pumpAndSettle();
    expect(find.text('Vận động buổi sáng'), findsNothing);
    await tester.tap(find.text('Lên lịch vận động'));
    await tester.pumpAndSettle();
    expect(find.text('1. Chọn thời gian đi bộ.'), findsOneWidget);
    expect(find.text('Nguồn: WHO'), findsOneWidget);
    expect(requests, 2);
  });
}
