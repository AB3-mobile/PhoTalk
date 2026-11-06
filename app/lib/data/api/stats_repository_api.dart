import '../../domain/models/keyword_count.dart';
import '../../domain/models/monthly_count.dart';
import '../../domain/repositories/stats_repository.dart';
import '../mock/stats_repository_mock.dart';
import 'api_post.dart';

// 서버(Flask)에서 인물별 키워드를 가져오는 StatsRepository (월별 메시지 수는 아직 Mock)
class StatsRepositoryApi implements StatsRepository {
  // 월별 메시지 수 API를 연결하기 전까지 대신 쓰는 Mock
  final StatsRepository _monthlyFallback = StatsRepositoryMock();

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

  // TODO: 서버의 월별 통계 API에 연결 (지금은 Mock 값을 돌려준다)
  @override
  Future<List<MonthlyCount>> getMonthlyMessageCounts(String chatroomId, String participantId) =>
      _monthlyFallback.getMonthlyMessageCounts(chatroomId, participantId);
}
