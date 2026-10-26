// File: lib/views/userview/phan_tich_anh_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../viewmodels/user_viewmodel.dart';
import 've_do_hoa_view.dart';

class PhanTichAnhView extends StatelessWidget {
  const PhanTichAnhView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final spec = viewModel.uploadSpec;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Padding(
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
          _buildDashedUploadArea(context, spec, isMobile: isMobile),
          SizedBox(height: isMobile ? 20 : 28),
          _buildOrCaptureDivider(spec.dividerText),
          SizedBox(height: isMobile ? 18 : 24),
          if (isMobile)
            _buildCameraCaptureButton(
              context,
              spec.cameraButtonLabel,
              isMobile: true,
            )
          else
            Center(
              child: _buildCameraCaptureButton(context, spec.cameraButtonLabel),
            ),
          SizedBox(height: isMobile ? 22 : 32),
          _buildBottomWarningNotice(spec, isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildDashedUploadArea(
    BuildContext context,
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
          onTap: () =>
              context.read<UserViewModel>().onSelectImageFromFilePressed(),
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
                SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: ElevatedButton(
                    onPressed: () => context
                        .read<UserViewModel>()
                        .onSelectImageFromFilePressed(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: 38,
                        vertical: isMobile ? 14 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(spec.selectButtonLabel),
                  ),
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

  Widget _buildCameraCaptureButton(
    BuildContext context,
    String label, {
    bool isMobile = false,
  }) {
    return OutlinedButton(
      onPressed: () =>
          context.read<UserViewModel>().onCaptureFromCameraPressed(),
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
              Icons.camera_alt_outlined,
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
}
