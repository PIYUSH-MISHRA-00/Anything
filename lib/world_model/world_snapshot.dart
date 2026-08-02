/// WorldSnapshot/WorldVersion — every state the World Graph has ever
/// been in, versioned and timestamped, mirroring the established
/// versioning discipline from LearningMemory (V8) and ReviewHistory (V6).
library;

import 'world_graph.dart';

class WorldVersion {
  final int number;
  final DateTime createdAt;

  const WorldVersion({required this.number, required this.createdAt});
}

class WorldSnapshot {
  final WorldVersion version;
  final WorldGraph graph;

  const WorldSnapshot({required this.version, required this.graph});

  int get nodeCount => graph.nodes.length;

  int get edgeCount => graph.edges.length;
}
