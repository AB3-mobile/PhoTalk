import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import 'add_chat_screen.dart';
import 'collect_controller.dart';
import 'collect_data.dart';
import 'graph_building_screen.dart';
import 'photo_select_screen.dart';
import 'widgets/next_button.dart';
import 'widgets/sub_screen_scaffold.dart';

// 수집 확인 화면: 모은 데이터의 양을 한눈에 보고 그래프 만들기로 넘어간다
class ConfirmScreen extends StatelessWidget {
  const ConfirmScreen({super.key, required this.controller});

  final CollectController controller;

  // 대화방 '수정': 대화방 추가 화면을 현재 값으로 열어 파일·표시 이름을 고치거나 삭제하게 한다 (이미 서버에 올린 것은 막는다)
  Future<void> _editChat(BuildContext context, int index) async {
    if (index < controller.uploadedCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 서버에 올린 대화방은 수정할 수 없어요')),
      );
      return;
    }
    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(builder: (_) => AddChatScreen(existing: controller.pendingChats[index])),
    );
    if (result is PickedChat) {
      controller.replacePending(index, result);
    } else if (result == kDeleteChat) {
      controller.removePending(index);
      // 대화방이 하나도 없으면 확인할 게 없으니 데이터 수집 화면으로 돌아간다
      if (controller.pendingChats.isEmpty && context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final period = c.period;
        return SubScreenScaffold(
          title: '수집 확인',
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이 데이터로 그래프를 만들까요?', style: appText(17, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('내용을 확인하고 그래프 만들기를 눌러주세요', style: appText(12, color: AppColors.textSecondary)),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _StatCard(label: '대화방', value: '${c.pendingChats.length}', unit: '개')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: '메시지', value: formatCount(c.messageTotal), unit: '개')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _StatCard(label: '사진', value: '${c.photoCount}', unit: '장')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: '참여자', value: '${c.participantTotal}', unit: '명')),
                ]),
                const SizedBox(height: 16),
                _buildPeriod(period),
                const SizedBox(height: 16),
                _buildList(context),
              ],
            ),
          ),
          bottom: NextButton(
            label: '그래프 만들기',
            enabled: true,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GraphBuildingScreen(controller: controller)),
            ),
          ),
        );
      },
    );
  }

  // 기간 카드 (처음~마지막 날짜와 총 일수 배지)
  Widget _buildPeriod(DateTimeRange? period) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('기간', style: appText(11.5, weight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  period == null ? '-' : '${formatDate(period.start)} – ${formatDate(period.end)}',
                  style: appText(14, weight: FontWeight.w700),
                ),
              ),
              if (period != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.tileBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${period.end.difference(period.start).inDays + 1}일',
                    style: appText(10.5, weight: FontWeight.w700, color: AppColors.accent),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 대화방마다 한 줄, 사진 한 줄을 '수정' 버튼과 함께 보여 주는 목록 카드
  Widget _buildList(BuildContext context) {
    final c = controller;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          for (var i = 0; i < c.pendingChats.length; i++) ...[
            _ListRow(
              icon: Icons.chat_bubble_rounded,
              title: c.pendingChats[i].preview.fileName,
              sub: '${c.pendingChats[i].displayName} · 메시지 ${formatCount(c.pendingChats[i].preview.messageCount)}개',
              onEdit: () => _editChat(context, i),
            ),
            const Divider(height: 1, color: Color(0xFFE6EAF6)),
          ],
          _ListRow(
            icon: Icons.image_outlined,
            title: c.photoCount == 0 ? '사진 없음' : '사진 ${c.photoCount}장',
            sub: c.photoCount == 0 ? '사진 없이 대화만 분석해요' : '이름 입력 ${c.namedCount} / ${c.photoCount}장',
            editLabel: c.photoCount == 0 ? '추가' : '수정',
            onEdit: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PhotoSelectScreen(controller: controller)),
            ),
          ),
        ],
      ),
    );
  }
}

// 큰 숫자 한 개를 보여 주는 통계 카드 (이름표, 숫자, 단위)
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: appText(11.5, weight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(text: value, style: appText(26, weight: FontWeight.w700)),
            TextSpan(text: ' $unit', style: appText(12, weight: FontWeight.w700, color: AppColors.textSecondary)),
          ])),
        ],
      ),
    );
  }
}

// 목록 카드의 한 줄 (아이콘, 제목, 설명, 수정 버튼)
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onEdit,
    this.editLabel = '수정',
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onEdit;
  // 오른쪽 버튼 글자 (사진이 없으면 '추가')
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.tileBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: appText(11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Text(editLabel, style: appText(12, weight: FontWeight.w700, color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}
