import 'package:flutter_test/flutter_test.dart';

import 'package:photalk/data/mock/chatroom_repository_mock.dart';
import 'package:photalk/main.dart';

void main() {
  testWidgets('시작 화면에서 시작하기를 누르면 데이터 수집 화면이 열린다 (Mock 사용)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        PhoTalkApp(chatroomRepository: ChatroomRepositoryMock()));

    expect(find.text('PhoTalk'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    // 화면 제목과 왼쪽 메뉴 항목에 같은 글자가 있어 하나 이상 있는지만 확인한다
    expect(find.text('데이터 수집'), findsWidgets);
    expect(find.text('+ 대화방 추가'), findsOneWidget);
  });
}
