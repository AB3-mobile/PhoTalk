import '../../domain/models/relationship.dart';
import '../../domain/repositories/relationship_repository.dart';
import 'api_post.dart';

// 서버(Flask)에서 참여자 사이 관계를 가져오는 RelationshipRepository
class RelationshipRepositoryApi implements RelationshipRepository {
  @override
  Future<List<Relationship>> getRelationships(
    String chatroomId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final json = await apiPost('/chatroom-relationships', {
      'chatroom_id': chatroomId,
      'start_date': apiDate(start),
      'end_date': apiDate(end),
    });
    return (json['data']['relationships'] as List).map((e) => Relationship.fromJson(e as Map<String, dynamic>)).toList();
  }
}
