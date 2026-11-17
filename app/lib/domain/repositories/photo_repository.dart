import 'dart:typed_data';

// 사진 업로드 (서버가 저장하면서 얼굴 벡터를 뽑고, 이름이 있으면 그 사람과 연결한다)
abstract class PhotoRepository {
  // 사진 한 장과 사진 속 인물 이름(없으면 null)을 올리고, 서버가 찾은 얼굴 수를 돌려준다
  Future<int> uploadPhoto({
    required List<int> bytes,
    required String fileName,
    String? name,
  });

  // 이 이름으로 저장된 얼굴을 잘라낸 정사각형 JPEG을 돌려준다 (저장된 얼굴이 없으면 null)
  Future<Uint8List?> getPersonFace(String name);
}
