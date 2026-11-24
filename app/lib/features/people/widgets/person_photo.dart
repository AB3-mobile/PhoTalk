import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_config.dart';
import '../../../domain/repositories/photo_repository.dart';
import '../../collect/widgets/person_avatar.dart';

// 사람 사진을 동그랗게 보여 준다
// 1) 서버에 저장된 이 사람의 실제 얼굴 사진 (히스토리 화면과 같은 방식)
// 2) 없으면 서버가 만들어 준 아바타 그림 (avatarUrl)
// 3) 그것도 없으면 이름으로 색을 고른 기본 아바타
class PersonPhoto extends StatefulWidget {
  const PersonPhoto({super.key, required this.name, this.avatarUrl, this.size = 48});

  final String name;
  final String? avatarUrl;
  final double size;

  // 이미 요청 중인 얼굴 (같은 이름을 동시에 여러 번 요청하지 않게, 요청이 끝나면 비운다)
  static final Map<String, Future<Uint8List?>> _pending = {};
  // 저장된 얼굴이 없다고 답받은 시각 (30초 동안은 다시 묻지 않는다)
  static final Map<String, DateTime> _missing = {};

  @override
  State<PersonPhoto> createState() => _PersonPhotoState();
}

class _PersonPhotoState extends State<PersonPhoto> {
  Uint8List? _face;

  @override
  void initState() {
    super.initState();
    _loadFace();
  }

  @override
  void didUpdateWidget(covariant PersonPhoto old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) {
      _face = null;
      _loadFace();
    }
  }

  // 서버에 저장된 얼굴이 있으면 받아 온다 (없거나 실패하면 기본 아바타로 남는다)
  Future<void> _loadFace() async {
    final name = widget.name;
    final missedAt = PersonPhoto._missing[name];
    if (missedAt != null && DateTime.now().difference(missedAt) < const Duration(seconds: 30)) return;
    final repo = context.read<PhotoRepository>();
    final future = PersonPhoto._pending.putIfAbsent(name, () async {
      try {
        return await repo.getPersonFace(name, random: true);
      } catch (_) {
        return null;
      }
    });
    final bytes = await future;
    PersonPhoto._pending.remove(name);
    if (bytes == null) {
      PersonPhoto._missing[name] = DateTime.now();
      return;
    }
    // 저장해 두지 않으므로 화면을 새로 열 때마다 저장된 얼굴 중 아무거나 새로 뽑힌다
    if (mounted && widget.name == name) setState(() => _face = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // 이름이 같으면 항상 같은 색이 나오게 이름 글자로 색을 고른다
    final fallback = PersonAvatar(index: widget.name.codeUnits.fold<int>(0, (a, b) => a + b), size: size);
    // 1순위: 저장된 실제 얼굴 사진
    final face = _face;
    if (face != null) {
      return ClipOval(child: Image.memory(face, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true));
    }
    // 2순위: 서버가 만들어 준 아바타 그림, 3순위: 기본 아바타
    final url = widget.avatarUrl;
    if (url == null || url.isEmpty) return fallback;
    final full = url.startsWith('http') ? url : '$apiBaseUrl$url';
    return ClipOval(
      child: Image.network(
        full,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
      ),
    );
  }
}
