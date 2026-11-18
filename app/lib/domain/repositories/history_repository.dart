import '../models/history_summary.dart';
import '../models/keyword_count.dart';
import '../models/keyword_mentioner.dart';

// 히스토리 화면용 월별 요약·키워드 조회
abstract class HistoryRepository {
  // 대화방의 월별 요약 (기간 오름차순)
  Future<List<HistorySummary>> getMonthlySummaries(String chatroomId);

  // 대화방 전체의 월별 키워드 순위 ("2026-08" → 언급 많은 순 키워드)
  Future<Map<String, List<KeywordCount>>> getMonthlyKeywords(String chatroomId);

  // 한 달의 날짜별 키워드 언급 횟수 ("2026-08-11" → 그날 언급된 키워드들, month는 "2026-08")
  Future<Map<String, List<KeywordCount>>> getDailyKeywords(String chatroomId, String month);

  // 어느 날("2026-08-11") 그 키워드를 언급한 사람과 횟수 (많은 순)
  Future<List<KeywordMentioner>> getKeywordMentioners(String chatroomId, String date, String keyword);
}
