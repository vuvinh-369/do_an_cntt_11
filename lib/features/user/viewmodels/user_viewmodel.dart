import 'package:flutter/material.dart';

import 'analysis_result_viewmodel.dart';
import 'chat_viewmodel.dart';
import 'document_viewmodel.dart';
import 'first_aid_viewmodel.dart';
import 'history_viewmodel.dart';
import 'home_viewmodel.dart';
import 'image_analysis_viewmodel.dart';
import 'knowledge_viewmodel.dart';
import 'user_navigation_viewmodel.dart';

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
