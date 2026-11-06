import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'data/api/chatroom_repository_api.dart';
import 'data/api/graph_repository_api.dart';
import 'data/api/relationship_repository_api.dart';
import 'data/mock/search_repository_mock.dart';
import 'data/api/stats_repository_api.dart';
import 'domain/repositories/chatroom_repository.dart';
import 'domain/repositories/graph_repository.dart';
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
    // 대화방·참여자·인물별 키워드·관계는 서버(Api), 검색은 아직 Mock이다.
    return MultiProvider(
      providers: [
        Provider<ChatroomRepository>.value(value: chatroomRepository),
        Provider<RelationshipRepository>(
            create: (_) => RelationshipRepositoryApi()),
        Provider<StatsRepository>(create: (_) => StatsRepositoryApi()),
        Provider<GraphRepository>(create: (_) => GraphRepositoryApi()),
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
