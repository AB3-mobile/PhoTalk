// 업로드 전에 서버가 대화 파일을 읽어 돌려준 미리보기 (참여자·기간·메시지 수)
class ChatPreview {
  const ChatPreview({
    required this.fileName,
    required this.sizeBytes,
    required this.content,
    required this.suggestedName,
    required this.participantCounts,
    required this.start,
    required this.end,
    required this.messageCount,
  });

  final String fileName;
  final int sizeBytes;
  final String content;
  // 서버가 추측한 대화방 이름 (앱에 표시할 이름의 기본값)
  final String suggestedName;
  // 참여자 이름별 메시지 수
  final Map<String, int> participantCounts;
  final DateTime? start;
  final DateTime? end;
  final int messageCount;

  // 서버 /message-preview 응답과 파일 정보로 미리보기를 만든다
  factory ChatPreview.fromJson(
    Map<String, dynamic> json, {
    required String fileName,
    required int sizeBytes,
    required String content,
  }) {
    final people = (json['participants'] as List? ?? []).cast<Map<String, dynamic>>();
    return ChatPreview(
      fileName: fileName,
      sizeBytes: sizeBytes,
      content: content,
      suggestedName: json['room_name'] as String? ?? fileName,
      participantCounts: {
        for (final p in people) p['name'] as String: p['message_count'] as int? ?? 0,
      },
      start: _date(json['start_date']),
      end: _date(json['end_date']),
      messageCount: json['message_count'] as int? ?? 0,
    );
  }

  // 메시지를 한 개 이상 읽었으면 성공
  bool get ok => messageCount > 0 && start != null && end != null;

  // 메시지를 많이 보낸 순서의 참여자 이름 목록
  List<String> get participants {
    final names = participantCounts.keys.toList();
    names.sort((a, b) => participantCounts[b]!.compareTo(participantCounts[a]!));
    return names;
  }

  // 기간의 총 일수 (첫 날과 마지막 날 포함)
  int get days => (start == null || end == null) ? 0 : end!.difference(start!).inDays + 1;

  // "2026-03-01" 글자를 날짜로 바꾼다 (없으면 null)
  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);
}
