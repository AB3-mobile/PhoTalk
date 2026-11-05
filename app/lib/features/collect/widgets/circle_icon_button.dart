import 'package:flutter/material.dart';

// 흰 원 안에 아이콘이 들어간 둥근 버튼 (메뉴·검색 버튼에 쓴다)
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.iconColor,
    this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 22, color: iconColor),
        ),
      ),
    );
  }
}
