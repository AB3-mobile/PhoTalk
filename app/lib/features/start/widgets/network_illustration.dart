import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';

// 노드가 어떤 모양(말풍선·사진·인물)인지 구분하는 종류
enum _NodeKind { dotsBubble, textBubble, photoBlue, photoLavender, person }

// 허브 둘레에 놓이는 노드 하나의 종류와 위치(허브 기준 비율)
class _NodeSpec {
  const _NodeSpec(this.kind, this.dx, this.dy);

  final _NodeKind kind;
  final double dx;
  final double dy;
}

// 허브 둘레 8개 노드 (위쪽부터 시계 방향이며 이웃끼리 점선으로 이어진다)
const List<_NodeSpec> _nodes = [
  _NodeSpec(_NodeKind.dotsBubble, 0.02, -0.78),
  _NodeSpec(_NodeKind.photoLavender, 0.76, -0.57),
  _NodeSpec(_NodeKind.textBubble, 0.83, 0.10),
  _NodeSpec(_NodeKind.photoBlue, 0.61, 0.71),
  _NodeSpec(_NodeKind.textBubble, -0.04, 0.98),
  _NodeSpec(_NodeKind.person, -0.78, 0.61),
  _NodeSpec(_NodeKind.dotsBubble, -0.58, 0.14),
  _NodeSpec(_NodeKind.photoBlue, -0.71, -0.50),
];

// 가운데 허브와 둘레 노드, 연결선으로 이루어진 PhoTalk 로고 일러스트
class NetworkIllustration extends StatelessWidget {
  const NetworkIllustration({super.key, required this.side});

  // 일러스트가 차지하는 정사각형의 한 변 길이
  final double side;

  // 노드 종류에 맞는 크기를 돌려준다 (말풍선은 가로로 길고 나머지는 정사각형)
  Size _sizeOf(_NodeKind kind) {
    final isBubble =
        kind == _NodeKind.dotsBubble || kind == _NodeKind.textBubble;
    return isBubble ? Size(side * 0.20, side * 0.14) : Size(side * 0.17, side * 0.17);
  }

  // 중심 좌표 기준으로 자식을 놓는다
  Widget _placeAt(Offset center, Size size, Widget child) {
    return Positioned(
      left: center.dx - size.width / 2,
      top: center.dy - size.height / 2,
      width: size.width,
      height: size.height,
      child: child,
    );
  }

  // 종류에 맞는 노드 모양 위젯을 만든다
  Widget _buildNode(_NodeKind kind) {
    switch (kind) {
      case _NodeKind.dotsBubble:
        return const CustomPaint(
            painter: _BubblePainter(withDots: true, tailOnLeft: true));
      case _NodeKind.textBubble:
        return const CustomPaint(
            painter: _BubblePainter(withDots: false, tailOnLeft: false));
      default:
        return CustomPaint(painter: _TilePainter(kind));
    }
  }

  @override
  Widget build(BuildContext context) {
    final half = side / 2;
    final hub = Offset(half, half);
    final centers = [
      for (final n in _nodes)
        Offset(half + n.dx * half * 0.9, half + n.dy * half * 0.9),
    ];

    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LinesPainter(hub, centers)),
          ),
          for (var i = 0; i < _nodes.length; i++)
            _placeAt(centers[i], _sizeOf(_nodes[i].kind),
                _buildNode(_nodes[i].kind)),
          _placeAt(hub, Size(side * 0.27, side * 0.27),
              const CustomPaint(painter: _HubPainter())),
        ],
      ),
    );
  }
}

// 허브에서 각 노드로 가는 실선과 이웃 노드끼리 잇는 점선을 그리는 페인터
class _LinesPainter extends CustomPainter {
  const _LinesPainter(this.hub, this.centers);

  final Offset hub;
  final List<Offset> centers;

  @override
  void paint(Canvas canvas, Size size) {
    final solid = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final dashed = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    for (final c in centers) {
      canvas.drawLine(hub, c, solid);
    }
    for (var i = 0; i < centers.length; i++) {
      _drawDashed(
          canvas, centers[i], centers[(i + 1) % centers.length], dashed);
    }
  }

  // 두 점 사이를 짧은 선분으로 끊어서 점선으로 그린다
  void _drawDashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final end = math.min(d + dash, total);
      canvas.drawLine(a + dir * d, a + dir * end, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 흰색 말풍선(점 세 개 또는 글줄 두 개가 들어간 모양)을 그리는 페인터
class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.withDots, required this.tailOnLeft});

  final bool withDots;
  final bool tailOnLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final bodyH = size.height * 0.82;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, bodyH),
      Radius.circular(bodyH * 0.35),
    );
    final tail = Path()
      ..moveTo(w * (tailOnLeft ? 0.15 : 0.62), bodyH - 1)
      ..lineTo(w * (tailOnLeft ? 0.10 : 0.90), size.height)
      ..lineTo(w * (tailOnLeft ? 0.38 : 0.85), bodyH - 1)
      ..close();
    final shape = Path.combine(
      PathOperation.union,
      Path()..addRRect(body),
      tail,
    );
    canvas.drawShadow(shape, Colors.black, 3, false);
    canvas.drawPath(shape, Paint()..color = Colors.white);

    if (withDots) {
      final r = bodyH * 0.09;
      final y = bodyH / 2;
      canvas.drawCircle(
          Offset(w * 0.3, y), r, Paint()..color = AppColors.primary);
      canvas.drawCircle(
          Offset(w * 0.5, y), r, Paint()..color = AppColors.photoLavender);
      canvas.drawCircle(Offset(w * 0.7, y), r,
          Paint()..color = AppColors.photoLavender.withValues(alpha: 0.6));
    } else {
      final line = Paint()
        ..color = AppColors.photoLavender
        ..strokeWidth = bodyH * 0.1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(w * 0.2, bodyH * 0.38), Offset(w * 0.8, bodyH * 0.38), line);
      canvas.drawLine(
          Offset(w * 0.2, bodyH * 0.62), Offset(w * 0.55, bodyH * 0.62), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 흰 테두리 안에 풍경(사진 노드) 또는 사람(인물 노드)이 들어간 둥근 타일을 그리는 페인터
class _TilePainter extends CustomPainter {
  const _TilePainter(this.kind);

  final _NodeKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.22),
    );
    canvas.drawShadow(Path()..addRRect(outer), Colors.black, 3, false);
    canvas.drawRRect(outer, Paint()..color = Colors.white);

    final inner = outer.deflate(size.width * 0.05);
    final List<Color> colors;
    switch (kind) {
      case _NodeKind.person:
        colors = const [Color(0xFFB5E0D3), AppColors.personTeal];
        break;
      case _NodeKind.photoLavender:
        colors = const [Color(0xFFD2D2F6), AppColors.photoLavender];
        break;
      default:
        colors = const [Color(0xFFC8E3F8), AppColors.photoBlue];
    }

    canvas.save();
    canvas.clipRRect(inner);
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(inner.outerRect),
    );
    if (kind == _NodeKind.person) {
      _paintPerson(canvas, size);
    } else {
      _paintLandscape(canvas, size);
    }
    canvas.restore();
  }

  // 해와 두 개의 산으로 된 풍경 아이콘을 그린다
  void _paintLandscape(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final white = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final softWhite = Paint()..color = Colors.white.withValues(alpha: 0.6);

    canvas.drawCircle(Offset(w * 0.68, h * 0.30), w * 0.08, white);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.1, h * 0.85)
        ..lineTo(w * 0.38, h * 0.5)
        ..lineTo(w * 0.64, h * 0.85)
        ..close(),
      white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.45, h * 0.85)
        ..lineTo(w * 0.68, h * 0.58)
        ..lineTo(w * 0.92, h * 0.85)
        ..close(),
      softWhite,
    );
  }

  // 머리와 어깨로 된 사람 아이콘을 그린다
  void _paintPerson(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final white = Paint()..color = Colors.white.withValues(alpha: 0.9);

    canvas.drawCircle(Offset(w * 0.5, h * 0.38), w * 0.13, white);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.88),
        width: w * 0.6,
        height: h * 0.5,
      ),
      white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 가운데 허브(흰 둥근 사각형 안의 파란 말풍선과 작은 사진 말풍선)를 그리는 페인터
class _HubPainter extends CustomPainter {
  const _HubPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final box = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(w * 0.3),
    );
    canvas.drawShadow(Path()..addRRect(box), Colors.black, 6, false);
    canvas.drawRRect(box, Paint()..color = Colors.white);

    final blue = Paint()..color = AppColors.primary;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.17, h * 0.2, w * 0.46, h * 0.36),
        Radius.circular(w * 0.1),
      ),
      blue,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.24, h * 0.54)
        ..lineTo(w * 0.2, h * 0.66)
        ..lineTo(w * 0.36, h * 0.55)
        ..close(),
      blue,
    );

    final photo = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.5, h * 0.42, w * 0.34, h * 0.28),
      Radius.circular(w * 0.07),
    );
    canvas.drawRRect(photo, Paint()..color = Colors.white);
    canvas.drawRRect(
      photo.deflate(w * 0.025),
      Paint()..color = AppColors.photoBlue,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.56, h * 0.64)
        ..lineTo(w * 0.64, h * 0.52)
        ..lineTo(w * 0.72, h * 0.64)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
