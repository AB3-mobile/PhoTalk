import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/models/chatroom.dart';
import '../../domain/models/chatroom_mood.dart';
import '../../domain/models/date_range_info.dart';
import '../../domain/models/person.dart';
import '../../domain/repositories/chatroom_repository.dart';
import '../../domain/repositories/people_repository.dart';
import '../../domain/repositories/stats_repository.dart';
import '../collect/widgets/circle_icon_button.dart';
import '../menu/app_menu_drawer.dart';
import '../search/search_panel.dart';
import 'people_format.dart';
import 'person_detail_screen.dart';
import 'widgets/period_card.dart';
import 'widgets/people_style.dart';
import 'widgets/person_photo.dart';
import 'widgets/room_sheet.dart';
import 'widgets/sort_widgets.dart';

// 멤버 정렬 기준
enum _Sort { name, most, least, recent }

const _sortItems = <(String, _Sort)>[
  ('이름순', _Sort.name),
  ('메시지 많은순', _Sort.most),
  ('메시지 적은순', _Sort.least),
  ('최근 대화순', _Sort.recent),
];

// 멤버: 대화방을 고르고, 그 방 멤버를 카드로 보여 준다 (카드를 누르면 사람 상세)
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  late final ChatroomRepository _chatroomRepo;
  late final PeopleRepository _peopleRepo;
  late final StatsRepository _statsRepo;

  List<Chatroom> _rooms = [];
  String? _roomId;
  List<Person> _people = [];
  ChatroomMoods? _mood;

  // 전체 대화 날짜 범위와 지금 고른 분석 기간
  DateTime? _first;
  DateTime? _last;
  DateTime? _start;
  DateTime? _end;

  _Sort _sort = _Sort.name;
  bool _sortOpen = false;
  double _sortTop = 0;
  // 사람 id → 가장 늦게 대화한 달 ("2026-08", 최근 대화순 정렬용)
  final Map<String, String> _lastMonths = {};

  bool _loading = true;
  String? _error;
  // 오래된 요청의 결과가 새 화면을 덮지 않게 하는 번호표
  int _token = 0;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _sortKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _chatroomRepo = context.read<ChatroomRepository>();
    _peopleRepo = context.read<PeopleRepository>();
    _statsRepo = context.read<StatsRepository>();
    _init();
  }

  // 대화방 목록과 전체 날짜 범위를 불러온 뒤 첫 번째 대화방을 연다
  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rooms = (await _chatroomRepo.getChatrooms()).where((r) => r.indexed).toList();
      var range = const DateRangeInfo();
      try {
        range = await _peopleRepo.getDateRange();
      } catch (_) {}
      if (!mounted) return;
      if (rooms.isEmpty) {
        setState(() {
          _rooms = [];
          _loading = false;
          _error = '표시할 대화방이 없어요. 서버가 켜져 있는지 확인해 주세요.';
        });
        return;
      }
      final now = DateTime.now();
      final last = range.last ?? DateTime(now.year, now.month, now.day);
      final first = range.first ?? DateTime(last.year - 1, last.month, last.day);
      setState(() {
        _rooms = rooms;
        _first = first;
        _last = last;
        _start = first;
        _end = last;
      });
      await _load(rooms.first.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '멤버를 불러오지 못했어요. 서버가 켜져 있는지 확인해 주세요.';
      });
    }
  }

  Future<ChatroomMoods?> _moodOrNull(String roomId, DateTime s, DateTime e) async {
    try {
      return await _peopleRepo.getMoods(roomId, start: s, end: e);
    } catch (_) {
      return null;
    }
  }

  Person _withCount(Person p, int count) => Person(
        participantId: p.participantId,
        name: p.name,
        messageCount: count,
        description: p.description,
        shortBio: p.shortBio,
        avatarUrl: p.avatarUrl,
      );

  // 한 대화방의 멤버(전체 정보 + 분석 기간 안 메시지 수)와 분위기를 불러온다
  Future<void> _load(String roomId) async {
    final token = ++_token;
    final s = _start!;
    final e = _end!;
    setState(() {
      _roomId = roomId;
      _loading = true;
      _error = null;
      _sortOpen = false;
    });
    try {
      final lists = await Future.wait<List<Person>>([
        _chatroomRepo.getPeople(roomId),
        _chatroomRepo.getPersonDetail(roomId, start: s, end: e),
      ]);
      final mood = await _moodOrNull(roomId, s, e);
      if (!mounted || token != _token) return;
      final counts = {for (final p in lists[1]) p.participantId: p.messageCount};
      setState(() {
        _people = [for (final p in lists[0]) _withCount(p, counts[p.participantId] ?? 0)];
        _mood = mood;
        _lastMonths.clear();
        _loading = false;
      });
      if (_sort == _Sort.recent) _loadLastMonths(token);
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _error = '멤버를 불러오지 못했어요. 서버가 켜져 있는지 확인해 주세요.';
      });
    }
  }

  // 분석 기간만 바뀌었을 때: 화면 전체를 비우지 않고 메시지 수와 분위기만 새로 받는다
  Future<void> _onPeriod(DateTime s, DateTime e) async {
    setState(() {
      _start = s;
      _end = e;
    });
    final roomId = _roomId;
    if (roomId == null) return;
    final token = ++_token;
    try {
      final detail = await _chatroomRepo.getPersonDetail(roomId, start: s, end: e);
      final mood = await _moodOrNull(roomId, s, e);
      if (!mounted || token != _token) return;
      final counts = {for (final p in detail) p.participantId: p.messageCount};
      setState(() {
        _people = [for (final p in _people) _withCount(p, counts[p.participantId] ?? 0)];
        _mood = mood;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 기간의 멤버 정보를 불러오지 못했어요')));
    }
  }

  // 최근 대화순을 위해 사람마다 월별 메시지 수를 받아 가장 늦은 달을 찾는다
  Future<void> _loadLastMonths(int token) async {
    final roomId = _roomId;
    if (roomId == null) return;
    final entries = await Future.wait(_people.map((p) async {
      try {
        final list = await _statsRepo.getMonthlyMessageCounts(roomId, p.participantId);
        final months = list.where((m) => m.count > 0).map((m) => m.month).toList()..sort();
        return MapEntry(p.participantId, months.isEmpty ? '' : months.last);
      } catch (_) {
        return MapEntry(p.participantId, '');
      }
    }));
    if (!mounted || token != _token) return;
    setState(() {
      _lastMonths
        ..clear()
        ..addEntries(entries);
    });
  }

  List<Person> get _sortedPeople {
    final list = [..._people];
    switch (_sort) {
      case _Sort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _Sort.most:
        list.sort((a, b) => b.messageCount.compareTo(a.messageCount));
      case _Sort.least:
        list.sort((a, b) => a.messageCount.compareTo(b.messageCount));
      case _Sort.recent:
        list.sort((a, b) {
          final c = (_lastMonths[b.participantId] ?? '').compareTo(_lastMonths[a.participantId] ?? '');
          return c != 0 ? c : b.messageCount.compareTo(a.messageCount);
        });
    }
    return list;
  }

  String get _sortLabel => _sortItems.firstWhere((e) => e.$2 == _sort).$1;

  String _roomName() {
    for (final r in _rooms) {
      if (r.id == _roomId) return r.name;
    }
    return '대화방';
  }

  // 정렬 목록을 열고 닫는다 (열 때 정렬 줄 아래 위치를 재서 그 아래를 어둡게 덮는다)
  void _toggleSort() {
    if (_sortOpen) {
      setState(() => _sortOpen = false);
      return;
    }
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final rowBox = _sortKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox != null && rowBox != null) {
      _sortTop = rowBox.localToGlobal(Offset(0, rowBox.size.height), ancestor: stackBox).dy;
    }
    setState(() => _sortOpen = true);
  }

  void _pickSort(_Sort s) {
    setState(() {
      _sort = s;
      _sortOpen = false;
    });
    if (s == _Sort.recent && _lastMonths.isEmpty) _loadLastMonths(_token);
  }

  Future<void> _pickRoom() async {
    final first = _first;
    final last = _last;
    if (first == null || last == null) return;
    final picked = await showRoomSheet(context, rooms: _rooms, selectedId: _roomId, first: first, last: last);
    if (picked != null && picked != _roomId) _load(picked);
  }

  void _openDetail(Person p) {
    final roomId = _roomId;
    if (roomId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonDetailScreen(
          roomId: roomId,
          roomName: _roomName(),
          person: p,
          people: _people,
          first: _first!,
          last: _last!,
          start: _start!,
          end: _end!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _rooms.isNotEmpty && _first != null && _last != null && _start != null && _end != null;
    final mood = _mood?.representative(_end ?? DateTime.now());
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppMenuDrawer(current: AppMenuItem.member),
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            Column(
              children: [
                _header(),
                if (ready) _roomBar(),
                if (ready && mood != null) _moodPill(mood.description),
                if (ready && _error == null) _membersRow(),
                Expanded(child: _body()),
                if (ready) PeriodCard(first: _first!, last: _last!, start: _start!, end: _end!, onChanged: _onPeriod),
              ],
            ),
            if (_sortOpen) ...[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: _sortTop,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _sortOpen = false),
                  child: Container(color: PeopleStyle.scrim),
                ),
              ),
              Positioned(
                right: 16,
                top: _sortTop,
                child: SortPanel<_Sort>(items: _sortItems, selected: _sort, onSelected: _pickSort),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 메뉴 버튼 · 제목 · 검색 버튼
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Builder(
            builder: (context) => InkResponse(
              radius: 24,
              onTap: () => Scaffold.of(context).openDrawer(),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.menu_rounded, size: 30, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('멤버', style: appText(22, weight: FontWeight.w800))),
          CircleIconButton(icon: Icons.search_rounded, iconColor: AppColors.accent, onPressed: () => openSearchPanel(context)),
        ],
      ),
    );
  }

  // 지금 보고 있는 대화방 (누르면 대화방 선택 시트)
  Widget _roomBar() {
    final count = _people.isNotEmpty
        ? _people.length
        : _rooms.firstWhere((r) => r.id == _roomId, orElse: () => _rooms.first).participantCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: PeopleStyle.border)),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          onTap: _pickRoom,
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.chat_bubble_rounded, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_roomName(), maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(17, weight: FontWeight.w800))),
                  Text('$count명', style: appText(14, color: AppColors.chevron)),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: AppColors.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 하트와 방 분위기 한 줄
  Widget _moodPill(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: PeopleStyle.moodBg, borderRadius: BorderRadius.circular(18)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.favorite_rounded, size: 15, color: PeopleStyle.heart)),
              const SizedBox(width: 8),
              // 길면 잘라 내지 않고 여러 줄로 줄바꿈해서 끝까지 보여 준다
              Flexible(child: Text(text, style: appText(14, weight: FontWeight.w700, color: AppColors.accent).copyWith(height: 1.4))),
            ],
          ),
        ),
      ),
    );
  }

  // "멤버 12명"과 정렬 선택
  Widget _membersRow() {
    return Padding(
      key: _sortKey,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Expanded(child: Text('멤버 ${_people.length}명', style: appText(18, weight: FontWeight.w800))),
          SortPill(label: _sortLabel, onTap: _toggleSort),
        ],
      ),
    );
  }

  // 불러오는 중·실패·멤버 없음·정상에 맞는 본문
  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _message(_error!, _init);
    if (_people.isEmpty) return _message('이 대화방에 멤버가 없어요', () => _load(_roomId!));
    final people = _sortedPeople;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 118 / 122,
      ),
      itemCount: people.length,
      itemBuilder: (_, i) => _PersonCard(person: people[i], onTap: () => _openDetail(people[i])),
    );
  }

  Widget _message(String text, VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(text, textAlign: TextAlign.center, style: appText(13, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: retry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

// 멤버 카드: 사진, 이름, 오른쪽 위에 기간 안 메시지 수
class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.onTap});

  final Person person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: PeopleStyle.border)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: PeopleStyle.pill, borderRadius: BorderRadius.circular(10)),
                child: Text(formatCount(person.messageCount), style: appText(11, weight: FontWeight.w700, color: AppColors.textSecondary)),
              ),
            ),
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  PersonPhoto(name: person.name, avatarUrl: person.avatarUrl, size: 64),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(15, weight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
