import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'data/mock/chatroom_repository_mock.dart';
import 'data/mock/relationship_repository_mock.dart';
import 'data/mock/search_repository_mock.dart';
import 'data/mock/stats_repository_mock.dart';
import 'domain/repositories/chatroom_repository.dart';
import 'domain/repositories/relationship_repository.dart';
import 'domain/repositories/search_repository.dart';
import 'domain/repositories/stats_repository.dart';

void main() {
  runApp(const PhoTalkApp());
}

class PhoTalkApp extends StatelessWidget {
  const PhoTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 어떤 구현을 쓸지 정하는 곳은 여기 한 군데다.
    // 서버를 연결할 때는 아래 Mock만 Api 구현으로 바꾸면 된다.
    return MultiProvider(
      providers: [
        Provider<ChatroomRepository>(create: (_) => ChatroomRepositoryMock()),
        Provider<RelationshipRepository>(
            create: (_) => RelationshipRepositoryMock()),
        Provider<StatsRepository>(create: (_) => StatsRepositoryMock()),
        Provider<SearchRepository>(create: (_) => SearchRepositoryMock()),
      ],
      child: MaterialApp(
        title: 'PhoTalk',
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Center(child: Text('PhoTalk')),
        ),
      ),
    );
  }
}
