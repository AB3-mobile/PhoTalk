import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';

// 화면 아래 큰 파란 버튼 (사진이 없으면 흐리게 막고, 준비되면 파란 그라데이션)
class NextButton extends StatelessWidget {
  const NextButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.label = '다음',
  });

  final bool enabled;
  final VoidCallback onPressed;
  // 버튼에 적힐 글자
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: enabled ? null : AppColors.disabled,
        gradient: enabled
            ? const LinearGradient(colors: [AppColors.buttonStart, AppColors.primary])
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: Text(label, style: appText(15, weight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
