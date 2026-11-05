import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import 'collect_controller.dart';
import 'collect_data.dart';
import 'name_input_screen.dart';
import 'widgets/next_button.dart';
import 'widgets/photo_placeholder.dart';
import 'widgets/sub_screen_scaffold.dart';

// 사진 선택 화면: 사진을 눌러 고르고(선택 순서 표시) 다음에 이름 입력으로 넘어간다
class PhotoSelectScreen extends StatefulWidget {
  const PhotoSelectScreen({super.key, required this.controller});

  final CollectController controller;

  @override
  State<PhotoSelectScreen> createState() => _PhotoSelectScreenState();
}

class _PhotoSelectScreenState extends State<PhotoSelectScreen> {
  // 지금 선택한 사진 번호 (선택한 순서 그대로)
  late final List<int> _selected = List.of(widget.controller.selectedPhotos);

  // 사진을 누르면 선택하고, 이미 선택했으면 해제한다
  void _toggle(int id) {
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  // 선택을 저장하고 이름 입력 화면으로 간다 (거기서 끝나면 이 화면도 닫는다)
  Future<void> _next() async {
    widget.controller.setSelection(_selected);
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NameInputScreen(controller: widget.controller)),
    );
    if (done == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final period = widget.controller.period;
    return SubScreenScaffold(
      title: '사진 선택',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _FilterPill(
                    icon: Icons.calendar_today_rounded,
                    label: period == null
                        ? '전체 기간'
                        : '${formatShortDate(period.start)} – ${formatShortDate(period.end)}',
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: _FilterPill(label: '전체 앨범')),
              ],
            ),
          ),
          if (period != null) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFE3E8FA), borderRadius: BorderRadius.circular(14)),
              child: Text('대화 기간에 맞춰 날짜를 추천했어요', style: appText(11, weight: FontWeight.w700, color: AppColors.accent)),
            ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Align(alignment: Alignment.centerLeft, child: _DateLabel()),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: CollectController.totalPhotos,
              itemBuilder: (_, id) => _PhotoTile(
                id: id,
                order: _selected.indexOf(id) + 1, // 0이면 선택 안 됨
                onTap: () => _toggle(id),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_selected.length}장 선택됨', style: appText(14, weight: FontWeight.w700)),
                GestureDetector(
                  onTap: () => setState(_selected.clear),
                  child: Text('전체 해제', style: appText(12, weight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: NextButton(label: '다음 · 이름 입력', enabled: _selected.isNotEmpty, onPressed: _next),
    );
  }
}

// 위쪽 필터 알약 (기간/앨범 선택 모양, 아직 눌러도 바뀌지 않는다)
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFDDE3F7)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(label, style: appText(12, weight: FontWeight.w700))),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.accent),
        ],
      ),
    );
  }
}

// 사진 목록 위의 날짜 글자 (지금은 더미 날짜)
class _DateLabel extends StatelessWidget {
  const _DateLabel();

  @override
  Widget build(BuildContext context) {
    return Text('9월 21일 · 토', style: appText(11, weight: FontWeight.w700, color: AppColors.textSecondary));
  }
}

// 사진 한 칸 (선택하면 파란 테두리와 선택 순서 번호가 붙는다)
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.id, required this.order, required this.onTap});

  final int id;
  // 선택 순서 (1부터), 선택 안 됐으면 0
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = order > 0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PhotoPlaceholder(variant: id, radius: 12),
          if (selected)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent, width: 2.5),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.accent : Colors.white.withValues(alpha: 0.7),
              ),
              child: selected
                  ? Text('$order', style: appText(10.5, weight: FontWeight.w700, color: Colors.white))
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
