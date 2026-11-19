import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 최근 검색어를 기기에 저장해 두는 목록 (최신순, 중복 없이 최대 10개)
class RecentSearches extends ChangeNotifier {
  RecentSearches() {
    _load();
  }

  static const _key = 'recent_searches';
  static const _max = 10;

  List<String> _items = [];
  List<String> get items => List.unmodifiable(_items);

  // 저장된 목록을 읽어 온다 (읽지 못하면 빈 목록으로 둔다)
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _items = prefs.getStringList(_key) ?? [];
      notifyListeners();
    } catch (_) {}
  }

  // 현재 목록을 기기에 저장한다
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _items);
    } catch (_) {}
  }

  // 검색어를 맨 앞에 넣는다 (이미 있으면 앞으로 옮긴다)
  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    _items = [q, ..._items.where((e) => e != q)].take(_max).toList();
    notifyListeners();
    _save();
  }

  // 검색어 하나를 지운다
  void remove(String query) {
    _items = _items.where((e) => e != query).toList();
    notifyListeners();
    _save();
  }

  // 모든 검색어를 지운다
  void clear() {
    _items = [];
    notifyListeners();
    _save();
  }
}
