// 대화 한 줄
class ChatMessage {
  final String time;
  final String? sender;
  final String text;
  final bool isSystem;

  const ChatMessage({
    required this.time,
    this.sender,
    required this.text,
    required this.isSystem,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        time: json['time'] as String? ?? '',
        sender: json['sender'] as String?,
        text: json['text'] as String? ?? '',
        isSystem: json['is_system'] as bool? ?? false,
      );
}

// 하루치 대화 묶음 (검색 결과의 근거 원문)
class ChatBlock {
  final String id;
  final String roomName;
  final String date;
  final List<ChatMessage> messages;

  const ChatBlock({
    required this.id,
    required this.roomName,
    required this.date,
    required this.messages,
  });

  factory ChatBlock.fromJson(Map<String, dynamic> json) => ChatBlock(
        id: json['id'] as String,
        roomName: json['room_name'] as String? ?? '',
        date: json['date'] as String? ?? '',
        messages: (json['messages'] as List? ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
