import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';

// 점선 테두리의 둥근 상자 (대화방 추가·사진 선택 같은 눌러서 추가하는 칸에 쓴다)
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.height,
    required this.child,
    this.onTap,
    this.fillColor,
    this.borderColor = AppColors.dashed,
  });

  final double height;
  final Widget child;
  final VoidCallback? onTap;
  final Color? fillColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: fillColor ?? Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: CustomPaint(
          foregroundPainter: _DashedBorderPainter(borderColor),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

// 둥근 사각형 테두리를 짧은 선분으로 끊어서 점선으로 그리는 페인터
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    ).deflate(0.6);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 5, metric.length)),
          paint,
        );
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
