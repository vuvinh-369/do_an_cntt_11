import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/rule_engine/rule_models.dart';
import '../models/image_analysis_models.dart';
import '../viewmodels/user_viewmodel.dart';
import 'widgets/user_painters.dart';

class KetQuaPhanTichView extends StatelessWidget {
  const KetQuaPhanTichView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final result = viewModel.analysisResult;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 36,
            vertical: isMobile ? 16 : 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isMobile) ...[
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          context.read<UserViewModel>().navigateBack(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF0D2B6B),
                        size: 22,
                      ),
                      tooltip: 'Quay lại',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        hoverColor: const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Kết quả phân tích hình ảnh',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2B6B),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              _buildTopConfidenceBanner(result, isMobile: isMobile),
              SizedBox(height: isMobile ? 16 : 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTwoColumn = constraints.maxWidth >= 660;

                  if (isTwoColumn) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 48,
                          child: _buildRealWoundImageCard(context, viewModel, result, isMobile: false),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 52,
                          child: _buildRightIdentificationColumn(
                            context,
                            viewModel,
                            isMobile: false,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildRealWoundImageCard(context, viewModel, result, isMobile: true),
                        const SizedBox(height: 18),
                        _buildRightIdentificationColumn(
                          context,
                          viewModel,
                          isMobile: true,
                        ),
                      ],
                    );
                  }
                },
              ),

              // Bảng chọn thủ công khi người dùng bấm "Kết quả quét không phù hợp"
              if (viewModel.isShowingManualPicker) ...[
                const SizedBox(height: 20),
                _buildManualCorrectionCard(context, viewModel, isMobile: isMobile),
              ],

              SizedBox(height: isMobile ? 18 : 26),
              _buildResultBottomInfoNotice(result.bottomNoticeText),
              SizedBox(height: isMobile ? 18 : 24),

              // Hàng nút hành động dưới cùng
              _buildBottomActionButtons(context, viewModel, result, isMobile: isMobile),
            ],
          ),
        ),

        // Lớp overlay loading hiển thị khi đang Quét lại
        if (viewModel.isAnalyzing)
          Positioned.fill(
            child: _buildReAnalyzingLoadingOverlay(context, viewModel),
          ),
      ],
    );
  }

  /// Banner đầu trang hiển thị tình trạng phát hiện vết thương
  Widget _buildTopConfidenceBanner(
    AiAnalysisResultModel result, {
    bool isMobile = false,
  }) {
    final bool isSuccess = result.isDetected && result.confidencePercent >= 50;
    final bool isLowConfidence = !result.isManualSelection &&
        (result.isDetected && result.confidencePercent < 50);
    final bool isManual = result.isManualSelection;

    final Color bgColor = isManual
        ? const Color(0xFFF0FDF4)
        : (isSuccess
            ? const Color(0xFFECFDF5)
            : (isLowConfidence ? const Color(0xFFFFF7ED) : const Color(0xFFFFFBEB)));
    final Color borderColor = isManual
        ? const Color(0xFF86EFAC)
        : (isSuccess
            ? const Color(0xFFA7F3D0)
            : (isLowConfidence ? const Color(0xFFFED7AA) : const Color(0xFFFDE68A)));
    final Color iconColor = isManual
        ? const Color(0xFF16A34A)
        : (isSuccess
            ? const Color(0xFF059669)
            : (isLowConfidence ? const Color(0xFFEA580C) : const Color(0xFFD97706)));
    final Color titleColor = isManual
        ? const Color(0xFF15803D)
        : (isSuccess
            ? const Color(0xFF15803D)
            : (isLowConfidence ? const Color(0xFFC2410C) : const Color(0xFFB45309)));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSuccess ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(color: iconColor, width: 1.8),
            ),
            child: Icon(
              isSuccess ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.bannerTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isManual
                      ? 'Người dùng đã xác nhận thủ công: ${result.injuryType}'
                      : (isLowConfidence
                          ? 'Độ tin cậy: ${result.confidencePercent}% (Không đủ chắc chắn <50%)'
                          : (isSuccess
                              ? '${result.confidenceLabelPrefix} ${result.formattedConfidence}'
                              : (result.detectionMessage ?? 'Chưa xác định độ tin cậy'))),
                  style: TextStyle(
                    fontSize: isMobile ? 15.5 : 17,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          if (result.appliedContrast != 1.0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Text(
                'Tương phản x${result.appliedContrast.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Khung hiển thị ẢNH THỰC TẾ của người dùng + Bounding Box AI
  Widget _buildRealWoundImageCard(
    BuildContext context,
    UserViewModel viewModel,
    AiAnalysisResultModel result, {
    bool isMobile = false,
  }) {
    final Uint8List? imageBytes = result.rawImageBytes;

    return Container(
      height: isMobile ? 280 : 360,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140D2B6B),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Ảnh thực tế do người dùng tải lên
          if (imageBytes != null && imageBytes.isNotEmpty)
            Positioned.fill(
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 10),
                  Text(
                    'Chưa có dữ liệu ảnh',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                ],
              ),
            ),

          // 2. Bounding Box thật của YOLO đè lên ảnh (hỗ trợ hiển thị đồng thời 2-3 vết thương)
          if (imageBytes != null && (result.allDetections.isNotEmpty || (result.boundingBox != null && result.boundingBox!.length == 4)))
            _buildRealBoundingBoxes(result),

          // 3. Tên file ảnh hiển thị góc dưới
          if (result.imageFileName != null && result.imageFileName!.isNotEmpty)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_outlined, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      result.imageFileName!,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Vẽ các khung Bounding Box theo toạ độ YOLO [x1, y1, x2, y2] (hỗ trợ nhiều vết thương)
  Widget _buildRealBoundingBoxes(AiAnalysisResultModel result) {
    final double? origW = result.originalImageWidth;
    final double? origH = result.originalImageHeight;

    final List<DetectedWoundItemModel> detections = result.allDetections.isNotEmpty
        ? result.allDetections
        : (result.boundingBox != null && result.boundingBox!.length == 4
            ? [
                DetectedWoundItemModel(
                  label: result.injuryType,
                  topicId: result.detectedTopicId,
                  confidencePercent: result.confidencePercent,
                  severity: 'Nhẹ',
                  box: result.boundingBox!,
                  classId: '',
                )
              ]
            : []);

    if (detections.isEmpty) return const SizedBox.shrink();

    if (origW == null || origH == null || origW <= 0 || origH <= 0) {
      return Center(
        child: Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEF4444), width: 2.5),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: const Color(0xFFEF4444),
            child: Text(
              result.boundingBoxLabel,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerW = constraints.maxWidth;
        final double containerH = constraints.maxHeight;

        final double imageAspect = origW / origH;
        final double containerAspect = containerW / containerH;

        double renderW, renderH, offsetX, offsetY;
        if (imageAspect > containerAspect) {
          renderW = containerW;
          renderH = containerW / imageAspect;
          offsetX = 0;
          offsetY = (containerH - renderH) / 2;
        } else {
          renderH = containerH;
          renderW = containerH * imageAspect;
          offsetX = (containerW - renderW) / 2;
          offsetY = 0;
        }

        return Stack(
          children: detections.map((det) {
            final box = det.box;
            if (box.length < 4) return const SizedBox.shrink();

            final double leftRatio = (box[0] / origW).clamp(0.0, 1.0);
            final double topRatio = (box[1] / origH).clamp(0.0, 1.0);
            final double rightRatio = (box[2] / origW).clamp(0.0, 1.0);
            final double bottomRatio = (box[3] / origH).clamp(0.0, 1.0);

            final double boxLeft = offsetX + (leftRatio * renderW);
            final double boxTop = offsetY + (topRatio * renderH);
            final double boxW = (rightRatio - leftRatio) * renderW;
            final double boxH = (bottomRatio - topRatio) * renderH;
            final boxColor = det.tagColor;

            return Positioned(
              left: boxLeft,
              top: boxTop,
              width: boxW.clamp(20.0, containerW),
              height: boxH.clamp(20.0, containerH),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: boxColor, width: 2.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      '${det.label} ${det.confidencePercent}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Cột thông tin nhận diện bên phải
  Widget _buildRightIdentificationColumn(
    BuildContext context,
    UserViewModel viewModel, {
    bool isMobile = false,
  }) {
    final result = viewModel.analysisResult;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060D2B6B),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    result.infoCardTitle,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D2B6B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: result.isManualSelection
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: result.isManualSelection
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Text(
                      result.isManualSelection ? 'Người dùng chọn' : 'YOLO AI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: result.isManualSelection
                            ? const Color(0xFF15803D)
                            : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildIdentificationInfoRow(
                label: result.injuryTypeLabel,
                value: result.injuryType,
                isHighlight: true,
              ),
              const SizedBox(height: 12),
              _buildIdentificationInfoRow(
                label: result.confidenceRowLabel,
                value: result.formattedConfidence,
              ),
              const SizedBox(height: 12),
              _buildIdentificationInfoRow(
                label: result.locationRowLabel,
                value: viewModel.selectedLocationLabel,
              ),
              if (result.detectionMessage != null && result.detectionMessage!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildIdentificationInfoRow(
                  label: 'Ghi chú:',
                  value: result.detectionMessage!,
                ),
              ],

              // Danh sách các tổn thương phát hiện đồng thời trên ảnh
              if (result.hasMultipleInjuries) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.hub_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'Tổn thương kết hợp phát hiện (${result.allDetections.length}):',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D2B6B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.allDetections.map((det) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: det.tagColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: det.tagColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: det.tagColor),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${det.label} (${det.confidencePercent}%)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: det.tagColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Khung điều chỉnh Cảm giác đau (3 mức: Không đau, Đau nhẹ, Đau nặng)
        _buildPainLevelSelector(context, viewModel, isMobile: isMobile),
        const SizedBox(height: 14),

        // 3 Checkbox bổ sung tình trạng lâm sàng (để nếu người dùng quên chọn ở bước trước có thể tích chọn lại)
        _buildClinicalCheckboxesCard(context, viewModel, isMobile: isMobile),
        const SizedBox(height: 14),

        // NÚT: "Kết quả quét không phù hợp" (cho phép chọn thủ công)
        OutlinedButton.icon(
          onPressed: () => viewModel.toggleManualPicker(),
          icon: Icon(
            viewModel.isShowingManualPicker
                ? Icons.keyboard_arrow_up_rounded
                : Icons.tune_rounded,
            color: const Color(0xFFD97706),
          ),
          label: Text(
            viewModel.isShowingManualPicker
                ? 'Ẩn danh sách chọn thủ công'
                : 'Kết quả quét không phù hợp? Chọn thủ công tại đây',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB45309),
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFFFFBEB),
            side: const BorderSide(color: Color(0xFFFDE68A), width: 1.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        const SizedBox(height: 18),
        Text(
          result.locationSectionTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D2B6B),
          ),
        ),
        const SizedBox(height: 12),
        _buildLocationSelectorRow(context, viewModel),
      ],
    );
  }

  /// Nút gạt 3 mức cảm giác đau trên Màn hình kết quả: Không đau -> Đau nhẹ -> Đau nặng
  Widget _buildPainLevelSelector(
    BuildContext context,
    UserViewModel viewModel, {
    bool isMobile = false,
  }) {
    final currentLevel = viewModel.painLevel;
    final int activeIndex = currentLevel == PainLevel.none ? 0 : (currentLevel == PainLevel.mild ? 1 : 2);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D2B6B),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: Color(0xFF2563EB), size: 19),
              const SizedBox(width: 8),
              const Text(
                'Cảm giác đau hiện tại:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D2B6B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: currentLevel.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: currentLevel.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(currentLevel.icon, size: 14, color: currentLevel.color),
                    const SizedBox(width: 4),
                    Text(
                      currentLevel.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: currentLevel.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nút gạt 3 nấc: Không đau (0) -> Đau nhẹ (1) -> Đau nặng (2)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: currentLevel.color,
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: currentLevel.color,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayColor: currentLevel.color.withValues(alpha: 0.15),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
              activeTickMarkColor: Colors.white,
              inactiveTickMarkColor: const Color(0xFF94A3B8),
            ),
            child: Slider(
              value: activeIndex.toDouble(),
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: (val) {
                viewModel.setPainLevelFromIndex(val.round());
              },
            ),
          ),

          // 3 nhãn tương tác có thể bấm trực tiếp
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => viewModel.setPainLevel(PainLevel.none),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: activeIndex == 0 ? const Color(0xFFDCFCE7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeIndex == 0 ? const Color(0xFF86EFAC) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Không đau',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: activeIndex == 0 ? FontWeight.w800 : FontWeight.w600,
                            color: activeIndex == 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '0/10',
                          style: TextStyle(
                            fontSize: 10,
                            color: activeIndex == 0 ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => viewModel.setPainLevel(PainLevel.mild),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: activeIndex == 1 ? const Color(0xFFFEF3C7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeIndex == 1 ? const Color(0xFFFCD34D) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Đau nhẹ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: activeIndex == 1 ? FontWeight.w800 : FontWeight.w600,
                            color: activeIndex == 1 ? const Color(0xFFB45309) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '1 - 4/10',
                          style: TextStyle(
                            fontSize: 10,
                            color: activeIndex == 1 ? const Color(0xFFB45309) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => viewModel.setPainLevel(PainLevel.severe),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: activeIndex == 2 ? const Color(0xFFFEE2E2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeIndex == 2 ? const Color(0xFFFCA5A5) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Đau nặng',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: activeIndex == 2 ? FontWeight.w800 : FontWeight.w600,
                            color: activeIndex == 2 ? const Color(0xFFB91C1C) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '7 - 10/10',
                          style: TextStyle(
                            fontSize: 10,
                            color: activeIndex == 2 ? const Color(0xFFB91C1C) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currentLevel.description,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  /// Khung 3 Checkbox tình trạng vết thương (bổ sung nếu người dùng quên chọn trước đó)
  Widget _buildClinicalCheckboxesCard(
    BuildContext context,
    UserViewModel viewModel, {
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D2B6B),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.checklist_rtl_rounded, color: Color(0xFF2563EB), size: 19),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tình trạng quan sát kèm theo (chọn lại nếu cần):',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D2B6B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSingleCheckboxTile(
            title: 'Dị vật cắm vào vết thương (kim loại, dằm, thủy tinh...)',
            subtitle: 'Rule Engine sẽ cảnh báo KHÔNG được tự ý rút dị vật ra',
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFEA580C),
            value: viewModel.hasForeignBody,
            onChanged: (val) {
              viewModel.toggleHasForeignBody(val);
              viewModel.toggleWarningSymptom(hasDeepWoundOrForeignBody: val ?? false);
            },
          ),
          const SizedBox(height: 8),
          _buildSingleCheckboxTile(
            title: 'Vết thương đang chảy máu (chảy nhiều hoặc liên tục)',
            subtitle: 'Hệ thống sẽ ưu tiên các bước cầm máu khẩn cấp',
            icon: Icons.water_drop_rounded,
            iconColor: const Color(0xFFDC2626),
            value: viewModel.isBleeding,
            onChanged: (val) {
              viewModel.toggleIsBleeding(val);
              viewModel.toggleWarningSymptom(isBleedingHeavy: val ?? false);
            },
          ),
          const SizedBox(height: 8),
          _buildSingleCheckboxTile(
            title: 'Vết thương chảy mủ / Sưng đỏ tấy (dấu hiệu nhiễm trùng)',
            subtitle: 'Hướng dẫn sát trùng chuyên sâu và khuyến cáo khám y tế',
            icon: Icons.healing_outlined,
            iconColor: const Color(0xFFD97706),
            value: viewModel.hasPusOrInfection,
            onChanged: (val) {
              viewModel.toggleHasPusOrInfection(val);
              viewModel.toggleWarningSymptom(hasSignsOfInfection: val ?? false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSingleCheckboxTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Material(
      color: value ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
              width: value ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: value ? FontWeight.w700 : FontWeight.w600,
                        color: value ? const Color(0xFF1E40AF) : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card cho phép người dùng tự tay chọn thủ công 1 trong 4 loại vết thương
  Widget _buildManualCorrectionCard(
    BuildContext context,
    UserViewModel viewModel, {
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10B45309),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 24),
              SizedBox(width: 10),
              Text(
                'Chọn thủ công loại vết thương đang có trong hình:',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Nếu AI nhận diện chưa chính xác hoặc ảnh mờ, bạn hãy chọn trực tiếp loại tổn thương bên dưới để mở ngay bài sơ cứu phù hợp nhất:',
            style: TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.4),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final double itemWidth = isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: viewModel.manualInjuryOptions.map((option) {
                  final isCurrentSelected =
                      viewModel.analysisResult.isManualSelection &&
                      viewModel.analysisResult.detectedTopicId == option.topicId;

                  return SizedBox(
                    width: itemWidth,
                    child: Material(
                      color: isCurrentSelected
                          ? const Color(0xFFFEF3C7)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          viewModel.selectManualInjury(option);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã chọn thủ công: ${option.label}'),
                              backgroundColor: const Color(0xFF15803D),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCurrentSelected
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFE2E8F0),
                              width: isCurrentSelected ? 1.8 : 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCurrentSelected
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  option.icon,
                                  color: isCurrentSelected
                                      ? const Color(0xFF92400E)
                                      : const Color(0xFF475569),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.label,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: isCurrentSelected
                                            ? const Color(0xFF92400E)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      option.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isCurrentSelected)
                                const Icon(Icons.check_circle, color: Color(0xFFD97706), size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIdentificationInfoRow({
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 126,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 15.5 : 14.5,
              fontWeight: FontWeight.w700,
              color: isHighlight ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSelectorRow(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const double spacing = 10;
        final int count = viewModel.injuryLocations.length;

        int columns = count;
        if (maxWidth < 280) {
          columns = 2;
        } else if (maxWidth < 420) {
          columns = 3;
        }

        final double cardWidth = (maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: viewModel.injuryLocations.map((option) {
            final isSelected = viewModel.selectedLocationId == option.id;
            return SizedBox(
              width: cardWidth,
              child: _buildSingleLocationOptionCard(
                context,
                option: option,
                isSelected: isSelected,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSingleLocationOptionCard(
    BuildContext context, {
    required InjuryLocationOptionModel option,
    required bool isSelected,
  }) {
    final Color strokeAndTextColor =
        isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B);
    final Color iconStrokeColor =
        isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8);

    return Material(
      color: isSelected ? const Color(0xFFEBF2FE) : const Color(0xFFFAFBFD),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final vm = context.read<UserViewModel>();
          vm.selectInjuryLocation(option.id);
          vm.updateLatestHistoryLocation(option.label);
        },
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CustomPaint(
                  painter: BodyPartIconPainter(
                    partId: option.id,
                    color: iconStrokeColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                option.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: strokeAndTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBottomInfoNotice(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF2563EB),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hàng nút hành động dưới cùng: Quét ảnh khác + Quét lại + Xem kết quả sơ cứu nhanh (Rule Engine) + Xem kết quả với AI
  Widget _buildBottomActionButtons(
    BuildContext context,
    UserViewModel viewModel,
    AiAnalysisResultModel result, {
    bool isMobile = false,
  }) {
    return Wrap(
      alignment: isMobile ? WrapAlignment.center : WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        // 1. Nút chọn ảnh khác
        OutlinedButton.icon(
          onPressed: () => viewModel.onSelectImageFromFilePressed(context),
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: const Text('Quét ảnh khác'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0D2B6B),
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.3),
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isMobile ? 13 : 15,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        // 2. Nút QUÉT LẠI (TĂNG TƯƠNG PHẢN CONTRAST)
        OutlinedButton.icon(
          onPressed: () {
            // Chu kỳ tương phản: 1.0 -> 1.35 -> 1.6 -> 0.8
            final double current = result.appliedContrast;
            double nextContrast = 1.35;
            if (current == 1.35) {
              nextContrast = 1.6;
            } else if (current == 1.6) {
              nextContrast = 0.85;
            } else {
              nextContrast = 1.35;
            }
            viewModel.reScanWithContrast(context, newContrast: nextContrast);
          },
          icon: const Icon(Icons.contrast_rounded, size: 18, color: Color(0xFF2563EB)),
          label: Text(
            result.appliedContrast != 1.0
                ? 'Quét lại (x${result.appliedContrast == 1.35 ? 1.6 : 1.35})'
                : 'Quét lại (Tương phản)',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFEFF6FF),
            side: const BorderSide(color: Color(0xFF93C5FD), width: 1.3),
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isMobile ? 13 : 15,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        // 3. Nút XEM KẾT QUẢ SƠ CỨU NHANH (SỬ DỤNG RULE ENGINE & KNOWLEDGE BASE)
        ElevatedButton.icon(
          onPressed: () => context.read<UserViewModel>().onViewFirstAidGuidePressed(),
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: const Text(
            'Xem kết quả sơ cứu nhanh',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E40AF),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: isMobile ? 14 : 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        // 4. Nút XEM KẾT QUẢ VỚI AI (CHUYỂN PROMPT SANG CHATBOX AI)
        ElevatedButton.icon(
          onPressed: () => context.read<UserViewModel>().consultAiWithCurrentAnalysis(),
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text(
            'Xem kết quả với AI',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            elevation: 1,
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: isMobile ? 14 : 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  /// Lớp overlay loading hiển thị khi đang Quét lại
  Widget _buildReAnalyzingLoadingOverlay(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final int percent = (viewModel.analysisProgress * 100).clamp(0, 100).toInt();

    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x380D2B6B),
                  blurRadius: 36,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF2563EB),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Đang Quét Lại AI...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D2B6B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Áp dụng độ tương phản x${viewModel.appliedContrast.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                // THANH TIẾN TRÌNH PROGRESS BAR
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: viewModel.analysisProgress,
                    minHeight: 12,
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
                        fontSize: 14.5,
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
                    fontSize: 13,
                    color: Color(0xFF334155),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
