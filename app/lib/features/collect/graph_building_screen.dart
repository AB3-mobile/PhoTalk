import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/repositories/chatroom_repository.dart';
import 'collect_controller.dart';
import 'collect_data.dart';
import 'graph_done_screen.dart';
import 'widgets/main_header.dart';
import 'widgets/next_button.dart';

// 그래프 만드는 중 화면: 서버 인덱싱 진행률을 원형 그래프와 4단계 목록으로 보여 주고, 끝나면 완성 화면으로 넘어간다
class GraphBuildingScreen extends StatefulWidget {
  const GraphBuildingScreen({super.key, required this.controller});

  final CollectController controller;

  @override
  State<GraphBuildingScreen> createState() => _GraphBuildingScreenState();
}

class _GraphBuildingScreenState extends State<GraphBuildingScreen> {
  // 구축 단계 이름과 설명 (서버가 단계별 이름을 주지 않아 진행률 구간으로 나눈다)
  static const _titles = ['대화 파싱', '인물·관계 추출', '사진 매칭', '정리'];
  // 단계가 끝나는 진행률 경계 (0~15 / 15~60 / 60~90 / 90~100)
  static const _bounds = [15, 60, 90, 100];

  // 지금 진행률 0~100 (작업이 여러 개면 가장 느린 것 기준)
  int _progress = 0;
  // 실패 문구 (없으면 null)
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 아직 서버에 안 올린 대화방을 올려 그래프 구축을 시작시킨 뒤, 2초마다 진행률을 확인한다
  Future<void> _start() async {
    final c = widget.controller;
    final repo = context.read<ChatroomRepository>();
    setState(() => _progress = 1);
    try {
      while (c.uploadedCount < c.pendingChats.length && mounted) {
        final chat = c.pendingChats[c.uploadedCount];
        final jobId = await repo.uploadMessenger(
          content: chat.preview.content,
          filename: chat.preview.fileName,
          roomName: chat.displayName,
        );
        // 파싱·저장이 끝날 때까지 기다린 뒤 서버가 시작한 구축 작업 ID를 받는다
        while (mounted) {
          final st = await repo.getUploadStatus(jobId);
          if (st.isError) throw Exception(st.error ?? '업로드 실패');
          if (st.isDone) {
            c.markUploaded(graphJobId: st.graphJobId, roomId: st.roomId);
            break;
          }
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
      return;
    }
    if (!mounted) return;
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  // 서버에 진행률을 물어 화면에 반영하고, 모두 끝났으면 완성 화면으로 간다
  Future<void> _poll() async {
    final ids = widget.controller.graphJobIds;
    // 진행 중인 작업이 없으면(이미 인덱싱된 대화방) 바로 완료로 본다
    if (ids.isEmpty) return _finish();
    try {
      final repo = context.read<ChatroomRepository>();
      final all = await Future.wait(ids.map(repo.getGraphBuildStatus));
      if (!mounted) return;
      if (all.any((s) => s.isFailed)) {
        _timer?.cancel();
        setState(() => _error = all.firstWhere((s) => s.isFailed).message);
        return;
      }
      setState(() => _progress = all.map((s) => s.progress).reduce(math.min));
      if (all.every((s) => s.isDone)) _finish();
    } catch (_) {
      // 잠깐 연결이 끊겨도 다음 주기에 다시 시도한다
    }
  }

  // 진행률을 100으로 채우고 잠깐 뒤 완성 화면으로 바꾼다
  void _finish() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _progress = 100);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GraphDoneScreen(controller: widget.controller)),
      );
    });
  }

  // 진행률로 현재 단계(0~3)를 구한다 (100이면 4)
  int get _step {
    if (_progress >= 100) return 4;
    for (var i = 0; i < _bounds.length; i++) {
      if (_progress < _bounds[i]) return i;
    }
    return 3;
  }

  // 현재 단계 안에서 얼마나 왔는지 0~1
  double get _stepFraction {
    final s = _step;
    if (s >= 4) return 1;
    final from = s == 0 ? 0 : _bounds[s - 1];
    return ((_progress - from) / (_bounds[s] - from)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final room = c.pendingChats.isNotEmpty ? c.pendingChats.first.displayName : '대화방';
    final details = [
      '메시지 ${formatCount(c.messageTotal)}개 정리',
      '인물 ${c.participantTotal}명 발견',
      c.photoCount == 0 ? '사진 없음 · 건너뜀' : '사진 ${c.photoCount}장 매칭',
      '그래프 구조 정리',
    ];

    return PopScope(
      canPop: false, // 구축 중에는 뒤로 가지 않는다 (작업은 서버에서 계속 진행된다)
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MainHeader(title: '그래프 만드는 중'),
                const SizedBox(height: 14),
                Text(
                  '$room · 메시지 ${formatCount(c.messageTotal)}개 · 사진 ${c.photoCount}장',
                  style: appText(12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                Center(child: _Ring(percent: _progress, step: _step)),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  Text('그래프를 만들지 못했어요: $_error', style: appText(12.5, color: const Color(0xFFD64545))),
                  const SizedBox(height: 12),
                  NextButton(label: '돌아가기', enabled: true, onPressed: () => Navigator.of(context).pop()),
                ] else
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        for (var i = 0; i < 4; i++)
                          _StepRow(
                            title: _titles[i],
                            detail: details[i],
                            state: i < _step ? _StepState.done : (i == _step ? _StepState.current : _StepState.waiting),
                            fraction: _stepFraction,
                            isLast: i == 3,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 가운데에 퍼센트와 "N / 4 단계"가 있는 원형 진행 그래프
class _Ring extends StatelessWidget {
  const _Ring({required this.percent, required this.step});

  final int percent;
  final int step;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 188,
      height: 188,
      child: CustomPaint(
        painter: _RingPainter(percent / 100),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: '$percent', style: appText(38, weight: FontWeight.w700)),
                TextSpan(text: '%', style: appText(18, weight: FontWeight.w700)),
              ])),
              Text('${math.min(step + 1, 4)} / 4 단계', style: appText(12, weight: FontWeight.w700, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// 연한 바탕 원 위에 진행 비율만큼 파란 호를 그리는 페인터 (위쪽에서 시계 방향)
class _RingPainter extends CustomPainter {
  const _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFE6EBFB);
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0.0, 1.0),
      false,
      base..color = AppColors.accent..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}

enum _StepState { done, current, waiting }

// 단계 목록의 한 줄 (왼쪽 원 아이콘과 이어진 선, 제목, 설명, 오른쪽 상태)
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.title,
    required this.detail,
    required this.state,
    required this.fraction,
    required this.isLast,
  });

  final String title;
  final String detail;
  final _StepState state;
  // 현재 단계의 진행 비율 (진행 중 막대에 쓴다)
  final double fraction;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final waiting = state == _StepState.waiting;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                _Dot(state: state),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: state == _StepState.done ? AppColors.accent : const Color(0xFFDDE3F3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: appText(13.5, weight: FontWeight.w700, color: waiting ? const Color(0xFFA3ACC6) : AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(detail, style: appText(11, color: waiting ? const Color(0xFFA3ACC6) : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (state == _StepState.done)
                    Text('완료', style: appText(11, weight: FontWeight.w700, color: AppColors.accent))
                  else if (state == _StepState.current)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          width: 90,
                          height: 6,
                          child: LinearProgressIndicator(
                            value: fraction,
                            backgroundColor: const Color(0xFFE6EBFB),
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 단계 상태를 나타내는 원 (완료: 파란 체크, 진행 중: 파란 테두리와 점, 대기: 회색 빈 원)
class _Dot extends StatelessWidget {
  const _Dot({required this.state});

  final _StepState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _StepState.done:
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EDFB),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
        );
      case _StepState.waiting:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDDE3F3), width: 2),
          ),
        );
    }
  }
}
