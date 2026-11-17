import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../collect_data.dart';

// 고른 실제 사진을 둥근 모서리 칸에 꽉 채워 보여 준다 (HEIC처럼 이 기기가 못 그리는 형식이면 사진 아이콘으로 대신한다)
class PickedPhotoImage extends StatelessWidget {
  const PickedPhotoImage({
    super.key,
    required this.photo,
    this.radius = 12,
    this.dim = false,
  });

  final PickedPhoto photo;
  final double radius;
  // true면 어둡게 덮는다 (이름 입력이 끝난 사진 표시)
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            photo.bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // 그리드에 원본 해상도를 그대로 올리면 메모리를 많이 쓰므로 작게 디코드한다
            cacheWidth: 600,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: AppColors.tileBg,
              child: Center(child: Icon(Icons.image_outlined, color: AppColors.accent)),
            ),
          ),
          if (dim) const ColoredBox(color: Color(0x661E2A4A)),
        ],
      ),
    );
  }
}
