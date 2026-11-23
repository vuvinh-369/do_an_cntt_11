// File: lib/core/security/widgets/auth_captcha_box.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:do_an_cntt_11/core/security/auth_brute_force_service.dart';

/// Widget hiển thị thử thách CAPTCHA chữ và số (font chữ xấu, lệch) chống spam bot
/// và biểu ngữ đếm ngược trì hoãn lũy tiến khi đăng nhập sai đúng 5 lần liên tiếp.
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

    // Chỉ hiển thị khi có phạt delay hoặc đúng >= 5 lần đăng nhập sai liên tiếp
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

          // 2. Thử thách CAPTCHA bắt buộc (chữ và số với font chữ xấu, lệch)
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
                const Text(
                  'Không phân biệt hoa/thường',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Khung hiển thị mã CAPTCHA chữ & số vẽ font chữ xấu, nghiêng lệch, nhiễu
            DistortedCaptchaView(
              code: challenge.code,
              challengeId: challenge.id,
              isRefreshingDisabled: isDelay,
              onRefresh: () {
                service.generateNewChallenge(widget.scope);
                widget.controller.clear();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: widget.controller,
              enabled: !isDelay,
              keyboardType: TextInputType.visiblePassword,
              textCapitalization: TextCapitalization.characters,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Nhập mã gồm 5 chữ và số ở trên...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.password_rounded, size: 18, color: Color(0xFF64748B)),
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

/// Widget vẽ chuỗi chữ và số với hiệu ứng CAPTCHA cổ điển (font chữ xấu, nghiêng lệch, gạch xước, chấm nhiễu)
class DistortedCaptchaView extends StatelessWidget {
  final String code;
  final String challengeId;
  final VoidCallback? onRefresh;
  final bool isRefreshingDisabled;

  const DistortedCaptchaView({
    super.key,
    required this.code,
    required this.challengeId,
    this.onRefresh,
    this.isRefreshingDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Slate 100
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: _DistortedCaptchaPainter(
                  code: code,
                  seed: challengeId.hashCode,
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            bottom: 4,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Đổi mã xác thực khác',
                color: const Color(0xFF475569),
                splashRadius: 18,
                onPressed: isRefreshingDisabled ? null : onRefresh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter vẽ các ký tự chữ và số với góc quay, lệch vị trí, đường sóng và gạch xước
class _DistortedCaptchaPainter extends CustomPainter {
  final String code;
  final int seed;

  _DistortedCaptchaPainter({required this.code, required this.seed});

  static const List<Color> _inkColors = [
    Color(0xFF0F172A), // Slate 900
    Color(0xFF1E3A8A), // Blue 900
    Color(0xFF831843), // Pink 900
    Color(0xFF065F46), // Emerald 800
    Color(0xFF701A75), // Fuchsia 900
    Color(0xFF9A3412), // Orange 800
    Color(0xFF312E81), // Indigo 900
    Color(0xFF164E63), // Cyan 900
  ];

  static const List<Color> _noiseLineColors = [
    Color(0x663B82F6),
    Color(0x66EF4444),
    Color(0x6610B981),
    Color(0x668B5CF6),
    Color(0x66F59E0B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);

    // 1. Vẽ nền chấm nhiễu ngẫu nhiên (Noise dots)
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 45; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final radius = 0.8 + rng.nextDouble() * 1.6;
      final ink = _inkColors[rng.nextInt(_inkColors.length)];
      dotPaint.color = ink.withValues(alpha: 0.15 + rng.nextDouble() * 0.25);
      canvas.drawCircle(Offset(dx, dy), radius, dotPaint);
    }

    // 2. Vẽ 3 đường sóng nhiễu nền (Background curved wave lines)
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final startY = rng.nextDouble() * size.height;
      final endY = rng.nextDouble() * size.height;
      final cp1X = size.width * (0.2 + rng.nextDouble() * 0.25);
      final cp1Y = rng.nextDouble() * size.height;
      final cp2X = size.width * (0.55 + rng.nextDouble() * 0.25);
      final cp2Y = rng.nextDouble() * size.height;

      path.moveTo(0, startY);
      path.cubicTo(cp1X, cp1Y, cp2X, cp2Y, size.width, endY);

      final linePaint = Paint()
        ..color = _noiseLineColors[i % _noiseLineColors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 + rng.nextDouble() * 1.2;
      canvas.drawPath(path, linePaint);
    }

    // 3. Vẽ từng ký tự chữ và số với góc nghiêng, lệch trên dưới, font xấu lệch
    if (code.isNotEmpty) {
      final renderWidth = size.width - 44; // Dành khoảng trống bên phải cho nút refresh
      final charStep = renderWidth / (code.length + 0.5);

      for (int i = 0; i < code.length; i++) {
        final char = code[i];
        final charColor = _inkColors[rng.nextInt(_inkColors.length)];
        final fontSize = 24.0 + rng.nextDouble() * 6.0; // 24 đến 30
        final isItalic = rng.nextBool();
        final fontWeight = rng.nextBool() ? FontWeight.w800 : FontWeight.w900;
        final rotationAngle = (rng.nextDouble() - 0.5) * 0.48; // ~ -14° đến +14°
        final verticalJitter = (rng.nextDouble() - 0.5) * 16.0; // trồi sụt lệch trên dưới

        final textPainter = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: charColor,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final charCenterX = 18.0 + charStep * (i + 0.5) + (rng.nextDouble() - 0.5) * 6.0;
        final charCenterY = (size.height / 2) + verticalJitter;

        canvas.save();
        canvas.translate(charCenterX, charCenterY);
        canvas.rotate(rotationAngle);
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
        canvas.restore();
      }
    }

    // 4. Vẽ 2 đường gạch xước xuyên ngang chữ (Foreground cross scratch lines)
    final scratchPaint = Paint()
      ..color = const Color(0x77334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 2; i++) {
      final y1 = 12.0 + rng.nextDouble() * (size.height - 24.0);
      final y2 = 12.0 + rng.nextDouble() * (size.height - 24.0);
      canvas.drawLine(Offset(10, y1), Offset(size.width - 50, y2), scratchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DistortedCaptchaPainter oldDelegate) {
    return oldDelegate.code != code || oldDelegate.seed != seed;
  }
}
