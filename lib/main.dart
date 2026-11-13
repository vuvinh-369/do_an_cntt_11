// File: lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_scroll_behavior.dart';
import 'core/doctor_management/doctor_management_service.dart';
import 'core/serper/serper_config_service.dart';
import 'core/storage/local_storage_service.dart';
import 'core/supabase/supabase_service.dart';
import 'core/user_management/user_account_service.dart';
import 'core/widgets/in_app_notification_host.dart';
import 'features/admin/viewmodels/admin_viewmodel.dart';
import 'features/admin/views/admin_shell_view.dart';
import 'features/doctor/views/doctor_login_view.dart';
import 'features/doctor/views/doctor_workspace_view.dart';
import 'features/user/models/doctor_consultation_models.dart';
import 'features/user/services/doctor_consultation_service.dart';
import 'features/user/viewmodels/user_viewmodel.dart';
import 'features/user/views/user_shell_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.instance.initialize();
  unawaited(SerperConfigService.instance.fetchConfigFromSupabase());
  await LocalStorageService.instance.loadDoctorSession();
  await DoctorManagementService.instance.loadFromLocalStorage();
  await UserAccountService.instance.loadFromLocalStorage();
  DoctorManagementService.instance.subscribeRealtime();
  DoctorConsultationService.instance.subscribeRealtime();
  runApp(const MyApp());
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

/// Kiểm tra xem URL hiện tại trên trình duyệt (hoặc tên route) có phải là '/doctor' hay không.
/// Hỗ trợ cả 2 dạng:
/// 1. http://localhost:56178/doctor (Path URL)
/// 2. http://localhost:56178/#/doctor (Hash URL)
bool isBrowserUrlTargetingDoctor([String? routeName]) {
  final normalizedRoute = (routeName ?? '').trim().toLowerCase();
  if (normalizedRoute == '/doctor' ||
      normalizedRoute == 'doctor' ||
      normalizedRoute.startsWith('/doctor/') ||
      normalizedRoute.contains('#/doctor') ||
      normalizedRoute.contains('#doctor')) {
    return true;
  }

  final currentPath = Uri.base.path.trim().toLowerCase();
  if (currentPath == '/doctor' || currentPath.startsWith('/doctor/')) {
    return true;
  }

  final currentFragment = Uri.base.fragment.trim().toLowerCase();
  if (currentFragment == '/doctor' ||
      currentFragment == 'doctor' ||
      currentFragment.startsWith('/doctor/')) {
    return true;
  }

  return false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final startInAdminMode = isBrowserUrlTargetingAdmin();
    final startInDoctorMode = isBrowserUrlTargetingDoctor();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: DoctorManagementService.instance,
        ),
        ChangeNotifierProvider.value(
          value: DoctorConsultationService.instance,
        ),
        ChangeNotifierProvider(
          create: (_) => UserViewModel()..restoreSavedUserSession(),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminViewModel()
            ..syncPortalWithUrl(isAdminUrl: startInAdminMode)
            ..loadSavedAdminCredentials(),
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
        initialRoute: startInAdminMode
            ? '/admin'
            : (startInDoctorMode ? '/doctor' : '/'),
        builder: (context, child) {
          return InAppNotificationHost(
            child: child ?? const SizedBox.shrink(),
          );
        },
        onGenerateRoute: (RouteSettings settings) {
          final isRouteAdmin = isBrowserUrlTargetingAdmin(settings.name);
          final isRouteDoctor = isBrowserUrlTargetingDoctor(settings.name);

          return MaterialPageRoute(
            settings: settings,
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final adminVm = context.read<AdminViewModel>();
                if (isRouteAdmin && !adminVm.isAdminPortalActive) {
                  adminVm.openAdminPortal();
                } else if (isRouteDoctor && adminVm.isAdminPortalActive) {
                  adminVm.exitAdminPortalToUserApp();
                }
              });

              return AppRootPortalSwitcher(
                forceAdminFromRoute: isRouteAdmin,
                forceDoctorFromRoute: isRouteDoctor,
              );
            },
          );
        },
      ),
    );
  }
}

/// Bộ chuyển đổi hiển thị giữa Phân hệ Người dùng (Màn hình 1-8), Phân hệ Quản trị (/admin) và Phân hệ Bác sĩ (/doctor)
class AppRootPortalSwitcher extends StatefulWidget {
  final bool forceAdminFromRoute;
  final bool forceDoctorFromRoute;

  const AppRootPortalSwitcher({
    super.key,
    this.forceAdminFromRoute = false,
    this.forceDoctorFromRoute = false,
  });

  @override
  State<AppRootPortalSwitcher> createState() => _AppRootPortalSwitcherState();
}

class _AppRootPortalSwitcherState extends State<AppRootPortalSwitcher> {
  bool _doctorExited = false;

  @override
  Widget build(BuildContext context) {
    final isAdminActive = context.select<AdminViewModel, bool>(
      (vm) => vm.isAdminPortalActive,
    );
    final userVm = context.watch<UserViewModel>();

    final isExplicitDoctorRoute = widget.forceDoctorFromRoute && !widget.forceAdminFromRoute;
    if (!isExplicitDoctorRoute && (isAdminActive || widget.forceAdminFromRoute)) {
      return const AdminShellView();
    }

    final isDoctorSessionSaved = LocalStorageService.instance.isDoctorLoggedIn();
    if (isDoctorSessionSaved && _doctorExited) {
      _doctorExited = false;
    }

    final isDoctorMode = (widget.forceDoctorFromRoute && !_doctorExited) ||
        isDoctorSessionSaved;

    if (isDoctorMode) {
      if (isDoctorSessionSaved) {
        DoctorProfile? activeDoc;
        final savedId = LocalStorageService.instance.getDoctorSavedId();
        final savedUsername = LocalStorageService.instance.getDoctorSavedUsername();
        if (savedId != null && savedId.isNotEmpty) {
          activeDoc = DoctorManagementService.instance.getDoctorById(savedId);
        }
        if (activeDoc == null && savedUsername != null && savedUsername.isNotEmpty) {
          activeDoc = DoctorManagementService.instance.getDoctorByUsername(savedUsername);
        }

        return DoctorWorkspaceView(
          initialDoctor: activeDoc,
          onLogout: () async {
            await LocalStorageService.instance.clearDoctorSession();
            await userVm.logoutUser();
            if (mounted) {
              setState(() {
                // Quay về màn hình Đăng nhập Bác sĩ (DoctorLoginView)
              });
            }
          },
        );
      } else {
        // Chưa đăng nhập phiên Bác sĩ: hiển thị màn hình Đăng nhập Bác sĩ
        return DoctorLoginView(
          onLoginSuccess: (doctor) async {
            if (mounted) {
              setState(() {
                _doctorExited = false;
              });
            }
          },
          onExitToUserApp: () {
            setState(() {
              _doctorExited = true;
            });
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        );
      }
    }

    return const UserShellView();
  }
}
