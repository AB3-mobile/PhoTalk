import 'package:flutter/material.dart';

import '../../../core/api_config.dart';
import '../../collect/widgets/person_avatar.dart';

// 사람 얼굴 사진(서버가 준 주소)을 동그랗게 보여 주고, 없거나 못 불러오면 기본 아바타를 보여 준다
class PersonPhoto extends StatelessWidget {
  const PersonPhoto({super.key, required this.name, this.avatarUrl, this.size = 48});

  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    // 이름이 같으면 항상 같은 색이 나오게 이름 글자로 색을 고른다
    final fallback = PersonAvatar(index: name.codeUnits.fold<int>(0, (a, b) => a + b), size: size);
    final url = avatarUrl;
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
