import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../domain/models/photo_match.dart';
import '../../domain/repositories/photo_repository.dart';

// 서버(Flask) /photo-upload, /photo-match 에 사진을 multipart로 올리는 PhotoRepository
class PhotoRepositoryApi implements PhotoRepository {
  // 사진 파일과 필드를 담은 multipart 요청을 만든다 (후보 이름은 JSON 배열 문자열 하나로 보낸다)
  http.MultipartRequest _request(String path, List<int> bytes, String fileName, List<String>? candidates) {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl$path'))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    if (candidates != null) req.fields['candidates'] = jsonEncode(candidates);
    return req;
  }

  // 요청을 보내고 JSON을 읽는다 (실패면 서버가 준 이유로 예외)
  Future<Map<String, dynamic>> _send(http.MultipartRequest req, String failMessage) async {
    final res = await http.Response.fromStream(await req.send());
    final json = jsonDecode(utf8.decode(res.bodyBytes)); // 한글 깨짐 방지
    if (res.statusCode != 200 || json['ok'] != true) {
      throw Exception('$failMessage: ${json['error'] ?? res.statusCode}');
    }
    return json as Map<String, dynamic>;
  }

  @override
  Future<int> uploadPhoto({
    required List<int> bytes,
    required String fileName,
    String? name,
    List<String>? candidates,
  }) async {
    final req = _request('/photo-upload', bytes, fileName, candidates);
    final n = name?.trim() ?? '';
    if (n.isNotEmpty) req.fields['name'] = n;
    final json = await _send(req, '사진 업로드 실패 ($fileName)');
    return json['face_count'] as int;
  }

  @override
  Future<PhotoMatch> matchPhoto({
    required List<int> bytes,
    required String fileName,
    List<String>? candidates,
  }) async {
    final json = await _send(_request('/photo-match', bytes, fileName, candidates), '얼굴 매칭 실패 ($fileName)');
    return PhotoMatch.fromJson(json);
  }

  @override
  Future<Uint8List?> getPersonFace(String name, {bool random = false}) async {
    final uri = Uri.parse('$apiBaseUrl/person-face').replace(queryParameters: {'name': name, if (random) 'random': '1'});
    final res = await http.get(uri);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw Exception('/person-face 요청 실패 (${res.statusCode})');
    return res.bodyBytes;
  }
}
