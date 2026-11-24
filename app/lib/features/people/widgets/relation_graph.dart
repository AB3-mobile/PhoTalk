import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import '../people_format.dart';
import 'people_style.dart';
import 'person_photo.dart';

// 관계 그래프에 놓일 사람 한 명 (가운데 사람과 이어지는 상대)
class RelationNode {
  const RelationNode({required this.name, required this.label, this.avatarUrl, this.messageCount});

  final String name;
  // 가운데 사람과의 관계 이름 (예: 친구, 팀플 파트너)
  final String label;
  final String? avatarUrl;
  final int? messageCount;
}

// 가운데에 고른 사람, 둘레에 관계 있는 사람들을 원형으로 놓고 선과 관계 이름으로 잇는 그래프
// 사람을 누르면 작은 카드(이름·관계·메시지 수·상세 보기)가 뜬다
class RelationGraph extends StatefulWidget {
  const RelationGraph({
    super.key,
    required this.centerName,
    required this.nodes,
    required this.onDetail,
    this.centerAvatarUrl,
  });

  final String centerName;
  final String? centerAvatarUrl;
  final List<RelationNode> nodes;
  // 카드의 "상세 보기"를 눌렀을 때 그 사람 이름을 알려 준다
  final ValueChanged<String> onDetail;

  @override
  State<RelationGraph> createState() => _RelationGraphState();
}

class _RelationGraphState extends State<RelationGraph> {
  int? _sel;

  static const double _height = 470;
  static const double _centerY = 226;
  static const double _radiusY = 182;
  static const double _popupH = 124;

  @override
  void didUpdateWidget(covariant RelationGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sel != null && _sel! >= widget.nodes.length) _sel = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final cx = w / 2;
        final n = widget.nodes.length;
        final rx = math.min(w / 2 - 36, 150.0);
        // 첫 사람이 맨 위, 나머지는 시계 방향으로 같은 간격
        final pts = <Offset>[
          for (var i = 0; i < n; i++)
            Offset(
              cx + rx * math.cos(-math.pi / 2 + 2 * math.pi * i / n),
              _centerY + _radiusY * math.sin(-math.pi / 2 + 2 * math.pi * i / n),
            ),
        ];
        final center = Offset(cx, _centerY);
        return SizedBox(
          height: _height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _sel = null),
                ),
              ),
              Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _EdgePainter(center: center, ends: pts)))),
              // 선 위의 관계 이름 (가운데에서 바깥쪽으로 58% 지점)
              for (var i = 0; i < n; i++)
                Positioned(
                  left: center.dx + (pts[i].dx - center.dx) * 0.58,
                  top: center.dy + (pts[i].dy - center.dy) * 0.58,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: IgnorePointer(child: _labelPill(widget.nodes[i].label)),
                  ),
                ),
              // 가운데 사람
              Positioned(
                left: cx - 40,
                top: _centerY - 40,
                child: Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: PeopleStyle.tint, shape: BoxShape.circle),
                  child: PersonPhoto(name: widget.centerName, avatarUrl: widget.centerAvatarUrl, size: 68),
                ),
              ),
              Positioned(
                left: cx - 60,
                top: _centerY + 44,
                width: 120,
                child: Text(
                  widget.centerName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(17, weight: FontWeight.w800, color: AppColors.accent),
                ),
              ),
              // 둘레의 사람들
              for (var i = 0; i < n; i++) _node(i, pts[i]),
              if (_sel != null && _sel! < n) _popup(w, center, pts[_sel!], widget.nodes[_sel!]),
            ],
          ),
        );
      },
    );
  }

  Widget _labelPill(String label) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC9D2F3)),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(13, weight: FontWeight.w800, color: AppColors.accent)),
    );
  }

  Widget _node(int i, Offset p) {
    final node = widget.nodes[i];
    final on = _sel == i;
    return Positioned(
      left: p.dx - 36,
      top: p.dy - 28,
      width: 72,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _sel = on ? null : i),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? AppColors.accent : Colors.transparent, width: 3),
              ),
              child: PersonPhoto(name: node.name, avatarUrl: node.avatarUrl, size: 44),
            ),
            const SizedBox(height: 2),
            Text(node.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(14, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // 고른 사람 근처에 뜨는 카드 (위쪽 사람이면 아래에, 아래쪽 사람이면 위에 놓는다)
  Widget _popup(double w, Offset center, Offset p, RelationNode node) {
    final popupW = math.min(w - 8, 250.0);
    final rawTop = p.dy < center.dy ? p.dy + 38 : p.dy - 38 - _popupH;
    final top = math.min(math.max(rawTop, 0.0), _height - _popupH);
    final count = node.messageCount;
    return Positioned(
      left: (w - popupW) / 2,
      top: top,
      width: popupW,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: PeopleStyle.border),
          boxShadow: const [BoxShadow(color: Color(0x1F2E4BAD), blurRadius: 20, offset: Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                PersonPhoto(name: node.name, avatarUrl: node.avatarUrl, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(18, weight: FontWeight.w800)),
                      Text('관계 ${node.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(13, color: AppColors.chevron)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (count != null) Text('메시지 ${formatCount(count)}', style: appText(14, weight: FontWeight.w800)),
                const Spacer(),
                Material(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => widget.onDetail(node.name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Text('상세 보기', style: appText(14, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 가운데에서 각 사람까지 긋는 연한 파란 선
class _EdgePainter extends CustomPainter {
  const _EdgePainter({required this.center, required this.ends});

  final Offset center;
  final List<Offset> ends;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBCC6F2)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final e in ends) {
      canvas.drawLine(center, e, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => old.center != center || old.ends != ends;
}
