import 'package:flutter/material.dart';

// 사람 모양 아이콘이 들어간 둥근 아바타 (번호에 따라 파랑/청록/보라 색을 돌려 쓴다)
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.index, this.size = 44});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    const palettes = [
      [Color(0xFFC7D2FA), Color(0xFF9CAEF0)],
      [Color(0xFFBDE6DC), Color(0xFF8CC7B8)],
      [Color(0xFFD9CCF5), Color(0xFFB4A0EA)],
    ];
    final colors = palettes[index % palettes.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(Icons.person_rounded, size: size * 0.55, color: Colors.white),
    );
  }
}
