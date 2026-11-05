import 'package:flutter/material.dart';

import '../../domain/models/chat_preview.dart';
import 'collect_data.dart';

// 데이터 수집 화면들이 함께 쓰는 상태 (추가한 대화방, 선택한 사진, 입력한 이름, 그래프 작업)
class CollectController extends ChangeNotifier {
  // 지금 갤러리에 있다고 가정하는 더미 사진 수 (실제 갤러리 연결 전까지)
  static const int totalPhotos = 24;

  // 추가는 했지만 "그래프 만들기"를 누르기 전이라 서버에 올리지 않은 대화방들
  final List<PickedChat> pendingChats = [];
  // 지금까지 서버에 올린 대화방 수 (pendingChats 앞에서부터 순서대로)
  int uploadedCount = 0;
  // 서버가 시작한 그래프 구축 작업 ID들 (진행률 조회용)
  final List<String> graphJobIds = [];
  // 서버가 정한 대화방 ID들 (관계 조회용)
  final List<String> roomIds = [];
  // 선택한 사진 번호 (선택한 순서 그대로)
  final List<int> selectedPhotos = [];
  // 사진 번호별로 입력한 인물 이름
  final Map<int, String> photoNames = {};

  // 대화방을 목록에 추가한다 (서버 업로드는 그래프 만들기 때 한다)
  void addPending(PickedChat chat) {
    pendingChats.add(chat);
    notifyListeners();
  }

  // i번째 대화방을 새 값으로 바꾼다 (파일이나 표시 이름을 고쳤을 때)
  void replacePending(int index, PickedChat chat) {
    pendingChats[index] = chat;
    notifyListeners();
  }

  // i번째 대화방을 목록에서 뺀다
  void removePending(int index) {
    pendingChats.removeAt(index);
    notifyListeners();
  }

  // 서버에 올린 대화방 하나의 결과를 기록한다
  void markUploaded({String? graphJobId, String? roomId}) {
    uploadedCount++;
    if (graphJobId != null && !graphJobIds.contains(graphJobId)) graphJobIds.add(graphJobId);
    if (roomId != null && !roomIds.contains(roomId)) roomIds.add(roomId);
    notifyListeners();
  }

  // 사진 선택 결과로 바꾸고, 선택에서 빠진 사진의 이름은 지운다
  void setSelection(List<int> ids) {
    selectedPhotos
      ..clear()
      ..addAll(ids);
    photoNames.removeWhere((id, _) => !ids.contains(id));
    notifyListeners();
  }

  // 사진 한 장의 인물 이름을 저장한다 (비어 있으면 지운다)
  void setName(int photo, String name) {
    final n = name.trim();
    if (n.isEmpty) {
      photoNames.remove(photo);
    } else {
      photoNames[photo] = n;
    }
    notifyListeners();
  }

  int get photoCount => selectedPhotos.length;
  int get namedCount => photoNames.length;

  // 추가한 대화방들의 미리보기
  List<ChatPreview> get previews => pendingChats.map((c) => c.preview).toList();

  // 이름 자동완성에 쓸 대화 참여자 이름 목록 (중복 없음)
  List<String> get participantNames {
    final names = <String>{};
    for (final p in previews) {
      names.addAll(p.participants);
    }
    return names.toList();
  }

  // 참여자별 메시지 수
  Map<String, int> get messageCounts {
    final map = <String, int>{};
    for (final p in previews) {
      p.participantCounts.forEach((k, v) => map[k] = (map[k] ?? 0) + v);
    }
    return map;
  }

  // 모든 대화방의 메시지 수 합계
  int get messageTotal => previews.fold(0, (sum, p) => sum + p.messageCount);

  // 모든 대화방의 참여자를 중복 없이 센 수
  int get participantTotal => participantNames.length;

  // 가장 이른 날짜와 가장 늦은 날짜 (모르면 null)
  DateTimeRange? get period {
    DateTime? s;
    DateTime? e;
    for (final p in previews) {
      if (p.start != null && (s == null || p.start!.isBefore(s))) s = p.start;
      if (p.end != null && (e == null || p.end!.isAfter(e))) e = p.end;
    }
    return (s == null || e == null) ? null : DateTimeRange(start: s, end: e);
  }
}
