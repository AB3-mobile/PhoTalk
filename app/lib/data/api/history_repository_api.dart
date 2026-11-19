import '../../domain/models/history_summary.dart';
import '../../domain/models/keyword_count.dart';
import '../../domain/models/keyword_mentioner.dart';
import '../../domain/repositories/history_repository.dart';
import 'api_post.dart';

// 서버의 /chatroom-summaries, /chatroom-keyword-monthly-stats 에서 히스토리 데이터를 가져오는 HistoryRepository
class HistoryRepositoryApi implements HistoryRepository {
  @override
  Future<List<HistorySummary>> getMonthlySummaries(String chatroomId) async {
    final json = await apiPost('/chatroom-summaries', {'chatroom_id': chatroomId, 'summarize_unit': 'monthly'});
    return (json['data']['summaries'] as List).map((e) => HistorySummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Map<String, List<KeywordCount>>> getMonthlyKeywords(String chatroomId) async {
    final json = await apiPost('/chatroom-keyword-monthly-stats', {'chatroom_id': chatroomId});
    final data = (json['data'] as Map<String, dynamic>?) ?? {};
    return {
      for (final e in data.entries) e.key: (e.value as List).map((k) => KeywordCount.fromJson(k as Map<String, dynamic>)).toList(),
    };
  }

  @override
  Future<Map<String, List<KeywordCount>>> getDailyKeywords(String chatroomId, String month) async {
    final json = await apiPost('/chatroom-keyword-daily-stats', {'chatroom_id': chatroomId, 'month': month});
    final data = (json['data'] as Map<String, dynamic>?) ?? {};
    return {
      for (final e in data.entries) e.key: (e.value as List).map((k) => KeywordCount.fromJson(k as Map<String, dynamic>)).toList(),
    };
  }

  @override
  Future<List<KeywordMentioner>> getKeywordMentioners(String chatroomId, String date, String keyword) async {
    final json = await apiPost('/chatroom-keyword-mentioners', {'chatroom_id': chatroomId, 'date': date, 'keyword': keyword});
    return (json['data'] as List).map((e) => KeywordMentioner.fromJson(e as Map<String, dynamic>)).toList();
  }
}
