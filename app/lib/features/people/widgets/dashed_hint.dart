import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';

// 점선 테두리 안에 안내 글만 있는 빈 칸 ("막대를 누르면 ... 나타나요")
class DashedHint extends StatelessWidget {
  const DashedHint({super.key, required this.text, this.height = 96});

  final String text;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const _DashedRRectPainter(),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Center(child: Text(text, style: appText(15, color: AppColors.chevron))),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)).deflate(0.8);
    final paint = Paint()
      ..color = AppColors.dashed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => false;
}
