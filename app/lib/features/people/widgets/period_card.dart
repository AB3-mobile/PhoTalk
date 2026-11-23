import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import '../people_format.dart';
import 'people_style.dart';

// 아래에 고정되는 "분석 기간" 카드: 시작과 끝을 월 단위로 고르는 범위 슬라이더
class PeriodCard extends StatefulWidget {
  const PeriodCard({
    super.key,
    required this.first,
    required this.last,
    required this.start,
    required this.end,
    required this.onChanged,
  });

  // 고를 수 있는 가장 이른/늦은 날짜
  final DateTime first;
  final DateTime last;
  // 지금 선택된 기간
  final DateTime start;
  final DateTime end;
  // 손가락을 뗄 때 새 기간을 알려 준다
  final void Function(DateTime start, DateTime end) onChanged;

  @override
  State<PeriodCard> createState() => _PeriodCardState();
}

class _PeriodCardState extends State<PeriodCard> {
  late RangeValues _values;
  bool _dragging = false;

  // first가 속한 달부터 last가 속한 달까지의 달 수
  int get _months => math.max(1, (widget.last.year - widget.first.year) * 12 + widget.last.month - widget.first.month + 1);

  int _index(DateTime d) {
    final i = (d.year - widget.first.year) * 12 + d.month - widget.first.month;
    return math.min(math.max(i, 0), _months - 1);
  }

  // 달 번호 → 그 달 첫날 (맨 처음 달은 실제 첫 대화 날짜)
  DateTime _startOf(int i) => i <= 0 ? widget.first : DateTime(widget.first.year, widget.first.month + i, 1);

  // 달 번호 → 그 달 마지막 날 (맨 마지막 달은 실제 마지막 대화 날짜)
  DateTime _endOf(int i) => i >= _months - 1 ? widget.last : DateTime(widget.first.year, widget.first.month + i + 1, 0);

  RangeValues _fromWidget() => RangeValues(_index(widget.start).toDouble(), _index(widget.end).toDouble());

  @override
  void initState() {
    super.initState();
    _values = _fromWidget();
  }

  @override
  void didUpdateWidget(covariant PeriodCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) _values = _fromWidget();
  }

  @override
  Widget build(BuildContext context) {
    final n = _months;
    final start = _startOf(_values.start.round());
    final end = _endOf(_values.end.round());
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: PeopleStyle.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('분석 기간', style: appText(16, weight: FontWeight.w800)),
              const Spacer(),
              Text('${formatDot(start)} — ${formatDot(end)}', style: appText(15, weight: FontWeight.w800, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 6),
          if (n >= 2) ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: PeopleStyle.track,
                rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                rangeThumbShape: const _RingThumb(),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
                overlayColor: Colors.transparent,
              ),
              child: RangeSlider(
                values: _values,
                min: 0,
                max: (n - 1).toDouble(),
                divisions: n - 1,
                onChangeStart: (_) => _dragging = true,
                onChanged: (v) => setState(() => _values = v),
                onChangeEnd: (v) {
                  _dragging = false;
                  widget.onChanged(_startOf(v.start.round()), _endOf(v.end.round()));
                },
              ),
            ),
            _labels(n),
          ] else
            _staticTrack(),
        ],
      ),
    );
  }

  // 대화가 한 달 안에만 있으면 고를 구간이 없어서, 양 끝에 손잡이가 있는 줄만 보여 준다
  Widget _staticTrack() {
    Widget ring() => Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 3.5),
          ),
        );
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Container(
              height: 8,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          Positioned(left: 0, child: ring()),
          Positioned(right: 0, child: ring()),
        ],
      ),
    );
  }

  // 슬라이더 아래에 6개월(범위가 아주 길면 12개월)마다 달 이름을 붙인다
  Widget _labels(int n) {
    final step = n > 60 ? 12 : 6;
    final ticks = <int>[for (var i = step; i < n; i += step) i];
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, box) {
          const pad = 13.0;
          final w = box.maxWidth - pad * 2;
          return Stack(
            children: [
              for (final i in ticks)
                Positioned(
                  left: pad + w * i / (n - 1) - 24,
                  width: 48,
                  top: 0,
                  child: Text(
                    formatYm(DateTime(widget.first.year, widget.first.month + i)),
                    textAlign: TextAlign.center,
                    softWrap: false,
                    style: appText(10.5, color: AppColors.chevron),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// 흰 원에 파란 테두리가 있는 슬라이더 손잡이
class _RingThumb extends RangeSliderThumbShape {
  const _RingThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(26, 26);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 12.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
  }
}
