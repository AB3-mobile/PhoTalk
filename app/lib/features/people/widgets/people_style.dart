import 'package:flutter/material.dart';

// 멤버 화면에서만 쓰는 색 (Figma 값 확인 전 임시값)
class PeopleStyle {
  PeopleStyle._();

  // 카드·알약의 연한 테두리
  static const Color border = Color(0xFFE3E8F8);
  // 연한 파랑 알약·버튼 배경
  static const Color tint = Color(0xFFDDE3FB);
  // 건수 알약의 연한 배경
  static const Color pill = Color(0xFFEEF0FB);
  // 방 분위기 알약 배경
  static const Color moodBg = Color(0xFFEBEEFD);
  // 분위기 하트 색
  static const Color heart = Color(0xFFF0709A);
  // 선택되지 않은 막대 색
  static const Color barLight = Color(0xFFC5CEF3);
  // 슬라이더 비활성 줄과 차트 점선 색
  static const Color track = Color(0xFFDDE3F8);
  // 드롭다운이 열릴 때 화면을 덮는 어두운 막
  static const Color scrim = Color(0x331E2A4A);
  // 아래에서 올라오는 시트 뒤의 어두운 막
  static const Color sheetScrim = Color(0x991E2A4A);
}
