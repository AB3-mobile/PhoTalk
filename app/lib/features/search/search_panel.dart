import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/repositories/chatroom_repository.dart';
import '../../domain/repositories/search_repository.dart';
import 'recent_searches.dart';
import 'search_page.dart';
import 'search_session.dart';
import 'widgets/search_parts.dart';

// 모든 화면 오른쪽 위 검색 아이콘을 누르면 아래에서 올라오는 '대화 검색' 패널을 연다
Future<void> openSearchPanel(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _SearchPanel(),
  );
}

// 플로팅 검색 패널: 입력창과 최근 검색어, 검색 중·답변·결과 없음 상태, 자세히 검색하기 버튼
class _SearchPanel extends StatefulWidget {
  const _SearchPanel();

  @override
  State<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<_SearchPanel> {
  final _controller = TextEditingController();
  late final SearchSession _session;

  @override
  void initState() {
    super.initState();
    _session = SearchSession(context.read<SearchRepository>(), context.read<ChatroomRepository>())..addListener(_refresh);
  }

  @override
  void dispose() {
    _session.dispose();
    _controller.dispose();
    super.dispose();
  }

  // 검색 상태가 바뀌면 화면을 다시 그린다
  void _refresh() {
    if (mounted) setState(() {});
  }

  // 입력한 글을 검색하고 최근 검색어에 남긴다
  void _submit([String? text]) {
    final q = (text ?? _controller.text).trim();
    if (q.isEmpty) return;
    _controller.text = q;
    context.read<RecentSearches>().add(q);
    FocusScope.of(context).unfocus();
    _session.run(q);
  }

  // 패널을 닫고 같은 검색어를 채운 검색 페이지로 넘어간다
  void _openPage() {
    final q = _controller.text;
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => SearchPage(initialQuery: q)));
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: (MediaQuery.of(context).size.height * 0.82).clamp(0.0, MediaQuery.of(context).size.height - inset - 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.disabled, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Text('대화 검색', style: appText(18, weight: FontWeight.w700))),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: AppColors.chevron)),
                ],
              ),
              const SizedBox(height: 8),
              SearchInput(controller: _controller, onSubmit: _submit, autofocus: true),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: _session.phase == SearchPhase.idle
                      ? RecentList(onPick: _submit)
                      : SearchBody(
                          session: _session,
                          footer: _session.phase == SearchPhase.done ? _moreButton() : null,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 같은 질문을 검색 페이지에서 더 자세히 보는 버튼
  Widget _moreButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.accent, shape: const StadiumBorder()),
        onPressed: _openPage,
        icon: const Icon(Icons.search_rounded, size: 18),
        label: Text('자세히 검색하기', style: appText(14, weight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}
