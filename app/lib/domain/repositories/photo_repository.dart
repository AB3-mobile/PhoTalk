import 'dart:typed_data';

import '../models/photo_match.dart';

// 사진 업로드 (서버가 저장하면서 얼굴 벡터를 뽑고, 이름이 있으면 그 사람과 연결한다)
abstract class PhotoRepository {
  // 사진 한 장과 사진 속 인물 이름(없으면 null)을 올리고, 서버가 찾은 얼굴 수를 돌려준다
  // candidates가 있으면 이름 붙이지 않은 나머지 얼굴의 자동 매칭을 그 이름들로만 제한한다
  Future<int> uploadPhoto({
    required List<int> bytes,
    required String fileName,
    String? name,
    List<String>? candidates,
  });

  // 저장하지 않고 사진 속 얼굴들을 이미 아는 사람(candidates가 있으면 그 이름들)과 비교한 결과를 돌려준다
  Future<PhotoMatch> matchPhoto({
    required List<int> bytes,
    required String fileName,
    List<String>? candidates,
  });

  // 이 이름으로 저장된 얼굴을 잘라낸 정사각형 JPEG을 돌려준다 (저장된 얼굴이 없으면 null)
  Future<Uint8List?> getPersonFace(String name);
}
