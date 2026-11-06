import '../models/graph_data.dart';

// 대화방의 지식 그래프(노드·선) 조회
abstract class GraphRepository {
  Future<GraphData> getGraph(String chatroomId);
}
