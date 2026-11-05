import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import 'circle_icon_button.dart';

// 뒤로가기 버튼과 제목이 위에 있는 하위 화면의 공통 틀 (본문 + 아래 고정 영역)
class SubScreenScaffold extends StatelessWidget {
  const SubScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
  });

  final String title;
  final Widget body;
  // 화면 아래에 고정할 버튼 영역 (없으면 생략)
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.chevron_left_rounded,
                    iconColor: AppColors.textPrimary,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 16),
                  Text(title, style: appText(22, weight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(child: body),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}
