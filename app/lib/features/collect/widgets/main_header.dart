import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import 'circle_icon_button.dart';

// 메뉴 버튼 · 제목 · 검색 버튼이 한 줄로 놓인 메인 화면 상단 (메뉴와 검색은 아직 동작 없음)
class MainHeader extends StatelessWidget {
  const MainHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleIconButton(icon: Icons.menu_rounded, iconColor: AppColors.textPrimary),
        const SizedBox(width: 16),
        Expanded(child: Text(title, style: appText(22, weight: FontWeight.w700))),
        const CircleIconButton(icon: Icons.search_rounded, iconColor: AppColors.accent),
      ],
    );
  }
}
