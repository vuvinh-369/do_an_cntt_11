// File: lib/features/user/views/doctor_directory_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/doctor_management/doctor_management_service.dart';
import '../models/doctor_consultation_models.dart';
import '../viewmodels/user_viewmodel.dart';

/// Màn hình Danh bạ Bác sĩ dành cho Bệnh nhân (Yêu cầu R1)
/// Cho phép bệnh nhân tìm kiếm, xem chuyên khoa, bệnh viện công tác,
/// địa chỉ nơi làm việc, số điện thoại và chuyển ngay vào phòng tư vấn với bác sĩ đã chọn.
class DoctorDirectoryView extends StatefulWidget {
  const DoctorDirectoryView({super.key});

  @override
  State<DoctorDirectoryView> createState() => _DoctorDirectoryViewState();
}

class _DoctorDirectoryViewState extends State<DoctorDirectoryView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedSpecialty = 'all';

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
    final userVm = context.watch<UserViewModel>();
    final doctors = DoctorManagementService.instance.doctors;
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    final filtered = doctors.where((doc) {
      final query = _searchCtrl.text.trim().toLowerCase();
      final matchQuery = query.isEmpty ||
          doc.fullName.toLowerCase().contains(query) ||
          doc.specialty.toLowerCase().contains(query) ||
          doc.hospital.toLowerCase().contains(query) ||
          doc.workplaceAddress.toLowerCase().contains(query);
      final matchSpecialty = _selectedSpecialty == 'all' || doc.specialty == _selectedSpecialty;
      return matchQuery && matchSpecialty;
    }).toList();

    final allSpecialties = doctors.map((d) => d.specialty).toSet().toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Danh bạ Bác sĩ Chuyên khoa',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0D2B6B)),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm bác sĩ, chuyên khoa, bệnh viện, địa chỉ...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
                if (allSpecialties.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'Tất cả'),
                        ...allSpecialties.map((s) => _buildFilterChip(s, s)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Danh sách Card Bác sĩ
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy bác sĩ phù hợp.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : 16,
                      vertical: 16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      return _buildPatientDoctorCard(context, doc, userVm);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedSpecialty == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedSpecialty = value),
        selectedColor: const Color(0xFF2563EB),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildPatientDoctorCard(BuildContext context, DoctorProfile doctor, UserViewModel userVm) {
    final isActive = userVm.activeDoctorProfile.id == doctor.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          width: isActive ? 1.5 : 1,
        ),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: doctor.avatarColor,
                      child: Text(
                        doctor.avatarInitials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    if (doctor.isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
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
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B)),
                            ),
                          ),
                          if (doctor.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF2563EB)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${doctor.title} • ${doctor.specialty}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nơi công tác: ${doctor.hospital}',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      Text(
                        'Địa chỉ: ${doctor.workplaceAddress}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 13, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            doctor.phoneNumber,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(width: 12),
                          Text('${doctor.rating} ⭐', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          Text('(${doctor.consultationCount}+ ca)', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _showDoctorDetailBottomSheet(context, doctor),
                  child: const Text('Xem chi tiết'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    userVm.switchDoctor(doctor);
                    userVm.navigateToDoctorConsultation();
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: Text(isActive ? 'Đang tư vấn' : 'Tư vấn ngay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDoctorDetailBottomSheet(BuildContext context, DoctorProfile doctor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doctor.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D2B6B))),
            Text('${doctor.title} • ${doctor.specialty}', style: const TextStyle(fontSize: 14, color: Color(0xFF2563EB))),
            const Divider(height: 24),
            Text('• Cơ sở y tế: ${doctor.hospital}'),
            const SizedBox(height: 6),
            Text('• Địa chỉ nơi công tác: ${doctor.workplaceAddress}'),
            const SizedBox(height: 6),
            Text('• Số điện thoại liên hệ: ${doctor.phoneNumber}'),
            const SizedBox(height: 6),
            Text('• Kinh nghiệm công tác: ${doctor.experienceYears} năm'),
            const SizedBox(height: 6),
            Text('• Chi phí tư vấn: ${doctor.consultationFee}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
