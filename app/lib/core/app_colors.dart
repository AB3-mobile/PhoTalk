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

  // 화면 전체 배경색 (이미지로 맞춘 임시값)
  static const Color background = Color(0xFFF3F4FB);
  // 제목과 본문에 쓰는 진한 남색 (Figma 값 #1E2A4A)
  static const Color textPrimary = Color(0xFF1E2A4A);
  // 보조 설명에 쓰는 회색 글자색 (Figma 값 #6B7697)
  static const Color textSecondary = Color(0xFF6B7697);
  // 버튼 글자와 아이콘에 쓰는 밝은 파랑 (Figma 값 #3F5BD6)
  static const Color accent = Color(0xFF3F5BD6);
  // '가져옴' 같은 완료 상태의 초록색 (Figma 값 #22A36A)
  static const Color success = Color(0xFF22A36A);
  // 완료 배지의 연한 초록 배경 (임시값)
  static const Color successBg = Color(0xFFDFF4E8);
  // '아직 없음' 배지의 연한 회색 배경 (임시값)
  static const Color badgeGrayBg = Color(0xFFE9ECF4);
  // 카드 왼쪽 아이콘 칸의 연한 파랑 배경 (임시값)
  static const Color tileBg = Color(0xFFE8EDFB);
  // 대화방·사진 요약 줄의 연한 배경 (임시값)
  static const Color rowBg = Color(0xFFF3F5FC);
  // 사진 선택 영역의 연한 파랑 배경 (임시값)
  static const Color pickAreaBg = Color(0xFFE9EDFB);
  // 점선 테두리 색 (임시값)
  static const Color dashed = Color(0xFFB4C0F0);
  // 화살표 같은 흐린 아이콘 색 (임시값)
  static const Color chevron = Color(0xFF9AA3C2);
  // 비활성 버튼의 연한 보라색 (임시값)
  static const Color disabled = Color(0xFFC9D0EC);
  // 활성 버튼 그라데이션의 시작(왼쪽) 색 (임시값)
  static const Color buttonStart = Color(0xFF4A67E3);

  // 지식 그래프의 중앙(대화방) 노드 색 (임시값)
  static const Color nodeRoom = Color(0xFF2F4FD0);
  // 지식 그래프의 인물 노드 색 (임시값)
  static const Color nodePerson = Color(0xFF8E9DEB);
  // 지식 그래프의 키워드 노드 색 (임시값)
  static const Color nodeKeyword = Color(0xFF4FA3E6);
  // 지식 그래프의 파일 노드 색 (임시값)
  static const Color nodeFile = Color(0xFF7FE0F2);
  // 지식 그래프의 사진 노드 색 (임시값)
  static const Color nodePhoto = Color(0xFFB9D6F2);
  // 인물과 중앙을 잇는 굵은 선 색 (임시값)
  static const Color edgeStrong = Color(0xFF9AA8EE);
  // 인물과 항목을 잇는 얇은 선 색 (임시값)
  static const Color edgeThin = Color(0xFFB8C4EE);
  // 인물끼리 잇는 보조 점선 색 (임시값)
  static const Color edgeDotted = Color(0xFFC9D1EE);

  // 지식 그래프의 날짜 노드 색 (임시값)
  static const Color nodeDate = Color(0xFFB9C1E4);
  // 지식 그래프의 고유명사(개체) 노드 색 (임시값)
  static const Color nodeEntity = Color(0xFFE6A1C8);
  // 지식 그래프의 이벤트 노드 색 (임시값)
  static const Color nodeEvent = Color(0xFFA98BF0);
}
