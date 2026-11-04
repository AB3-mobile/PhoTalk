import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_config.dart';
import '../../domain/models/person.dart';
import '../../domain/repositories/chatroom_repository.dart';

// 첫 번째 대화방의 참여자를 아바타 이미지와 이름으로 보여주는 화면
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  late Future<_RoomPeople> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RoomPeople> _load() async {
    final repo = context.read<ChatroomRepository>();
    final rooms = await repo.getChatrooms();
    final room = rooms.firstWhere(
      (r) => r.indexed,
      orElse: () => throw Exception('인덱싱이 끝난 대화방이 없습니다.'),
    );
    final people = await repo.getPeople(room.id);
    return _RoomPeople(room.name, people);
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PhoTalk')),
      body: FutureBuilder<_RoomPeople>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('불러오지 못했어요\n${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _retry, child: const Text('다시 시도')),
                ],
              ),
            );
          }
          final data = snap.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(data.roomName,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 24,
                  children: data.people.map((p) => _PersonTile(person: p)).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoomPeople {
  final String roomName;
  final List<Person> people;
  const _RoomPeople(this.roomName, this.people);
}

class _PersonTile extends StatelessWidget {
  final Person person;
  const _PersonTile({required this.person});

  @override
  Widget build(BuildContext context) {
    final url = person.avatarUrl == null ? null : '$apiBaseUrl${person.avatarUrl}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: url == null ? null : NetworkImage(url),
          child: url == null ? Text(person.name.characters.first) : null,
        ),
        const SizedBox(height: 8),
        Text(person.name, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
