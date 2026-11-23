// 하루의 메시지 수 (date: "2022-05-19")
class DailyCount {
  const DailyCount({required this.date, required this.count});

  final String date;
  final int count;

  factory DailyCount.fromJson(Map<String, dynamic> json) => DailyCount(
        date: (json['date'] ?? '').toString(),
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}
