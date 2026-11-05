import 'package:flutter/material.dart';

// 앱에서 쓰는 색상 모음 (값은 설계서 이미지를 보고 맞춘 임시값이라 Figma 값으로 교체 예정)
class AppColors {
  AppColors._();

  // 시작 화면 배경 그라데이션의 위쪽 색
  static const Color startTop = Color(0xFF5576DD);
  // 시작 화면 배경 그라데이션의 아래쪽 색
  static const Color startBottom = Color(0xFF3050B0);
  // 시작 화면 일러스트 뒤의 밝은 빛 번짐 색
  static const Color startGlow = Color(0xFF86A2F0);
  // 버튼 글자와 강조 요소에 쓰는 진한 파랑 (Figma 값 #2E4BAD)
  static const Color primary = Color(0xFF2E4BAD);
  // 사진 노드에 쓰는 연한 하늘색
  static const Color photoBlue = Color(0xFF9CC8EC);
  // 사진 노드에 쓰는 연한 보라색
  static const Color photoLavender = Color(0xFFB4B4EE);
  // 인물 노드에 쓰는 청록색
  static const Color personTeal = Color(0xFF8CC7B8);
}
