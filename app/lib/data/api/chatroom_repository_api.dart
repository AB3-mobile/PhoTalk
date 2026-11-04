import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../domain/models/chatroom.dart';
import '../../domain/models/person.dart';
import '../../domain/repositories/chatroom_repository.dart';

// 서버(Flask)에서 대화방·참여자를 가져오는 ChatroomRepository
class ChatroomRepositoryApi implements ChatroomRepository {
  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('$path 요청 실패 (${res.statusCode})');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)); // 한글 깨짐 방지
  }

  @override
  Future<List<Chatroom>> getChatrooms() async {
    final json = await _post('/messenger-chatrooms', {});
    return (json['data']['chatrooms'] as List)
        .map((e) => Chatroom.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Person>> getPeople(String chatroomId) async {
    final json = await _post('/chatroom-people', {'chatroom_id': chatroomId});
    return (json['data']['people'] as List)
        .map((e) => Person.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // TODO: 서버의 /chatroom-person-detail 에 연결 (지금은 getPeople 결과로 대신한다)
  @override
  Future<List<Person>> getPersonDetail(
    String chatroomId, {
    required DateTime start,
    required DateTime end,
    String? participantId,
  }) async {
    final people = await getPeople(chatroomId);
    if (participantId == null) return people;
    return people.where((p) => p.participantId == participantId).toList();
  }
}
