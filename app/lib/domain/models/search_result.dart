// 자연어 검색 결과: 답변 + 근거가 된 대화 블록 ID
class SearchResult {
  final String answer;
  final List<String> sourceIds;

  const SearchResult({required this.answer, required this.sourceIds});

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        answer: json['result'] as String? ?? '',
        sourceIds: (json['source_ids'] as List? ?? []).cast<String>(),
      );
}
