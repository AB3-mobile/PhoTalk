import '../../domain/models/relationship.dart';
import '../../domain/repositories/relationship_repository.dart';
import 'mock_loader.dart';

// 서버 없이 더미 JSON으로 동작하는 RelationshipRepository
class RelationshipRepositoryMock implements RelationshipRepository {
  @override
  Future<List<Relationship>> getRelationships(
    String chatroomId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final json = await loadMockJson('relationships') as Map<String, dynamic>;
    final list = json[chatroomId] as List? ?? [];
    return list
        .map((e) => Relationship.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
