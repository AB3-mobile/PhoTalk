import '../../domain/models/chatroom.dart';
import '../../domain/models/person.dart';
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
}
