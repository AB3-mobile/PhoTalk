import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/platform_drop_target.dart';
import '../../core/app_text.dart';
import 'add_chat_screen.dart';
import 'collect_controller.dart';
import 'collect_data.dart';
import 'confirm_screen.dart';
import 'photo_select_screen.dart';
import 'widgets/chat_section.dart';
import 'widgets/circle_icon_button.dart';
import 'widgets/next_button.dart';
import 'widgets/photo_section.dart';

// 데이터 수집 화면: 대화방과 사진을 모으고 수집 확인 화면으로 넘어가는 첫 작업 화면
class CollectScreen extends StatefulWidget {
  const CollectScreen({super.key});

  @override
  State<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends State<CollectScreen> {
  // 수집 화면들이 함께 쓰는 상태
  final CollectController _c = CollectController();
  // 파일을 끌어서 화면 위에 올려 둔 상태인지
  bool _dragging = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // 알림 문구를 화면 아래에 잠깐 보여준다
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // '+ 대화방 추가': 대화방 추가 화면에서 확정한 대화방을 목록에 넣는다 (서버 업로드는 그래프 만들기 때 한다)
  Future<void> _addChat({DroppedFile? dropped}) async {
    final picked = await Navigator.push<PickedChat>(
      context,
      MaterialPageRoute(builder: (_) => AddChatScreen(initial: dropped)),
    );
    if (picked != null) _c.addPending(picked);
  }

  // 화면에 .txt 파일을 끌어다 놓으면 그 파일로 대화방 추가 화면을 연다
  Future<void> _onDrop(List<dynamic> files) async {
    setState(() => _dragging = false);
    if (files.isEmpty) return;
    final f = files.first;
    final name = f.name as String;
    if (!name.toLowerCase().endsWith('.txt')) {
      _toast('.txt 대화 파일만 놓을 수 있어요');
      return;
    }
    await _addChat(dropped: DroppedFile(name: name, bytes: await f.readAsBytes()));
  }

  // '사진 선택하기'/'+ 사진 추가': 사진 선택 화면을 연다
  void _pickPhotos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoSelectScreen(controller: _c)),
    );
  }

  // '다음': 수집 확인 화면으로 간다
  void _goConfirm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ConfirmScreen(controller: _c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        // 사진은 선택 사항이라 대화방만 있어도 다음 단계로 넘어갈 수 있다
        final canNext = _c.pendingChats.isNotEmpty;
        return PlatformDropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (d) => _onDrop(d.files),
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Header(),
                          const SizedBox(height: 22),
                          Text('데이터 수집', style: appText(22, weight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('대화와 사진을 가져와 주세요', style: appText(12.5, color: AppColors.textSecondary)),
                          const SizedBox(height: 20),
                          ChatSection(chats: _c.pendingChats, onAdd: _addChat, dragging: _dragging),
                          const SizedBox(height: 14),
                          PhotoSection(
                            photoCount: _c.photoCount,
                            namedCount: _c.namedCount,
                            photoIds: _c.selectedPhotos,
                            onPick: _pickPhotos,
                            // 대화방이 없으면 이름 자동완성에 쓸 참여자가 없어 사진 선택을 막는다
                            enabled: _c.pendingChats.isNotEmpty,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Column(
                      children: [
                        Text(
                          canNext ? '준비됐어요. 사진은 없어도 괜찮아요' : '대화방을 추가하면 다음으로 넘어갈 수 있어요',
                          style: appText(11.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        NextButton(enabled: canNext, onPressed: _goConfirm),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// 화면 맨 위 줄: 왼쪽 메뉴 버튼과 오른쪽 검색 버튼
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CircleIconButton(icon: Icons.menu_rounded, iconColor: AppColors.textPrimary),
        CircleIconButton(icon: Icons.search_rounded, iconColor: AppColors.accent),
      ],
    );
  }
}
