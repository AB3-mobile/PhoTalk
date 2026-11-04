// 대화방 한 개의 요약 정보
class Chatroom {
  final String id;
  final String name;
  final int messageCount;
  final int participantCount;
  final List<String> topParticipants;
  final bool indexed;

  const Chatroom({
    required this.id,
    required this.name,
    required this.messageCount,
    required this.participantCount,
    required this.topParticipants,
    required this.indexed,
  });

  factory Chatroom.fromJson(Map<String, dynamic> json) => Chatroom(
        id: json['chatroom_id'] as String,
        name: json['chatroom_name'] as String,
        messageCount: json['message_count'] as int? ?? 0,
        participantCount: json['participant_count'] as int? ?? 0,
        topParticipants:
            (json['top_participants'] as List? ?? []).cast<String>(),
        indexed: json['indexed'] as bool? ?? false,
      );
}
