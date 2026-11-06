// 서버 /graph-data가 주는 그래프 노드 한 개 (GraphRAG가 뽑은 엔티티)
class GraphDataNode {
  const GraphDataNode({
    required this.id,
    required this.label,
    required this.entityType,
    this.description,
    this.degree = 0,
  });

  final String id;
  final String label;
  // CHATROOM / PERSON / KEYWORD / ATTACHMENT / DATE / NAMEDENTITY / EVENT 등 서버가 주는 종류
  final String entityType;
  final String? description;
  // 이 노드에 이어진 선의 개수
  final int degree;

  // 서버 JSON 한 항목에서 노드를 만든다
  factory GraphDataNode.fromJson(Map<String, dynamic> json) => GraphDataNode(
        id: '${json['id']}',
        label: (json['label'] ?? json['id']).toString(),
        entityType: (json['entity_type'] ?? '').toString(),
        description: json['description'] as String?,
        degree: (json['degree'] as num?)?.toInt() ?? 0,
      );
}

// 서버 /graph-data가 주는 선 한 개 (두 노드의 관계)
class GraphDataEdge {
  const GraphDataEdge({required this.source, required this.target, this.description, this.weight});

  final String source;
  final String target;
  final String? description;
  // 관계의 가중치 (클수록 선이 굵다)
  final double? weight;

  // 서버 JSON 한 항목에서 선을 만든다
  factory GraphDataEdge.fromJson(Map<String, dynamic> json) => GraphDataEdge(
        source: '${json['source']}',
        target: '${json['target']}',
        description: json['description'] as String?,
        weight: (json['weight'] as num?)?.toDouble(),
      );
}

// 한 대화방의 지식 그래프 전체 (노드와 선)
class GraphData {
  const GraphData({required this.nodes, required this.edges});

  final List<GraphDataNode> nodes;
  final List<GraphDataEdge> edges;

  // 서버 /graph-data 응답에서 그래프를 만든다
  factory GraphData.fromJson(Map<String, dynamic> json) => GraphData(
        nodes: (json['nodes'] as List? ?? []).map((e) => GraphDataNode.fromJson(e as Map<String, dynamic>)).toList(),
        edges: (json['edges'] as List? ?? []).map((e) => GraphDataEdge.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
