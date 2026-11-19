import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../domain/models/chat_block.dart';
import '../../domain/models/search_result.dart';
import '../../domain/repositories/search_repository.dart';
import 'api_post.dart';

// 서버의 /run-query-async 와 /job-status 로 모든 대화방을 검색하는 SearchRepository
class SearchRepositoryApi implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? chatroomId}) async {
    // 서버가 인덱싱된 모든 대화방을 함께 검색하므로 chatroomId는 비어 있지만 않으면 된다
    final start = await apiPost('/run-query-async', {
      'message': query,
      'user_id': chatroomId ?? '',
      'domain': 'messenger',
      'resMethod': 'local',
    });
    final jobId = start['jobId'] as String;
    // 답이 끝날 때까지 1.5초마다 물어본다 (최대 4분)
    for (var i = 0; i < 160; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      final res = await http.get(Uri.parse('$apiBaseUrl/job-status/$jobId'));
      if (res.statusCode != 200) throw Exception('/job-status 요청 실패 (${res.statusCode})');
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final status = json['status'] as String?;
      if (status == 'done') return SearchResult.fromJson(json);
      if (status == 'error') throw Exception(json['result'] ?? '검색 중 오류가 났어요');
    }
    throw Exception('검색 시간이 너무 오래 걸려요');
  }

  @override
  Future<ChatBlock> getChatBlock(String chatroomId, String blockId) async {
    final json = await apiPost('/messenger-body-by-ids', {'account': chatroomId, 'mail_id': blockId});
    return ChatBlock.fromJson(json as Map<String, dynamic>);
  }
}
