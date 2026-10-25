import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../viewmodels/user_viewmodel.dart';
import 've_do_hoa_view.dart';

class KhoTaiLieuView extends StatelessWidget {
  const KhoTaiLieuView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hàng Tiêu đề "Kho tài liệu y tế" (Trái) + Nút "+ Thêm tài liệu" (Phải)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Text(
                'Kho tài liệu y tế',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D2B6B),
                  letterSpacing: -0.3,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _showAddLocalDocumentDialog(context, viewModel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Thêm tài liệu',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // 2. Hàng Thanh tìm kiếm "Tìm kiếm tài liệu..." + Dropdown "Tất cả danh mục"
          _buildDocumentsSearchAndDropdownRow(context, viewModel),
          const SizedBox(height: 22),

          // 3. Khu vực chính: Cột danh mục tài liệu bên trái + Bảng danh sách tài liệu bên phải
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideContent = constraints.maxWidth >= 680;

              if (isWideContent) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 200,
                      child: _buildDocumentCategorySubMenu(
                        context,
                        viewModel,
                        isVertical: true,
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: _buildMedicalDocumentsTableCard(
                        context,
                        viewModel,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDocumentCategorySubMenu(
                      context,
                      viewModel,
                      isVertical: false,
                    ),
                    const SizedBox(height: 16),
                    _buildMedicalDocumentsTableCard(context, viewModel),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // 4. Thanh phân trang (< 1 2 3 >) ở góc dưới bên phải
          Align(
            alignment: Alignment.centerRight,
            child: _buildDocumentsPaginationBar(context, viewModel),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSearchAndDropdownRow(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;

        final searchBox = Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD8E3F2), width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: TextField(
            controller: viewModel.documentSearchController,
            onChanged: (value) =>
                context.read<UserViewModel>().updateDocumentSearchQuery(value),
            style: const TextStyle(
              fontSize: 14.5,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              icon: Icon(
                Icons.search_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              hintText: 'Tìm kiếm tài liệu...',
              hintStyle: TextStyle(
                fontSize: 14.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        );

        final categoryDropdown = Container(
          height: 46,
          width: isCompact ? double.infinity : 210,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD8E3F2), width: 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: viewModel.selectedDocumentCategoryId,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF475569),
                size: 22,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              items: viewModel.documentCategories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat.id,
                  child: Text(
                    cat.dropdownLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (selectedId) {
                if (selectedId != null) {
                  context.read<UserViewModel>().selectDocumentCategory(
                    selectedId,
                  );
                }
              },
            ),
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [searchBox, const SizedBox(height: 10), categoryDropdown],
          );
        }

        return Row(
          children: [
            Expanded(child: searchBox),
            const SizedBox(width: 14),
            categoryDropdown,
          ],
        );
      },
    );
  }

  Widget _buildDocumentCategorySubMenu(
    BuildContext context,
    UserViewModel viewModel, {
    required bool isVertical,
  }) {
    if (!isVertical) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: viewModel.documentCategories.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildSingleDocumentCategoryItem(context, viewModel, cat),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: viewModel.documentCategories.map((cat) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildSingleDocumentCategoryItem(context, viewModel, cat),
        );
      }).toList(),
    );
  }

  Widget _buildSingleDocumentCategoryItem(
    BuildContext context,
    UserViewModel viewModel,
    MedicalDocumentCategoryModel category,
  ) {
    final isSelected = viewModel.selectedDocumentCategoryId == category.id;
    final displayLabel = viewModel.getDocumentCategorySidebarLabel(category);

    return Material(
      color: isSelected ? const Color(0xFFE8F1FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            context.read<UserViewModel>().selectDocumentCategory(category.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CustomPaint(
                  painter: DocumentSubCategoryIconPainter(
                    categoryId: category.id,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  displayLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicalDocumentsTableCard(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final docs = viewModel.filteredMedicalDocuments;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050D2B6B),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: const [
                Expanded(
                  flex: 52,
                  child: Text(
                    'Tên tài liệu',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                Expanded(
                  flex: 28,
                  child: Text(
                    'Danh mục',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Text(
                    'Ngày thêm',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8EEF5)),
          if (docs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42, horizontal: 20),
              child: Center(
                child: Text(
                  'Không tìm thấy tài liệu y tế phù hợp.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ...List.generate(docs.length, (index) {
              final doc = docs[index];
              final isLast = index == docs.length - 1;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSingleMedicalDocumentRow(context, viewModel, doc),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSingleMedicalDocumentRow(
    BuildContext context,
    UserViewModel viewModel,
    MedicalDocumentModel doc,
  ) {
    final isHighlightedBadge = doc.categoryId == 'basic_first_aid';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _showOpenAndManageDocumentDialog(context, viewModel, doc),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 52,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF2FE),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const CustomPaint(
                        painter: MedicalDocumentRowIconPainter(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            doc.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D2B6B),
                              height: 1.3,
                            ),
                          ),
                          if (doc.isUserAdded) ...[
                            const SizedBox(height: 3),
                            Text(
                              '${doc.fileName} (${doc.fileSize})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 28,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isHighlightedBadge ? 10 : 0,
                      vertical: isHighlightedBadge ? 5 : 0,
                    ),
                    decoration: isHighlightedBadge
                        ? BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          )
                        : null,
                    child: Text(
                      doc.categoryLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 20,
                child: Text(
                  doc.dateAdded,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddLocalDocumentDialog(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final titleController = TextEditingController();
    final fileNameController = TextEditingController(
      text: viewModel.sampleDeviceFiles.first['fileName'],
    );
    final localPathController = TextEditingController(
      text: viewModel.sampleDeviceFiles.first['localFilePath'],
    );
    final summaryController = TextEditingController();

    String selectedCategoryId = 'basic_first_aid';
    String selectedExtension =
        viewModel.sampleDeviceFiles.first['fileExtension']!;
    String selectedFileSize = viewModel.sampleDeviceFiles.first['fileSize']!;

    final selectableCategories = viewModel.documentCategories
        .where((c) => c.id != 'all')
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.upload_file_rounded,
                              color: Color(0xFF2563EB),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thêm tài liệu y tế vào thiết bị',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0D2B6B),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Lưu trữ, phân loại và mở tệp tài liệu cục bộ trên thiết bị',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),
                      const Text(
                        '1. Chọn tệp trên thiết bị:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: viewModel.sampleDeviceFiles.map((fileInfo) {
                          final isCurrentFile =
                              fileNameController.text == fileInfo['fileName'];
                          return ActionChip(
                            backgroundColor: isCurrentFile
                                ? const Color(0xFFE8F1FF)
                                : const Color(0xFFF8FAFC),
                            side: BorderSide(
                              color: isCurrentFile
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFE2E8F0),
                            ),
                            avatar: Icon(
                              Icons.insert_drive_file_outlined,
                              size: 16,
                              color: isCurrentFile
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF64748B),
                            ),
                            label: Text(
                              fileInfo['fileName']!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isCurrentFile
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCurrentFile
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF334155),
                              ),
                            ),
                            onPressed: () {
                              setModalState(() {
                                fileNameController.text = fileInfo['fileName']!;
                                localPathController.text =
                                    fileInfo['localFilePath']!;
                                selectedExtension = fileInfo['fileExtension']!;
                                selectedFileSize = fileInfo['fileSize']!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '2. Tên tài liệu y tế (*):',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'Nhập tên tài liệu (ví dụ: Sổ tay sơ cứu gia đình)',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF94A3B8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '3. Phân loại danh mục:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategoryId,
                            isExpanded: true,
                            items: selectableCategories.map((cat) {
                              return DropdownMenuItem<String>(
                                value: cat.id,
                                child: Text(cat.dropdownLabel),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedCategoryId = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '4. Đường dẫn tệp lưu trữ cục bộ trên thiết bị:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: localPathController,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.folder_outlined,
                            size: 19,
                            color: Color(0xFF2563EB),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '5. Tóm tắt nội dung tài liệu:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2B6B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: summaryController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'Mô tả ngắn gọn nội dung tệp tài liệu y tế...',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF94A3B8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text(
                              'Hủy',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              final enteredTitle = titleController.text.trim();
                              final finalTitle = enteredTitle.isNotEmpty
                                  ? enteredTitle
                                  : fileNameController.text
                                        .replaceAll('.pdf', '')
                                        .replaceAll('.docx', '')
                                        .replaceAll('.txt', '')
                                        .replaceAll('_', ' ');

                              viewModel.addLocalMedicalDocument(
                                title: finalTitle,
                                categoryId: selectedCategoryId,
                                fileName: fileNameController.text,
                                fileExtension: selectedExtension,
                                fileSize: selectedFileSize,
                                localFilePath: localPathController.text,
                                summary: summaryController.text,
                              );
                              Navigator.of(dialogContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text(
                              'Lưu tài liệu vào thiết bị',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showOpenAndManageDocumentDialog(
    BuildContext context,
    UserViewModel viewModel,
    MedicalDocumentModel doc,
  ) {
    bool isEditing = false;
    final editTitleController = TextEditingController(text: doc.title);
    final editSummaryController = TextEditingController(text: doc.summary);
    String editCategoryId = doc.categoryId;

    final selectableCategories = viewModel.documentCategories
        .where((c) => c.id != 'all')
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.all(9),
                            child: const CustomPaint(
                              painter: MedicalDocumentRowIconPainter(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Quản lý & Phân loại tài liệu'
                                      : doc.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0D2B6B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F1FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        viewModel.getCategoryLabelById(
                                          editCategoryId,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Ngày thêm: ${doc.dateAdded}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.sd_storage_outlined,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tệp cục bộ: ${doc.fileName} (${doc.fileExtension} • ${doc.fileSize})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Đường dẫn thiết bị: ${doc.localFilePath}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isEditing) ...[
                        const Text(
                          'Tên tài liệu:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D2B6B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: editTitleController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Phân loại danh mục:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D2B6B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: editCategoryId,
                              isExpanded: true,
                              items: selectableCategories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat.id,
                                  child: Text(cat.dropdownLabel),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    editCategoryId = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tóm tắt nội dung:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D2B6B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: editSummaryController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          doc.summary,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF334155),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...doc.contentPoints.map(
                          (point) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              point,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              viewModel.deleteMedicalDocument(doc.id);
                              Navigator.of(dialogContext).pop();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                            ),
                            label: const Text(
                              'Xóa tài liệu',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  if (isEditing) {
                                    viewModel.updateMedicalDocument(
                                      id: doc.id,
                                      newTitle: editTitleController.text,
                                      newCategoryId: editCategoryId,
                                      newSummary: editSummaryController.text,
                                    );
                                    Navigator.of(dialogContext).pop();
                                  } else {
                                    setModalState(() {
                                      isEditing = true;
                                    });
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0D2B6B),
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: Icon(
                                  isEditing
                                      ? Icons.check_rounded
                                      : Icons.edit_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  isEditing
                                      ? 'Lưu thay đổi'
                                      : 'Phân loại / Sửa',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!isEditing &&
                                  doc.relatedGuideTopicId != null) ...[
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    viewModel.navigateToFirstAidGuide(
                                      topicId: doc.relatedGuideTopicId,
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF2563EB),
                                    side: const BorderSide(
                                      color: Color(0xFFBFDBFE),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Hướng dẫn sơ cứu',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Đóng',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocumentsPaginationBar(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPaginationArrowButton(
          icon: Icons.chevron_left_rounded,
          onTap: () => context.read<UserViewModel>().goToPreviousDocumentPage(),
        ),
        const SizedBox(width: 6),
        ...[1, 2, 3].map((page) {
          final isSelected = viewModel.currentDocumentPage == page;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Material(
              color: isSelected ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    context.read<UserViewModel>().selectDocumentPage(page),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    '$page',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 6),
        _buildPaginationArrowButton(
          icon: Icons.chevron_right_rounded,
          onTap: () => context.read<UserViewModel>().goToNextDocumentPage(),
        ),
      ],
    );
  }

  Widget _buildPaginationArrowButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }
}
