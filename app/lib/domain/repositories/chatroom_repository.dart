import '../models/chat_preview.dart';
import '../models/chatroom.dart';
import '../models/graph_build_status.dart';
import '../models/person.dart';
import '../models/upload_status.dart';

// 대화방·참여자 조회
abstract class ChatroomRepository {
  Future<List<Chatroom>> getChatrooms();

  Future<List<Person>> getPeople(String chatroomId);

  // 기간 안의 메시지 수가 들어간 참여자 정보 (participantId를 주면 한 명만)
  Future<List<Person>> getPersonDetail(
    String chatroomId, {
    required DateTime start,
    required DateTime end,
    String? participantId,
  });

  // 카카오톡 대화 내보내기 텍스트를 서버에 올리고 작업 ID(jobId)를 돌려준다
  Future<String> uploadMessenger(
      {required String content, String? filename, String? roomName});

  // 업로드 작업의 진행 상태를 조회한다
  Future<UploadStatus> getUploadStatus(String jobId);

  // 업로드 전에 서버가 대화 파일을 읽어 참여자·기간·메시지 수 미리보기를 돌려준다
  Future<ChatPreview> previewMessenger({
    required String content,
    required String fileName,
    required int sizeBytes,
  });

  // 그래프 구축 작업(jobId)의 진행률과 상태를 조회한다
  Future<GraphBuildStatus> getGraphBuildStatus(String jobId);
}
