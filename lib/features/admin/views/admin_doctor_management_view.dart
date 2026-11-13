// File: lib/features/admin/views/admin_doctor_management_view.dart
import 'package:flutter/material.dart';

import '../../../core/doctor_management/doctor_management_service.dart';
import '../../../core/user_management/user_account_service.dart';
import '../../user/models/doctor_consultation_models.dart';

/// Màn hình Quản lý Bác sĩ trong phân hệ Quản trị (/admin)
/// Cung cấp đầy đủ tính năng CRUD thông tin Bác sĩ:
/// - Thống kê KPI: Tổng số bác sĩ, Trực tuyến, Đã xác thực, Chuyên khoa
/// - Tìm kiếm theo tên, SĐT, bệnh viện, chuyên khoa & Lọc theo trạng thái
/// - Thêm mới & Chỉnh sửa Bác sĩ với ràng buộc SĐT Việt Nam & Địa chỉ công tác
/// - Xóa bác sĩ với hộp thoại xác nhận an toàn
class AdminDoctorManagementView extends StatefulWidget {
  const AdminDoctorManagementView({super.key});

  @override
  State<AdminDoctorManagementView> createState() => _AdminDoctorManagementViewState();
}

class _AdminDoctorManagementViewState extends State<AdminDoctorManagementView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedSpecialty = 'all';
  String _statusFilter = 'all'; // 'all', 'online', 'offline'
  int _currentPage = 1;
  static const int _pageSize = 6;

  @override
  void initState() {
    super.initState();
    DoctorManagementService.instance.addListener(_onServiceUpdate);
    DoctorManagementService.instance.fetchDoctors();
  }

  @override
  void dispose() {
    DoctorManagementService.instance.removeListener(_onServiceUpdate);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = DoctorManagementService.instance;
    final allDoctors = service.doctors;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    // Lọc theo từ khóa, chuyên khoa và trạng thái online
    final filtered = allDoctors.where((doc) {
      final query = _searchCtrl.text.trim().toLowerCase();
      final matchQuery = query.isEmpty ||
          doc.fullName.toLowerCase().contains(query) ||
          doc.phoneNumber.toLowerCase().contains(query) ||
          doc.hospital.toLowerCase().contains(query) ||
          doc.specialty.toLowerCase().contains(query);

      final matchSpecialty = _selectedSpecialty == 'all' || doc.specialty == _selectedSpecialty;

      final matchStatus = _statusFilter == 'all' ||
          (_statusFilter == 'online' && doc.isOnline) ||
          (_statusFilter == 'offline' && !doc.isOnline);

      return matchQuery && matchSpecialty && matchStatus;
    }).toList();

    // Thống kê KPI
    final totalCount = allDoctors.length;
    final onlineCount = allDoctors.where((d) => d.isOnline).length;
    final verifiedCount = allDoctors.where((d) => d.isVerified).length;
    final specialtyCount = allDoctors.map((d) => d.specialty).toSet().length;

    // Phân trang
    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final pageItems = filtered.skip(startIndex).take(_pageSize).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 28,
        vertical: isMobile ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Nút thêm bác sĩ
          _buildHeader(context, isMobile),
          const SizedBox(height: 18),

          // Thẻ KPI thống kê
          _buildKpiStatCards(totalCount, onlineCount, verifiedCount, specialtyCount, isMobile),
          const SizedBox(height: 18),

          // Thanh tìm kiếm và bộ lọc
          _buildSearchAndFilterBar(allDoctors),
          const SizedBox(height: 16),

          // Danh sách Bác sĩ
          if (service.isLoading && allDoctors.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (pageItems.isEmpty)
            _buildEmptyPlaceholder()
          else
            ...pageItems.map((doc) => _buildDoctorCard(doc, isMobile)),

          const SizedBox(height: 16),
          // Phân trang
          if (filtered.isNotEmpty)
            _buildPaginationBar(
              currentPage: currentPage,
              totalPages: totalPages,
              totalItems: filtered.length,
              onPageChanged: (p) => setState(() => _currentPage = p),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Quản lý Bác sĩ hệ thống',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D2B6B),
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Quản lý danh sách, hồ sơ công tác, số điện thoại, địa chỉ và trạng thái trực tuyến của các bác sĩ.',
                style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _showDoctorFormDialog(context),
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: Text(isMobile ? 'Thêm' : 'Thêm Bác sĩ mới'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiStatCards(int total, int online, int verified, int specialties, bool isMobile) {
    final items = [
      _buildStatTile('Tổng số Bác sĩ', '$total', Icons.medical_services_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
      _buildStatTile('Đang trực tuyến', '$online', Icons.check_circle_outline_rounded, const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
      _buildStatTile('Đã xác thực', '$verified', Icons.verified_user_outlined, const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
      _buildStatTile('Chuyên khoa', '$specialties', Icons.category_outlined, const Color(0xFF7C3AED), const Color(0xFFF3E8FF)),
    ];

    if (isMobile) {
      return Column(
        children: items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
      );
    }

    return Row(
      children: items.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: w))).toList(),
    );
  }

  Widget _buildStatTile(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(List<DoctorProfile> allDoctors) {
    final allSpecialties = allDoctors.map((d) => d.specialty).toSet().toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() => _currentPage = 1),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, SĐT, bệnh viện...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              _buildStatusFilterChip('all', 'Tất cả'),
              _buildStatusFilterChip('online', 'Trực tuyến'),
              _buildStatusFilterChip('offline', 'Ngoại tuyến'),
            ],
          ),
          if (allSpecialties.isNotEmpty)
            DropdownButton<String>(
              value: _selectedSpecialty,
              underline: const SizedBox(),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('Tất cả chuyên khoa')),
                ...allSpecialties.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (val) {
                if (val != null) setState(() { _selectedSpecialty = val; _currentPage = 1; });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() { _statusFilter = value; _currentPage = 1; }),
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    );
  }

  Widget _buildDoctorCard(DoctorProfile doctor, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: doctor.avatarColor,
                    child: Text(
                      doctor.avatarInitials,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: doctor.isOnline ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            doctor.fullName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (doctor.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF2563EB)),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: doctor.isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: doctor.isOnline ? const Color(0xFFBBF7D0) : const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            doctor.isOnline ? 'TRỰC TUYẾN' : 'OFFLINE',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: doctor.isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Chip trạng thái tài khoản đăng nhập (Yêu cầu R2)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: doctor.hasAccount ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: doctor.hasAccount ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                doctor.hasAccount ? Icons.account_circle : Icons.warning_amber_rounded,
                                size: 13,
                                color: doctor.hasAccount ? const Color(0xFF15803D) : const Color(0xFFB45309),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                doctor.hasAccount ? 'Đã cấp TK: @${doctor.accountUsername}' : 'Chưa cấp TK',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: doctor.hasAccount ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${doctor.title} • ${doctor.specialty}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              doctor.phoneNumber,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_hospital_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(doctor.hospital, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(doctor.workplaceAddress, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Action buttons
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (!doctor.hasAccount)
                ElevatedButton.icon(
                  onPressed: () => _showProvisionAccountDialog(context, doctor),
                  icon: const Icon(Icons.key_rounded, size: 15),
                  label: const Text('Cấp tài khoản', style: TextStyle(fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _showAccountInfoDialog(context, doctor),
                  icon: const Icon(Icons.badge_outlined, size: 15, color: Color(0xFF16A34A)),
                  label: Text(
                    'Thông tin TK (@${doctor.accountUsername})',
                    style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFBBF7D0)),
                    backgroundColor: const Color(0xFFF0FDF4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _showDoctorFormDialog(context, doctorToEdit: doctor),
                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Chỉnh sửa', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _confirmDeleteDoctor(context, doctor),
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                label: const Text('Xóa', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: const [
          Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text(
            'Không tìm thấy bác sĩ nào phù hợp',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          ),
          SizedBox(height: 4),
          Text(
            'Thử thay đổi từ khóa tìm kiếm hoặc lọc theo chuyên khoa khác.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required ValueChanged<int> onPageChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tổng: $totalItems bác sĩ ($_pageSize mục/trang)',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              Text(
                'Trang $currentPage / $totalPages',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HỘP THOẠI THÊM / SỬA BÁC SĨ (VỚI RÀNG BUỘC SĐT & ĐỊA CHỈ NƠI CÔNG TÁC)
  // ===========================================================================

  void _showDoctorFormDialog(BuildContext context, {DoctorProfile? doctorToEdit}) {
    final formKey = GlobalKey<FormState>();
    final isEditing = doctorToEdit != null;

    final nameCtrl = TextEditingController(text: doctorToEdit?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: doctorToEdit?.phoneNumber ?? '');
    final addressCtrl = TextEditingController(text: doctorToEdit?.workplaceAddress ?? '');
    final titleCtrl = TextEditingController(text: doctorToEdit?.title ?? 'BS. CKI');
    final specialtyCtrl = TextEditingController(text: doctorToEdit?.specialty ?? 'Ngoại Chấn thương & Xử trí Vết thương cấp');
    final hospitalCtrl = TextEditingController(text: doctorToEdit?.hospital ?? 'Bệnh viện Đa khoa Trung ương');
    final expCtrl = TextEditingController(text: (doctorToEdit?.experienceYears ?? 10).toString());
    final feeCtrl = TextEditingController(text: doctorToEdit?.consultationFee ?? 'Tư vấn sơ cứu miễn phí');

    bool isOnline = doctorToEdit?.isOnline ?? true;
    bool isVerified = doctorToEdit?.isVerified ?? true;
    bool provisionAccount = false;
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'Bacsi@123');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.person_add_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  Text(isEditing ? 'Cập nhật thông tin Bác sĩ' : 'Thêm Bác sĩ mới'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Họ và tên
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên Bác sĩ *',
                            hintText: 'VD: BS. CKI Nguyễn Văn A',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 3) {
                              return 'Họ và tên phải có tối thiểu 3 ký tự.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Số điện thoại (Regex VN)
                        TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại liên hệ *',
                            hintText: 'VD: 0912345678 hoặc +84912345678',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Số điện thoại không được để trống.';
                            }
                            final clean = v.trim();
                            final phoneRegex = RegExp(r'^(0|\+84)[0-9]{9}$');
                            if (!phoneRegex.hasMatch(clean)) {
                              return 'Số điện thoại không hợp lệ (VD: 0912345678 hoặc +84912345678).';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Địa chỉ nơi công tác
                        TextFormField(
                          controller: addressCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Địa chỉ nơi công tác *',
                            hintText: 'VD: Số 215 Hồng Bàng, Phường 11, Quận 5, TP. Hồ Chí Minh',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 5) {
                              return 'Địa chỉ nơi công tác phải có tối thiểu 5 ký tự.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Chức danh & Chuyên khoa
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: titleCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Chức danh *',
                                  hintText: 'VD: BS. CKI, ThS.BS',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: expCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Năm kinh nghiệm',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: specialtyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Chuyên khoa *',
                            hintText: 'VD: Ngoại Chấn thương, Cấp cứu',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Chuyên khoa bắt buộc' : null,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: hospitalCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Bệnh viện / Cơ sở y tế *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Bệnh viện bắt buộc' : null,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: feeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mức phí tư vấn',
                            hintText: 'VD: Tư vấn sơ cứu miễn phí',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Trạng thái Switchers
                        SwitchListTile(
                          title: const Text('Trực tuyến (Sẵn sàng tiếp nhận ca bệnh)', style: TextStyle(fontSize: 13.5)),
                          value: isOnline,
                          onChanged: (val) => setModalState(() => isOnline = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: const Text('Đã xác minh chứng chỉ hành nghề y tế', style: TextStyle(fontSize: 13.5)),
                          value: isVerified,
                          onChanged: (val) => setModalState(() => isVerified = val),
                          contentPadding: EdgeInsets.zero,
                        ),

                        // Phần mở rộng: Cấp tài khoản đăng nhập ngay khi thêm Bác sĩ mới (Yêu cầu R2)
                        if (!isEditing) ...[
                          const Divider(height: 24),
                          SwitchListTile(
                            title: const Text(
                              'Cấp tài khoản đăng nhập ngay',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                            ),
                            subtitle: const Text(
                              'Tạo tài khoản Bác sĩ và liên kết tự động với hồ sơ chuyên môn này',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: provisionAccount,
                            onChanged: (val) {
                              setModalState(() {
                                provisionAccount = val;
                                if (val && usernameCtrl.text.isEmpty && nameCtrl.text.isNotEmpty) {
                                  final clean = nameCtrl.text.trim().toLowerCase()
                                      .replaceAll('bs.', '')
                                      .replaceAll('cki', '')
                                      .replaceAll('ckii', '')
                                      .replaceAll('ths.', '')
                                      .trim();
                                  final slug = clean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                                  usernameCtrl.text = 'bs_$slug';
                                }
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (provisionAccount) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: usernameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Tên đăng nhập Bác sĩ *',
                                hintText: 'VD: bs_an_nguyen',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.alternate_email, size: 18),
                              ),
                              validator: (v) {
                                if (provisionAccount) {
                                  if (v == null || v.trim().length < 3) {
                                    return 'Tên đăng nhập tối thiểu 3 ký tự.';
                                  }
                                  if (v.trim().contains(' ')) {
                                    return 'Tên đăng nhập không được chứa khoảng trắng.';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: passwordCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Mật khẩu khởi tạo *',
                                hintText: 'Tối thiểu 6 ký tự',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.lock_outline, size: 18),
                              ),
                              validator: (v) {
                                if (provisionAccount && (v == null || v.length < 6)) {
                                  return 'Mật khẩu tối thiểu 6 ký tự.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final cleanName = nameCtrl.text.trim();
                    final parts = cleanName.split(' ').where((p) => p.isNotEmpty).toList();
                    final initials = parts.length >= 2
                        ? '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase()
                        : (parts.isNotEmpty ? parts[0][0].toUpperCase() : 'BS');

                    final doctorData = DoctorProfile(
                      id: isEditing ? doctorToEdit.id : 'doc_${DateTime.now().millisecondsSinceEpoch}',
                      fullName: cleanName,
                      phoneNumber: phoneCtrl.text.trim(),
                      workplaceAddress: addressCtrl.text.trim(),
                      title: titleCtrl.text.trim(),
                      specialty: specialtyCtrl.text.trim(),
                      hospital: hospitalCtrl.text.trim(),
                      experienceYears: int.tryParse(expCtrl.text.trim()) ?? 10,
                      consultationFee: feeCtrl.text.trim(),
                      avatarInitials: initials.isNotEmpty ? initials : 'BS',
                      avatarColor: doctorToEdit?.avatarColor ?? const Color(0xFF1D4ED8),
                      avatarUrl: doctorToEdit?.avatarUrl,
                      rating: doctorToEdit?.rating ?? 4.95,
                      consultationCount: doctorToEdit?.consultationCount ?? 1500,
                      isOnline: isOnline,
                      statusText: isOnline ? 'Đang trực tuyến • Sẵn sàng hỗ trợ sơ cứu' : 'Hiện đang ngoại tuyến',
                      isVerified: isVerified,
                      accountUsername: isEditing ? doctorToEdit.accountUsername : null,
                    );

                    Navigator.pop(ctx);

                    if (isEditing) {
                      await DoctorManagementService.instance.updateDoctor(doctorData);
                      if (context.mounted) _showToast(context, 'Đã cập nhật thông tin bác sĩ ${doctorData.fullName}.');
                    } else {
                      final addedDoctor = await DoctorManagementService.instance.addDoctor(doctorData);
                      if (provisionAccount && usernameCtrl.text.trim().isNotEmpty) {
                        final provErr = await UserAccountService.instance.createDoctorAccount(
                          username: usernameCtrl.text.trim(),
                          password: passwordCtrl.text.trim(),
                          doctorId: addedDoctor.id,
                          fullName: addedDoctor.fullName,
                          phone: addedDoctor.phoneNumber,
                        );
                        if (context.mounted) {
                          if (provErr != null) {
                            _showToast(context, 'Đã thêm bác sĩ nhưng cấp tài khoản lỗi: $provErr');
                          } else {
                            _showToast(context, 'Đã thêm bác sĩ ${addedDoctor.fullName} và cấp tài khoản @${usernameCtrl.text.trim()} thành công!');
                          }
                        }
                      } else {
                        if (context.mounted) _showToast(context, 'Đã thêm mới bác sĩ ${addedDoctor.fullName}.');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  child: Text(isEditing ? 'Lưu thay đổi' : 'Thêm Bác sĩ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // HỘP THOẠI CẤP TÀI KHOẢN ĐĂNG NHẬP BÁC SĨ (PROVISION DOCTOR ACCOUNT DIALOG)
  // ===========================================================================

  void _showProvisionAccountDialog(BuildContext context, DoctorProfile doctor) {
    final formKey = GlobalKey<FormState>();
    String defaultUsername = doctor.accountUsername ?? '';
    if (defaultUsername.isEmpty) {
      if (doctor.id == 'doc_an_nguyen' || doctor.fullName.contains('Nguyễn Văn An')) {
        defaultUsername = 'bs_an';
      } else {
        final cleanId = doctor.id.replaceFirst('doc_', '');
        defaultUsername = 'bs_$cleanId';
      }
    }

    final userCtrl = TextEditingController(text: defaultUsername);
    final passCtrl = TextEditingController(text: 'Bacsi@123');
    final confirmPassCtrl = TextEditingController(text: 'Bacsi@123');
    bool obscurePass = true;
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cấp tài khoản Bác sĩ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(
                          doctor.fullName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        TextFormField(
                          controller: userCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tên đăng nhập (Username) *',
                            hintText: 'VD: bs_an_nguyen',
                            prefixIcon: Icon(Icons.alternate_email, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 3) {
                              return 'Tên đăng nhập phải có ít nhất 3 ký tự.';
                            }
                            if (v.trim().contains(' ')) {
                              return 'Tên đăng nhập không được chứa khoảng trắng.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passCtrl,
                          obscureText: obscurePass,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu khởi tạo *',
                            hintText: 'Tối thiểu 6 ký tự',
                            prefixIcon: const Icon(Icons.lock_outline, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setModalState(() => obscurePass = !obscurePass),
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.length < 6) {
                              return 'Mật khẩu phải có ít nhất 6 ký tự.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmPassCtrl,
                          obscureText: obscurePass,
                          decoration: const InputDecoration(
                            labelText: 'Xác nhận mật khẩu *',
                            prefixIcon: Icon(Icons.lock_outline, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v != passCtrl.text) {
                              return 'Mật khẩu xác nhận không khớp.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thông tin liên kết tự động:',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 4),
                              const Text('• Vai trò: Bác sĩ tư vấn (doctor)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              Text('• Mã bác sĩ: ${doctor.id}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              Text('• SĐT liên hệ: ${doctor.phoneNumber}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          final result = await UserAccountService.instance.createDoctorAccount(
                            username: userCtrl.text.trim(),
                            password: passCtrl.text.trim(),
                            doctorId: doctor.id,
                            fullName: doctor.fullName,
                            phone: doctor.phoneNumber,
                          );

                          if (!context.mounted) return;

                          if (result != null) {
                            setModalState(() {
                              isSubmitting = false;
                              errorMessage = result;
                            });
                          } else {
                            Navigator.pop(ctx);
                            await DoctorManagementService.instance.fetchDoctors();
                            if (mounted) setState(() {});
                            _showToast(
                              context,
                              'Đã cấp tài khoản @${userCtrl.text.trim()} thành công cho bác sĩ ${doctor.fullName}!',
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Cấp tài khoản'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // HỘP THOẠI THÔNG TIN TÀI KHOẢN BÁC SĨ (ACCOUNT INFO & RESET PASSWORD)
  // ===========================================================================

  void _showAccountInfoDialog(BuildContext context, DoctorProfile doctor) {
    final account = UserAccountService.instance.findByUsername(doctor.accountUsername ?? '');
    final newPassCtrl = TextEditingController();
    bool isResetting = false;
    String? statusMsg;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_user_outlined, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Thông tin Tài khoản Bác sĩ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(
                          doctor.fullName,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tên đăng nhập:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                Text(
                                  '@${doctor.accountUsername}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Vai trò hệ thống:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    account?.role.toUpperCase() ?? 'DOCTOR',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB), fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Mã hồ sơ liên kết:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                Text(doctor.id, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Trạng thái tài khoản:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                Text(
                                  account?.isLocked == true ? 'Đang bị khóa' : 'Hoạt động bình thường',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: account?.isLocked == true ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Đặt lại mật khẩu
                      const Text(
                        'Đặt lại mật khẩu cho Bác sĩ:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newPassCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Nhập mật khẩu mới (>= 6 ký tự)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isResetting
                                ? null
                                : () async {
                                    final pass = newPassCtrl.text.trim();
                                    if (pass.length < 6) {
                                      setModalState(() => statusMsg = 'Mật khẩu phải từ 6 ký tự trở lên.');
                                      return;
                                    }
                                    setModalState(() {
                                      isResetting = true;
                                      statusMsg = null;
                                    });

                                    await UserAccountService.instance.changePassword(doctor.accountUsername!, pass);
                                    if (!context.mounted) return;
                                    setModalState(() {
                                      isResetting = false;
                                      statusMsg = 'Đã đổi mật khẩu thành công!';
                                      newPassCtrl.clear();
                                    });
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            child: isResetting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Đổi MK'),
                          ),
                        ],
                      ),
                      if (statusMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          statusMsg!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: statusMsg!.contains('thành công') ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // HỘP THOẠI XÁC NHẬN XÓA BÁC SĨ
  // ===========================================================================

  void _confirmDeleteDoctor(BuildContext context, DoctorProfile doctor) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Xác nhận xóa Bác sĩ'),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa bác sĩ ${doctor.fullName} (${doctor.title} - ${doctor.specialty}) khỏi hệ thống?\n\n'
            'Địa chỉ công tác: ${doctor.workplaceAddress}\n'
            'Số điện thoại: ${doctor.phoneNumber}\n\n'
            'Hành động này sẽ gỡ bỏ hồ sơ bác sĩ khỏi danh sách tư vấn của bệnh nhân.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await DoctorManagementService.instance.deleteDoctor(doctor.id);
                if (context.mounted) {
                  _showToast(context, 'Đã xóa bác sĩ ${doctor.fullName} khỏi hệ thống.');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              child: const Text('Xác nhận xóa'),
            ),
          ],
        );
      },
    );
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
