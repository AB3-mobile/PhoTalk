// 한 달(또는 한 해)의 대화 요약에 나오는 주요 연락처 한 명
class HistoryContact {
  const HistoryContact({required this.name, this.description, this.shortBio});

  final String name;
  final String? description;
  final String? shortBio;

  // 서버 summaries[].contacts[] 한 항목에서 만든다
  factory HistoryContact.fromJson(Map<String, dynamic> json) => HistoryContact(
        name: (json['person_name'] ?? '').toString(),
        description: json['description'] as String?,
        shortBio: json['short_bio'] as String?,
      );
}

// 한 달(또는 한 해)의 대화 요약과 그 기간의 주요 연락처
class HistorySummary {
  const HistorySummary({required this.period, required this.text, required this.contacts});

  // 기간 글자 (월별은 2026-08, 연별은 2026)
  final String period;
  final String text;
  final List<HistoryContact> contacts;

  // 서버 summaries[] 한 항목에서 만든다
  factory HistorySummary.fromJson(Map<String, dynamic> json) => HistorySummary(
        period: (json['summary_period'] ?? '').toString(),
        text: (json['summarized_context'] ?? '').toString(),
        contacts: (json['contacts'] as List? ?? []).map((e) => HistoryContact.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
