import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/models/graph_data.dart';
import 'force_simulation.dart';

// 노드 종류별 색 (서버 entity_type 기준)
Color _typeColor(String t) {
  switch (t) {
    case 'CHATROOM':
      return AppColors.nodeRoom;
    case 'PERSON':
      return AppColors.nodePerson;
    case 'KEYWORD':
      return AppColors.nodeKeyword;
    case 'ATTACHMENT':
      return AppColors.nodeFile;
    case 'DATE':
      return AppColors.nodeDate;
    case 'NAMEDENTITY':
      return AppColors.nodeEntity;
    case 'EVENT':
      return AppColors.nodeEvent;
    default:
      return AppColors.nodePhoto;
  }
}

// 노드 종류의 한글 이름
String _typeLabel(String t) {
  switch (t) {
    case 'CHATROOM':
      return '대화방';
    case 'PERSON':
      return '인물';
    case 'KEYWORD':
      return '키워드';
    case 'ATTACHMENT':
      return '첨부';
    case 'DATE':
      return '날짜';
    case 'NAMEDENTITY':
      return '개체';
    case 'EVENT':
      return '이벤트';
    default:
      return t.isEmpty ? '기타' : t;
  }
}

// 서버가 준 지식 그래프를 힘 기반으로 배치해 보여 주는 화면 (MailGrapher 방식)
class ForceGraphView extends StatefulWidget {
  const ForceGraphView({super.key, required this.data});

  final GraphData data;

  @override
  State<ForceGraphView> createState() => _ForceGraphViewState();
}

class _ForceGraphViewState extends State<ForceGraphView> with SingleTickerProviderStateMixin {
  // 선택한 노드 종류 (비어 있으면 전부 보인다)
  late Set<String> _enabled;
  // 지금 그려지는 노드와 선
  List<GraphDataNode> _nodes = [];
  List<(int, int)> _links = [];
  List<double> _weights = [];
  List<Set<int>> _adj = [];
  List<double> _radius = [];
  late ForceSimulation _sim;
  // 화면 갱신 신호 (값이 바뀌면 다시 그린다)
  final ValueNotifier<int> _rev = ValueNotifier(0);
  late final Ticker _ticker;
  // 확대 비율과 이동 (화면 좌표 = 월드 좌표 * 비율 + 이동)
  double _scale = 1;
  Offset _offset = Offset.zero;
  Size _size = Size.zero;
  bool _needFit = true;
  // 선택된 노드와 드래그 중인 노드 (없으면 -1)
  int _selected = -1;
  int _dragging = -1;
  // 제스처 시작 시점의 값
  double _baseScale = 1;
  Offset _baseOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  // 라벨 글자 그리기 캐시
  final Map<String, TextPainter> _labels = {};

  @override
  void initState() {
    super.initState();
    _enabled = <String>{};
    _ticker = createTicker(_onTick);
    _rebuild();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _rev.dispose();
    super.dispose();
  }

  // 한 프레임마다 시뮬레이션을 진행하고 식으면 멈춘다
  void _onTick(Duration _) {
    if (_sim.isIdle) {
      _ticker.stop();
      return;
    }
    _sim.tick();
    _rev.value++;
  }

  // 시뮬레이션을 깨워 계속 움직이게 한다
  void _wake(double alpha) {
    _sim.reheat(alpha);
    if (!_ticker.isActive) _ticker.start();
  }

  // 켜 둔 종류만 골라 노드·선을 다시 만들고 시뮬레이션을 새로 돌린다
  void _rebuild() {
    final old = <String, (double, double)>{};
    if (_nodes.isNotEmpty) {
      for (var i = 0; i < _nodes.length; i++) {
        old[_nodes[i].id] = (_sim.x[i], _sim.y[i]);
      }
    }
    final nodes = widget.data.nodes.where((n) => _enabled.isEmpty || _enabled.contains(n.entityType)).toList();
    final idx = {for (var i = 0; i < nodes.length; i++) nodes[i].id: i};
    final links = <(int, int)>[];
    final weights = <double>[];
    final adj = List.generate(nodes.length, (_) => <int>{});
    for (final e in widget.data.edges) {
      final s = idx[e.source], t = idx[e.target];
      if (s == null || t == null || s == t) continue;
      links.add((s, t));
      weights.add(e.weight ?? 1);
      adj[s].add(t);
      adj[t].add(s);
    }
    // 노드 크기: 연결이 많을수록 크게 (제곱근 비례)
    var dMin = 1 << 30, dMax = 0;
    for (final n in nodes) {
      dMin = math.min(dMin, n.degree);
      dMax = math.max(dMax, n.degree);
    }
    final radius = [
      for (final n in nodes)
        n.entityType == 'CHATROOM'
            ? 26.0
            : 6 + 18 * math.sqrt(dMax == dMin ? 0.0 : (n.degree - dMin) / (dMax - dMin)),
    ];
    _nodes = nodes;
    _links = links;
    _weights = weights;
    _adj = adj;
    _radius = radius;
    _selected = -1;
    _labels.clear();
    _sim = ForceSimulation(radius: radius, links: links, seed: [for (final n in nodes) old[n.id]]);
    // 처음 보여 주기 전에 미리 돌려 어느 정도 자리를 잡아 둔다
    final warm = math.min(150, 40 + 4000000 ~/ math.max(1, nodes.length * nodes.length));
    for (var i = 0; i < warm && !_sim.isIdle; i++) {
      _sim.tick();
    }
    _needFit = true;
    _rev.value++;
    _wake(0.3);
  }

  // 모든 노드가 한눈에 들어오도록 확대 비율과 위치를 맞춘다
  void _fit() {
    if (_size == Size.zero || _nodes.isEmpty) return;
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < _nodes.length; i++) {
      minX = math.min(minX, _sim.x[i] - _radius[i]);
      maxX = math.max(maxX, _sim.x[i] + _radius[i]);
      minY = math.min(minY, _sim.y[i] - _radius[i]);
      maxY = math.max(maxY, _sim.y[i] + _radius[i]);
    }
    final w = math.max(maxX - minX, 1), h = math.max(maxY - minY, 1);
    _scale = math.min((_size.width - 32) / w, (_size.height - 32) / h).clamp(0.05, 2.0);
    _offset = Offset(_size.width / 2 - (minX + maxX) / 2 * _scale, _size.height / 2 - (minY + maxY) / 2 * _scale);
    _rev.value++;
  }

  // 화면 좌표를 월드 좌표로 바꾼다
  Offset _toWorld(Offset p) => (p - _offset) / _scale;

  // 화면의 한 점 아래에 있는 노드 번호 (없으면 -1)
  int _hit(Offset p) {
    final w = _toWorld(p);
    for (var i = _nodes.length - 1; i >= 0; i--) {
      final reach = math.max(_radius[i], 16 / _scale) + 4 / _scale;
      final dx = _sim.x[i] - w.dx, dy = _sim.y[i] - w.dy;
      if (dx * dx + dy * dy <= reach * reach) return i;
    }
    return -1;
  }

  // 탭하면 노드를 선택하고 빈 곳을 탭하면 해제한다
  void _onTap(TapUpDetails d) {
    setState(() => _selected = _hit(d.localPosition));
    _rev.value++;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _startFocal = d.localFocalPoint;
    _dragging = d.pointerCount == 1 ? _hit(d.localFocalPoint) : -1;
    if (_dragging >= 0) {
      final w = _toWorld(d.localFocalPoint);
      _sim.fx[_dragging] = w.dx;
      _sim.fy[_dragging] = w.dy;
      _sim.alphaTarget = 0.3;
      _wake(0.3);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_dragging >= 0) {
      // 붙잡은 노드를 손가락 위치에 고정해 이웃이 끌려오게 한다
      final w = _toWorld(d.localFocalPoint);
      _sim.fx[_dragging] = w.dx;
      _sim.fy[_dragging] = w.dy;
      return;
    }
    // 빈 곳은 이동, 두 손가락은 손가락 위치 기준으로 확대·축소
    final s = (_baseScale * d.scale).clamp(0.05, 4.0);
    final world = (_startFocal - _baseOffset) / _baseScale;
    _scale = s;
    _offset = d.localFocalPoint - world * s;
    _rev.value++;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_dragging >= 0) {
      // 놓으면 고정을 풀고 시뮬레이션이 천천히 식게 한다
      _sim.fx[_dragging] = null;
      _sim.fy[_dragging] = null;
      _sim.alphaTarget = 0;
      _dragging = -1;
    }
  }

  // 노드 종류를 켜거나 끈다
  void _toggle(String type) {
    setState(() {
      _enabled = _enabled.contains(type) ? ({..._enabled}..remove(type)) : {..._enabled, type};
      _rebuild();
    });
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final n in widget.data.nodes) {
      counts[n.entityType] = (counts[n.entityType] ?? 0) + 1;
    }
    final types = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return Column(
      children: [
        // 노드 종류를 체크로 고르는 드롭다운 (아무것도 고르지 않으면 전체 표시)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: MenuAnchor(
              menuChildren: [
                for (final t in types)
                  CheckboxMenuButton(
                    closeOnActivate: false,
                    value: _enabled.contains(t),
                    onChanged: (_) => _toggle(t),
                    trailingIcon: CircleAvatar(radius: 5, backgroundColor: _typeColor(t)),
                    child: Text('${_typeLabel(t)} ${counts[t]}', style: appText(13, color: AppColors.textPrimary)),
                  ),
              ],
              builder: (context, controller, _) => OutlinedButton(
                // 오른쪽 여백을 줄여 화살표를 테두리에 가깝게 붙인다
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.only(left: 16, right: 4)),
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 글자와 화살표 사이를 좁게 붙인다
                    Text(
                      _enabled.isEmpty ? '전체' : types.where(_enabled.contains).map(_typeLabel).join(', '),
                      style: appText(13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              if (size != _size) {
                _size = size;
                if (_needFit) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _fit();
                      _needFit = false;
                    }
                  });
                }
              } else if (_needFit) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _needFit) {
                    _fit();
                    _needFit = false;
                  }
                });
              }
              return ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: _onTap,
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: _onScaleEnd,
                        child: CustomPaint(painter: _ForcePainter(this)),
                      ),
                    ),
                    if (_selected >= 0 && _selected < _nodes.length) Positioned(left: 8, right: 8, bottom: 8, child: _infoCard(_nodes[_selected])),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 선택한 노드의 종류·이름·설명을 보여 주는 카드
  Widget _infoCard(GraphDataNode n) {
    final desc = (n.description ?? '').trim();
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_typeLabel(n.entityType)} · 연결 ${n.degree}개', style: appText(11, color: _typeColor(n.entityType), weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(n.label, style: appText(16, weight: FontWeight.w700)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(desc, maxLines: 5, overflow: TextOverflow.ellipsis, style: appText(12, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

// 선과 노드와 이름을 캔버스에 그리는 페인터
class _ForcePainter extends CustomPainter {
  _ForcePainter(this.s) : super(repaint: s._rev);

  final _ForceGraphViewState s;

  // 라벨 글자를 한 번만 만들어 재사용한다
  TextPainter _label(String text) {
    return s._labels.putIfAbsent(text, () {
      final t = text.length > 12 ? '${text.substring(0, 12)}…' : text;
      return TextPainter(
        text: TextSpan(text: t, style: appText(11, color: AppColors.textPrimary)),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = s._nodes;
    if (nodes.isEmpty) return;
    final sim = s._sim;
    canvas.save();
    canvas.translate(s._offset.dx, s._offset.dy);
    canvas.scale(s._scale);
    final sel = s._selected;
    final near = sel >= 0 && sel < nodes.length ? s._adj[sel] : const <int>{};
    var wMax = 1.0;
    for (final w in s._weights) {
      wMax = math.max(wMax, w);
    }
    // 선: 가중치가 클수록 굵게, 선택 중이면 연결된 선만 진하게
    final line = Paint()..style = PaintingStyle.stroke;
    for (var k = 0; k < s._links.length; k++) {
      final (a, b) = s._links[k];
      final on = sel >= 0 && (a == sel || b == sel);
      line
        ..strokeWidth = (0.6 + 2.2 * s._weights[k] / wMax) / math.sqrt(s._scale.clamp(0.5, 3.0))
        ..color = on ? AppColors.accent : AppColors.edgeThin.withValues(alpha: sel >= 0 ? 0.25 : 0.7);
      canvas.drawLine(Offset(sim.x[a], sim.y[a]), Offset(sim.x[b], sim.y[b]), line);
    }
    // 노드: 종류별 색, 선택 중이면 이웃이 아닌 노드는 흐리게
    final fill = Paint();
    for (var i = 0; i < nodes.length; i++) {
      final dim = sel >= 0 && i != sel && !near.contains(i);
      fill.color = _typeColor(nodes[i].entityType).withValues(alpha: dim ? 0.25 : 1);
      final c = Offset(sim.x[i], sim.y[i]);
      canvas.drawCircle(c, s._radius[i], fill);
      if (i == sel) {
        canvas.drawCircle(c, s._radius[i] + 3, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = AppColors.accent);
      }
    }
    // 이름: 충분히 크게 보이는 노드와 선택·이웃 노드에만 쓴다
    for (var i = 0; i < nodes.length; i++) {
      final shown = i == sel || (sel >= 0 && near.contains(i)) || s._radius[i] * s._scale >= 9 || s._scale > 1.6;
      if (!shown) continue;
      final tp = _label(nodes[i].label);
      tp.paint(canvas, Offset(sim.x[i] - tp.width / 2, sim.y[i] + s._radius[i] + 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ForcePainter old) => false;
}
