import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import '../collect_data.dart';
import 'dashed_box.dart';
import 'section_card.dart';

// TALK 카드: 가져온 대화방 목록과 '+ 대화방 추가' 버튼을 보여준다
class ChatSection extends StatelessWidget {
  const ChatSection({
    super.key,
    required this.chats,
    required this.onAdd,
    this.progressText,
    this.dragging = false,
  });

  final List<PickedChat> chats;
  final VoidCallback onAdd;
  // 업로드·인덱싱 중일 때 보여줄 문구 (없으면 '+ 대화방 추가' 버튼을 보여준다)
  final String? progressText;
  // 파일을 끌어서 카드 위에 올려 둔 상태인지 (true면 강조 표시)
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      label: 'TALK',
      title: '대화',
      icon: Icons.chat_bubble_outline_rounded,
      badgeText: chats.isEmpty ? '아직 없음' : '${chats.length}개 가져옴',
      badgeDone: chats.isNotEmpty,
      child: Column(
        children: [
          for (final chat in chats) ...[
            _ChatRow(chat: chat),
            const SizedBox(height: 8),
          ],
          DashedBox(
            height: 44,
            onTap: progressText == null ? onAdd : null,
            fillColor: dragging ? AppColors.pickAreaBg : null,
            borderColor: dragging ? AppColors.accent : AppColors.dashed,
            child: progressText == null
                ? Text(dragging ? '여기에 놓아 주세요' : '+ 대화방 추가', style: appText(13, weight: FontWeight.w700, color: AppColors.accent))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(progressText!, style: appText(12, color: AppColors.textSecondary)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// 가져온 대화방 한 줄 (이름, 참여자 수, 메시지 수, 화살표)
class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat});

  final PickedChat chat;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.rowBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chat.displayName, style: appText(13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '참여자 ${chat.preview.participants.length}명 · 메시지 ${formatCount(chat.preview.messageCount)}개',
                  style: appText(11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.chevron),
        ],
      ),
    );
  }
}
