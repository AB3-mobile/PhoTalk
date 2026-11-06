import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/models/relationship.dart';
import '../../domain/repositories/relationship_repository.dart';
import '../graph/knowledge_graph_screen.dart';
import 'collect_controller.dart';
import 'collect_data.dart';
import 'widgets/main_header.dart';
import 'widgets/next_button.dart';
import 'widgets/person_avatar.dart';

// 그래프 완성 화면: 만들어진 관계 그래프를 작게 보여 주고 인물·관계·사진 수와 관계가 많은 사람 3명을 알려 준다
class GraphDoneScreen extends StatefulWidget {
  const GraphDoneScreen({super.key, required this.controller});

  final CollectController controller;

  @override
  State<GraphDoneScreen> createState() => _GraphDoneScreenState();
}

class _GraphDoneScreenState extends State<GraphDoneScreen> {
  // 서버에서 받은 인물 사이 관계 (아직 못 받았거나 실패하면 null)
  List<Relationship>? _relations;

  @override
  void initState() {
    super.initState();
    _loadRelations();
  }

  // 첫 대화방의 관계 목록을 읽어온다 (실패하면 관계 수는 '-'로 보인다)
  Future<void> _loadRelations() async {
    final c = widget.controller;
    if (c.roomIds.isEmpty) return;
    try {
      final period = c.period;
      final list = await context.read<RelationshipRepository>().getRelationships(
            c.roomIds.first,
            start: period?.start ?? DateTime(2000),
            end: period?.end ?? DateTime.now(),
          );
      if (mounted) setState(() => _relations = list);
    } catch (_) {}
  }

  // 사람별 관계 수를 세어 많은 순서로 최대 3명을 돌려준다
  List<MapEntry<String, int>> get _top3 {
    final counts = <String, int>{};
    for (final r in _relations ?? const <Relationship>[]) {
      counts[r.source] = (counts[r.source] ?? 0) + 1;
      counts[r.target] = (counts[r.target] ?? 0) + 1;
    }
    final list = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final room = c.pendingChats.isNotEmpty ? c.pendingChats.first.displayName : '대화방';
    final period = c.period;
    // 그래프에 그릴 인물 (관계가 많은 사람이 있으면 우선, 없으면 참여자 순서)
    final people = (_top3.map((e) => e.key).toList() +
            c.participantNames.where((n) => !_top3.any((e) => e.key == n)).toList())
        .take(6)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MainHeader(title: '그래프 완성'),
                    const SizedBox(height: 16),
                    Container(
                      height: 262,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                      child: _GraphPreview(center: room, people: people),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text('관계 그래프가 완성됐어요', style: appText(17, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      period == null ? room : '$room · ${formatDate(period.start)} – ${formatShortDate(period.end)}',
                      style: appText(12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _Stat(label: '인물', value: '${c.participantTotal}', unit: '명')),
                      const SizedBox(width: 10),
                      Expanded(child: _Stat(label: '관계', value: _relations == null ? '-' : '${_relations!.length}', unit: '개')),
                      const SizedBox(width: 10),
                      Expanded(child: _Stat(label: '매칭된 사진', value: '${c.namedCount}', unit: '장')),
                    ]),
                    const SizedBox(height: 14),
                    _buildTop3(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: NextButton(
                label: '그래프 보기',
                enabled: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => KnowledgeGraphScreen(chatroomId: c.roomIds.isNotEmpty ? c.roomIds.first : null),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // '가장 많이 이어진 사람' 카드 (1위는 파란 테두리로 강조)
  Widget _buildTop3() {
    final top = _top3;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('가장 많이 이어진 사람', style: appText(11.5, weight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          if (top.isEmpty)
            Text('관계 정보를 불러오는 중이에요', style: appText(11.5, color: AppColors.textSecondary))
          else
            Row(
              children: [
                for (var i = 0; i < top.length; i++)
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: i == 0
                              ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accent, width: 2))
                              : null,
                          child: PersonAvatar(index: i, size: 36),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(top[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(13, weight: FontWeight.w700)),
                              Text('관계 ${top[i].value}개', style: appText(10.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// 숫자 한 개를 보여 주는 작은 통계 카드 (이름표, 숫자, 단위)
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: appText(11, weight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text.rich(TextSpan(children: [
            TextSpan(text: value, style: appText(24, weight: FontWeight.w700)),
            TextSpan(text: ' $unit', style: appText(12, weight: FontWeight.w700, color: AppColors.textSecondary)),
          ])),
        ],
      ),
    );
  }
}

// 가운데 대화방 노드와 둘레의 인물 노드를 선으로 이은 작은 그래프 미리보기
class _GraphPreview extends StatelessWidget {
  const _GraphPreview({required this.center, required this.people});

  final String center;
  final List<String> people;

  // i번째 인물 노드의 중심 위치 (위쪽에서 시작해 타원형으로 고르게 배치)
  Offset _pos(int i, Size size) {
    final angle = -math.pi / 2 + 2 * math.pi * i / math.max(people.length, 1);
    return Offset(
      size.width / 2 + math.min(size.width * 0.29, 120) * math.cos(angle),
      size.height / 2 + 86 * math.sin(angle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final c = Offset(size.width / 2, size.height / 2);
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LinePainter([for (var i = 0; i < people.length; i++) _pos(i, size)], c)),
          ),
          for (var i = 0; i < people.length; i++)
            Positioned(
              left: _pos(i, size).dx - 28,
              top: _pos(i, size).dy - 20,
              width: 56,
              child: Column(
                children: [
                  PersonAvatar(index: i, size: 34),
                  const SizedBox(height: 4),
                  Text(people[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(10, weight: FontWeight.w700)),
                ],
              ),
            ),
          Positioned(
            left: c.dx - 28,
            top: c.dy - 28,
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(center, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(8.5, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

// 가운데에서 인물로 가는 굵은 선과 인물끼리 잇는 연한 선을 그리는 페인터
class _LinePainter extends CustomPainter {
  const _LinePainter(this.points, this.center);

  final List<Offset> points;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = const Color(0xFFD9E0F7)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = const Color(0xFFA9B8EE)
      ..strokeWidth = 2;
    for (var i = 0; i < points.length; i++) {
      canvas.drawLine(points[i], points[(i + 1) % points.length], thin);
    }
    for (final p in points) {
      canvas.drawLine(center, p, thick);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}
