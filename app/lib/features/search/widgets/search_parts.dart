import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import '../../../domain/models/search_result.dart';
import '../recent_searches.dart';
import '../search_session.dart';
import 'evidence_sheet.dart';
import 'related_people.dart';

// 둥근 입력창과 오른쪽 파란 검색 버튼
class SearchInput extends StatelessWidget {
  const SearchInput({super.key, required this.controller, required this.onSubmit, this.autofocus = false, this.focused = true});

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool autofocus;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.accent, width: focused ? 1.5 : 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmit(),
              style: appText(14),
              decoration: InputDecoration(
                hintText: '자연어로 물어보세요',
                hintStyle: appText(14, color: AppColors.chevron),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          Material(
            color: AppColors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSubmit,
              child: const SizedBox(width: 38, height: 38, child: Icon(Icons.search_rounded, size: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// 최근 검색어 목록 (누르면 그 검색어로 검색, ✕는 하나 지우기, 전체 삭제)
class RecentList extends StatelessWidget {
  const RecentList({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final recent = context.watch<RecentSearches>();
    if (recent.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('최근 검색어', style: appText(13, weight: FontWeight.w700))),
            InkWell(
              onTap: recent.clear,
              child: Text('전체 삭제', style: appText(12, color: AppColors.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final q in recent.items)
          InkWell(
            onTap: () => onPick(q),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: AppColors.chevron),
                  const SizedBox(width: 12),
                  Expanded(child: Text(q, style: appText(14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  InkWell(
                    onTap: () => recent.remove(q),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 18, color: AppColors.disabled),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// 검색 상태(검색 중 / 결과 / 없음 / 오류)에 맞는 본문 (idle일 때는 아무것도 그리지 않는다)
class SearchBody extends StatelessWidget {
  const SearchBody({super.key, required this.session, this.onCancel, this.footer, this.showPeople = false});

  final SearchSession session;
  final VoidCallback? onCancel;
  // 결과 카드 아래에 붙일 위젯 (플로팅 패널의 '자세히 검색하기' 버튼)
  final Widget? footer;
  // 결과 아래에 근거 대화에 나온 '관련 인물'을 보여 줄지 (검색 페이지에서만 켠다)
  final bool showPeople;

  // 검색 중·결과 없음·오류는 패널 폭 가운데로, 결과 카드는 왼쪽 정렬 그대로 둔다
  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    return session.phase == SearchPhase.done ? content : Align(alignment: Alignment.topCenter, child: content);
  }

  // 검색 상태(검색 중 / 결과 / 없음 / 오류)에 맞는 본문을 만든다
  Widget _content(BuildContext context) {
    switch (session.phase) {
      case SearchPhase.idle:
        return const SizedBox.shrink();
      case SearchPhase.loading:
        return Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Column(
            children: [
              const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(height: 16),
              Text('대화를 찾는 중…', style: appText(14, color: AppColors.textSecondary)),
              if (onCancel != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: onCancel, child: Text('취소', style: appText(14, color: AppColors.accent))),
              ],
            ],
          ),
        );
      case SearchPhase.empty:
        return Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded, size: 40, color: AppColors.chevron),
              const SizedBox(height: 12),
              Text('관련 대화를 찾지 못했어요', style: appText(15, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('다른 표현으로 다시 물어봐 주세요', style: appText(13, color: AppColors.textSecondary)),
            ],
          ),
        );
      case SearchPhase.error:
        return Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Column(
            children: [
              Text('검색에 실패했어요', style: appText(15, weight: FontWeight.w700, color: AppColors.error)),
              const SizedBox(height: 6),
              Text(session.error ?? '', style: appText(12, color: AppColors.textSecondary), textAlign: TextAlign.center),
            ],
          ),
        );
      case SearchPhase.done:
        final result = session.result!;
        final items = result.items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('검색어', style: appText(12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(session.query, style: appText(15, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (items.isEmpty) _AnswerCard(item: SearchItem(title: result.answer, date: '', room: '', content: '')) else for (final it in items) _AnswerCard(item: it),
            if (showPeople)
              RelatedPeople(
                key: ValueKey(session.query),
                sources: [for (final it in items) if (it.source != null && it.source!.canOpen) it.source!],
              ),
            if (footer != null) ...[const SizedBox(height: 6), footer!],
          ],
        );
    }
  }
}

// 답변 한 건: 대화방 · 날짜, 요약, 내용, 근거 대화 보기
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.item});

  final SearchItem item;

  @override
  Widget build(BuildContext context) {
    final src = item.source;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.tileBg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.room.isNotEmpty || item.date.isNotEmpty)
            Row(
              children: [
                if (item.room.isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.tileBg, borderRadius: BorderRadius.circular(12)),
                      child: Text(item.room, style: appText(12, weight: FontWeight.w700, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                if (item.date.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(item.date, style: appText(12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          if (item.room.isNotEmpty || item.date.isNotEmpty) const SizedBox(height: 10),
          Text(item.title, style: appText(14, weight: FontWeight.w700)),
          if (item.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.content, style: appText(13, color: AppColors.textPrimary)),
          ],
          if (src != null && src.canOpen) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showEvidenceSheet(context, src),
                child: Text('근거 대화 보기', style: appText(13, weight: FontWeight.w700, color: AppColors.accent)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
