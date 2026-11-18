import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/models/chatroom.dart';
import '../../domain/models/person.dart';
import '../../domain/repositories/chatroom_repository.dart';
import '../collect/collect_data.dart';
import '../collect/widgets/next_button.dart';
import '../collect/widgets/person_avatar.dart';
import '../collect/widgets/sub_screen_scaffold.dart';

// 사진을 넣을 대화방을 고르고 그 방의 인물을 확인하는 화면 (다음을 누르면 그 인물들을 돌려준다)
class RoomSelectScreen extends StatefulWidget {
  const RoomSelectScreen({super.key});

  @override
  State<RoomSelectScreen> createState() => _RoomSelectScreenState();
}

class _RoomSelectScreenState extends State<RoomSelectScreen> {
  // 인덱싱이 끝난 대화방들 (불러오는 중이면 null)
  List<Chatroom>? _rooms;
  // 고른 대화방 id와 그 방의 인물 (불러오는 중이면 null)
  String? _roomId;
  List<Person>? _people;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  // 서버에서 인덱싱된 대화방 목록을 읽는다
  Future<void> _loadRooms() async {
    setState(() => _failed = false);
    try {
      final all = await context.read<ChatroomRepository>().getChatrooms();
      if (!mounted) return;
      setState(() => _rooms = all.where((r) => r.indexed).toList());
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  // 대화방을 고르고 그 방의 인물을 읽는다 (다른 방으로 빠르게 바꾸면 늦게 온 응답은 버린다)
  Future<void> _pick(String id) async {
    setState(() {
      _roomId = id;
      _people = null;
    });
    try {
      final people = await context.read<ChatroomRepository>().getPeople(id);
      if (mounted && _roomId == id) setState(() => _people = people);
    } catch (_) {
      if (mounted && _roomId == id) setState(() => _people = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _rooms;
    return SubScreenScaffold(
      title: '대화방 선택',
      body: _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('대화방을 불러오지 못했어요', style: appText(13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _loadRooms, child: const Text('다시 시도')),
                ],
              ),
            )
          : rooms == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    if (rooms.isEmpty) Text('인덱싱된 대화방이 없어요', style: appText(13, color: AppColors.textSecondary)),
                    for (final r in rooms) _roomTile(r),
                    if (_roomId != null) ...[
                      const SizedBox(height: 18),
                      Text('대화 참여자', style: appText(13, weight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _peopleList(),
                    ],
                  ],
                ),
      bottom: NextButton(
        label: '다음 · 사진 선택',
        enabled: _people != null && _people!.isNotEmpty,
        onPressed: () => Navigator.pop(context, _people),
      ),
    );
  }

  // 대화방 한 줄 (고른 방은 파란 테두리)
  Widget _roomTile(Chatroom r) {
    final on = r.id == _roomId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _pick(r.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? AppColors.accent : Colors.transparent, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: appText(15, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('참여자 ${r.participantCount}명 · 메시지 ${formatCount(r.messageCount)}개', style: appText(11.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (on) const Icon(Icons.check_circle_rounded, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 고른 방의 인물 목록
  Widget _peopleList() {
    final people = _people;
    if (people == null) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    if (people.isEmpty) return Text('참여자를 불러오지 못했어요', style: appText(12, color: AppColors.textSecondary));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          for (var i = 0; i < people.length; i++)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  PersonAvatar(index: i, size: 24),
                  const SizedBox(width: 10),
                  Text(people[i].name, style: appText(13, weight: FontWeight.w700)),
                  const Spacer(),
                  Text('메시지 ${formatCount(people[i].messageCount)}개', style: appText(10.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
