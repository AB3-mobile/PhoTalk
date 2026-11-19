// 어떤 날 어떤 키워드를 언급한 사람과 그 횟수
class KeywordMentioner {
  const KeywordMentioner({required this.name, required this.count});

  final String name;
  final int count;

  // 서버 /chatroom-keyword-mentioners 의 data[] 한 항목에서 만든다
  factory KeywordMentioner.fromJson(Map<String, dynamic> json) => KeywordMentioner(
        name: (json['name'] ?? json['participant_id'] ?? '').toString(),
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}
