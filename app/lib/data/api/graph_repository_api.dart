import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../domain/models/graph_data.dart';
import '../../domain/repositories/graph_repository.dart';

// 서버(Flask)의 /graph-data에서 지식 그래프를 가져오는 GraphRepository
class GraphRepositoryApi implements GraphRepository {
  @override
  Future<GraphData> getGraph(String chatroomId) async {
    final uri = Uri.parse('$apiBaseUrl/graph-data').replace(queryParameters: {'user_id': chatroomId, 'domain': 'messenger'});
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('/graph-data 요청 실패 (${res.statusCode})');
    return GraphData.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }
}
