// 인덱싱된 대화 전체에서 가장 이른 날짜와 가장 늦은 날짜 (데이터가 없으면 둘 다 null)
class DateRangeInfo {
  const DateRangeInfo({this.first, this.last});

  final DateTime? first;
  final DateTime? last;

  factory DateRangeInfo.fromJson(Map<String, dynamic> json) => DateRangeInfo(
        first: DateTime.tryParse((json['first_date'] ?? '').toString()),
        last: DateTime.tryParse((json['last_date'] ?? '').toString()),
      );
}
