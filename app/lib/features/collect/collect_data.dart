import '../../domain/models/chat_preview.dart';

// 숫자를 1,284처럼 천 단위 쉼표가 들어간 글자로 바꾼다
String formatCount(int n) {
  return n.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );
}

// 날짜를 2026.09.07 모양으로 바꾼다
String formatDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

// 날짜를 09.07 모양(연도 없이)으로 바꾼다
String formatShortDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

// 바이트 수를 2.4 MB 같은 글자로 바꾼다
String formatSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

// 대화방 수정 화면이 '삭제'를 눌렀을 때 이전 화면에 돌려주는 값
const String kDeleteChat = 'delete-chat';

// 끌어다 놓은 파일의 이름과 내용 (대화방 추가 화면에 넘기는 값)
class DroppedFile {
  const DroppedFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

// 대화방 추가 화면에서 사용자가 확정한 값 (미리보기 + 앱에 표시할 이름)
class PickedChat {
  const PickedChat({required this.preview, required this.displayName});

  final ChatPreview preview;
  final String displayName;
}
