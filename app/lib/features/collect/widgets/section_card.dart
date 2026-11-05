import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import 'status_badge.dart';

// TALK/PHOTO 같은 흰 카드 틀 (작은 라벨, 제목, 상태 배지, 내용 영역)
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.label,
    required this.title,
    required this.icon,
    required this.badgeText,
    required this.badgeDone,
    required this.child,
  });

  final String label;
  final String title;
  final IconData icon;
  final String badgeText;
  final bool badgeDone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0F2E4BAD), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.tileBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: appText(9.5, weight: FontWeight.w700, color: AppColors.accent)),
                    const SizedBox(height: 2),
                    Text(title, style: appText(15, weight: FontWeight.w700)),
                  ],
                ),
              ),
              StatusBadge(label: badgeText, done: badgeDone),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
