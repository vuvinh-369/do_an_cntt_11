// File: lib/views/userview/huong_dan_so_cuu_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/first_aid_models.dart';
import '../viewmodels/user_viewmodel.dart';
import 'widgets/user_painters.dart';

class HuongDanSoCuuView extends StatelessWidget {
  const HuongDanSoCuuView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final guide = viewModel.firstAidGuide;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 36,
        vertical: isMobile ? 16 : 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            guide.screenTitle,
            style: TextStyle(
              fontSize: isMobile ? 18.5 : 23,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0D2B6B),
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: isMobile ? 14 : 20),
          _buildInjuryStatusYellowBox(guide, isMobile: isMobile),
          SizedBox(height: isMobile ? 18 : 24),
          Text(
            guide.stepsSectionTitle,
            style: TextStyle(
              fontSize: isMobile ? 16.5 : 18.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0D2B6B),
            ),
          ),
          const SizedBox(height: 12),
          _buildFirstAidStepsTimelineCard(guide.steps, isMobile: isMobile),
          SizedBox(height: isMobile ? 18 : 24),
          _buildWhenToSeeDoctorRedBox(guide, isMobile: isMobile),
          SizedBox(height: isMobile ? 18 : 24),
          if (isMobile)
            _buildBackToImageAnalysisButton(
              context,
              guide.backButtonLabel,
              isMobile: true,
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: _buildBackToImageAnalysisButton(
                context,
                guide.backButtonLabel,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInjuryStatusYellowBox(
    FirstAidGuideModel guide, {
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 22,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 42,
            height: 42,
            child: CustomPaint(painter: SoftAmberWarningTrianglePainter()),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.statusBoxTitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  guide.severityText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  guide.safetyNoteText,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstAidStepsTimelineCard(
    List<FirstAidStepModel> steps, {
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 18 : 24,
      ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(steps.length, (index) {
          final isLast = index == steps.length - 1;
          return _buildSingleFirstAidTimelineStep(
            step: steps[index],
            isLast: isLast,
            isMobile: isMobile,
          );
        }),
      ),
    );
  }

  Widget _buildSingleFirstAidTimelineStep({
    required FirstAidStepModel step,
    required bool isLast,
    bool isMobile = false,
  }) {
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 13.25,
            top: 28,
            bottom: 0,
            width: 1.5,
            child: Container(color: const Color(0xFFCBD5E1)),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : (isMobile ? 18 : 24)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${step.stepNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(9),
                ),
                padding: const EdgeInsets.all(6.5),
                child: CustomPaint(
                  painter: FirstAidStepIconPainter(stepId: step.id),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D2B6B),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhenToSeeDoctorRedBox(
    FirstAidGuideModel guide, {
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 22,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  guide.redWarningTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...guide.redWarningBullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF991B1B),
                      height: 1.45,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF991B1B),
                        height: 1.45,
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

  Widget _buildBackToImageAnalysisButton(
    BuildContext context,
    String label, {
    bool isMobile = false,
  }) {
    return SizedBox(
      width: isMobile ? double.infinity : null,
      child: ElevatedButton(
        onPressed: () =>
            context.read<UserViewModel>().onBackToImageAnalysisPressed(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: 28,
            vertical: isMobile ? 15 : 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
