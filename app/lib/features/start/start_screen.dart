import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../collect/collect_screen.dart';
import 'widgets/network_illustration.dart';
import 'widgets/start_background.dart';

// 앱을 처음 열면 보이는 시작 화면 (로고 일러스트, 앱 이름, '시작하기' 버튼)
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  // '시작하기'를 누르면 다음 화면으로 넘어간다 (다음 화면이 정해지기 전까지는 참여자 목록으로 임시 연결)
  void _onStart(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CollectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StartBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // 화면이 작아도 넘치지 않도록 너비와 높이에 맞춰 일러스트 크기를 정한다
              final side = math.min(
                math.min(box.maxWidth * 0.86, 320.0),
                box.maxHeight * 0.45,
              );
              return Column(
                children: [
                  const Spacer(flex: 3),
                  NetworkIllustration(side: side),
                  const Spacer(flex: 2),
                  Text(
                    'PhoTalk',
                    style: GoogleFonts.oswald(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _StartButton(onPressed: () => _onStart(context)),
                  const Spacer(flex: 2),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// 흰색 알약 모양의 '시작하기' 버튼 (오른쪽에 파란 화살표 원이 붙어 있다)
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black45,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '시작하기',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 10),
              CircleAvatar(
                radius: 11,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.arrow_forward, size: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
