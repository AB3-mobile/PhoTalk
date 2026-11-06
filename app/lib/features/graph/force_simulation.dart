import 'dart:math' as math;
import 'dart:typed_data';

// MailGrapher(D3)와 같은 힘 모델로 노드 위치를 계산하는 시뮬레이션
class ForceSimulation {
  ForceSimulation({required this.radius, required List<(int, int)> links, List<(double, double)?>? seed})
      : n = radius.length,
        _ls = Int32List(links.length),
        _lt = Int32List(links.length) {
    x = Float64List(n);
    y = Float64List(n);
    vx = Float64List(n);
    vy = Float64List(n);
    fx = List<double?>.filled(n, null);
    fy = List<double?>.filled(n, null);
    // 처음 위치: 이전 위치가 있으면 그대로, 없으면 해바라기 모양으로 흩뿌린다
    for (var i = 0; i < n; i++) {
      final s = seed != null && i < seed.length ? seed[i] : null;
      if (s != null) {
        x[i] = s.$1;
        y[i] = s.$2;
      } else {
        final r = 10 * math.sqrt(i + 0.5);
        final a = i * math.pi * (3 - math.sqrt(5));
        x[i] = r * math.cos(a);
        y[i] = r * math.sin(a);
      }
    }
    final deg = List<int>.filled(n, 0);
    for (var k = 0; k < links.length; k++) {
      _ls[k] = links[k].$1;
      _lt[k] = links[k].$2;
      deg[links[k].$1]++;
      deg[links[k].$2]++;
    }
    _strength = Float64List(links.length);
    _bias = Float64List(links.length);
    for (var k = 0; k < links.length; k++) {
      final ds = deg[_ls[k]], dt = deg[_lt[k]];
      _strength[k] = 1 / math.max(1, math.min(ds, dt));
      _bias[k] = ds / math.max(1, ds + dt);
    }
  }

  // 노드 개수
  final int n;
  // 노드별 반지름 (겹치지 않게 밀어내는 기준)
  final List<double> radius;
  // 노드 위치와 속도
  late final Float64List x, y, vx, vy;
  // 손가락으로 붙잡은 노드의 고정 좌표 (없으면 null)
  late final List<double?> fx, fy;
  final Int32List _ls, _lt;
  late final Float64List _strength, _bias;

  // 시뮬레이션 열기: 1에서 시작해 0으로 식는다
  double alpha = 1;
  // 드래그 중에는 0.3으로 유지해 이웃이 계속 따라오게 한다
  double alphaTarget = 0;
  static const _alphaMin = 0.001;
  static const _alphaDecay = 0.0228;
  static const _linkDistance = 140.0;
  static const _charge = -800.0;
  static const _chargeMaxD2 = 500.0 * 500.0;
  final math.Random _rnd = math.Random(7);

  // 더 이상 움직일 일이 없는 상태인지
  bool get isIdle => alpha < _alphaMin && alphaTarget == 0;

  // 식어 가던 시뮬레이션을 다시 데운다
  void reheat(double a) => alpha = math.max(alpha, a);

  double _jitter() => (_rnd.nextDouble() - 0.5) * 1e-6;

  // 한 걸음 계산: 연결 당김, 서로 밀어냄, 겹침 방지, 중심 맞춤
  void tick() {
    alpha += (alphaTarget - alpha) * _alphaDecay;
    // 연결된 노드끼리 일정 거리로 당기는 힘
    for (var k = 0; k < _ls.length; k++) {
      final s = _ls[k], t = _lt[k];
      var dx = x[t] + vx[t] - x[s] - vx[s];
      var dy = y[t] + vy[t] - y[s] - vy[s];
      if (dx == 0 && dy == 0) {
        dx = _jitter();
        dy = _jitter();
      }
      final l = math.sqrt(dx * dx + dy * dy);
      final f = (l - _linkDistance) / l * alpha * _strength[k];
      dx *= f;
      dy *= f;
      final b = _bias[k];
      vx[t] -= dx * b;
      vy[t] -= dy * b;
      vx[s] += dx * (1 - b);
      vy[s] += dy * (1 - b);
    }
    // 모든 쌍에 반발력을 주고 겹치면 더 벌린다
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        var dx = x[j] - x[i];
        var dy = y[j] - y[i];
        var d2 = dx * dx + dy * dy;
        if (d2 == 0) {
          dx = _jitter();
          dy = _jitter();
          d2 = dx * dx + dy * dy;
        }
        if (d2 >= _chargeMaxD2) continue;
        final k = _charge * alpha / math.max(d2, 25);
        vx[i] += dx * k;
        vy[i] += dy * k;
        vx[j] -= dx * k;
        vy[j] -= dy * k;
        final rr = radius[i] + radius[j] + 8;
        if (d2 < rr * rr) {
          final l = math.sqrt(d2);
          final push = (rr - l) / math.max(l, 1e-6) * 0.35;
          vx[i] -= dx * push;
          vy[i] -= dy * push;
          vx[j] += dx * push;
          vy[j] += dy * push;
        }
      }
    }
    // 전체 무게중심을 원점으로 되돌리는 힘
    var cx = 0.0, cy = 0.0;
    for (var i = 0; i < n; i++) {
      cx += x[i];
      cy += y[i];
    }
    if (n > 0) {
      cx /= n;
      cy /= n;
    }
    // 속도 감쇠 후 위치 갱신 (붙잡은 노드는 고정)
    for (var i = 0; i < n; i++) {
      x[i] -= cx;
      y[i] -= cy;
      final px = fx[i], py = fy[i];
      if (px == null) {
        vx[i] *= 0.6;
        x[i] += vx[i];
      } else {
        x[i] = px;
        vx[i] = 0;
      }
      if (py == null) {
        vy[i] *= 0.6;
        y[i] += vy[i];
      } else {
        y[i] = py;
        vy[i] = 0;
      }
    }
  }
}
