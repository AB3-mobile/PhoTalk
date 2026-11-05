import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'data/api/chatroom_repository_api.dart';
import 'data/mock/relationship_repository_mock.dart';
import 'data/mock/search_repository_mock.dart';
import 'data/mock/stats_repository_mock.dart';
import 'domain/repositories/chatroom_repository.dart';
import 'domain/repositories/relationship_repository.dart';
import 'domain/repositories/search_repository.dart';
import 'domain/repositories/stats_repository.dart';
import 'features/start/start_screen.dart';

void main() {
  runApp(PhoTalkApp());
}

class PhoTalkApp extends StatelessWidget {
  // 테스트에서 다른 구현(Mock)을 넣을 수 있게 열어둔다. 기본은 서버(Api).
  PhoTalkApp({super.key, ChatroomRepository? chatroomRepository})
      : chatroomRepository = chatroomRepository ?? ChatroomRepositoryApi();

  final ChatroomRepository chatroomRepository;

  @override
  Widget build(BuildContext context) {
    // 어떤 구현을 쓸지 정하는 곳은 여기 한 군데다.
    // 대화방·참여자는 서버(Api), 나머지는 아직 Mock이다.
    return MultiProvider(
      providers: [
        Provider<ChatroomRepository>.value(value: chatroomRepository),
        Provider<RelationshipRepository>(
            create: (_) => RelationshipRepositoryMock()),
        Provider<StatsRepository>(create: (_) => StatsRepositoryMock()),
        Provider<SearchRepository>(create: (_) => SearchRepositoryMock()),
      ],
      child: MaterialApp(
        title: 'PhoTalk',
        theme: buildAppTheme(),
        home: const StartScreen(),
      ),
    );
  }
}
