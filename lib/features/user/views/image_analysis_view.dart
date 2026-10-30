import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/image_analysis_models.dart';
import '../viewmodels/user_viewmodel.dart';
import 'widgets/user_painters.dart';

class PhanTichAnhView extends StatelessWidget {
  const PhanTichAnhView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final spec = viewModel.uploadSpec;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () {
          context.read<UserViewModel>().onPasteImagePressed(context);
        },
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () {
          context.read<UserViewModel>().onPasteImagePressed(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 40,
                vertical: isMobile ? 18 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isMobile) ...[
                    Text(
                      spec.screenTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2B6B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Nếu đã nạp ảnh vào (Staged): Hiển thị khung xem trước và nút Bắt đầu quét
                  if (viewModel.hasStagedImage)
                    _buildStagedImagePreviewArea(context, viewModel, isMobile: isMobile)
                  else
                    // Chưa có ảnh: Hiển thị khung kéo thả / chọn tệp
                    _buildDashedUploadArea(context, viewModel, spec, isMobile: isMobile),

                  SizedBox(height: isMobile ? 20 : 28),
                  _buildOrCaptureDivider(spec.dividerText),
                  SizedBox(height: isMobile ? 18 : 24),

                  if (isMobile)
                    _buildPasteImageButton(
                      context,
                      viewModel,
                      spec.cameraButtonLabel,
                      isMobile: true,
                    )
                  else
                    Center(
                      child: _buildPasteImageButton(
                        context,
                        viewModel,
                        spec.cameraButtonLabel,
                      ),
                    ),
                  SizedBox(height: isMobile ? 22 : 32),
                  _buildBottomWarningNotice(spec, isMobile: isMobile),
                ],
              ),
            ),

            // Lớp phủ hiển thị trạng thái khi AI đang quét ảnh kèm Progress Bar
            if (viewModel.isAnalyzing)
              _buildAnalyzingLoadingOverlay(context, viewModel),
          ],
        ),
      ),
    );
  }

  /// Khung hiển thị ảnh xem trước khi người dùng vừa chọn/dán xong, kèm nút "Bắt đầu quét AI"
  Widget _buildStagedImagePreviewArea(
    BuildContext context,
    UserViewModel viewModel, {
    bool isMobile = false,
  }) {
    final imageBytes = viewModel.stagedImageBytes;
    final imageName = viewModel.stagedImageName ?? 'Ảnh được chọn';
    final imageSizeKb = ((imageBytes?.length ?? 0) / 1024).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D2B6B),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.preview_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ảnh đã nạp thành công',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D2B6B),
                      ),
                    ),
                    Text(
                      '$imageName ($imageSizeKb KB)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => viewModel.clearStagedImage(),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                tooltip: 'Hủy ảnh này',
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Khung ảnh xem trước
          Container(
            height: isMobile ? 240 : 340,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageBytes != null
                ? Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // Hàng nút hành động: Nút QUÉT AI + Nút đổi ảnh khác
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => viewModel.onSelectImageFromFilePressed(context),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Đổi ảnh khác'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => viewModel.onPasteImagePressed(context),
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: const Text('Dán ảnh khác (Ctrl+V)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),

              // NÚT CHÍNH: BẮT ĐẦU QUÉT AI
              ElevatedButton.icon(
                onPressed: () => viewModel.startAnalysis(context),
                icon: const Icon(Icons.auto_awesome, size: 20),
                label: const Text('Bắt đầu quét phân tích AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashedUploadArea(
    BuildContext context,
    UserViewModel viewModel,
    AiUploadSpecModel spec, {
    bool isMobile = false,
  }) {
    return CustomPaint(
      painter: const DashedBorderPainter(
        color: Color(0xFFBFDBFE),
        strokeWidth: 1.8,
        dashLength: 7.0,
        gapLength: 5.0,
        borderRadius: 14.0,
      ),
      child: Material(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => viewModel.onSelectImageFromFilePressed(context),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 24,
              vertical: isMobile ? 28 : 44,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 68,
                  height: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: const [
                      Icon(
                        Icons.cloud_outlined,
                        size: 64,
                        color: Color(0xFF2563EB),
                      ),
                      Positioned(
                        bottom: 10,
                        child: Icon(
                          Icons.add,
                          size: 26,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D2B6B),
                    ),
                    children: [
                      TextSpan(text: spec.dropzonePrefixText),
                      TextSpan(
                        text: spec.dropzoneActionText,
                        style: const TextStyle(color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  spec.supportedFormatsText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 12.5 : 13.5,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => viewModel.onSelectImageFromFilePressed(context),
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: Text(spec.selectButtonLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : 28,
                          vertical: isMobile ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => viewModel.onPasteImagePressed(context),
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      label: const Text('Dán ảnh (Ctrl+V)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF93C5FD), width: 1.4),
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 22,
                          vertical: isMobile ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrCaptureDivider(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
      ],
    );
  }

  Widget _buildPasteImageButton(
    BuildContext context,
    UserViewModel viewModel,
    String label, {
    bool isMobile = false,
  }) {
    return OutlinedButton(
      onPressed: () => viewModel.onPasteImagePressed(context),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D2B6B),
        side: const BorderSide(color: Color(0xFFD8E3F2), width: 1.5),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 32,
          vertical: isMobile ? 14 : 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEBF2FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.content_paste_go_rounded,
              color: Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D2B6B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomWarningNotice(
    AiUploadSpecModel spec, {
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.noticeBoldText,
                  style: TextStyle(
                    fontSize: isMobile ? 13.5 : 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D2B6B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.noticeDetailText,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF334155),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lớp overlay loading hiển thị khi AI đang quét hình ảnh, có PROGRESS BAR và % tiến trình thực tế
  Widget _buildAnalyzingLoadingOverlay(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final int percent = (viewModel.analysisProgress * 100).clamp(0, 100).toInt();

    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          width: 360,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330D2B6B),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF2563EB),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'AI Đang Phân Tích Hình Ảnh',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D2B6B),
                ),
              ),
              const SizedBox(height: 14),

              // THANH TIẾN TRÌNH PROGRESS BAR
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: viewModel.analysisProgress,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tiến độ phân tích:',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                viewModel.analysisStatusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF334155),
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
