import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/models/chatroom.dart';
import '../../domain/models/graph_data.dart';
import '../../domain/repositories/chatroom_repository.dart';
import '../../domain/repositories/graph_repository.dart';
import '../collect/widgets/circle_icon_button.dart';
import '../menu/app_menu_drawer.dart';
import 'force_graph_view.dart';

// 지식 그래프 보기 화면: 대화방을 가운데 두고 인물·키워드를 선으로 이은 그래프를 보여 준다
class KnowledgeGraphScreen extends StatefulWidget {
  const KnowledgeGraphScreen({super.key, this.chatroomId});

  // 처음 보여 줄 대화방 (없으면 인덱싱이 끝난 첫 대화방)
  final String? chatroomId;

  @override
  State<KnowledgeGraphScreen> createState() => _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends State<KnowledgeGraphScreen> {
  // 서버(또는 Mock)에서 받은 대화방 목록
  List<Chatroom> _rooms = [];
  // 지금 보고 있는 대화방 id
  String? _roomId;
  // 만들어 낸 그래프 (불러오는 중이거나 실패하면 null)
  GraphData? _graph;
  bool _loading = true;
  String? _error;
  // 대화방을 빠르게 바꿨을 때 늦게 온 이전 응답을 버리기 위한 번호
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // 대화방 목록을 읽고 처음 볼 대화방을 정해 그래프를 불러온다
  Future<void> _init() async {
    final chat = context.read<ChatroomRepository>();
    try {
      _rooms = await chat.getChatrooms();
    } catch (_) {}
    if (!mounted) return;
    final indexed = _rooms.where((r) => r.indexed).toList();
    final id = widget.chatroomId ?? indexed.firstOrNull?.id ?? _rooms.firstOrNull?.id;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = '표시할 대화방이 없어요. 서버가 켜져 있는지 확인해 주세요.';
      });
      return;
    }
    await _load(id);
  }

  // 대화방 id로 이름을 찾는다 (목록에 없으면 기본 이름)
  String _roomName(String id) {
    for (final r in _rooms) {
      if (r.id == id) return r.name;
    }
    return '대화방';
  }

  // 한 대화방의 지식 그래프(노드·선)를 서버에서 읽는다
  Future<void> _load(String roomId) async {
    final repo = context.read<GraphRepository>();
    final token = ++_token;
    setState(() {
      _roomId = roomId;
      _loading = true;
      _error = null;
    });
    try {
      final data = await repo.getGraph(roomId);
      if (!mounted || token != _token) return;
      setState(() {
        _graph = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _graph = null;
        _loading = false;
        _error = '그래프를 불러오지 못했어요. 서버 연결을 확인해 주세요.';
      });
    }
  }

  // 다른 대화방을 고르는 목록을 아래에서 띄운다
  Future<void> _pickRoom() async {
    final indexed = _rooms.where((r) => r.indexed).toList();
    final list = indexed.isNotEmpty ? indexed : _rooms;
    if (list.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (final r in list)
              ListTile(
                title: Text(r.name, style: appText(15, weight: FontWeight.w600)),
                subtitle: Text('참여자 ${r.participantCount}명', style: appText(12, color: AppColors.textSecondary)),
                trailing: r.id == _roomId ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
                onTap: () => Navigator.pop(context, r.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != _roomId) _load(picked);
  }

  @override
  Widget build(BuildContext context) {
    final name = _roomId == null ? '대화방' : _roomName(_roomId!);
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppMenuDrawer(current: AppMenuItem.graph),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => CircleIconButton(
                      icon: Icons.menu_rounded,
                      iconColor: AppColors.textPrimary,
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text('지식 그래프 보기', style: appText(22, weight: FontWeight.w700))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // 현재 분석 중인 대화방 이름 (누르면 다른 대화방 선택)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _pickRoom,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_rounded, size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(name, style: appText(15, weight: FontWeight.w700, color: AppColors.accent)),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.accent),
                  ],
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  // 불러오는 중·실패·빈 그래프·정상 그래프에 맞는 본문을 만든다
  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: appText(13, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(onPressed: _init, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    final g = _graph;
    if (g == null || g.nodes.length <= 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '표시할 그래프가 아직 없어요.\n인덱싱이 끝나는 중이면 잠시 뒤에 다시 시도해 주세요.',
                textAlign: TextAlign.center,
                style: appText(13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => _roomId == null ? _init() : _load(_roomId!), child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: ForceGraphView(key: ValueKey(_roomId), data: g),
    );
  }
}
