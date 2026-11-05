import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import 'dashed_box.dart';
import 'photo_placeholder.dart';
import 'section_card.dart';

// PHOTO 카드: 사진이 없으면 선택 영역, 있으면 썸네일 요약과 '+ 사진 추가'를 보여준다
class PhotoSection extends StatelessWidget {
  const PhotoSection({
    super.key,
    required this.photoCount,
    required this.namedCount,
    required this.onPick,
    required this.photoIds,
    this.enabled = true,
  });

  final int photoCount;
  final int namedCount;
  final VoidCallback onPick;
  // 앞쪽 썸네일로 보여줄 선택된 사진 번호들
  final List<int> photoIds;
  // 대화방이 없으면 false (사진 선택 박스를 흐리게 막는다)
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasPhotos = photoCount > 0;
    return SectionCard(
      label: 'PHOTO',
      title: '사진',
      icon: Icons.image_outlined,
      badgeText: hasPhotos ? '$photoCount장 가져옴' : '아직 없음',
      badgeDone: hasPhotos,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: hasPhotos ? _buildCollected() : _buildEmpty(),
      ),
    );
  }

  // 사진이 없을 때 보이는 큰 '사진 선택하기' 영역
  Widget _buildEmpty() {
    return DashedBox(
      height: 132,
      fillColor: AppColors.pickAreaBg,
      onTap: enabled ? onPick : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.add_rounded, size: 24, color: AppColors.accent),
          ),
          const SizedBox(height: 10),
          Text('사진 선택하기', style: appText(14, weight: FontWeight.w700, color: AppColors.accent)),
          const SizedBox(height: 4),
          Text(enabled ? '선택 사항이에요. 인물 사진을 골라주세요' : '대화방을 먼저 추가해 주세요', style: appText(10.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // 사진이 있을 때 보이는 썸네일 줄, 요약 줄, '+ 사진 추가' 버튼
  Widget _buildCollected() {
    final shown = photoIds.take(4).toList();
    final rest = photoCount - shown.length;
    return Column(
      children: [
        Row(
          children: [
            for (final id in shown) ...[
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: PhotoPlaceholder(variant: id, radius: 10),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (rest > 0) Expanded(child: _Thumb(color: AppColors.tileBg, label: '+$rest')),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: AppColors.rowBg, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('사진 $photoCount장', style: appText(13, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('이름 입력 $namedCount / $photoCount장', style: appText(11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.success),
            ],
          ),
        ),
        const SizedBox(height: 10),
        DashedBox(
          height: 44,
          onTap: onPick,
          child: Text('+ 사진 추가', style: appText(13, weight: FontWeight.w700, color: AppColors.accent)),
        ),
      ],
    );
  }
}

// 정사각형 사진 썸네일 자리 (실제 사진 대신 색 칸, label이 있으면 글자를 얹는다)
class _Thumb extends StatelessWidget {
  const _Thumb({required this.color, this.label});

  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: label == null
            ? const Icon(Icons.person_rounded, size: 22, color: Colors.white)
            : Text(label!, style: appText(12, weight: FontWeight.w700, color: AppColors.accent)),
      ),
    );
  }
}
