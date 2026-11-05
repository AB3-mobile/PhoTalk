// 메신저 업로드(파싱·인덱싱) 작업의 진행 상태
class UploadStatus {
  final String status; // running / done / error 등 서버가 주는 값
  final String message;
  final String? error;
  // 업로드가 끝난 뒤 서버가 시작한 그래프 구축 작업의 ID (진행률 조회에 쓴다)
  final String? graphJobId;
  // 서버가 정한 대화방 ID (그래프·관계 조회에 쓴다)
  final String? roomId;

  const UploadStatus({
    required this.status,
    required this.message,
    this.error,
    this.graphJobId,
    this.roomId,
  });

  bool get isDone => status == 'done';
  bool get isError => status == 'error' || status == 'not_found';

  factory UploadStatus.fromJson(Map<String, dynamic> json) => UploadStatus(
        status: json['status'] as String? ?? '',
        message: json['message'] as String? ?? '',
        error: json['error'] as String?,
        graphJobId: (json['result'] is Map) ? (json['result'] as Map)['job_id'] as String? : null,
        roomId: (json['result'] is Map) ? (json['result'] as Map)['room_id'] as String? : null,
      );
}
