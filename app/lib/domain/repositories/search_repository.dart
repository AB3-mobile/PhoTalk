import '../models/chat_block.dart';
import '../models/search_result.dart';

// 자연어 검색과 근거 원문 조회
abstract class SearchRepository {
  Future<SearchResult> search(String query, {String? chatroomId});

  Future<ChatBlock> getChatBlock(String chatroomId, String blockId);
}
