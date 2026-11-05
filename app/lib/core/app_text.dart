import 'package:flutter/material.dart';

import 'app_colors.dart';

// 본문 폰트 이름 (Pretendard 파일을 등록하기 전에는 기본 폰트로 대신 표시된다)
const String appFontFamily = 'Pretendard';

// 글자 크기·굵기·색을 받아 앱 공통 글자 스타일을 만든다
TextStyle appText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.textPrimary,
}) {
  return TextStyle(
    fontFamily: appFontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}
