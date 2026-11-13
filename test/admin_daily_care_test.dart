import 'package:do_an_cntt_11/features/admin/viewmodels/admin_viewmodel.dart';
import 'package:do_an_cntt_11/features/admin/views/admin_daily_care_management_view.dart';
import 'package:do_an_cntt_11/features/admin/views/admin_shell_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('AdminDailyCareManagementView renders standalone without crashing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminDailyCareManagementView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdminDailyCareManagementView), findsOneWidget);
    expect(find.text('Quản lý Chăm sóc sức khỏe hằng ngày'), findsOneWidget);
    expect(find.text('Quản lý Bài học & Cẩm nang'), findsOneWidget);
    expect(find.text('Cấu hình Tiêu chuẩn & Thích ứng'), findsOneWidget);
    expect(find.text('Thống kê & Độ tuân thủ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Switch to Tab 1 (Config)
    await tester.tap(find.text('Cấu hình Tiêu chuẩn & Thích ứng'));
    await tester.pumpAndSettle();
    expect(find.text('Cấu hình Tham số Chuẩn & Thuật toán Trợ lý AI'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Switch to Tab 2 (Analytics)
    await tester.tap(find.text('Thống kê & Độ tuân thủ'));
    await tester.pumpAndSettle();
    expect(find.text('Thống kê Mức độ Tuân thủ & Sử dụng của Người dùng'), findsOneWidget);
    expect(find.text('Tổng ngày ghi nhận'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Navigating to daily care in AdminShellView does not crash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final adminVm = AdminViewModel();
    adminVm.completeAdminAuthentication(); // authenticate admin to enter workspace

    final dailyCareIdx = adminVm.adminSidebarItems.indexWhere(
      (item) => item.id == 'daily_care_management',
    );
    expect(dailyCareIdx, isNot(-1));

    await tester.pumpWidget(
      ChangeNotifierProvider<AdminViewModel>.value(
        value: adminVm,
        child: const MaterialApp(
          home: AdminShellView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select daily care management
    adminVm.selectAdminSidebarIndex(dailyCareIdx);
    await tester.pumpAndSettle();

    expect(find.byType(AdminDailyCareManagementView), findsOneWidget);
    expect(find.text('Quản lý Chăm sóc sức khỏe hằng ngày'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdminDailyCareManagementView renders cleanly at mobile width 390.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final adminVm = AdminViewModel();
    adminVm.completeAdminAuthentication(); // authenticate admin

    final dailyCareIdx = adminVm.adminSidebarItems.indexWhere(
      (item) => item.id == 'daily_care_management',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AdminViewModel>.value(
        value: adminVm,
        child: const MaterialApp(
          home: AdminShellView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    adminVm.selectAdminSidebarIndex(dailyCareIdx);
    await tester.pumpAndSettle();

    expect(find.byType(AdminDailyCareManagementView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
