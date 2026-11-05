import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import 'collect_controller.dart';
import 'collect_data.dart';
import 'widgets/next_button.dart';
import 'widgets/person_avatar.dart';
import 'widgets/photo_placeholder.dart';
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
  }

  @override
  void dispose() {
    _text.dispose();
    _strip.dispose();
    super.dispose();
  }

  // 지금 사진의 이름을 저장한다
  void _save() => widget.controller.setName(_current, _text.text);

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
                Text('${_index + 1}', style: appText(20, weight: FontWeight.w700, color: AppColors.accent)),
                Text(' / ${_photos.length}', style: appText(14, weight: FontWeight.w700, color: AppColors.textSecondary)),
                const Spacer(),
                GestureDetector(
                  onTap: _skip,
                  child: Text('건너뛰기', style: appText(12, weight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 362 / 258,
              child: PhotoPlaceholder(variant: _current, radius: 24),
            ),
            const SizedBox(height: 14),
            _buildStrip(),
            const SizedBox(height: 18),
            Text('이 사진에 나온 사람', style: appText(13, weight: FontWeight.w700)),
            const SizedBox(height: 8),
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
          ],
        ),
      ),
      bottom: Row(
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
              child: Text('이전', style: appText(15, weight: FontWeight.w700, color: AppColors.accent)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: NextButton(label: _isLast ? '완료' : '다음 사진', enabled: true, onPressed: _next)),
        ],
      ),
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                  PhotoPlaceholder(variant: id, radius: 11, dim: named),
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
    final matches = widget.controller.participantNames
        .where((n) => q.isEmpty || n.startsWith(q))
        .toList();
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
            child: Text('대화 참여자', style: appText(10.5, weight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          for (var i = 0; i < matches.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _text.text = matches[i]),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: i == 0 ? AppColors.tileBg : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    PersonAvatar(index: i, size: 24),
                    const SizedBox(width: 10),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                        text: matches[i].substring(0, q.length.clamp(0, matches[i].length)),
                        style: appText(13, weight: FontWeight.w700, color: AppColors.accent),
                      ),
                      TextSpan(
                        text: matches[i].substring(q.length.clamp(0, matches[i].length)),
                        style: appText(13, weight: FontWeight.w700),
                      ),
                    ])),
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
