import 'package:flutter_test/flutter_test.dart';

import 'package:photalk/data/mock/chatroom_repository_mock.dart';
import 'package:photalk/main.dart';

void main() {
  testWidgets('참여자 이름이 화면에 보인다 (Mock 사용)', (WidgetTester tester) async {
    await tester.pumpWidget(
        PhoTalkApp(chatroomRepository: ChatroomRepositoryMock()));
    await tester.pumpAndSettle();

    expect(find.text('민지'), findsOneWidget);
    expect(find.text('준호'), findsOneWidget);
  });
}
