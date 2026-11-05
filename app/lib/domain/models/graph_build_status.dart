// 서버가 돌리는 그래프 구축(인덱싱) 작업의 진행 상태
class GraphBuildStatus {
  final String status; // queued / running / done / failed 등 서버가 주는 값
  final int progress; // 0 ~ 100
  final String message;

  const GraphBuildStatus({required this.status, required this.progress, required this.message});

  bool get isDone => status == 'done' || progress >= 100;
  bool get isFailed => status == 'failed' || status == 'error';

  // 서버 작업 목록의 한 항목에서 상태를 만든다
  factory GraphBuildStatus.fromJson(Map<String, dynamic> json) => GraphBuildStatus(
        status: json['type'] as String? ?? json['status'] as String? ?? '',
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        message: json['message'] as String? ?? '',
      );
}
