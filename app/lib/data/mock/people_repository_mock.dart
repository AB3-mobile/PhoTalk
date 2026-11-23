import '../../domain/models/chat_block.dart';
import '../../domain/models/chatroom_mood.dart';
import '../../domain/models/daily_count.dart';
import '../../domain/models/date_range_info.dart';
import '../../domain/repositories/people_repository.dart';
import 'mock_loader.dart';

// 서버 없이 더미 JSON(assets/mock/people_stats.json)으로 동작하는 PeopleRepository
class PeopleRepositoryMock implements PeopleRepository {
  @override
  Future<DateRangeInfo> getDateRange() async {
    final json = await loadMockJson('people_stats') as Map<String, dynamic>;
    return DateRangeInfo.fromJson(json['date_range'] as Map<String, dynamic>);
  }

  @override
  Future<ChatroomMoods> getMoods(String chatroomId, {required DateTime start, required DateTime end}) async {
    final json = await loadMockJson('people_stats') as Map<String, dynamic>;
    final room = (json['mood'] as Map<String, dynamic>)[chatroomId] as Map<String, dynamic>?;
    return room == null ? const ChatroomMoods() : ChatroomMoods.fromJson(room);
  }

  // 달마다 정해진 날 네 곳에 메시지 수를 나눠 돌려준다 (사람 이름으로 값이 조금씩 달라진다)
  @override
  Future<List<DailyCount>> getDailyCounts(String chatroomId, String participantId, String month) async {
    final seed = participantId.codeUnits.fold<int>(0, (a, b) => a + b) + month.codeUnits.fold<int>(0, (a, b) => a + b);
    const days = [3, 10, 19, 27];
    return [
      for (var i = 0; i < days.length; i++)
        DailyCount(date: '$month-${days[i].toString().padLeft(2, '0')}', count: 8 + (seed * (i + 3)) % 50),
    ];
  }

  @override
  Future<List<ChatMessage>> getDayMessages(String chatroomId, String date) async {
    final json = await loadMockJson('people_stats') as Map<String, dynamic>;
    return (json['day_messages'] as List).map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }
}
