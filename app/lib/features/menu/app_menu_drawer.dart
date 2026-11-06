import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../collect/collect_screen.dart';
import '../graph/knowledge_graph_screen.dart';

// 서비스 이름 아래에 표시할 팀 이름 (실제 팀 이름으로 바꿔 쓴다)
const String kTeamName = '고모프';

// 왼쪽 메뉴에 들어가는 화면 목록
enum AppMenuItem { collect, build, graph, member, history, search }

// 메뉴 항목의 이름과 아이콘을 돌려준다
(String, IconData) _info(AppMenuItem i) {
  switch (i) {
    case AppMenuItem.collect:
      return ('데이터 수집', Icons.storage_outlined);
    case AppMenuItem.build:
      return ('그래프 구축', Icons.share_outlined);
    case AppMenuItem.graph:
      return ('지식 그래프 보기', Icons.show_chart_rounded);
    case AppMenuItem.member:
      return ('멤버', Icons.person_outline_rounded);
    case AppMenuItem.history:
      return ('히스토리', Icons.schedule_rounded);
    case AppMenuItem.search:
      return ('검색', Icons.search_rounded);
  }
}

// 왼쪽에서 열리는 공통 메뉴: 서비스 이름, 닫기 버튼, 이동 항목(현재 화면은 파란색 강조)
class AppMenuDrawer extends StatelessWidget {
  const AppMenuDrawer({super.key, required this.current});

  // 지금 보고 있는 화면 (이 항목이 파랗게 강조된다)
  final AppMenuItem current;

  // 항목을 누르면 메뉴를 닫고 해당 화면으로 이동한다 (아직 없는 화면은 안내만 띄운다)
  void _go(BuildContext context, AppMenuItem item) {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    nav.pop();
    if (item == current) return;
    Widget? page;
    if (item == AppMenuItem.collect) page = const CollectScreen();
    if (item == AppMenuItem.graph) page = const KnowledgeGraphScreen();
    if (page == null) {
      messenger.showSnackBar(SnackBar(content: Text('${_info(item).$1} 화면은 다음 단계에서 연결해요')));
      return;
    }
    // 시작 화면만 남기고 나머지 화면을 걷어 낸 뒤 새 화면을 연다
    final target = page;
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => target), (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 290,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 서비스 이름과 팀, 오른쪽 닫기 버튼
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    child: Text('P', style: appText(16, weight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PhoTalk', style: appText(17, weight: FontWeight.w700)),
                        Text(kTeamName, style: appText(11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.chevron),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              for (final item in AppMenuItem.values) _tile(context, item),
            ],
          ),
        ),
      ),
    );
  }

  // 메뉴 한 줄 (현재 화면이면 파란 배경에 흰 글자)
  Widget _tile(BuildContext context, AppMenuItem item) {
    final (label, icon) = _info(item);
    final on = item == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: on ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _go(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: on ? Colors.white : AppColors.chevron),
                const SizedBox(width: 14),
                Text(label, style: appText(15, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? Colors.white : AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
