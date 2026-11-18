import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/models/chatroom.dart';
import '../../domain/models/history_summary.dart';
import '../../domain/models/keyword_count.dart';
import '../../domain/models/keyword_mentioner.dart';
import '../../domain/repositories/chatroom_repository.dart';
import '../../domain/repositories/history_repository.dart';
import '../collect/widgets/circle_icon_button.dart';
import '../collect/widgets/person_avatar.dart';
import '../menu/app_menu_drawer.dart';

// 히스토리 화면(My Time): 대화방과 연도·월을 고르면 그 달의 주요 사건 요약, 주요 연락처, 키워드 순위를 보여 준다
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Chatroom> _rooms = [];
  String? _roomId;
  // 기간("2026-08")별 요약과 키워드 순위
  Map<String, HistorySummary> _summaries = {};
  Map<String, List<KeywordCount>> _keywords = {};
  // 데이터가 있는 기간들 (오름차순)과 지금 고른 연도·월
  List<String> _periods = [];
  int? _year;
  int? _month;
  bool _loading = true;
  String? _error;
  // 일별 그래프를 보고 있는 키워드 (없으면 키워드 목록)와 월별로 받아 둔 일별 키워드
  String? _detail;
  final Map<String, Map<String, List<KeywordCount>>> _dailyCache = {};
  bool _dailyLoading = false;
  bool _dailyFailed = false;
  // 일별 그래프에서 고른 막대(일)와 날짜·키워드별로 받아 둔 언급자 목록
  int? _selDay;
  final Map<String, List<KeywordMentioner>> _mentionCache = {};
  bool _mentionFailed = false;
  // 대화방을 빠르게 바꿨을 때 늦게 온 응답을 버리기 위한 번호
  int _token = 0;
  // 열려 있는 연도·월 드롭다운 (없으면 null)과 알약 줄의 위치를 재기 위한 키
  _Drop? _drop;
  double _pillsTop = 0;
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _pillsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _init();
  }

  // 대화방 목록을 읽고 인덱싱된 첫 대화방의 히스토리를 불러온다
  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rooms = await context.read<ChatroomRepository>().getChatrooms();
    } catch (_) {}
    if (!mounted) return;
    final indexed = _rooms.where((r) => r.indexed).toList();
    final id = indexed.firstOrNull?.id ?? _rooms.firstOrNull?.id;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = '표시할 대화방이 없어요. 서버가 켜져 있는지 확인해 주세요.';
      });
      return;
    }
    await _load(id);
  }

  // 한 대화방의 월별 요약과 키워드를 읽어 가장 최근 달을 고른다
  Future<void> _load(String roomId) async {
    final repo = context.read<HistoryRepository>();
    final token = ++_token;
    setState(() {
      _roomId = roomId;
      _loading = true;
      _error = null;
      _detail = null;
      _selDay = null;
      _dailyCache.clear();
      _mentionCache.clear();
    });
    try {
      final results = await Future.wait([repo.getMonthlySummaries(roomId), repo.getMonthlyKeywords(roomId)]);
      if (!mounted || token != _token) return;
      final summaries = {for (final s in results[0] as List<HistorySummary>) s.period: s};
      final keywords = results[1] as Map<String, List<KeywordCount>>;
      final periods = {...summaries.keys, ...keywords.keys}.toList()..sort();
      setState(() {
        _summaries = summaries;
        _keywords = keywords;
        _periods = periods;
        _loading = false;
        if (periods.isNotEmpty) _select(periods.last);
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _error = '히스토리를 불러오지 못했어요. 서버 연결을 확인해 주세요.';
      });
    }
  }

  // "2026-08" 모양의 기간으로 연도와 월을 맞춘다
  void _select(String period) {
    final p = period.split('-');
    _year = int.parse(p[0]);
    _month = int.parse(p[1]);
  }

  String get _key => '$_year-${_month.toString().padLeft(2, '0')}';
  // 데이터가 있는 연도들
  List<int> get _years => {for (final p in _periods) int.parse(p.split('-')[0])}.toList();
  // 고른 연도에서 데이터가 있는 월들
  List<int> get _months => [for (final p in _periods) if (p.startsWith('$_year-')) int.parse(p.split('-')[1])];

  // 연도를 바꾸면 그 해의 가장 최근 달로 맞춘다
  void _pickYear(int y) {
    setState(() {
      _year = y;
      _month = _months.last;
      _detail = null;
      _selDay = null;
    });
  }

  // 키워드를 누르면 그 달의 일별 언급 횟수를 (아직 없으면) 받아 와서 상세 그래프로 바꾼다
  Future<void> _openDetail(String word) async {
    final month = _key;
    final roomId = _roomId!;
    setState(() {
      _detail = word;
      _selDay = null;
      _dailyFailed = false;
      _dailyLoading = !_dailyCache.containsKey(month);
    });
    if (!_dailyLoading) return;
    try {
      final daily = await context.read<HistoryRepository>().getDailyKeywords(roomId, month);
      if (!mounted) return;
      setState(() {
        _dailyCache[month] = daily;
        _dailyLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _dailyLoading = false;
          _dailyFailed = true;
        });
      }
    }
  }

  // 고른 키워드·날짜의 언급자 캐시 키
  String _mentionKey(int day) => '$_detail|$_key-${day.toString().padLeft(2, '0')}';

  // 막대를 누르면 그 날 언급한 사람을 (아직 없으면) 받아 오고, 같은 막대를 다시 누르면 선택을 푼다
  Future<void> _selectBar(int day) async {
    if (_selDay == day) {
      setState(() => _selDay = null);
      return;
    }
    final key = _mentionKey(day);
    final date = '$_key-${day.toString().padLeft(2, '0')}';
    final word = _detail!;
    final roomId = _roomId!;
    setState(() {
      _selDay = day;
      _mentionFailed = false;
    });
    if (_mentionCache.containsKey(key)) return;
    try {
      final list = await context.read<HistoryRepository>().getKeywordMentioners(roomId, date, word);
      if (!mounted) return;
      setState(() => _mentionCache[key] = list);
    } catch (_) {
      if (mounted && _selDay == day) setState(() => _mentionFailed = true);
    }
  }

  // 지금 고른 달에서 키워드가 언급된 날(일)과 횟수 목록
  List<(int, int)> _daysOf(String word) {
    final daily = _dailyCache[_key] ?? const <String, List<KeywordCount>>{};
    final dates = daily.keys.toList()..sort();
    final result = <(int, int)>[];
    for (final d in dates) {
      for (final k in daily[d]!) {
        if (k.word == word) result.add((int.parse(d.substring(8, 10)), k.count));
      }
    }
    return result;
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

  String _roomName() {
    for (final r in _rooms) {
      if (r.id == _roomId) return r.name;
    }
    return '대화방';
  }

  // 연도·월 알약을 보여 줄 수 있는 상태인지
  bool get _showPills => !_loading && _error == null && _periods.isNotEmpty;

  // 드롭다운을 열거나 닫는다 (열 때 알약 줄의 위치를 재서 어두운 막 위에 다시 그린다)
  void _openDrop(_Drop d) {
    if (_drop == d) {
      setState(() => _drop = null);
      return;
    }
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final pillsBox = _pillsKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox != null && pillsBox != null) {
      _pillsTop = pillsBox.localToGlobal(Offset.zero, ancestor: stackBox).dy;
    }
    setState(() => _drop = d);
  }

  // 연도·월 알약 두 개 (top이 true면 어두운 막 위에 그리는 것이라 열린 목록 패널도 함께 낸다)
  Widget _pills(bool top) {
    Widget column(_Drop d, String label, List<(String, int)> items, int selected, ValueChanged<int> onSelected) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 46, child: _DropPill(label: label, open: _drop == d, onTap: () => _openDrop(d))),
            if (top && _drop == d) ...[
              const SizedBox(height: 10),
              _DropPanel(
                items: items,
                selected: selected,
                onSelected: (v) {
                  setState(() => _drop = null);
                  onSelected(v);
                },
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        column(_Drop.year, '$_year년', [for (final y in _years) ('$y년', y)], _year!, _pickYear),
        const SizedBox(width: 12),
        column(_Drop.month, '$_month월', [for (final m in _months) ('$m월', m)], _month!, (m) => setState(() {
              _month = m;
              _detail = null;
              _selDay = null;
            })),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppMenuDrawer(current: AppMenuItem.history),
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            Column(
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
                      Expanded(child: Text('히스토리', style: appText(22, weight: FontWeight.w700))),
                      const CircleIconButton(icon: Icons.search_rounded, iconColor: AppColors.accent),
                    ],
                  ),
                ),
                // 지금 보고 있는 대화방 (누르면 다른 대화방 선택)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _pickRoom,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_rounded, size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(_roomName(), style: appText(14, weight: FontWeight.w700, color: AppColors.accent)),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.accent),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showPills)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SizedBox(key: _pillsKey, height: 46, child: _pills(false)),
                  ),
                Expanded(child: _body()),
              ],
            ),
            // 드롭다운이 열리면 화면을 어둡게 하고 그 위에 알약과 목록 패널을 다시 그린다
            if (_drop != null) ...[
              Positioned.fill(
                child: GestureDetector(onTap: () => setState(() => _drop = null), child: Container(color: const Color(0x331E2A4A))),
              ),
              Positioned(left: 16, right: 16, top: _pillsTop, child: _pills(true)),
            ],
          ],
        ),
      ),
    );
  }

  // 불러오는 중·실패·데이터 없음·정상에 맞는 본문을 만든다
  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _periods.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? '이 대화방의 히스토리가 아직 없어요', textAlign: TextAlign.center, style: appText(13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => _roomId == null ? _init() : _load(_roomId!), child: const Text('다시 시도')),
          ],
        ),
      );
    }
    final summary = _summaries[_key];
    final keywords = [...(_keywords[_key] ?? const <KeywordCount>[])]..sort((a, b) => b.count.compareTo(a.count));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // 아래(키워드) 카드를 먼저 그리고 위(요약) 카드를 나중에 그려, 연락처 말풍선이 키워드 카드 위로 나오게 한다
        Column(
          verticalDirection: VerticalDirection.up,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _detail == null
                ? _KeywordCard(keywords: keywords.take(7).toList(), onTap: _openDetail)
                : _KeywordDetailCard(
                    keyword: _detail!,
                    days: _daysOf(_detail!),
                    loading: _dailyLoading,
                    failed: _dailyFailed,
                    month: _month!,
                    selectedDay: _selDay,
                    mentioners: _selDay == null ? null : _mentionCache[_mentionKey(_selDay!)],
                    mentionFailed: _mentionFailed,
                    onBarTap: _selectBar,
                    onBack: () => setState(() {
                      _detail = null;
                      _selDay = null;
                    }),
                  ),
            const SizedBox(height: 14),
            _SummaryCard(key: ValueKey(_key), summary: summary),
          ],
        ),
      ],
    );
  }
}

// 열 수 있는 드롭다운 종류
enum _Drop { year, month }

// 연도·월을 고르는 하얀 알약 (열리면 오른쪽 화살표가 파란 원의 위쪽 화살표로 바뀐다)
class _DropPill extends StatelessWidget {
  const _DropPill({required this.label, required this.open, required this.onTap});

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23)),
        child: Row(
          children: [
            Expanded(child: Center(child: Text(label, style: appText(16, weight: FontWeight.w700)))),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: open ? AppColors.accent : AppColors.tileBg, shape: BoxShape.circle),
              child: Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20, color: open ? Colors.white : AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

// 알약 아래에 열리는 하얀 목록 패널 (고른 항목은 파란색, 5개를 넘으면 스크롤)
class _DropPanel extends StatefulWidget {
  const _DropPanel({required this.items, required this.selected, required this.onSelected});

  // (보여 줄 글자, 값) 목록
  final List<(String, int)> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<_DropPanel> createState() => _DropPanelState();
}

class _DropPanelState extends State<_DropPanel> {
  static const double _itemHeight = 40;
  static const double _gap = 4;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    // 고른 항목이 목록 가운데쯤 보이도록 처음 스크롤 위치를 맞춘다
    final index = widget.items.indexWhere((e) => e.$2 == widget.selected);
    _scroll = ScrollController(initialScrollOffset: index <= 2 ? 0 : (index - 2) * (_itemHeight + _gap));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 5 * _itemHeight + 4 * _gap),
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: widget.items.length > 5,
          child: ListView.separated(
            controller: _scroll,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: widget.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: _gap),
            itemBuilder: (_, i) {
              final (text, value) = widget.items[i];
              final on = value == widget.selected;
              return GestureDetector(
                onTap: () => widget.onSelected(value),
                child: Container(
                  height: _itemHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: on ? AppColors.accent : const Color(0xFFF1F3FB), borderRadius: BorderRadius.circular(20)),
                  child: Text(text, style: appText(on ? 15 : 14, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? Colors.white : AppColors.textSecondary)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// 주요 사건 요약 글과 주요 연락처가 들어 있는 하얀 카드 (연락처를 누르면 소개 말풍선이 뜬다)
class _SummaryCard extends StatefulWidget {
  const _SummaryCard({super.key, required this.summary});

  final HistorySummary? summary;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  // 말풍선을 보고 있는 연락처 번호 (없으면 null)
  int? _sel;

  static const double _avatar = 48;
  static const double _gap = 14;
  static const double _runGap = 12;
  // 아바타 + 이름 한 줄의 높이
  static const double _itemHeight = 48 + 6 + 18;
  static const double _bubbleWidth = 230;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final contacts = summary?.contacts ?? const <HistoryContact>[];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('주요 사건 요약', style: appText(16, weight: FontWeight.w700)),
          const SizedBox(height: 14),
          // 글이 길면 이 칸 안에서만 스크롤한다
          SizedBox(
            height: 84,
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Text(
                  (summary?.text ?? '').isEmpty ? '이 달의 요약이 없어요' : summary!.text,
                  style: appText(13, color: AppColors.textPrimary).copyWith(height: 1.75),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('주요 연락처', style: appText(14, weight: FontWeight.w700)),
              Text('${contacts.length}명', style: appText(11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) => _contacts(contacts, box.maxWidth)),
        ],
      ),
    );
  }

  // 연락처 아바타들과, 고른 연락처 아래에 뜨는 소개 말풍선
  Widget _contacts(List<HistoryContact> contacts, double width) {
    final perRun = ((width + _gap) / (_avatar + _gap)).floor().clamp(1, 99);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Wrap(
          spacing: _gap,
          runSpacing: _runGap,
          children: [
            for (var i = 0; i < contacts.length; i++)
              GestureDetector(
                onTap: () => setState(() => _sel = _sel == i ? null : i),
                child: SizedBox(
                  width: _avatar,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          PersonAvatar(index: i, size: _avatar),
                          // 고른 연락처는 파란 테두리를 두른다
                          if (_sel == i)
                            Positioned(
                              left: -4,
                              right: -4,
                              top: -4,
                              bottom: -4,
                              child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accent, width: 2.5))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _sel == i ? const Color(0xFFDCE3FA) : null, borderRadius: BorderRadius.circular(9)),
                        child: Text(
                          contacts[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(11, weight: _sel == i ? FontWeight.w700 : FontWeight.w500, color: _sel == i ? AppColors.accent : AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (_sel != null && _sel! < contacts.length) _bubble(contacts[_sel!], perRun, width),
      ],
    );
  }

  // 고른 연락처의 소개를 담은 말풍선 (위쪽 꼭지가 그 연락처를 가리킨다)
  Widget _bubble(HistoryContact c, int perRun, double width) {
    final row = _sel! ~/ perRun;
    final col = _sel! % perRun;
    final centerX = col * (_avatar + _gap) + _avatar / 2;
    final w = _bubbleWidth < width ? _bubbleWidth : width;
    final left = (centerX - w / 2).clamp(0.0, width - w);
    final top = (row + 1) * _itemHeight + row * _runGap + 6;
    final text = (c.shortBio ?? '').trim().isNotEmpty ? c.shortBio!.trim() : ((c.description ?? '').trim().isNotEmpty ? c.description!.trim() : '소개가 아직 없어요');
    return Positioned(
      left: left,
      top: top,
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment(((centerX - left) / w) * 2 - 1, 0),
            child: CustomPaint(size: const Size(14, 7), painter: _UpArrow()),
          ),
          Container(
            width: w,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFECEFFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.accent.withValues(alpha: 0.6))),
            child: Text(text, style: appText(12.5, color: AppColors.textPrimary).copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// 말풍선 위쪽의 작은 삼각형 꼭지를 그리는 페인터
class _UpArrow extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(path, Paint()..color = const Color(0xFFECEFFC)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = AppColors.accent.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 키워드 언급 순위를 가로 막대로 보여 주는 하얀 카드
class _KeywordCard extends StatelessWidget {
  const _KeywordCard({required this.keywords, required this.onTap});

  final List<KeywordCount> keywords;
  // 키워드 한 줄을 눌렀을 때 (그 키워드의 글자를 넘긴다)
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final max = keywords.isEmpty ? 1 : keywords.first.count;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('키워드', style: appText(16, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('키워드를 누르면 일별 그래프가 나타나요', style: appText(11, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          for (final k in keywords)
            InkWell(
              onTap: () => onTap(k.word),
              child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(k.word, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(13, weight: FontWeight.w700))),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 10, decoration: BoxDecoration(color: AppColors.rowBg, borderRadius: BorderRadius.circular(5))),
                        FractionallySizedBox(
                          widthFactor: (k.count / max).clamp(0.02, 1.0),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              gradient: const LinearGradient(colors: [Color(0xFF8CA0EA), AppColors.accent]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 36, child: Text('${k.count}', textAlign: TextAlign.right, style: appText(13, color: AppColors.textSecondary))),
                ],
              ),
              ),
            ),
        ],
      ),
    );
  }
}

// 키워드 하나의 일별 언급 횟수를 막대 그래프로 보여 주는 하얀 카드 ("키워드 목록"으로 돌아가는 버튼 포함)
class _KeywordDetailCard extends StatelessWidget {
  const _KeywordDetailCard({
    required this.keyword,
    required this.days,
    required this.loading,
    required this.failed,
    required this.month,
    required this.selectedDay,
    required this.mentioners,
    required this.mentionFailed,
    required this.onBarTap,
    required this.onBack,
  });

  final String keyword;
  // (일, 언급 횟수) 목록 (언급이 있는 날만)
  final List<(int, int)> days;
  final bool loading;
  final bool failed;
  // 고른 달(월)과 고른 막대의 일, 그날 언급자 (아직 받는 중이면 null), 받기 실패 여부
  final int month;
  final int? selectedDay;
  final List<KeywordMentioner>? mentioners;
  final bool mentionFailed;
  final ValueChanged<int> onBarTap;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('키워드 상세보기', style: appText(16, weight: FontWeight.w700))),
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.accent),
                label: Text('키워드 목록', style: appText(12, weight: FontWeight.w700, color: AppColors.accent)),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.accent),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('막대를 누르면 그 날 언급한 사람을 볼 수 있어요.', style: appText(11, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFDDE3F7))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Text('"$keyword" 일별 언급 횟수', style: appText(13, weight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('언급 횟수', style: appText(11, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (loading)
                  const SizedBox(height: 190, child: Center(child: CircularProgressIndicator()))
                else if (failed || days.isEmpty)
                  SizedBox(height: 190, child: Center(child: Text(failed ? '일별 데이터를 불러오지 못했어요' : '이 달에는 언급이 없어요', style: appText(12, color: AppColors.textSecondary))))
                else
                  _DailyBarChart(
                    days: days,
                    selectedDay: selectedDay,
                    onBarTap: onBarTap,
                    tooltipTitle: selectedDay == null ? '' : '$month월 $selectedDay일 · ${days.firstWhere((d) => d.$1 == selectedDay).$2}회 언급',
                    tooltipBody: mentionFailed ? '불러오지 못했어요' : (mentioners == null ? '불러오는 중…' : mentioners!.map((m) => '${m.name} ${m.count}').join(' · ')),
                  ),
                const SizedBox(height: 8),
                Center(child: Text('날짜 (언급 있는 날만 표시)', style: appText(11, weight: FontWeight.w700, color: AppColors.textSecondary))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 날짜별 막대 그래프: 점선 눈금 3줄, 막대 위 숫자, 아래 날짜
class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.days, required this.selectedDay, required this.onBarTap, required this.tooltipTitle, required this.tooltipBody});

  final List<(int, int)> days;
  // 고른 막대의 일 (없으면 null), 막대를 눌렀을 때, 툴팁에 쓸 제목과 본문
  final int? selectedDay;
  final ValueChanged<int> onBarTap;
  final String tooltipTitle;
  final String tooltipBody;

  static const double _height = 150;
  static const double _axisWidth = 26;

  static const double _tipWidth = 176;

  // 고른 막대 바로 위에 아래쪽 꼭지가 막대를 가리키는 툴팁을 놓는다
  Widget _tooltip(double width, double slot, int top) {
    final i = days.indexWhere((d) => d.$1 == selectedDay);
    final centerX = _axisWidth + slot * (i + 0.5);
    final left = (centerX - _tipWidth / 2).clamp(0.0, width - _tipWidth);
    final barTop = (days[i].$2 / top * _height).clamp(2.0, _height);
    return Positioned(
      left: left,
      bottom: barTop + 8,
      width: _tipWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _tipWidth,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(14)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tooltipTitle, textAlign: TextAlign.center, style: appText(13, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 3),
                Text(tooltipBody, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: appText(11, color: const Color(0xFFB4C0F0))),
              ],
            ),
          ),
          // 막대 쪽을 가리키는 아래쪽 꼭지
          Align(
            alignment: Alignment(((centerX - left) / _tipWidth) * 2 - 1, 0),
            child: CustomPaint(size: const Size(12, 6), painter: _TipArrow()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxCount = days.map((d) => d.$2).reduce((a, b) => a > b ? a : b);
    // 눈금 맨 위 값: 4의 배수로 올림 (6이면 8, 눈금은 0·4·8)
    final top = ((maxCount + 3) ~/ 4) * 4;
    return LayoutBuilder(
      builder: (context, box) {
        final area = box.maxWidth - _axisWidth;
        final slot = area / days.length;
        final barWidth = (slot * 0.55).clamp(6.0, 42.0);
        // 칸이 좁으면 날짜를 몇 개씩 건너뛰며 보여 준다
        final labelEvery = (20 / slot).ceil().clamp(1, 99);
        return Column(
          children: [
            SizedBox(
              height: _height + 20,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 점선 눈금과 왼쪽 숫자
                  for (final level in [0.0, 0.5, 1.0])
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: level * _height - 7,
                      child: Row(
                        children: [
                          SizedBox(width: _axisWidth, child: Text('${(top * level).round()}', style: appText(11, weight: FontWeight.w700))),
                          Expanded(child: level == 0 ? Container(height: 1.5, color: AppColors.textPrimary) : CustomPaint(size: const Size(double.infinity, 1), painter: _DashedLine())),
                        ],
                      ),
                    ),
                  // 막대와 위쪽 숫자
                  Positioned(
                    left: _axisWidth,
                    right: 0,
                    bottom: 0,
                    height: _height + 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final d in days)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onBarTap(d.$1),
                            child: SizedBox(
                              width: slot,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // 고른 막대의 숫자는 툴팁에 나오므로 숨긴다
                                  if (d.$1 != selectedDay) Text('${d.$2}', style: appText(11, weight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Container(
                                    width: barWidth,
                                    height: (d.$2 / top * _height).clamp(2.0, _height),
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      // 막대를 고르면 나머지 막대는 연하게 만든다
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: selectedDay == null || d.$1 == selectedDay ? const [Color(0xFF8CA0EA), AppColors.accent] : const [Color(0xFFD9DEF5), Color(0xFFC3CBF0)],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 고른 막대 위에 뜨는 어두운 툴팁
                  if (selectedDay != null) _tooltip(box.maxWidth, slot, top),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 아래 날짜 (언급 있는 날만)
            Row(
              children: [
                const SizedBox(width: _axisWidth),
                for (var i = 0; i < days.length; i++)
                  SizedBox(
                    width: slot,
                    child: Center(
                      child: i % labelEvery == 0
                          ? Text('${days[i].$1}', style: appText(11, weight: FontWeight.w700, color: days[i].$1 == selectedDay ? AppColors.accent : AppColors.textPrimary))
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// 가로 점선 한 줄을 그리는 페인터
class _DashedLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9D1EE)
      ..strokeWidth = 1.2;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset((x + 4).clamp(0, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 툴팁 아래쪽의 작은 삼각형을 그리는 페인터
class _TipArrow extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.textPrimary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
