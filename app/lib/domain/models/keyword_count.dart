// 키워드와 언급 횟수
class KeywordCount {
  final String word;
  final int count;

  const KeywordCount({required this.word, required this.count});

  factory KeywordCount.fromJson(Map<String, dynamic> json) => KeywordCount(
        word: json['word'] as String,
        count: json['count'] as int? ?? 0,
      );
}
