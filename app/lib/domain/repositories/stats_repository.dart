import '../models/keyword_count.dart';
import '../models/monthly_count.dart';

// 키워드·메시지 수 통계 조회
abstract class StatsRepository {
  Future<List<KeywordCount>> getKeywordsByPerson(
    String chatroomId,
    String participantId, {
    required DateTime start,
    required DateTime end,
  });

  Future<List<MonthlyCount>> getMonthlyMessageCounts(
    String chatroomId,
    String participantId,
  );
}
