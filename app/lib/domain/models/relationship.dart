// 참여자 두 명 사이의 관계 (이름 기준)
class Relationship {
  final String source;
  final String target;
  final String relationLabel;
  final String? description;

  const Relationship({
    required this.source,
    required this.target,
    required this.relationLabel,
    this.description,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) => Relationship(
        source: json['source'] as String,
        target: json['target'] as String,
        relationLabel: json['relation_label'] as String,
        description: json['description'] as String?,
      );
}
