// 근거가 된 대화 블록의 위치 (어느 대화방의 어떤 날짜 블록인지)
class SearchSource {
  final String? id;
  final String? account;

  const SearchSource({this.id, this.account});

  // 서버는 {id, account} 객체로 주지만 예전 더미 데이터는 ID 글자만 줘서 둘 다 받는다
  factory SearchSource.fromJson(dynamic json) {
    if (json is Map) return SearchSource(id: json['id'] as String?, account: json['account'] as String?);
    return SearchSource(id: json as String?);
  }

  // 원문을 불러올 수 있는지 (대화방과 블록 ID가 모두 있어야 한다)
  bool get canOpen => (id ?? '').isNotEmpty && (account ?? '').isNotEmpty;
}

// 답변 안의 항목 한 개 (메시지 요약, 날짜, 대화방, 내용)
class SearchItem {
  final String title;
  final String date;
  final String room;
  final String content;
  final SearchSource? source;

  const SearchItem({required this.title, required this.date, required this.room, required this.content, this.source});
}

// 자연어 검색 결과: 답변 + 근거가 된 대화 블록
class SearchResult {
  final String answer;
  final List<SearchSource> sources;

  const SearchResult({required this.answer, required this.sources});

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        answer: json['result'] as String? ?? '',
        sources: (json['source_ids'] as List? ?? []).map(SearchSource.fromJson).toList(),
      );

  // 답변이 비었거나, 근거 없이 서버가 "모르겠다"는 고정 문장을 준 경우는 찾은 대화가 없는 것으로 본다
  bool get isEmpty {
    final a = answer.trim().toLowerCase();
    if (a.isEmpty) return true;
    if (sources.isNotEmpty) return false;
    return a.contains('unable to answer') || a.contains('i do not know') || a.contains("i don't know") || a.startsWith('i am sorry');
  }

  // 서버 답변("1. 메시지: …/날짜/채팅방/내용" 번호 항목)을 항목 목록으로 나눈다 (형식이 다르면 빈 목록)
  List<SearchItem> get items {
    final blocks = <List<MapEntry<String, String>>>[];
    for (final raw in answer.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final head = RegExp(r'^\d+\.\s*([^:]+):\s*(.*)$').firstMatch(line);
      if (head != null) {
        blocks.add([MapEntry(head.group(1)!.trim(), head.group(2)!.trim())]);
        continue;
      }
      if (blocks.isEmpty) continue;
      final field = RegExp(r'^([^:]{1,10}):\s*(.*)$').firstMatch(line);
      if (field != null) {
        blocks.last.add(MapEntry(field.group(1)!.trim(), field.group(2)!.trim()));
      } else {
        // 앞 필드의 이어지는 줄은 그 값 뒤에 붙인다
        final last = blocks.last.removeLast();
        blocks.last.add(MapEntry(last.key, '${last.value}\n$line'));
      }
    }
    String pick(List<MapEntry<String, String>> f, String key) =>
        f.firstWhere((e) => e.key == key, orElse: () => const MapEntry('', '')).value;
    final out = <SearchItem>[];
    for (var i = 0; i < blocks.length; i++) {
      final f = blocks[i];
      // 항목 순서와 근거 순서가 같다고 보고 같은 번호끼리 묶는다
      final src = sources.length == blocks.length ? sources[i] : null;
      final other = f.where((e) => e.key != '날짜' && e.key != '내용').toList();
      out.add(SearchItem(
        title: f.first.value,
        date: pick(f, '날짜'),
        room: other.length > 1 ? other[1].value : '',
        content: pick(f, '내용'),
        source: src,
      ));
    }
    return out;
  }
}
