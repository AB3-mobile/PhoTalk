import 'package:flutter_test/flutter_test.dart';

import 'package:photalk/main.dart';

void main() {
  testWidgets('앱이 실행되면 PhoTalk 글자가 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const PhoTalkApp());

    expect(find.text('PhoTalk'), findsOneWidget);
  });
}
