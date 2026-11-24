import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import '../../../domain/models/chat_block.dart';
import '../../../domain/repositories/people_repository.dart';
import '../people_format.dart';
import 'people_style.dart';
import 'person_photo.dart';

// 처음에 미리 보여 줄 대화 줄 수 (넘으면 "이 날 대화 전체 보기" 버튼이 나온다)
const int _previewCount = 6;

// 어느 하루("2022-05-19")의 원문 대화를 아래에서 올라오는 시트로 보여 준다
// personName이 보낸 말은 오른쪽 파란 말풍선, 나머지는 왼쪽 회색 말풍선
Future<void> showDayChatSheet(
  BuildContext context, {
  required String roomId,
  required String roomName,
  required String personName,
  required String date,
  required Map<String, String?> avatars,
}) {
  final h = MediaQuery.of(context).size.height;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    barrierColor: PeopleStyle.sheetScrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    constraints: BoxConstraints(minHeight: h * 0.78, maxHeight: h * 0.78),
    builder: (_) => _DayChatSheet(roomId: roomId, roomName: roomName, personName: personName, date: date, avatars: avatars),
  );
}

class _DayChatSheet extends StatefulWidget {
  const _DayChatSheet({
    required this.roomId,
    required this.roomName,
    required this.personName,
    required this.date,
    required this.avatars,
  });

  final String roomId;
  final String roomName;
  final String personName;
  final String date;
  final Map<String, String?> avatars;

  @override
  State<_DayChatSheet> createState() => _DayChatSheetState();
}

class _DayChatSheetState extends State<_DayChatSheet> {
  List<ChatMessage>? _messages;
  bool _failed = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<PeopleRepository>();
    try {
      final list = await repo.getDayMessages(widget.roomId, widget.date);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  // "2022-05-19" → "2022년 5월 19일"
  String get _title {
    final p = widget.date.split('-');
    if (p.length != 3) return widget.date;
    return '${p[0]}년 ${int.tryParse(p[1]) ?? p[1]}월 ${int.tryParse(p[2]) ?? p[2]}일';
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    final canExpand = messages != null && !_expanded && messages.length > _previewCount;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 60,
            height: 5,
            decoration: BoxDecoration(color: PeopleStyle.tint, borderRadius: BorderRadius.circular(3)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title, style: appText(22, weight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${widget.roomName} · 원문 대화', style: appText(13, color: AppColors.chevron)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 28, color: AppColors.chevron),
                ),
              ],
            ),
          ),
          Expanded(child: _body(messages)),
          if (canExpand)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Material(
                color: PeopleStyle.tint,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => setState(() => _expanded = true),
                  child: SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: Center(child: Text('이 날 대화 전체 보기', style: appText(17, weight: FontWeight.w800, color: AppColors.accent))),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(List<ChatMessage>? messages) {
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('대화를 불러오지 못했어요', style: appText(13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() => _failed = false);
                _load();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (messages == null) return const Center(child: CircularProgressIndicator());
    if (messages.isEmpty) {
      return Center(child: Text('이 날의 대화가 없어요', style: appText(13, color: AppColors.textSecondary)));
    }
    final shown = _expanded ? messages : messages.take(_previewCount).toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      itemCount: shown.length,
      itemBuilder: (_, i) => _line(shown, i),
    );
  }

  // 대화 한 줄 (시스템 알림 / 내가 고른 사람이 보낸 말 / 다른 사람이 보낸 말)
  Widget _line(List<ChatMessage> list, int i) {
    final m = list[i];
    if (m.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(child: Text(m.text, textAlign: TextAlign.center, style: appText(12, color: AppColors.chevron))),
      );
    }
    final time = Text(formatClock(m.time), style: appText(11, color: AppColors.chevron));
    final mine = m.sender == widget.personName;
    if (mine) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            time,
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(22)),
                child: Text(m.text, style: appText(15, color: Colors.white).copyWith(height: 1.4)),
              ),
            ),
          ],
        ),
      );
    }
    final sender = m.sender ?? '';
    final showHeader = i == 0 || list[i - 1].isSystem || list[i - 1].sender != m.sender;
    return Padding(
      padding: EdgeInsets.only(top: showHeader ? 12 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: showHeader ? PersonPhoto(name: sender, avatarUrl: widget.avatars[sender], size: 32) : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader) ...[
                  Text(sender, style: appText(12.5, weight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFFEFF2FC), borderRadius: BorderRadius.circular(22)),
                        child: Text(m.text, style: appText(15).copyWith(height: 1.4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    time,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
