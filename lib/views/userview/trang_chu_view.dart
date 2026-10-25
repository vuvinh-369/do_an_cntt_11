import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../viewmodels/user_viewmodel.dart';

class TrangChuView extends StatelessWidget {
  const TrangChuView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroSection(context, viewModel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeatureCardsSection(context, viewModel),
              const SizedBox(height: 36),
              _buildCommonSituationsSection(context, viewModel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection(BuildContext context, UserViewModel viewModel) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBF4FF), Color(0xFFDCEBFE)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: _buildHeroLeftColumn(context)),
                const SizedBox(width: 32),
                Expanded(flex: 5, child: _buildHeroRightIllustration()),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroLeftColumn(context),
                const SizedBox(height: 28),
                Center(child: _buildHeroRightIllustration()),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildHeroLeftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sơ cứu đúng cách\nBảo vệ sức khỏe\nVì một cộng đồng an toàn hơn',
          style: TextStyle(
            fontSize: 32,
            height: 1.32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D2B6B),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ứng dụng AI giúp nhận diện tổn thương, cung cấp hướng dẫn\nsơ cứu nhanh chóng và chính xác.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: () =>
                  context.read<UserViewModel>().onAnalyzeImageNowPressed(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Phân tích hình ảnh ngay'),
            ),
            OutlinedButton(
              onPressed: () =>
                  context.read<UserViewModel>().onLookupKnowledgePressed(),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D2B6B),
                side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Tra cứu kiến thức'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroRightIllustration() {
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 14,
            child: Container(
              width: 280,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0x221E3A8A),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          Positioned(
            right: 28,
            top: 24,
            child: Transform.rotate(
              angle: 0.35,
              child: const Icon(Icons.eco, size: 84, color: Color(0xFF6EE7B7)),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF93C5FD), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140D2B6B),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                size: 46,
                color: Color(0xFF1E40AF),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 16,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1D4ED8), width: 6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
              ),
              Container(
                width: 190,
                height: 145,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x331E3A8A),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 52),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 36,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x190D2B6B),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.healing, color: Color(0xFFD97706), size: 24),
                  SizedBox(width: 6),
                  Text(
                    'AI First-Aid',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A8A),
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

  Widget _buildFeatureCardsSection(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        int crossAxisCount = 4;
        if (maxWidth < 560) {
          crossAxisCount = 1;
        } else if (maxWidth < 920) {
          crossAxisCount = 2;
        }

        const double spacing = 20;
        final double cardWidth =
            (maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: viewModel.featureCards.map((card) {
            return SizedBox(
              width: cardWidth,
              child: _buildSingleFeatureCard(context, card),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSingleFeatureCard(BuildContext context, FeatureCardModel card) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.read<UserViewModel>().onFeatureCardTapped(card),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEFF4FB), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0D2B6B),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: card.iconBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(card.icon, color: card.iconColor, size: 26),
              ),
              const SizedBox(height: 18),
              Text(
                card.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D2B6B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                card.description,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommonSituationsSection(
    BuildContext context,
    UserViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tình huống thường gặp',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D2B6B),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            int columns = 5;
            if (maxWidth < 500) {
              columns = 1;
            } else if (maxWidth < 760) {
              columns = 2;
            } else if (maxWidth < 1024) {
              columns = 3;
            }

            const double spacing = 16;
            final double itemWidth =
                (maxWidth - (spacing * (columns - 1))) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: viewModel.commonSituations.map((situation) {
                return SizedBox(
                  width: itemWidth,
                  child: _buildSituationCard(context, situation),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSituationCard(
    BuildContext context,
    CommonSituationModel situation,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.read<UserViewModel>().onSituationCardTapped(situation),
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEFF4FB), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0D2B6B),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10.5),
                ),
                child: SizedBox(
                  height: 100,
                  child: _buildSafeSituationImage(situation),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Center(
                    child: Text(
                      situation.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D2B6B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeSituationImage(CommonSituationModel situation) {
    if (situation.imageUrl != null && situation.imageUrl!.isNotEmpty) {
      return Image.network(
        situation.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderWoundGraphic(situation);
        },
      );
    }
    return _buildPlaceholderWoundGraphic(situation);
  }

  Widget _buildPlaceholderWoundGraphic(CommonSituationModel situation) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            situation.baseSkinColor,
            situation.baseSkinColor.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  situation.woundAccentColor.withValues(alpha: 0.75),
                  situation.woundAccentColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Icon(
            situation.medicalIcon,
            color: Colors.white.withValues(alpha: 0.9),
            size: 22,
          ),
        ],
      ),
    );
  }
}
