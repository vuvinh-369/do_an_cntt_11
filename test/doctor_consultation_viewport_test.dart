
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:do_an_cntt_11/features/user/viewmodels/user_viewmodel.dart';
import 'package:do_an_cntt_11/features/user/views/user_shell_view.dart';
import 'package:do_an_cntt_11/features/doctor/views/doctor_consultation_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('Verify DoctorConsultationView input bar is fully visible in UserShellView on Desktop (1200x800)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final vm = UserViewModel();
    vm.navigateToDoctorConsultation();

    await tester.pumpWidget(
      ChangeNotifierProvider<UserViewModel>.value(
        value: vm,
        child: const MaterialApp(home: UserShellView()),
      ),
    );
    await tester.pumpAndSettle();

    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);

    final renderBox = tester.renderObject<RenderBox>(inputFinder);
    final pos = renderBox.localToGlobal(Offset.zero);
    final bottom = pos.dy + renderBox.size.height;

    // The chat input box must be strictly within the visible viewport (< 800)
    expect(bottom, lessThan(800.0));
    expect(pos.dy, greaterThan(0.0));
  });

  testWidgets('Verify DoctorConsultationView input bar is fully visible in UserShellView on Laptop (1366x768)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 768);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final vm = UserViewModel();
    vm.navigateToDoctorConsultation();

    await tester.pumpWidget(
      ChangeNotifierProvider<UserViewModel>.value(
        value: vm,
        child: const MaterialApp(home: UserShellView()),
      ),
    );
    await tester.pumpAndSettle();

    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);

    final renderBox = tester.renderObject<RenderBox>(inputFinder);
    final pos = renderBox.localToGlobal(Offset.zero);
    final bottom = pos.dy + renderBox.size.height;

    // The chat input box must be strictly within the visible viewport (< 768)
    expect(bottom, lessThan(768.0));
    expect(pos.dy, greaterThan(0.0));
  });

  testWidgets('Verify DoctorConsultationView input bar is fully visible on Mobile (390x844)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final vm = UserViewModel();
    vm.navigateToDoctorConsultation();

    await tester.pumpWidget(
      ChangeNotifierProvider<UserViewModel>.value(
        value: vm,
        child: const MaterialApp(home: UserShellView()),
      ),
    );
    await tester.pumpAndSettle();

    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);

    final renderBox = tester.renderObject<RenderBox>(inputFinder);
    final pos = renderBox.localToGlobal(Offset.zero);
    final bottom = pos.dy + renderBox.size.height;

    // The chat input box must be strictly within the visible viewport (< 844)
    expect(bottom, lessThan(844.0));
    expect(pos.dy, greaterThan(0.0));
  });
}
