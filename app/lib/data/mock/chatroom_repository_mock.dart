import '../../domain/models/chat_preview.dart';
import '../../domain/models/chatroom.dart';
import '../../domain/models/graph_build_status.dart';
import '../../domain/models/person.dart';
import '../../domain/models/upload_status.dart';
import '../../domain/repositories/chatroom_repository.dart';
import 'mock_loader.dart';

// 서버 없이 더미 JSON으로 동작하는 ChatroomRepository
class ChatroomRepositoryMock implements ChatroomRepository {
  @override
  Future<List<Chatroom>> getChatrooms() async {
    final json = await loadMockJson('chatrooms') as Map<String, dynamic>;
    final rooms = json['data']['chatrooms'] as List;
    return rooms
        .map((e) => Chatroom.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Person>> getPeople(String chatroomId) async {
    final json = await loadMockJson('people') as Map<String, dynamic>;
    final people = json[chatroomId] as List? ?? [];
    return people
        .map((e) => Person.fromJson(e as Map<String, dynamic>))
        .toList();
  }

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

  // 서버 없이 업로드가 바로 끝난 것처럼 흉내 낸다
  @override
  Future<String> uploadMessenger(
          {required String content, String? filename, String? roomName}) async =>
      'mock';

  @override
  Future<UploadStatus> getUploadStatus(String jobId) async =>
      const UploadStatus(status: 'done', message: '완료');

  // 서버 없이 고정된 샘플 미리보기를 돌려준다
  @override
  Future<ChatPreview> previewMessenger({
    required String content,
    required String fileName,
    required int sizeBytes,
  }) async {
    return ChatPreview(
      fileName: fileName,
      sizeBytes: sizeBytes,
      content: content,
      suggestedName: '스터디 모임',
      participantCounts: {'지민': 400, '서연': 300, '민수': 200, '하은': 150, '도윤': 134, '유진': 100},
      start: DateTime(2026, 9, 7),
      end: DateTime(2026, 9, 30),
      messageCount: 1284,
    );
  }

  int _tick = 0;

  // 서버 없이 호출할 때마다 진행률이 오르는 것처럼 흉내 낸다
  @override
  Future<GraphBuildStatus> getGraphBuildStatus(String jobId) async {
    _tick++;
    final p = (_tick * 12).clamp(0, 100);
    return GraphBuildStatus(status: p >= 100 ? 'done' : 'running', progress: p, message: '진행 중');
  }
}
