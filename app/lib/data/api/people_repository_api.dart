import '../../domain/models/chat_block.dart';
import '../../domain/models/chatroom_mood.dart';
import '../../domain/models/daily_count.dart';
import '../../domain/models/date_range_info.dart';
import '../../domain/repositories/people_repository.dart';
import 'api_post.dart';

// 서버(Flask)의 /messenger-date-range, /chatroom-mood, /chatroom-person-daily-stats, /chatroom-day-messages 에서 가져오는 PeopleRepository
class PeopleRepositoryApi implements PeopleRepository {
  @override
  Future<DateRangeInfo> getDateRange() async {
    final json = await apiPost('/messenger-date-range', {});
    return DateRangeInfo.fromJson((json['data'] as Map<String, dynamic>?) ?? {});
  }

  @override
  Future<ChatroomMoods> getMoods(String chatroomId, {required DateTime start, required DateTime end}) async {
    final json = await apiPost('/chatroom-mood', {
      'chatroom_id': chatroomId,
      'start_date': apiDate(start),
      'end_date': apiDate(end),
    });
    return ChatroomMoods.fromJson((json['data'] as Map<String, dynamic>?) ?? {});
  }

  @override
  Future<List<DailyCount>> getDailyCounts(String chatroomId, String participantId, String month) async {
    final json = await apiPost('/chatroom-person-daily-stats', {
      'chatroom_id': chatroomId,
      'participant_id': participantId,
      'month': month,
    });
    return (json['data']['days'] as List? ?? []).map((e) => DailyCount.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<ChatMessage>> getDayMessages(String chatroomId, String date) async {
    final json = await apiPost('/chatroom-day-messages', {'chatroom_id': chatroomId, 'date': date});
    return (json['data']['messages'] as List? ?? []).map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }
}
