import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import 'people_style.dart';

// "이름순 ⌄" 같은 정렬 선택 알약 (누르면 정렬 목록을 연다)
class SortPill extends StatelessWidget {
  const SortPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: PeopleStyle.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 10, 0),
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: appText(15, weight: FontWeight.w700)),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 26, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 정렬 기준 목록 패널 (고른 항목은 파란 알약으로 강조한다)
class SortPanel<T> extends StatelessWidget {
  const SortPanel({super.key, required this.items, required this.selected, required this.onSelected, this.width = 210});

  final List<(String, T)> items;
  final T selected;
  final ValueChanged<T> onSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: PeopleStyle.border)),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, value) in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: value == selected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelected(value),
                      child: Container(
                        height: 48,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          label,
                          style: appText(
                            16,
                            weight: value == selected ? FontWeight.w700 : FontWeight.w500,
                            color: value == selected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
