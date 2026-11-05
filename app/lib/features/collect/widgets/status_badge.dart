import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';

// 카드 오른쪽 위에 놓는 알약 모양 상태 표시 ("1개 가져옴", "아직 없음")
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.done});

  final String label;
  // true면 초록(완료), false면 회색(아직 없음)
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.successBg : AppColors.badgeGrayBg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: appText(
          10.5,
          weight: FontWeight.w700,
          color: done ? AppColors.success : AppColors.textSecondary,
        ),
      ),
    );
  }
}
