import 'package:flutter/material.dart';

import 'admin_viewmodel/dang_nhap_quan_tri_viewmodel.dart';
import 'admin_viewmodel/dashboard_quan_tri_viewmodel.dart';
import 'admin_viewmodel/dieu_huong_quan_tri_viewmodel.dart';

class AdminViewModel extends ChangeNotifier
    with
        DieuHuongQuanTriViewModel,
        DangNhapQuanTriViewModel,
        DashboardQuanTriViewModel {}
