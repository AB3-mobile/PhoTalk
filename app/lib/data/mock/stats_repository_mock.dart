import '../../domain/models/keyword_count.dart';
import '../../domain/models/monthly_count.dart';
import '../../domain/repositories/stats_repository.dart';
import 'mock_loader.dart';

// 서버 없이 더미 JSON으로 동작하는 StatsRepository
class StatsRepositoryMock implements StatsRepository {
  @override
  Future<List<KeywordCount>> getKeywordsByPerson(
    String chatroomId,
    String participantId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final json = await loadMockJson('keywords') as Map<String, dynamic>;
    final room = json[chatroomId] as Map<String, dynamic>? ?? {};
    final list = room[participantId] as List? ?? [];
    return list
        .map((e) => KeywordCount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<MonthlyCount>> getMonthlyMessageCounts(
    String chatroomId,
    String participantId,
  ) async {
    final json = await loadMockJson('monthly_counts') as Map<String, dynamic>;
    final room = json[chatroomId] as Map<String, dynamic>? ?? {};
    final list = room[participantId] as List? ?? [];
    return list
        .map((e) => MonthlyCount.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
