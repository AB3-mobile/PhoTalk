// 대화방 참여자 한 명
class Person {
  final String participantId;
  final String name;
  final int messageCount;
  final String? description;
  final String? shortBio;
  final String? avatarUrl;

  const Person({
    required this.participantId,
    required this.name,
    required this.messageCount,
    this.description,
    this.shortBio,
    this.avatarUrl,
  });

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        participantId: json['participant_id'] as String,
        name: json['name'] as String,
        messageCount: json['message_count'] as int? ?? 0,
        description: json['description'] as String?,
        shortBio: json['short_bio'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );
}
