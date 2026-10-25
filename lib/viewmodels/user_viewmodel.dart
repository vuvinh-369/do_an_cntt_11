import 'package:flutter/material.dart';

import 'user_viewmodel/lich_su_phan_tich_viewmodel.dart';
import 'user_viewmodel/chatbox_ai_viewmodel.dart';
import 'user_viewmodel/dieu_huong_co_so_viewmodel.dart';
import 'user_viewmodel/huong_dan_so_cuu_viewmodel.dart';
import 'user_viewmodel/ket_qua_phan_tich_viewmodel.dart';
import 'user_viewmodel/kho_tai_lieu_viewmodel.dart';
import 'user_viewmodel/phan_tich_anh_viewmodel.dart';
import 'user_viewmodel/tra_cuu_kien_thuc_viewmodel.dart';
import 'user_viewmodel/trang_chu_viewmodel.dart';

class UserViewModel extends ChangeNotifier
    with
        DieuHuongCoSoViewModel,
        HuongDanSoCuuViewModel,
        TrangChuViewModel,
        PhanTichAnhViewModel,
        KetQuaPhanTichViewModel,
        TraCuuKienThucViewModel,
        ChatBoxAiViewModel,
        KhoTaiLieuViewModel,
        LichSuPhanTichViewModel {
  @override
  void dispose() {
    chatInputController.dispose();
    chatScrollController.dispose();
    documentSearchController.dispose();
    super.dispose();
  }
}
