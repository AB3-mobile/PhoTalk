import 'package:flutter/material.dart';

import '../../domain/models/chat_preview.dart';
import '../../domain/models/person.dart';
import '../../domain/models/photo_match.dart';
import '../../domain/repositories/photo_repository.dart';
import 'collect_data.dart';

// 데이터 수집 화면들이 함께 쓰는 상태 (추가한 대화방, 선택한 사진, 입력한 이름, 그래프 작업)
class CollectController extends ChangeNotifier {
  // 사진 선택 화면에서 가져온 실제 사진들 (사진 번호 = 이 목록의 인덱스)
  final List<PickedPhoto> photos = [];
  // 지금까지 서버에 올린 사진 수 (selectedPhotos 앞에서부터 순서대로)
  int uploadedPhotoCount = 0;

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
  // 이미 인덱싱된 대화방의 인물 (사진만 추가할 때 이름 후보로 쓴다)
  final List<Person> knownPeople = [];
  // 사진 번호별 서버 얼굴 매칭 결과 (사진만 추가할 때 이름 자동 채움에 쓴다)
  final Map<int, PhotoMatch> photoMatches = {};
  // 지금 매칭 중인 사진 번호, 매칭 요청이 실패한 사진 번호
  final Set<int> matchingPhotos = {};
  final Set<int> matchFailedPhotos = {};
  // 사용자가 이름을 직접 저장(또는 건너뛰기)한 사진 번호 (자동 채움이 덮어쓰지 않게)
  final Set<int> _nameTouched = {};

  // 이미 아는 사람이 있을 때(사진만 추가할 때)만 얼굴 자동 매칭을 한다
  bool get autoMatchEnabled => knownPeople.isNotEmpty;

  // 매칭 후보 이름 = 고른 대화방 참여자
  List<String> get candidateNames => knownPeople.map((p) => p.name).toList();

  // 선택한 사진 중 아직 매칭하지 않은 사진을 차례로 서버에 보내 얼굴을 매칭하고,
  // 이름을 아직 적지 않은 사진에는 가장 큰 얼굴의 매칭 이름을 채워 둔다 (사용자가 확인·수정한다)
  Future<void> autoMatch(PhotoRepository repo) async {
    if (!autoMatchEnabled) return;
    final candidates = candidateNames;
    for (final id in List.of(selectedPhotos)) {
      if (photoMatches.containsKey(id) || matchingPhotos.contains(id)) continue;
      matchingPhotos.add(id);
      matchFailedPhotos.remove(id);
      notifyListeners();
      try {
        final photo = photos[id];
        final match = await repo.matchPhoto(bytes: photo.bytes, fileName: photo.name, candidates: candidates);
        photoMatches[id] = match;
        final name = match.bestName;
        // 사이에 선택이 바뀌었으면 이름은 채우지 않는다
        if (name != null && selectedPhotos.contains(id) && !_nameTouched.contains(id) && !photoNames.containsKey(id)) {
          photoNames[id] = name;
        }
      } catch (_) {
        matchFailedPhotos.add(id);
      } finally {
        matchingPhotos.remove(id);
        notifyListeners();
      }
    }
  }

  // 이름 후보로 쓸 기존 대화방 인물들을 정한다
  void setKnownPeople(List<Person> people) {
    knownPeople
      ..clear()
      ..addAll(people);
    notifyListeners();
  }

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

  // 고른 사진들을 목록 뒤에 붙이고 새로 붙은 사진 번호들을 돌려준다
  List<int> addPhotos(List<PickedPhoto> picked) {
    final start = photos.length;
    photos.addAll(picked);
    notifyListeners();
    return List.generate(picked.length, (i) => start + i);
  }

  // 사진 선택 결과로 바꾸고, 선택에서 빠진 사진의 이름은 지운다 (선택이 바뀌면 사진 업로드는 처음부터 다시)
  void setSelection(List<int> ids) {
    selectedPhotos
      ..clear()
      ..addAll(ids);
    photoNames.removeWhere((id, _) => !ids.contains(id));
    // 매칭 결과는 사진 번호에 붙어 있으므로 남겨 둬도 되지만, 빠진 사진 것은 정리한다
    photoMatches.removeWhere((id, _) => !ids.contains(id));
    matchFailedPhotos.removeWhere((id) => !ids.contains(id));
    _nameTouched.removeWhere((id) => !ids.contains(id));
    uploadedPhotoCount = 0;
    notifyListeners();
  }

  // 사진 한 장을 서버에 올렸다고 기록한다
  void markPhotoUploaded() {
    uploadedPhotoCount++;
    notifyListeners();
  }

  // 선택한 사진들 (선택 순서 그대로)
  List<PickedPhoto> get selectedPhotoFiles => selectedPhotos.map((id) => photos[id]).toList();

  // 사진 한 장의 인물 이름을 저장한다 (비어 있으면 지운다)
  void setName(int photo, String name) {
    _nameTouched.add(photo);
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
    names.addAll(knownPeople.map((p) => p.name));
    return names.toList();
  }

  // 참여자별 메시지 수
  Map<String, int> get messageCounts {
    final map = <String, int>{};
    for (final p in previews) {
      p.participantCounts.forEach((k, v) => map[k] = (map[k] ?? 0) + v);
    }
    for (final p in knownPeople) {
      map[p.name] = (map[p.name] ?? 0) + p.messageCount;
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
