import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../domain/repositories/photo_repository.dart';

// 서버(Flask) /photo-upload 에 사진을 multipart로 올리는 PhotoRepository
class PhotoRepositoryApi implements PhotoRepository {
  @override
  Future<int> uploadPhoto({
    required List<int> bytes,
    required String fileName,
    String? name,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/photo-upload'))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final n = name?.trim() ?? '';
    if (n.isNotEmpty) req.fields['name'] = n;

    final res = await http.Response.fromStream(await req.send());
    final json = jsonDecode(utf8.decode(res.bodyBytes)); // 한글 깨짐 방지
    if (res.statusCode != 200 || json['ok'] != true) {
      throw Exception('사진 업로드 실패 ($fileName): ${json['error'] ?? res.statusCode}');
    }
    return json['face_count'] as int;
  }

  @override
  Future<Uint8List?> getPersonFace(String name) async {
    final uri = Uri.parse('$apiBaseUrl/person-face').replace(queryParameters: {'name': name});
    final res = await http.get(uri);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw Exception('/person-face 요청 실패 (${res.statusCode})');
    return res.bodyBytes;
  }
}
