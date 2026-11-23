import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import '../../../domain/models/chatroom.dart';
import '../../../domain/models/chatroom_mood.dart';
import '../../../domain/repositories/people_repository.dart';
import '../people_format.dart';
import 'people_style.dart';
import 'sort_widgets.dart';

enum _RoomSort { mood, name, recent }

const _roomSortItems = <(String, _RoomSort)>[
  ('방 분위기순', _RoomSort.mood),
  ('이름순', _RoomSort.name),
  ('최근 대화순', _RoomSort.recent),
];

// 아래에서 올라오는 채팅방 선택 시트를 열고, 고른 대화방 id를 돌려준다 (닫으면 null)
Future<String?> showRoomSheet(
  BuildContext context, {
  required List<Chatroom> rooms,
  required String? selectedId,
  required DateTime first,
  required DateTime last,
}) {
  final h = MediaQuery.of(context).size.height;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    barrierColor: PeopleStyle.sheetScrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    constraints: BoxConstraints(minHeight: h * 0.8, maxHeight: h * 0.8),
    builder: (_) => _RoomSheet(rooms: rooms, selectedId: selectedId, first: first, last: last),
  );
}

class _RoomSheet extends StatefulWidget {
  const _RoomSheet({required this.rooms, required this.selectedId, required this.first, required this.last});

  final List<Chatroom> rooms;
  final String? selectedId;
  final DateTime first;
  final DateTime last;

  @override
  State<_RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends State<_RoomSheet> {
  final Map<String, ChatroomMoods> _moods = {};
  _RoomSort _sort = _RoomSort.mood;
  bool _sortOpen = false;
  double _panelTop = 70;
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _pillKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadMoods();
  }

  // 방마다 분위기를 불러온다 (실패한 방은 분위기 없이 보여 준다)
  Future<void> _loadMoods() async {
    final repo = context.read<PeopleRepository>();
    await Future.wait(widget.rooms.map((r) async {
      try {
        final m = await repo.getMoods(r.id, start: widget.first, end: widget.last);
        if (mounted) setState(() => _moods[r.id] = m);
      } catch (_) {}
    }));
  }

  ChatroomMood? _moodOf(Chatroom r) => _moods[r.id]?.representative(widget.last);

  List<Chatroom> get _sorted {
    final list = [...widget.rooms];
    switch (_sort) {
      case _RoomSort.mood:
        list.sort((a, b) {
          final sa = _moodOf(a)?.score;
          final sb = _moodOf(b)?.score;
          if (sa == null && sb == null) return 0;
          if (sa == null) return 1;
          if (sb == null) return -1;
          return sb.compareTo(sa);
        });
      case _RoomSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _RoomSort.recent:
        list.sort((a, b) => (_moods[b.id]?.lastMonth ?? '').compareTo(_moods[a.id]?.lastMonth ?? ''));
    }
    return list;
  }

  void _toggleSort() {
    if (_sortOpen) {
      setState(() => _sortOpen = false);
      return;
    }
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final pillBox = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox != null && pillBox != null) {
      _panelTop = pillBox.localToGlobal(Offset(0, pillBox.size.height + 6), ancestor: stackBox).dy;
    }
    setState(() => _sortOpen = true);
  }

  String get _sortLabel => _roomSortItems.firstWhere((e) => e.$2 == _sort).$1;

  @override
  Widget build(BuildContext context) {
    final rooms = _sorted;
    return Stack(
      key: _stackKey,
      children: [
        Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 60,
              height: 5,
              decoration: BoxDecoration(color: PeopleStyle.tint, borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 14),
              child: Row(
                children: [
                  Expanded(child: Text('채팅방 선택', style: appText(22, weight: FontWeight.w800))),
                  KeyedSubtree(
                    key: _pillKey,
                    child: SortPill(label: _sortLabel, onTap: _toggleSort),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewPadding.bottom),
                itemCount: rooms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _RoomCard(
                  room: rooms[i],
                  mood: _moodOf(rooms[i]),
                  selected: rooms[i].id == widget.selectedId,
                  onTap: () => Navigator.of(context).pop(rooms[i].id),
                ),
              ),
            ),
          ],
        ),
        if (_sortOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _sortOpen = false),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            right: 16,
            top: _panelTop,
            child: SortPanel<_RoomSort>(
              items: _roomSortItems,
              selected: _sort,
              onSelected: (v) => setState(() {
                _sort = v;
                _sortOpen = false;
              }),
            ),
          ),
        ],
      ],
    );
  }
}

// 대화방 한 줄 카드 (고른 방은 파란 테두리와 체크 표시)
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.mood, required this.selected, required this.onTap});

  final Chatroom room;
  final ChatroomMood? mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final desc = mood?.description ?? '';
    return Material(
      color: selected ? const Color(0xFFF2F5FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: selected ? AppColors.accent : PeopleStyle.border, width: selected ? 2 : 1),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : PeopleStyle.tint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.chat_bubble_rounded, size: 24, color: selected ? Colors.white : AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(17, weight: FontWeight.w800)),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded, size: 13, color: PeopleStyle.heart),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(13, weight: FontWeight.w500, color: AppColors.accent)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '멤버 ${room.participantCount}명 · 메시지 ${formatCount(room.messageCount)}',
                      style: appText(12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded, size: 28, color: AppColors.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
