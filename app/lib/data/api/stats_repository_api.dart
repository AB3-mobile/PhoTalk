import '../../domain/models/keyword_count.dart';
import '../../domain/models/monthly_count.dart';
import '../../domain/repositories/stats_repository.dart';
import 'api_post.dart';

// 서버(Flask)에서 인물별 키워드와 월별 메시지 수를 가져오는 StatsRepository
class StatsRepositoryApi implements StatsRepository {
  @override
  Future<List<KeywordCount>> getKeywordsByPerson(
    String chatroomId,
    String participantId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final json = await apiPost('/chatroom-keywords-by-person', {
      'chatroom_id': chatroomId,
      'participant_id': participantId,
      'start_date': apiDate(start),
      'end_date': apiDate(end),
    });
    return (json['data']['keywords'] as List).map((e) => KeywordCount.fromJson(e as Map<String, dynamic>)).toList();
  }

  // 서버 /chatroom-person-monthly-stats 에서 한 사람의 월별 메시지 수를 가져온다 (전체 기간, 월 오름차순)
  @override
  Future<List<MonthlyCount>> getMonthlyMessageCounts(String chatroomId, String participantId) async {
    final json = await apiPost('/chatroom-person-monthly-stats', {
      'chatroom_id': chatroomId,
      'participant_id': participantId,
    });
    return (json['data']['monthly'] as List? ?? []).map((e) => MonthlyCount.fromJson(e as Map<String, dynamic>)).toList();
  }
}
