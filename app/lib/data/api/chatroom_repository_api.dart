import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../domain/models/chat_preview.dart';
import '../../domain/models/chatroom.dart';
import '../../domain/models/graph_build_status.dart';
import '../../domain/models/person.dart';
import '../../domain/models/upload_status.dart';
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

  // 서버 /message-upload 에 대화 텍스트를 보내 jobId를 받는다
  @override
  Future<String> uploadMessenger(
      {required String content, String? filename, String? roomName}) async {
    final json = await _post('/message-upload', {
      'content': content,
      'room_name': roomName ?? '', // 비우면 서버가 대화 내용·파일명으로 방 이름을 추측한다
      'filename': filename ?? '',
    });
    return json['jobId'] as String;
  }

  // 서버 /message-upload-status/<jobId> 로 진행 상태를 읽는다
  @override
  Future<UploadStatus> getUploadStatus(String jobId) async {
    final res = await http.get(Uri.parse('$apiBaseUrl/message-upload-status/$jobId'));
    return UploadStatus.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  // 서버 /message-preview 로 대화 파일을 보내 미리보기를 받는다
  @override
  Future<ChatPreview> previewMessenger({
    required String content,
    required String fileName,
    required int sizeBytes,
  }) async {
    final json = await _post('/message-preview', {
      'content': content,
      'filename': fileName,
    });
    return ChatPreview.fromJson(
      json['data'] as Map<String, dynamic>,
      fileName: fileName,
      sizeBytes: sizeBytes,
      content: content,
    );
  }

  // 서버 /indexing-history(최근 작업 목록)에서 jobId에 맞는 작업의 진행률을 찾는다
  @override
  Future<GraphBuildStatus> getGraphBuildStatus(String jobId) async {
    final res = await http.get(Uri.parse('$apiBaseUrl/indexing-history'));
    if (res.statusCode != 200) throw Exception('진행률 조회 실패 (${res.statusCode})');
    final list = (jsonDecode(utf8.decode(res.bodyBytes)) as List).cast<Map<String, dynamic>>();
    final job = list.where((e) => e['job_id'] == jobId).firstOrNull;
    if (job == null) return const GraphBuildStatus(status: 'unknown', progress: 0, message: '');
    return GraphBuildStatus.fromJson(job);
  }
}
