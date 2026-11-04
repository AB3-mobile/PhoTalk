import '../../domain/models/chat_block.dart';
import '../../domain/models/search_result.dart';
import '../../domain/repositories/search_repository.dart';
import 'mock_loader.dart';

// 서버 없이 더미 JSON으로 동작하는 SearchRepository (질문과 상관없이 같은 답을 준다)
class SearchRepositoryMock implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? chatroomId}) async {
    final json = await loadMockJson('search') as Map<String, dynamic>;
    return SearchResult.fromJson(json);
  }

  @override
  Future<ChatBlock> getChatBlock(String chatroomId, String blockId) async {
    final json = await loadMockJson('chat_blocks') as Map<String, dynamic>;
    final block = json[blockId] as Map<String, dynamic>?;
    if (block == null) {
      throw StateError('대화를 찾을 수 없습니다: $blockId');
    }
    return ChatBlock.fromJson(block);
  }
}
