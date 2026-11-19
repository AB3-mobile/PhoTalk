import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import '../../../domain/models/chat_block.dart';
import '../../../domain/models/search_result.dart';
import '../../../domain/repositories/photo_repository.dart';
import '../../../domain/repositories/search_repository.dart';
import '../../collect/widgets/person_avatar.dart';

// 검색 결과의 근거가 된 그날의 대화를 아래에서 올라오는 시트로 보여 준다
Future<void> showEvidenceSheet(BuildContext context, SearchSource source) {
  final future = context.read<SearchRepository>().getChatBlock(source.account!, source.id!);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _EvidenceSheet(future: future),
  );
}

// 근거 대화 시트 본문: 제목, 대화방 · 날짜, 말풍선 목록
class _EvidenceSheet extends StatelessWidget {
  const _EvidenceSheet({required this.future});

  final Future<ChatBlock> future;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.disabled, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('근거 대화', style: appText(18, weight: FontWeight.w700))),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: AppColors.chevron)),
              ],
            ),
            Expanded(
              child: FutureBuilder<ChatBlock>(
                future: future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return Center(child: Text('대화를 불러오지 못했어요', style: appText(13, color: AppColors.error)));
                  return _EvidenceMessages(block: snap.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 근거 대화의 말풍선 목록: 말하는 사람마다 얼굴 사진(없으면 기본 아바타)을 옆에 붙인다
class _EvidenceMessages extends StatefulWidget {
  const _EvidenceMessages({required this.block});

  final ChatBlock block;

  @override
  State<_EvidenceMessages> createState() => _EvidenceMessagesState();
}

class _EvidenceMessagesState extends State<_EvidenceMessages> {
  final Map<String, Uint8List> _faces = {};
  late final List<String> _names;

  @override
  void initState() {
    super.initState();
    _names = [
      for (final m in widget.block.messages)
        if (!m.isSystem && (m.sender ?? '').trim().isNotEmpty) m.sender!.trim(),
    ].toSet().toList();
    _loadFaces();
  }

  // 이름마다 얼굴 사진을 받아 둔다 (없거나 실패하면 기본 아바타로 남는다)
  Future<void> _loadFaces() async {
    final repo = context.read<PhotoRepository>();
    await Future.wait(_names.map((name) async {
      try {
        final bytes = await repo.getPersonFace(name, random: true);
        if (bytes != null && mounted) setState(() => _faces[name] = bytes);
      } catch (_) {}
    }));
  }

  // 이름의 얼굴 사진이 있으면 원형 사진, 없으면 기본 아바타
  Widget _avatar(String name) {
    final bytes = _faces[name];
    if (bytes == null) return PersonAvatar(index: _names.indexOf(name), size: 32);
    return ClipOval(child: Image.memory(bytes, width: 32, height: 32, fit: BoxFit.cover, gaplessPlayback: true));
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final msgs = b.messages.where((m) => !m.isSystem).toList();
    return ListView(
      children: [
        Text('${b.roomName} · ${b.date}', style: appText(12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        for (final m in msgs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar((m.sender ?? '').trim()),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m.sender ?? ''}  ${m.time}', style: appText(11, color: AppColors.textSecondary)),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(color: AppColors.rowBg, borderRadius: BorderRadius.circular(14)),
                        child: Text(m.text, style: appText(13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
