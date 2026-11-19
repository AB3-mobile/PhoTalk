import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_text.dart';
import '../../../domain/models/search_result.dart';
import '../../../domain/repositories/photo_repository.dart';
import '../../../domain/repositories/search_repository.dart';
import '../../collect/widgets/person_avatar.dart';

// 검색 결과의 근거 대화에 나온 사람들을 얼굴 사진(없으면 기본 아바타)과 이름으로 보여 준다
class RelatedPeople extends StatefulWidget {
  const RelatedPeople({super.key, required this.sources});

  final List<SearchSource> sources;

  @override
  State<RelatedPeople> createState() => _RelatedPeopleState();
}

class _RelatedPeopleState extends State<RelatedPeople> {
  List<String> _names = [];
  final Map<String, Uint8List> _faces = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 근거 대화들을 불러 발화자 이름을 모으고, 이름마다 얼굴 사진을 받아 온다 (실패한 건 건너뛴다)
  Future<void> _load() async {
    final search = context.read<SearchRepository>();
    final photo = context.read<PhotoRepository>();
    final names = <String>[];
    await Future.wait(widget.sources.map((s) async {
      try {
        final b = await search.getChatBlock(s.account!, s.id!);
        for (final m in b.messages) {
          final n = (m.sender ?? '').trim();
          if (!m.isSystem && n.isNotEmpty && !names.contains(n)) names.add(n);
        }
      } catch (_) {}
    }));
    if (!mounted || names.isEmpty) return;
    setState(() => _names = names.take(12).toList());
    await Future.wait(_names.map((name) async {
      try {
        final bytes = await photo.getPersonFace(name, random: true);
        if (bytes != null && mounted) setState(() => _faces[name] = bytes);
      } catch (_) {}
    }));
  }

  @override
  Widget build(BuildContext context) {
    if (_names.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('관련 인물', style: appText(13, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            for (var i = 0; i < _names.length; i++)
              SizedBox(
                width: 56,
                child: Column(
                  children: [
                    _faces[_names[i]] == null
                        ? PersonAvatar(index: i, size: 48)
                        : ClipOval(child: Image.memory(_faces[_names[i]]!, width: 48, height: 48, fit: BoxFit.cover, gaplessPlayback: true)),
                    const SizedBox(height: 4),
                    Text(_names[i], style: appText(12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
