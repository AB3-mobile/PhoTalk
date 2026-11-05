import 'package:flutter/material.dart';

// 실제 사진 대신 쓰는 그림 자리 (산과 해가 있는 파란/청록 그라데이션 칸)
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({
    super.key,
    required this.variant,
    this.radius = 12,
    this.dim = false,
  });

  // 사진 번호 (홀짝에 따라 파랑/청록 색을 번갈아 쓴다)
  final int variant;
  final double radius;
  // true면 어둡게 덮는다 (이름 입력이 끝난 사진 표시)
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final blue = variant.isEven;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: blue
                    ? const [Color(0xFFDDE3FB), Color(0xFFB9C6F4)]
                    : const [Color(0xFFD6F2F6), Color(0xFFA9D9EA)],
              ),
            ),
          ),
          const CustomPaint(painter: _ScenePainter()),
          if (dim) const ColoredBox(color: Color(0x661E2A4A)),
        ],
      ),
    );
  }
}

// 해(원)와 산(삼각형 두 개)을 칸 크기에 맞춰 그리는 페인터
class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xCCFFFFFF);
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w * 0.72, h * 0.28), w * 0.1, paint);

    final mountain = Path()
      ..moveTo(w * 0.08, h * 0.82)
      ..lineTo(w * 0.36, h * 0.46)
      ..lineTo(w * 0.62, h * 0.82)
      ..close();
    canvas.drawPath(mountain, paint);

    final small = Path()
      ..moveTo(w * 0.45, h * 0.82)
      ..lineTo(w * 0.68, h * 0.54)
      ..lineTo(w * 0.92, h * 0.82)
      ..close();
    canvas.drawPath(small, paint);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => false;
}
