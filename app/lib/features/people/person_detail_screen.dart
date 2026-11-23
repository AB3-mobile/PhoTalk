import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../domain/models/daily_count.dart';
import '../../domain/models/keyword_count.dart';
import '../../domain/models/monthly_count.dart';
import '../../domain/models/person.dart';
import '../../domain/models/relationship.dart';
import '../../domain/repositories/people_repository.dart';
import '../../domain/repositories/relationship_repository.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/repositories/stats_repository.dart';
import '../collect/widgets/circle_icon_button.dart';
import '../search/search_panel.dart';
import '../search/widgets/evidence_sheet.dart';
import 'people_format.dart';
import 'widgets/dashed_hint.dart';
import 'widgets/day_chat_sheet.dart';
import 'widgets/keyword_cloud.dart';
import 'widgets/monthly_bar_chart.dart';
import 'widgets/people_style.dart';
import 'widgets/period_card.dart';
import 'widgets/person_photo.dart';
import 'widgets/relation_graph.dart';

const _tabLabels = ['송수신', '관계', '상세 설명', '키워드'];

// 사람 한 명의 상세: 송수신 / 관계 / 상세 설명 / 키워드 탭
class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.person,
    required this.people,
    required this.first,
    required this.last,
    required this.start,
    required this.end,
  });

  final String roomId;
  final String roomName;
  final Person person;
  // 같은 대화방의 모든 멤버 (관계·대화에 나온 사람의 사진을 찾는 데 쓴다)
  final List<Person> people;
  // 고를 수 있는 전체 날짜 범위
  final DateTime first;
  final DateTime last;
  // 메인 화면에서 넘어온 분석 기간
  final DateTime start;
  final DateTime end;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  late final StatsRepository _stats;
  late final RelationshipRepository _relationRepo;
  late final PeopleRepository _peopleRepo;

  late DateTime _start;
  late DateTime _end;
  int _tab = 0;

  List<MonthlyCount>? _monthly;
  bool _monthlyFailed = false;
  List<KeywordCount>? _keywords;
  bool _keywordsFailed = false;
  List<Relationship>? _relations;
  bool _relationsFailed = false;

  // 송수신 탭: 보고 있는 연도, 고른 달("2022-05"), 그 달의 날짜별 건수
  int? _year;
  String? _selMonth;
  List<DailyCount>? _daily;
  bool _dailyLoading = false;
  bool _dailyFailed = false;

  int _periodToken = 0;
  int _dailyToken = 0;

  @override
  void initState() {
    super.initState();
    _stats = context.read<StatsRepository>();
    _relationRepo = context.read<RelationshipRepository>();
    _peopleRepo = context.read<PeopleRepository>();
    _start = widget.start;
    _end = widget.end;
    _loadMonthly();
    _loadPeriod();
  }

  String get _pid => widget.person.participantId;

  Future<void> _loadMonthly() async {
    try {
      final list = await _stats.getMonthlyMessageCounts(widget.roomId, _pid);
      if (!mounted) return;
      setState(() => _monthly = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _monthlyFailed = true);
    }
  }

  // 분석 기간에 따라 달라지는 키워드와 관계를 불러온다
  void _loadPeriod() {
    final token = ++_periodToken;
    _loadKeywords(token);
    _loadRelations(token);
  }

  Future<void> _loadKeywords(int token) async {
    try {
      final list = await _stats.getKeywordsByPerson(widget.roomId, _pid, start: _start, end: _end);
      if (!mounted || token != _periodToken) return;
      setState(() => _keywords = list);
    } catch (_) {
      if (!mounted || token != _periodToken) return;
      setState(() => _keywordsFailed = true);
    }
  }

  Future<void> _loadRelations(int token) async {
    try {
      final list = await _relationRepo.getRelationships(widget.roomId, start: _start, end: _end);
      if (!mounted || token != _periodToken) return;
      setState(() => _relations = list);
    } catch (_) {
      if (!mounted || token != _periodToken) return;
      setState(() => _relationsFailed = true);
    }
  }

  void _onPeriod(DateTime s, DateTime e) {
    _dailyToken++;
    setState(() {
      _start = s;
      _end = e;
      _year = null;
      _selMonth = null;
      _daily = null;
      _dailyLoading = false;
      _keywords = null;
      _keywordsFailed = false;
      _relations = null;
      _relationsFailed = false;
    });
    _loadPeriod();
  }

  // 지금 차트에 보여 주는 연도 (기간 밖이면 가까운 연도로 맞춘다)
  int get _currentYear {
    final y = _year ?? _end.year;
    if (y < _start.year) return _start.year;
    if (y > _end.year) return _end.year;
    return y;
  }

  void _moveYear(int delta) {
    _dailyToken++;
    setState(() {
      _year = _currentYear + delta;
      _selMonth = null;
      _daily = null;
      _dailyLoading = false;
    });
  }

  // 분석 기간 안의 달별 건수 ("2022-05" → 건수)
  Map<String, int> get _countByMonth {
    final s = monthKey(_start.year, _start.month);
    final e = monthKey(_end.year, _end.month);
    return {
      for (final m in _monthly ?? const <MonthlyCount>[])
        if (m.month.compareTo(s) >= 0 && m.month.compareTo(e) <= 0) m.month: m.count,
    };
  }

  int get _periodTotal {
    if (_monthly == null) return widget.person.messageCount;
    return _countByMonth.values.fold<int>(0, (a, b) => a + b);
  }

  // 막대를 누르면 그 달의 날짜별 건수를 불러온다 (같은 막대를 다시 누르면 닫는다)
  Future<void> _selectMonth(int month) async {
    final key = monthKey(_currentYear, month);
    if (_selMonth == key) {
      _dailyToken++;
      setState(() {
        _selMonth = null;
        _daily = null;
        _dailyLoading = false;
      });
      return;
    }
    final token = ++_dailyToken;
    setState(() {
      _selMonth = key;
      _daily = null;
      _dailyLoading = true;
      _dailyFailed = false;
    });
    try {
      final list = await _peopleRepo.getDailyCounts(widget.roomId, _pid, key);
      if (!mounted || token != _dailyToken) return;
      setState(() {
        _daily = list;
        _dailyLoading = false;
      });
    } catch (_) {
      if (!mounted || token != _dailyToken) return;
      setState(() {
        _dailyLoading = false;
        _dailyFailed = true;
      });
    }
  }

  String? _avatarOf(String name) {
    for (final p in widget.people) {
      if (p.name == name) return p.avatarUrl;
    }
    return null;
  }

  void _openDay(String date) {
    showDayChatSheet(
      context,
      roomId: widget.roomId,
      roomName: widget.roomName,
      personName: widget.person.name,
      date: date,
      avatars: {for (final p in widget.people) p.name: p.avatarUrl},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _personRow(),
            _tabs(),
            Expanded(child: _tabBody()),
            PeriodCard(first: widget.first, last: widget.last, start: _start, end: _end, onChanged: _onPeriod),
          ],
        ),
      ),
    );
  }

  // 뒤로가기 · 제목 · 검색 버튼
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
      child: Row(
        children: [
          InkResponse(
            radius: 24,
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.chevron_left_rounded, size: 38, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('멤버', style: appText(22, weight: FontWeight.w800))),
          CircleIconButton(icon: Icons.search_rounded, iconColor: AppColors.accent, onPressed: () => openSearchPanel(context)),
        ],
      ),
    );
  }

  // 사진 · 이름 · "대화방 이름 · 건수" 알약
  Widget _personRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          PersonPhoto(name: widget.person.name, avatarUrl: widget.person.avatarUrl, size: 36),
          const SizedBox(width: 12),
          Text(widget.person.name, style: appText(20, weight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: PeopleStyle.tint, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${widget.roomName} · ${formatCount(_periodTotal)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(14, weight: FontWeight.w800, color: AppColors.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 송수신 / 관계 / 상세 설명 / 키워드 탭 줄
  Widget _tabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: PeopleStyle.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabLabels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = i),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == i ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    _tabLabels[i],
                    style: appText(
                      15,
                      weight: _tab == i ? FontWeight.w800 : FontWeight.w500,
                      color: _tab == i ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabBody() {
    final Widget content;
    switch (_tab) {
      case 0:
        content = _trafficTab();
      case 1:
        content = _relationTab();
      case 2:
        content = _aboutTab();
      default:
        content = _keywordTab();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [content],
    );
  }

  // 흰 카드 틀
  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(20)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: PeopleStyle.border),
      ),
      child: child,
    );
  }

  Widget _stateText(String text, {VoidCallback? retry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: appText(13, color: AppColors.textSecondary)),
            if (retry != null) TextButton(onPressed: retry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }

  // ───────── 송수신 탭 ─────────

  Widget _trafficTab() {
    return Column(
      children: [
        _statsCard(),
        const SizedBox(height: 14),
        _dailyArea(),
      ],
    );
  }

  Widget _statsCard() {
    final year = _currentYear;
    final hasPrev = year > _start.year;
    final hasNext = year < _end.year;
    final fromMonth = year == _start.year ? _start.month : 1;
    final toMonth = year == _end.year ? _end.month : 12;
    final months = [for (var m = fromMonth; m <= toMonth; m++) m];
    final byMonth = _countByMonth;
    final counts = {for (final m in months) m: byMonth[monthKey(year, m)] ?? 0};
    final selected = (_selMonth != null && _selMonth!.startsWith('$year-')) ? int.tryParse(_selMonth!.substring(5)) : null;

    final Widget chart;
    if (_monthlyFailed) {
      chart = _stateText('월별 메시지 수를 불러오지 못했어요', retry: () {
        setState(() => _monthlyFailed = false);
        _loadMonthly();
      });
    } else if (_monthly == null) {
      chart = const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()));
    } else if (byMonth.isEmpty) {
      chart = _stateText('이 기간에 보낸 메시지가 없어요');
    } else {
      chart = MonthlyBarChart(months: months, counts: counts, selected: selected, onTap: _selectMonth);
    }

    return _card(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('메신저 통계', style: appText(19, weight: FontWeight.w800)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: PeopleStyle.pill, borderRadius: BorderRadius.circular(14)),
                child: Text('총 ${formatCount(_periodTotal)}', style: appText(13, weight: FontWeight.w800, color: AppColors.textSecondary)),
              ),
              const Spacer(),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('보낸 메시지', style: appText(13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkResponse(
                  radius: 18,
                  onTap: hasPrev ? () => _moveYear(-1) : null,
                  child: Icon(Icons.chevron_left_rounded, size: 26, color: hasPrev ? AppColors.textPrimary : PeopleStyle.barLight),
                ),
                Text('$year년', style: appText(19, weight: FontWeight.w800)),
                if (hasNext)
                  InkResponse(
                    radius: 18,
                    onTap: () => _moveYear(1),
                    child: const Icon(Icons.chevron_right_rounded, size: 26, color: AppColors.textPrimary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          chart,
          const SizedBox(height: 4),
          Center(child: Text('막대를 누르면 그 달의 날짜별 건수를 볼 수 있어요', style: appText(12.5, color: AppColors.chevron))),
        ],
      ),
    );
  }

  // 고른 달이 없으면 점선 안내 칸, 있으면 그 달의 날짜별 건수 목록
  Widget _dailyArea() {
    final key = _selMonth;
    if (key == null) return const DashedHint(text: '막대를 누르면 날짜별 건수가 여기에 나타나요');
    final p = key.split('-');
    final year = int.tryParse(p[0]) ?? _currentYear;
    final month = int.tryParse(p[1]) ?? 1;
    final s = isoDate(_start);
    final e = isoDate(_end);
    final days = [
      for (final d in _daily ?? const <DailyCount>[])
        if (d.date.compareTo(s) >= 0 && d.date.compareTo(e) <= 0) d,
    ];
    final Widget body;
    if (_dailyFailed) {
      body = _stateText('날짜별 건수를 불러오지 못했어요', retry: () {
        final m = int.tryParse(key.substring(5)) ?? 1;
        setState(() => _selMonth = null);
        _selectMonth(m);
      });
    } else if (_dailyLoading) {
      body = const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator()));
    } else if (days.isEmpty) {
      body = _stateText('이 달에 보낸 메시지가 없어요');
    } else {
      body = Column(
        children: [
          for (var i = 0; i < days.length; i++) _dayRow(days[i], showDivider: i > 0),
        ],
      );
    }
    return _card(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$year년 $month월', style: appText(20, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('날짜를 누르면 그 날의 원문 대화를 볼 수 있어요', style: appText(13, color: AppColors.chevron)),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }

  Widget _dayRow(DailyCount d, {required bool showDivider}) {
    final p = d.date.split('-');
    final label = p.length == 3 ? '${int.tryParse(p[1]) ?? p[1]}월 ${int.tryParse(p[2]) ?? p[2]}일' : d.date;
    return Column(
      children: [
        if (showDivider) const Divider(height: 1, thickness: 1, color: Color(0xFFEDF0FA)),
        InkWell(
          onTap: () => _openDay(d.date),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                Expanded(child: Text(label, style: appText(17, weight: FontWeight.w800))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: PeopleStyle.pill, borderRadius: BorderRadius.circular(14)),
                  child: Text(formatCount(d.count), style: appText(14, weight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 26, color: AppColors.chevron),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────── 관계 탭 ─────────

  Widget _relationTab() {
    if (_relationsFailed) {
      return _stateText('관계를 불러오지 못했어요', retry: () {
        setState(() => _relationsFailed = false);
        _loadRelations(_periodToken);
      });
    }
    if (_relations == null) return const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()));
    final name = widget.person.name;
    final mine = _relations!.where((r) => r.source == name || r.target == name).toList()
      // 구체적인 관계(절친 등)를 위로, 기본값("채팅방 참여자")은 아래로 보낸다
      ..sort((a, b) {
        final da = a.relationLabel == '채팅방 참여자' ? 1 : 0;
        final db = b.relationLabel == '채팅방 참여자' ? 1 : 0;
        return da.compareTo(db);
      });
    if (mine.isEmpty) return _stateText('이 기간에 관계 정보가 없어요');
    final nodes = [
      for (final r in mine)
        () {
          final other = r.source == name ? r.target : r.source;
          return RelationNode(
            name: other,
            label: r.relationLabel,
            avatarUrl: _avatarOf(other),
            messageCount: _personByName(other)?.messageCount,
          );
        }(),
    ];
    return _card(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('관계 연결', style: appText(19, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('선택한 사람 기준', style: appText(13, color: AppColors.chevron)),
          RelationGraph(
            centerName: name,
            centerAvatarUrl: widget.person.avatarUrl,
            nodes: nodes,
            onDetail: _openOther,
          ),
        ],
      ),
    );
  }

  Person? _personByName(String name) {
    for (final p in widget.people) {
      if (p.name == name) return p;
    }
    return null;
  }

  // 그래프 카드의 "상세 보기": 그 사람의 상세 화면을 같은 기간으로 연다
  void _openOther(String name) {
    final other = _personByName(name);
    if (other == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PersonDetailScreen(
        roomId: widget.roomId,
        roomName: widget.roomName,
        person: other,
        people: widget.people,
        first: widget.first,
        last: widget.last,
        start: _start,
        end: _end,
      ),
    ));
  }

  // ───────── 상세 설명 탭 ─────────

  Widget _aboutTab() {
    final bio = widget.person.shortBio ?? '';
    final desc = widget.person.description ?? '';
    if (bio.isEmpty && desc.isEmpty) return _stateText('아직 이 사람의 설명이 없어요');
    return Column(
      children: [
        ..._descriptionSections(desc),
        if (bio.isNotEmpty) ...[
          if (desc.isNotEmpty) const SizedBox(height: 12),
          _summaryCard(bio),
        ],
      ],
    );
  }

  // "AI 한 줄 요약" 카드 (오른쪽 아래에 근거 대화 보기)
  Widget _summaryCard(String bio) {
    return _card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('AI 한 줄 요약', style: appText(15, weight: FontWeight.w800, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 12),
          Text(bio, style: appText(16, weight: FontWeight.w700).copyWith(height: 1.55)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: _evidenceLoading ? null : _openEvidence,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _evidenceLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                          const SizedBox(width: 8),
                          Text('근거 대화를 찾는 중이에요…', style: appText(14, weight: FontWeight.w800, color: AppColors.chevron)),
                        ],
                      )
                    : Text('근거 대화 보기', style: appText(14, weight: FontWeight.w800, color: AppColors.accent)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _evidenceLoading = false;

  // 이 사람에 대해 검색해 첫 근거 대화를 연다 (없으면 안내만 한다)
  Future<void> _openEvidence() async {
    if (_evidenceLoading) return;
    setState(() => _evidenceLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await context.read<SearchRepository>().search('${widget.person.name}에 대해 알려줘', chatroomId: widget.roomId);
      if (!mounted) return;
      final src = result.sources.where((s) => s.canOpen).toList();
      if (src.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('근거 대화를 찾지 못했어요')));
      } else {
        await showEvidenceSheet(
          context,
          src.first,
          avatarUrls: {
            for (final p in widget.people)
              if ((p.avatarUrl ?? '').isNotEmpty) p.name: p.avatarUrl!,
          },
        );
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('근거 대화를 불러오지 못했어요')));
    } finally {
      if (mounted) setState(() => _evidenceLoading = false);
    }
  }

  // 상세 설명 글을 "참여 패턴: ..." 같은 줄 단위로 쪼갠다 (이름표가 없는 줄은 앞 항목에 이어 붙인다)
  List<(String, String)> _splitDescription(String text) {
    final out = <(String, String)>[];
    final re = RegExp(r'^\s*([^:：\n]{1,12}?)\s*[:：]\s*(.*)$');
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final m = re.firstMatch(line);
      if (m != null) {
        out.add((m.group(1)!, m.group(2)!.trim()));
      } else if (out.isNotEmpty) {
        out[out.length - 1] = (out.last.$1, '${out.last.$2} $line'.trim());
      } else {
        out.add(('', line));
      }
    }
    return out;
  }

  // 상세 설명을 항목(참여 패턴, 자주 하는 이야기, 말투 등)마다 카드 하나씩으로 보여 준다
  List<Widget> _descriptionSections(String desc) {
    if (desc.isEmpty) return const [];
    final sections = _splitDescription(desc);
    return [
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        _aboutSection(sections[i].$1.isEmpty ? '상세 설명' : sections[i].$1, sections[i].$2),
      ],
    ];
  }

  // 알약 모양 이름표 + 본문
  Widget _aboutSection(String title, String body) {
    return _card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: PeopleStyle.tint, borderRadius: BorderRadius.circular(16)),
            child: Text(title, style: appText(14, weight: FontWeight.w800, color: AppColors.accent)),
          ),
          const SizedBox(height: 14),
          Text(body, style: appText(15, color: AppColors.textSecondary).copyWith(height: 1.65)),
        ],
      ),
    );
  }

  // ───────── 키워드 탭 ─────────

  Widget _keywordTab() {
    if (_keywordsFailed) {
      return _stateText('키워드를 불러오지 못했어요', retry: () {
        setState(() => _keywordsFailed = false);
        _loadKeywords(_periodToken);
      });
    }
    if (_keywords == null) return const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()));
    if (_keywords!.isEmpty) return _stateText('이 기간에 자주 쓴 키워드가 없어요');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('키워드', style: appText(19, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('많이 언급될수록 크게 보여요', style: appText(13, color: AppColors.chevron)),
          KeywordCloud(keywords: _keywords!),
        ],
      ),
    );
  }
}
