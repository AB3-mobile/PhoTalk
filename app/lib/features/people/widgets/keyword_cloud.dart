import 'package:flutter/material.dart';

import '../../../core/app_text.dart';
import '../../../domain/models/keyword_count.dart';

// 키워드를 언급 횟수가 많을수록 크게 보여 주는 단어 구름 (오른쪽 위에 작게 횟수를 붙인다)
class KeywordCloud extends StatelessWidget {
  const KeywordCloud({super.key, required this.keywords});

  final List<KeywordCount> keywords;

  // 많이 언급된 순서대로 돌아가며 쓰는 글자색
  static const _colors = [
    Color(0xFF4B63D9),
    Color(0xFF4DBFB0),
    Color(0xFF8E7BE0),
    Color(0xFF1E2A4A),
    Color(0xFF6C83E8),
    Color(0xFFE0708F),
  ];
  static const double _minSize = 18;
  static const double _maxSize = 42;

  @override
  Widget build(BuildContext context) {
    final list = [...keywords]..sort((a, b) => b.count.compareTo(a.count));
    final top = list.take(14).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxC = top.first.count;
    final minC = top.last.count;
    return Container(
      constraints: const BoxConstraints(minHeight: 300),
      alignment: Alignment.center,
      padding: const EdgeInsets.only(top: 28, bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 22,
        runSpacing: 22,
        children: [
          for (var i = 0; i < top.length; i++)
            _word(top[i], i, maxC == minC ? (_minSize + _maxSize) / 2 : _minSize + (top[i].count - minC) / (maxC - minC) * (_maxSize - _minSize)),
        ],
      ),
    );
  }

  Widget _word(KeywordCount k, int index, double size) {
    final color = _colors[index % _colors.length];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k.word, style: appText(size, weight: FontWeight.w800, color: color)),
        const SizedBox(width: 3),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('${k.count}', style: appText(12, weight: FontWeight.w700, color: const Color(0xFF8B94B3))),
        ),
      ],
    );
  }
}
