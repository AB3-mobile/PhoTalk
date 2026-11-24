// 대화방 분위기 한 건 (period: 월별은 "2026-08", 연별은 "2026")
class ChatroomMood {
  const ChatroomMood({required this.period, required this.description, this.score});

  final String period;
  final String description;
  final double? score;

  // 서버 mood.monthly[] / mood.yearly[] 한 항목에서 만든다
  factory ChatroomMood.fromJson(Map<String, dynamic> json) => ChatroomMood(
        period: (json['period'] ?? '').toString(),
        description: (json['mood_description'] ?? '').toString(),
        score: (json['mood_score'] as num?)?.toDouble(),
      );
}

// 기간 안의 월별·연별 분위기 모음
class ChatroomMoods {
  const ChatroomMoods({this.monthly = const [], this.yearly = const []});

  final List<ChatroomMood> monthly;
  final List<ChatroomMood> yearly;

  factory ChatroomMoods.fromJson(Map<String, dynamic> json) => ChatroomMoods(
        monthly: (json['monthly'] as List? ?? []).map((e) => ChatroomMood.fromJson(e as Map<String, dynamic>)).toList(),
        yearly: (json['yearly'] as List? ?? []).map((e) => ChatroomMood.fromJson(e as Map<String, dynamic>)).toList(),
      );

  // 화면에 한 줄로 보여 줄 분위기: 끝 연도의 연별 → 가장 늦은 연별 → 가장 늦은 월별 순으로 고른다 (없으면 null)
  ChatroomMood? representative(DateTime end) {
    final withText = yearly.where((m) => m.description.isNotEmpty).toList();
    for (final m in withText) {
      if (m.period == '${end.year}') return m;
    }
    if (withText.isNotEmpty) return withText.last;
    final months = monthly.where((m) => m.description.isNotEmpty).toList();
    return months.isEmpty ? null : months.last;
  }

  // 대화가 있었던 가장 늦은 달 ("2026-08", 없으면 null) — 최근 대화순 정렬에 쓴다
  String? get lastMonth => monthly.isEmpty ? null : monthly.map((m) => m.period).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
}
