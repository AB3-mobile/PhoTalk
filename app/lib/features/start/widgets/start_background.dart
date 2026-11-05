import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';

// 시작 화면의 파란 그라데이션 배경과 물결·점 장식을 깔아 주는 위젯
class StartBackground extends StatelessWidget {
  const StartBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.startTop, AppColors.startBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 가운데 일러스트 뒤에서 은은하게 빛나는 원형 그라데이션
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.25),
                radius: 0.75,
                colors: [
                  AppColors.startGlow.withValues(alpha: 0.45),
                  AppColors.startGlow.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          const CustomPaint(painter: _DecorationPainter()),
          child,
        ],
      ),
    );
  }
}

// 위·아래 물결 모양과 흩어진 작은 점을 그리는 페인터
class _DecorationPainter extends CustomPainter {
  const _DecorationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final top = Path()
      ..moveTo(w * 0.06, h * 0.03)
      ..cubicTo(w * 0.35, 0, w * 0.65, h * 0.07, w * 0.96, h * 0.02)
      ..cubicTo(w * 1.0, h * 0.2, w * 0.93, h * 0.45, w * 0.98, h * 0.68)
      ..cubicTo(w * 0.7, h * 0.76, w * 0.3, h * 0.62, w * 0.02, h * 0.7)
      ..cubicTo(w * 0.08, h * 0.4, w * 0.0, h * 0.2, w * 0.06, h * 0.03)
      ..close();
    // 아래로 갈수록 투명해져서 가장자리가 뚜렷한 선으로 보이지 않게 한다
    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.7)),
    );

    final bottom = Path()
      ..moveTo(0, h * 0.74)
      ..cubicTo(w * 0.25, h * 0.68, w * 0.7, h * 0.8, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        bottom, Paint()..color = Colors.black.withValues(alpha: 0.10));

    final dot = Paint()..color = Colors.white.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(w * 0.09, h * 0.32), 4.5, dot);
    canvas.drawCircle(Offset(w * 0.92, h * 0.28), 4, dot);
    canvas.drawCircle(Offset(w * 0.9, h * 0.45), 4, dot);
    canvas.drawCircle(Offset(w * 0.10, h * 0.58), 4, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
