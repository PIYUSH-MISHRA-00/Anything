/// WorldNode — the one shared node shape every part of the World Graph
/// reuses, mirroring DependencyNode (V4) / EvolutionGraphNode (V7) /
/// RilNode (V8)'s proven `{id, kind, label}` pattern exactly.
library;

import 'entity_identity.dart';
import 'world_types.dart';

class WorldNode {
  final EntityIdentity identity;
  final WorldNodeKind kind;
  final String label;

  const WorldNode({required this.identity, required this.kind, required this.label});

  String get id => identity.value;
}
