// File: lib/main.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'viewmodels/admin_viewmodel.dart';
import 'viewmodels/user_viewmodel.dart';
import 'views/admin_view.dart';
import 'views/user_view.dart';

void main() {
  runApp(const MyApp());
}

/// Cho phép nhấn giữ và kéo (drag to scroll) bằng cả Chuột máy tính (Mouse),
/// Cảm ứng (Touch), Trackpad và Bút cảm ứng trên Flutter Web & Desktop.
class AppCustomScrollBehavior extends MaterialScrollBehavior {
  const AppCustomScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}

/// Kiểm tra xem URL hiện tại trên trình duyệt (hoặc tên route) có phải là '/admin' hay không.
/// Hỗ trợ cả 2 dạng:
/// 1. http://localhost:56178/admin (Path URL)
/// 2. http://localhost:56178/#/admin (Hash URL)
bool isBrowserUrlTargetingAdmin([String? routeName]) {
  final normalizedRoute = (routeName ?? '').trim().toLowerCase();
  if (normalizedRoute == '/admin' ||
      normalizedRoute == 'admin' ||
      normalizedRoute.startsWith('/admin/')) {
    return true;
  }

  final currentPath = Uri.base.path.trim().toLowerCase();
  if (currentPath == '/admin' || currentPath.startsWith('/admin/')) {
    return true;
  }

  final currentFragment = Uri.base.fragment.trim().toLowerCase();
  if (currentFragment == '/admin' ||
      currentFragment == 'admin' ||
      currentFragment.startsWith('/admin/')) {
    return true;
  }

  return false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final startInAdminMode = isBrowserUrlTargetingAdmin();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserViewModel()),
        ChangeNotifierProvider(
          create: (_) =>
              AdminViewModel()..syncPortalWithUrl(isAdminUrl: startInAdminMode),
        ),
      ],
      child: MaterialApp(
        title: 'Trợ lý Cứu hộ AI',
        debugShowCheckedModeBanner: false,
        // Kích hoạt kéo cuộn bằng chuột trên toàn bộ ứng dụng Web/PC
        scrollBehavior: const AppCustomScrollBehavior(),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            primary: const Color(0xFF2563EB),
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        ),
        initialRoute: startInAdminMode ? '/admin' : '/',
        onGenerateRoute: (RouteSettings settings) {
          final isRouteAdmin = isBrowserUrlTargetingAdmin(settings.name);

          return MaterialPageRoute(
            settings: settings,
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final adminVm = context.read<AdminViewModel>();
                if (isRouteAdmin && !adminVm.isAdminPortalActive) {
                  adminVm.openAdminPortal();
                }
              });

              return AppRootPortalSwitcher(forceAdminFromRoute: isRouteAdmin);
            },
          );
        },
      ),
    );
  }
}

/// Bộ chuyển đổi hiển thị giữa Phân hệ Người dùng (Màn hình 1-8) và Phân hệ Quản trị (Màn hình 9-10)
class AppRootPortalSwitcher extends StatelessWidget {
  final bool forceAdminFromRoute;

  const AppRootPortalSwitcher({super.key, this.forceAdminFromRoute = false});

  @override
  Widget build(BuildContext context) {
    final isAdminActive = context.select<AdminViewModel, bool>(
      (vm) => vm.isAdminPortalActive,
    );

    if (isAdminActive) {
      return const AdminView();
    }
    return const UserView();
  }
}
