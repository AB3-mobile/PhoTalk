import '../models/chat_block.dart';
import '../models/chatroom_mood.dart';
import '../models/daily_count.dart';
import '../models/date_range_info.dart';

// 멤버 화면용 기간·분위기·날짜별 통계·하루 대화 조회
abstract class PeopleRepository {
  // 인덱싱된 모든 대화방을 통틀어 가장 이른/늦은 대화 날짜
  Future<DateRangeInfo> getDateRange();

  // 대화방의 기간 안 월별·연별 분위기
  Future<ChatroomMoods> getMoods(String chatroomId, {required DateTime start, required DateTime end});

  // 한 사람이 한 달(month는 "2022-05") 동안 날짜별로 보낸 메시지 수 (날짜 오름차순)
  Future<List<DailyCount>> getDailyCounts(String chatroomId, String participantId, String month);

  // 대화방의 하루(date는 "2022-05-19") 치 원문 대화 (시간 오름차순)
  Future<List<ChatMessage>> getDayMessages(String chatroomId, String date);
}
