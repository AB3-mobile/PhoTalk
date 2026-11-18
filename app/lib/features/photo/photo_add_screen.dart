import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/models/person.dart';
import '../../domain/repositories/photo_repository.dart';
import '../collect/collect_controller.dart';
import '../collect/photo_select_screen.dart';
import '../collect/widgets/next_button.dart';
import '../collect/widgets/picked_photo_image.dart';
import '../collect/widgets/sub_screen_scaffold.dart';
import 'room_select_screen.dart';

// 이미 만든 지식 그래프에 인물 사진을 더 넣는다: 대화방 선택 → 사진 선택 → 이름 입력 → 서버 업로드, 하나라도 올렸으면 true
Future<bool> openPhotoAdd(BuildContext context) async {
  final people = await Navigator.push<List<Person>>(context, MaterialPageRoute(builder: (_) => const RoomSelectScreen()));
  if (people == null || !context.mounted) return false;
  // 고른 대화방의 인물을 이름 후보로 넘긴다
  final c = CollectController()..setKnownPeople(people);
  // 사진 선택과 이름 입력은 데이터 수집 때 쓰는 화면을 그대로 쓴다
  final picked = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => PhotoSelectScreen(controller: c)),
  );
  if (picked != true || !context.mounted || c.selectedPhotos.isEmpty) return false;
  final done = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => PhotoUploadScreen(controller: c)),
  );
  return done == true;
}

// 사진 한 장의 업로드 상태
enum _Phase { waiting, uploading, done, failed }

// 고른 사진을 한 장씩 서버에 올리고 장마다 결과를 보여 주는 화면
class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key, required this.controller});

  final CollectController controller;

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  late final int _count = widget.controller.selectedPhotos.length;
  // 사진별 상태, 서버가 찾은 얼굴 수, 실패 이유
  late final List<_Phase> _phase = List.filled(_count, _Phase.waiting);
  late final List<int> _faces = List.filled(_count, 0);
  late final List<String> _error = List.filled(_count, '');
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  // 아직 못 올린 사진을 차례로 올린다 (이미 올린 사진은 건너뛴다)
  Future<void> _run() async {
    final c = widget.controller;
    final repo = context.read<PhotoRepository>();
    setState(() => _running = true);
    for (var i = 0; i < _count && mounted; i++) {
      if (_phase[i] == _Phase.done) continue;
      setState(() => _phase[i] = _Phase.uploading);
      final photo = c.photos[c.selectedPhotos[i]];
      try {
        // 같이 찍힌 다른 얼굴도 고른 대화방 참여자하고만 자동 매칭한다
        final faces = await repo.uploadPhoto(
          bytes: photo.bytes,
          fileName: photo.name,
          name: c.photoNames[c.selectedPhotos[i]],
          candidates: c.candidateNames,
        );
        if (!mounted) return;
        setState(() {
          _phase[i] = _Phase.done;
          _faces[i] = faces;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _phase[i] = _Phase.failed;
          _error[i] = '$e'.replaceFirst('Exception: ', '');
        });
      }
    }
    if (mounted) setState(() => _running = false);
  }

  bool get _hasFailed => _phase.contains(_Phase.failed);
  int get _doneCount => _phase.where((p) => p == _Phase.done).length;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return PopScope(
      // 올리는 중에는 뒤로가기를 막는다
      canPop: !_running,
      onPopInvokedWithResult: (_, _) {},
      child: SubScreenScaffold(
        title: '사진 추가',
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          itemCount: _count,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final id = c.selectedPhotos[i];
            final name = c.photoNames[id];
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  SizedBox(width: 52, height: 52, child: PickedPhotoImage(photo: c.photos[id], radius: 12)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name ?? '이름 없음', style: appText(14, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          _phase[i] == _Phase.failed ? _error[i] : c.photos[id].name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: appText(11, color: _phase[i] == _Phase.failed ? AppColors.error : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _status(i),
                ],
              ),
            );
          },
        ),
        bottom: NextButton(
          label: _running ? '올리는 중 $_doneCount / $_count' : (_hasFailed ? '실패한 사진 다시 올리기' : '완료'),
          enabled: !_running,
          onPressed: _hasFailed ? _run : () => Navigator.pop(context, _doneCount > 0),
        ),
      ),
    );
  }

  // 오른쪽에 보이는 사진별 상태 (대기, 올리는 중, 완료와 얼굴 수, 실패)
  Widget _status(int i) {
    switch (_phase[i]) {
      case _Phase.waiting:
        return Text('대기', style: appText(12, color: AppColors.textSecondary));
      case _Phase.uploading:
        return const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
      case _Phase.done:
        return Text('얼굴 ${_faces[i]}개', style: appText(12, weight: FontWeight.w700, color: AppColors.success));
      case _Phase.failed:
        return const Icon(Icons.error_outline_rounded, size: 20, color: AppColors.error);
    }
  }
}
