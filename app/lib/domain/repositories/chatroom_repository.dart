import '../models/chatroom.dart';
import '../models/person.dart';

// 대화방·참여자 조회
abstract class ChatroomRepository {
  Future<List<Chatroom>> getChatrooms();

  Future<List<Person>> getPeople(String chatroomId);

  // 기간 안의 메시지 수가 들어간 참여자 정보 (participantId를 주면 한 명만)
  Future<List<Person>> getPersonDetail(
    String chatroomId, {
    required DateTime start,
    required DateTime end,
    String? participantId,
  });
}
