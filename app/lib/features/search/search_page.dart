import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/repositories/chatroom_repository.dart';
import '../../domain/repositories/search_repository.dart';
import '../collect/widgets/circle_icon_button.dart';
import '../menu/app_menu_drawer.dart';
import 'recent_searches.dart';
import 'search_session.dart';
import 'widgets/search_parts.dart';

// 메뉴의 '검색' 화면 (플로팅 패널의 '자세히 검색하기'로도 들어오며, 그때는 검색어가 채워져 있다)
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery);
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

  @override
  Widget build(BuildContext context) {
    final idle = _session.phase == SearchPhase.idle;
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppMenuDrawer(current: AppMenuItem.search),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => CircleIconButton(
                      icon: Icons.menu_rounded,
                      iconColor: AppColors.textPrimary,
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text('검색', style: appText(22, weight: FontWeight.w700))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: SearchInput(controller: _controller, onSubmit: _submit, focused: idle),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  if (idle)
                    RecentList(onPick: _submit)
                  else
                    SearchBody(session: _session, onCancel: _session.cancel, showPeople: true),
                ],
              ),
            ),
            if (idle)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent, shape: const StadiumBorder()),
                    onPressed: _submit,
                    child: Text('검색', style: appText(15, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
