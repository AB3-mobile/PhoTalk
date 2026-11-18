import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/repositories/photo_repository.dart';
import 'collect_controller.dart';
import 'collect_data.dart';
import 'widgets/next_button.dart';
import 'widgets/person_avatar.dart';
import 'widgets/picked_photo_image.dart';
import 'widgets/sub_screen_scaffold.dart';

// 인물 이름 입력 화면: 선택한 사진을 한 장씩 보며 나온 사람 이름을 적는다 (자동완성 지원)
class NameInputScreen extends StatefulWidget {
  const NameInputScreen({super.key, required this.controller});

  final CollectController controller;

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  // 지금 보고 있는 사진의 순서 (0부터)
  int _index = 0;
  // 이름 입력칸
  final TextEditingController _text = TextEditingController();
  // 아래 썸네일 줄의 가로 스크롤
  final ScrollController _strip = ScrollController();

  List<int> get _photos => widget.controller.selectedPhotos;
  int get _current => _photos[_index];
  bool get _isLast => _index == _photos.length - 1;

  @override
  void initState() {
    super.initState();
    _text.text = widget.controller.photoNames[_current] ?? '';
    // 사진만 추가할 때는 서버에서 얼굴을 매칭해 이름을 미리 채운다
    if (widget.controller.autoMatchEnabled) {
      widget.controller.addListener(_onControllerChanged);
      widget.controller.autoMatch(context.read<PhotoRepository>());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _text.dispose();
    _strip.dispose();
    super.dispose();
  }

  // 매칭 결과가 오면 상태 표시를 갱신하고, 비어 있는 입력칸에는 자동으로 채워진 이름을 넣는다
  void _onControllerChanged() {
    if (!mounted) return;
    final name = widget.controller.photoNames[_current];
    setState(() {
      if (_text.text.trim().isEmpty && name != null) _text.text = name;
    });
  }

  // 사진만 추가할 때는 이름을 직접 적지 않고 고른 대화방 참여자 목록에서 고른다
  bool get _picking => widget.controller.autoMatchEnabled;

  // 지금 사진의 이름을 저장한다 (바뀐 게 없으면 그대로 둬서 늦게 온 자동 매칭이 채울 수 있게 한다)
  // 목록에서 고르는 경우는 누를 때 바로 저장하므로 할 일이 없다
  void _save() {
    if (_picking) return;
    final c = widget.controller;
    if (_text.text.trim() != (c.photoNames[_current] ?? '')) c.setName(_current, _text.text);
  }

  // 참여자 한 명을 이 사진의 사람으로 고른다 (이미 고른 사람을 다시 누르면 해제)
  void _pickPerson(String name) {
    final c = widget.controller;
    c.setName(_current, c.photoNames[_current] == name ? '' : name);
  }

  // 사진을 옮기고 입력칸과 썸네일 줄을 그 사진에 맞춘다
  void _goTo(int index) {
    setState(() {
      _index = index;
      _text.text = widget.controller.photoNames[_current] ?? '';
    });
    if (_strip.hasClients) {
      _strip.animateTo(
        (index * 60.0 - 100).clamp(0, _strip.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // 이름을 저장하고 다음 사진으로 간다 (마지막이면 끝내고 돌아간다)
  void _next() {
    _save();
    _isLast ? Navigator.pop(context, true) : _goTo(_index + 1);
  }

  // 이름 없이 다음 사진으로 넘어간다
  void _skip() {
    widget.controller.setName(_current, '');
    _isLast ? Navigator.pop(context, true) : _goTo(_index + 1);
  }

  // 이전 사진으로 가고, 첫 사진이면 이 화면을 닫는다
  void _prev() {
    _save();
    _index == 0 ? Navigator.pop(context) : _goTo(_index - 1);
  }

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: '인물 이름 입력',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${_index + 1}',
                  style: appText(20, weight: FontWeight.w700, color: AppColors.accent),
                ),
                Text(
                  ' / ${_photos.length}',
                  style: appText(14, weight: FontWeight.w700, color: AppColors.textSecondary),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _skip,
                  child: Text(
                    '건너뛰기',
                    style: appText(12, weight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 362 / 258,
              child: PickedPhotoImage(photo: widget.controller.photos[_current], radius: 24),
            ),
            const SizedBox(height: 14),
            _buildStrip(),
            const SizedBox(height: 18),
            Row(
              children: [
                Text('이 사진에 나온 사람', style: appText(13, weight: FontWeight.w700)),
                const Spacer(),
                if (widget.controller.autoMatchEnabled) _buildMatchStatus(),
              ],
            ),
            const SizedBox(height: 8),
            if (_picking) _buildPeoplePicker() else ..._buildNameField(),
          ],
        ),
      ),
      bottom: _buildBottom(),
    );
  }

  // 처음 데이터 수집할 때: 이름을 직접 적는 입력칸 + 자동완성
  List<Widget> _buildNameField() {
    return [
      TextField(
        controller: _text,
        onChanged: (_) => setState(() {}),
        style: appText(14, weight: FontWeight.w700),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: '이름을 입력하세요',
          hintStyle: appText(14, color: AppColors.chevron),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
      ),
      const SizedBox(height: 8),
      _buildSuggestions(),
    ];
  }

  // 아래 고정 버튼 (이전 / 다음 사진·완료)
  Widget _buildBottom() {
    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 52,
          child: OutlinedButton(
            onPressed: _prev,
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              side: const BorderSide(color: AppColors.dashed),
              backgroundColor: Colors.white,
            ),
            child: Text(
              '이전',
              style: appText(15, weight: FontWeight.w700, color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: NextButton(label: _isLast ? '완료' : '다음 사진', enabled: true, onPressed: _next),
        ),
      ],
    );
  }

  // 사진만 추가할 때: 고른 대화방 참여자 중에서 이 사진의 사람을 고른다
  // 자동 매칭된 사람은 (고른 사람이 바뀌어도) 항상 맨 위에 둔다
  Widget _buildPeoplePicker() {
    final c = widget.controller;
    final people = c.knownPeople;
    final matched = c.photoMatches[_current]?.bestName;
    final selected = c.photoNames[_current];
    // 원래 순서 번호는 아바타 색을 유지하려고 같이 들고 다닌다
    final order = List.generate(people.length, (i) => i)
      ..sort((a, b) {
        final am = people[a].name == matched ? 0 : 1;
        final bm = people[b].name == matched ? 0 : 1;
        return am != bm ? am - bm : a - b;
      });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
            child: Text(
              '대화 참여자 중에서 선택',
              style: appText(10.5, weight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ),
          for (final i in order)
            _personRow(i, people[i].name, people[i].messageCount, on: people[i].name == selected, auto: people[i].name == matched),
        ],
      ),
    );
  }

  // 참여자 한 줄 (고른 사람은 파란 배경·테두리와 체크, 자동 매칭된 사람은 '자동 매칭' 표시)
  Widget _personRow(int colorIndex, String name, int messages, {required bool on, required bool auto}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pickPerson(name),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: on ? AppColors.tileBg : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? AppColors.accent : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              PersonAvatar(index: colorIndex, size: 24),
              const SizedBox(width: 10),
              Text(
                name,
                style: appText(13, weight: FontWeight.w700, color: on ? AppColors.accent : AppColors.textPrimary),
              ),
              if (auto) ...[
                const SizedBox(width: 6),
                const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.success),
                const SizedBox(width: 2),
                Text(
                  '자동 매칭',
                  style: appText(10, weight: FontWeight.w700, color: AppColors.success),
                ),
              ],
              const Spacer(),
              Text('메시지 ${formatCount(messages)}개', style: appText(10.5, color: AppColors.textSecondary)),
              if (on) ...[const SizedBox(width: 8), const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.accent)],
            ],
          ),
        ),
      ),
    );
  }

  // 지금 사진의 얼굴 자동 매칭 상태 (확인 중, 자동 매칭+유사도, 못 찾음, 얼굴 없음, 실패)
  Widget _buildMatchStatus() {
    final c = widget.controller;
    final match = c.photoMatches[_current];
    if (c.matchingPhotos.contains(_current) || (match == null && !c.matchFailedPhotos.contains(_current))) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
          const SizedBox(width: 6),
          Text('얼굴 확인 중…', style: appText(11, color: AppColors.textSecondary)),
        ],
      );
    }
    if (match == null) return Text('얼굴 매칭 실패', style: appText(11, color: AppColors.error));
    if (match.faceCount == 0) {
      return Text('얼굴을 찾지 못했어요', style: appText(11, weight: FontWeight.w700, color: AppColors.error));
    }
    final name = match.bestName;
    final sim = match.bestSimilarity;
    if (name == null) return Text('아는 얼굴을 찾지 못했어요', style: appText(11, color: AppColors.textSecondary));
    // 사용자가 다른 이름으로 바꿨으면 자동 매칭 표시는 숨긴다
    final current = _picking ? c.photoNames[_current] : _text.text.trim();
    if (current != name) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.success),
        const SizedBox(width: 4),
        Text(
          sim == null ? '자동 매칭' : '자동 매칭 · 유사도 ${(sim * 100).round()}%',
          style: appText(11, weight: FontWeight.w700, color: AppColors.success),
        ),
      ],
    );
  }

  // 선택한 사진들의 작은 썸네일 줄 (이름 끝난 사진은 체크, 지금 사진은 파란 테두리)
  Widget _buildStrip() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        controller: _strip,
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final id = _photos[i];
          final named = widget.controller.photoNames.containsKey(id) && i != _index;
          return GestureDetector(
            onTap: () {
              _save();
              _goTo(i);
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: i == _index ? Border.all(color: AppColors.accent, width: 2) : null,
              ),
              padding: i == _index ? const EdgeInsets.all(2) : EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PickedPhotoImage(photo: widget.controller.photos[id], radius: 11, dim: named),
                  if (named)
                    const Center(
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: AppColors.success,
                        child: Icon(Icons.check_rounded, size: 11, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 입력한 글자로 시작하는 대화 참여자를 아래에 자동완성 목록으로 보여 준다 (입력이 비어 있으면 전체)
  Widget _buildSuggestions() {
    final q = _text.text.trim();
    final counts = widget.controller.messageCounts;
    final matches = widget.controller.participantNames.where((n) => q.isEmpty || n.startsWith(q)).toList();
    if (matches.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
            child: Text(
              '대화 참여자',
              style: appText(10.5, weight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ),
          for (var i = 0; i < matches.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _text.text = matches[i]),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: i == 0 ? AppColors.tileBg : null, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    PersonAvatar(index: i, size: 24),
                    const SizedBox(width: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: matches[i].substring(0, q.length.clamp(0, matches[i].length)),
                            style: appText(13, weight: FontWeight.w700, color: AppColors.accent),
                          ),
                          TextSpan(
                            text: matches[i].substring(q.length.clamp(0, matches[i].length)),
                            style: appText(13, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (counts[matches[i]] != null)
                      Text('메시지 ${formatCount(counts[matches[i]]!)}개', style: appText(10.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
