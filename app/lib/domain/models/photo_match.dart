// 사진 속 얼굴 하나를 아는 사람과 비교한 결과 (매칭 안 됐으면 name이 null)
class FaceMatch {
  const FaceMatch({this.name, this.similarity});

  final String? name;
  // 코사인 유사도 (0~1, 매칭 안 됐으면 null)
  final double? similarity;

  factory FaceMatch.fromJson(Map<String, dynamic> json) => FaceMatch(
        name: json['name'] as String?,
        similarity: (json['similarity'] as num?)?.toDouble(),
      );
}

// 사진 한 장의 얼굴 매칭 결과 (/photo-match). 얼굴은 큰 순서대로 온다.
class PhotoMatch {
  const PhotoMatch({required this.faceCount, required this.faces});

  final int faceCount;
  final List<FaceMatch> faces;

  factory PhotoMatch.fromJson(Map<String, dynamic> json) => PhotoMatch(
        faceCount: json['face_count'] as int? ?? 0,
        faces: [
          for (final f in (json['faces'] as List? ?? const [])) FaceMatch.fromJson(f as Map<String, dynamic>),
        ],
      );

  // 이 사진의 주인공 = 가장 큰 얼굴 (업로드할 때 이름이 이 얼굴에 확정된다)
  FaceMatch? get main => faces.isEmpty ? null : faces.first;
  String? get bestName => main?.name;
  double? get bestSimilarity => main?.similarity;
}
