import '../models/relationship.dart';

// 참여자 사이 관계 조회
abstract class RelationshipRepository {
  Future<List<Relationship>> getRelationships(
    String chatroomId, {
    required DateTime start,
    required DateTime end,
  });
}
