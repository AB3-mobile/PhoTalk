// 월별 메시지 수 (month: "2024-03")
class MonthlyCount {
  final String month;
  final int count;

  const MonthlyCount({required this.month, required this.count});

  factory MonthlyCount.fromJson(Map<String, dynamic> json) => MonthlyCount(
        month: json['month'] as String,
        count: json['count'] as int? ?? 0,
      );
}
