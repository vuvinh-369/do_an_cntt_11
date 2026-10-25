import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../viewmodels/user_viewmodel.dart';
import 've_do_hoa_view.dart';

class KetQuaPhanTichView extends StatelessWidget {
  const KetQuaPhanTichView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final result = viewModel.analysisResult;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopConfidenceBanner(result),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoColumn = constraints.maxWidth >= 660;

              if (isTwoColumn) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 46,
                      child: _buildAnalyzedWoundImageCard(result),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      flex: 54,
                      child: _buildRightIdentificationColumn(
                        context,
                        viewModel,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAnalyzedWoundImageCard(result),
                    const SizedBox(height: 24),
                    _buildRightIdentificationColumn(context, viewModel),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 26),
          _buildResultBottomInfoNotice(result.bottomNoticeText),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: _buildViewFirstAidGuideButton(
              context,
              result.primaryActionLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopConfidenceBanner(AiAnalysisResultModel result) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981), width: 1.8),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF059669),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.bannerTitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  result.bannerConfidenceText,
                  style: const TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzedWoundImageCard(AiAnalysisResultModel result) {
    return Container(
      height: 336,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
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
        fit: StackFit.expand,
        children: [
          if (result.analyzedImageUrl != null &&
              result.analyzedImageUrl!.isNotEmpty)
            Image.network(
              result.analyzedImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const CustomPaint(painter: ForearmAbrasionPainter());
              },
            )
          else
            const CustomPaint(painter: ForearmAbrasionPainter()),
          Center(
            child: SizedBox(
              width: 196,
              height: 196,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                    child: Text(
                      result.boundingBoxLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF22C55E),
                          width: 2.5,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightIdentificationColumn(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    final result = viewModel.analysisResult;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
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
              Text(
                result.infoCardTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D2B6B),
                ),
              ),
              const SizedBox(height: 18),
              _buildIdentificationInfoRow(
                label: result.injuryTypeLabel,
                value: result.injuryType,
              ),
              const SizedBox(height: 14),
              _buildIdentificationInfoRow(
                label: result.confidenceRowLabel,
                value: result.formattedConfidence,
              ),
              const SizedBox(height: 14),
              _buildIdentificationInfoRow(
                label: result.locationRowLabel,
                value: viewModel.selectedLocationLabel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          result.locationSectionTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D2B6B),
          ),
        ),
        const SizedBox(height: 14),
        _buildLocationSelectorRow(context, viewModel),
      ],
    );
  }

  Widget _buildIdentificationInfoRow({
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
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
        } else if (maxWidth < 390) {
          columns = 3;
        }

        final double cardWidth =
            (maxWidth - (spacing * (columns - 1))) / columns;

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
    final Color strokeAndTextColor = isSelected
        ? const Color(0xFF2563EB)
        : const Color(0xFF64748B);
    final Color iconStrokeColor = isSelected
        ? const Color(0xFF2563EB)
        : const Color(0xFF94A3B8);

    return Material(
      color: isSelected ? const Color(0xFFEBF2FE) : const Color(0xFFFAFBFD),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            context.read<UserViewModel>().selectInjuryLocation(option.id),
        child: Container(
          height: 98,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CustomPaint(
                  painter: BodyPartIconPainter(
                    partId: option.id,
                    color: iconStrokeColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                option.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
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

  Widget _buildViewFirstAidGuideButton(BuildContext context, String label) {
    return ElevatedButton(
      onPressed: () =>
          context.read<UserViewModel>().onViewFirstAidGuidePressed(),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward_rounded, size: 19),
        ],
      ),
    );
  }
}
