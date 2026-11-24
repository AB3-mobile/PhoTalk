import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import '../people_format.dart';
import 'people_style.dart';

// 월별 메시지 수 막대 차트 (막대를 누르면 파랗게 강조되고 위에 건수 말풍선이 뜬다)
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({super.key, required this.months, required this.counts, required this.selected, required this.onTap});

  // 가로축에 놓을 달 번호들 (예: 3~12)
  final List<int> months;
  // 달 번호 → 메시지 수 (없는 달은 0으로 본다)
  final Map<int, int> counts;
  // 강조할 달 번호 (없으면 null)
  final int? selected;
  final ValueChanged<int> onTap;

  static const double _plot = 150;
  static const double _top = 34;
  static const double _labelH = 24;
  static const double _axisW = 38;

  @override
  Widget build(BuildContext context) {
    var maxV = 0;
    for (final m in months) {
      maxV = math.max(maxV, counts[m] ?? 0);
    }
    final top = maxV <= 0 ? 1 : maxV;
    final mid = (top / 2).round();
    return SizedBox(
      height: _top + _plot + _labelH,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter(top: _top, plot: _plot, left: _axisW))),
          for (final (value, dy) in [(top, 0.0), (mid, _plot / 2), (0, _plot)])
            Positioned(
              left: 0,
              top: _top + dy - 8,
              width: _axisW - 8,
              child: Text('$value', textAlign: TextAlign.right, style: appText(12, color: AppColors.chevron)),
            ),
          Positioned(
            left: _axisW,
            right: 0,
            top: 0,
            bottom: 0,
            child: Row(
              children: [for (final m in months) Expanded(child: _bar(m, top))],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(int m, int top) {
    final c = counts[m] ?? 0;
    final h = math.max(3.0, c / top * _plot);
    final on = selected == m;
    final dim = selected != null && !on;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(m),
      child: Column(
        children: [
          SizedBox(
            height: _top + _plot,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 18,
                      height: h,
                      decoration: BoxDecoration(
                        color: dim ? PeopleStyle.barLight : AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (on)
                  Positioned(
                    left: -28,
                    right: -28,
                    bottom: h + 6,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(10)),
                        child: Text(formatCount(c), softWrap: false, style: appText(13, weight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: _labelH,
            child: Center(child: Text('$m월', style: appText(12, color: AppColors.chevron))),
          ),
        ],
      ),
    );
  }
}

// 위·가운데·아래 세 줄의 가로 점선
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.top, required this.plot, required this.left});

  final double top;
  final double plot;
  final double left;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = PeopleStyle.track
      ..strokeWidth = 1.2;
    for (final dy in [0.0, plot / 2, plot]) {
      final y = top + dy;
      var x = left;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, size.width), y), p);
        x += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.top != top || old.plot != plot || old.left != left;
}
