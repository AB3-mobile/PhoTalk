import 'package:flutter/foundation.dart';

import '../../domain/models/search_result.dart';
import '../../domain/repositories/chatroom_repository.dart';
import '../../domain/repositories/search_repository.dart';

// 검색 화면의 진행 상태
enum SearchPhase { idle, loading, done, empty, error }

// 한 번의 검색 흐름(입력 → 검색 중 → 결과/없음/오류)을 들고 있는 상태
class SearchSession extends ChangeNotifier {
  SearchSession(this._search, this._rooms);

  final SearchRepository _search;
  final ChatroomRepository _rooms;

  SearchPhase phase = SearchPhase.idle;
  String query = '';
  SearchResult? result;
  String? error;
  // 취소하거나 새로 검색했을 때 이전 검색의 늦은 답을 버리려고 쓰는 번호
  int _ticket = 0;

  // 질문을 검색한다 (인덱싱된 모든 대화방을 서버가 함께 찾는다)
  Future<void> run(String text) async {
    final q = text.trim();
    if (q.isEmpty) return;
    final ticket = ++_ticket;
    query = q;
    phase = SearchPhase.loading;
    result = null;
    error = null;
    notifyListeners();
    try {
      final rooms = (await _rooms.getChatrooms()).where((r) => r.indexed).toList();
      if (rooms.isEmpty) throw Exception('그래프가 만들어진 대화방이 없어요');
      final r = await _search.search(q, chatroomId: rooms.first.id);
      if (ticket != _ticket) return;
      result = r;
      phase = r.isEmpty ? SearchPhase.empty : SearchPhase.done;
    } catch (e) {
      if (ticket != _ticket) return;
      error = e.toString().replaceFirst('Exception: ', '');
      phase = SearchPhase.error;
    }
    notifyListeners();
  }

  // 진행 중인 검색을 그만두고 입력 상태로 돌아간다
  void cancel() {
    _ticket++;
    phase = SearchPhase.idle;
    notifyListeners();
  }

  // 결과를 지우고 입력 상태로 돌아간다
  void reset() => cancel();
}
