import 'package:flutter_test/flutter_test.dart';

import 'package:photalk/data/mock/chatroom_repository_mock.dart';
import 'package:photalk/main.dart';

void main() {
  testWidgets('시작 화면에서 시작하기를 누르면 참여자 이름이 보인다 (Mock 사용)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        PhoTalkApp(chatroomRepository: ChatroomRepositoryMock()));

    expect(find.text('PhoTalk'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('민지'), findsOneWidget);
    expect(find.text('준호'), findsOneWidget);
  });
}
