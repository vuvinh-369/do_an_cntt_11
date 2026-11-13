// File: lib/core/security/widgets/auth_captcha_box.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:do_an_cntt_11/core/security/auth_brute_force_service.dart';

/// Widget hiển thị thử thách CAPTCHA tự sinh và biểu ngữ đếm ngược trì hoãn lũy tiến
class AuthCaptchaBox extends StatefulWidget {
  final String scope;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const AuthCaptchaBox({
    super.key,
    required this.scope,
    required this.controller,
    this.onChanged,
  });

  @override
  State<AuthCaptchaBox> createState() => _AuthCaptchaBoxState();
}

class _AuthCaptchaBoxState extends State<AuthCaptchaBox> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    AuthBruteForceService.instance.addListener(_handleServiceUpdate);
    _startCountdownTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AuthCaptchaBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _startCountdownTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    AuthBruteForceService.instance.removeListener(_handleServiceUpdate);
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleServiceUpdate() {
    if (mounted) {
      setState(() {});
      _startCountdownTimerIfNeeded();
    }
  }

  void _startCountdownTimerIfNeeded() {
    _countdownTimer?.cancel();
    if (AuthBruteForceService.instance.isDelayActive(widget.scope)) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {});
        if (!AuthBruteForceService.instance.isDelayActive(widget.scope)) {
          timer.cancel();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = AuthBruteForceService.instance;
    final isDelay = service.isDelayActive(widget.scope);
    final remainingSeconds = service.getRemainingDelaySeconds(widget.scope);
    final isChallenge = service.isChallengeRequired(widget.scope);

    if (!isDelay && !isChallenge) {
      return const SizedBox.shrink();
    }

    final challenge = isChallenge ? service.getOrGenerateChallenge(widget.scope) : null;

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDelay ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDelay ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Biểu ngữ trì hoãn lũy tiến (nếu đang bị phạt chờ)
          if (isDelay) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phát hiện đăng nhập sai nhiều lần!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hệ thống áp dụng thời gian chờ lũy tiến. Vui lòng chờ $remainingSeconds giây trước khi thử lại.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB91C1C),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isChallenge) const Divider(height: 20, color: Color(0xFFFCA5A5)),
          ],

          // 2. Thử thách CAPTCHA bắt buộc (sau >= 5 lần sai)
          if (isChallenge && challenge != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Xác thực chống spam bot (Bắt buộc)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Đổi câu hỏi khác',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: const Color(0xFF64748B),
                  onPressed: isDelay
                      ? null
                      : () {
                          service.generateNewChallenge(widget.scope);
                          widget.controller.clear();
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF94A3B8)),
              ),
              child: Center(
                child: Text(
                  challenge.question,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: widget.controller,
              enabled: !isDelay,
              keyboardType: TextInputType.number,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Nhập kết quả phép tính...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.calculate_outlined, size: 18, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
