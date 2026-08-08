/// SoftwareNode / SoftwareEdge — the one shared shape every part of the
/// Software Graph reuses, mirroring WorldNode/WorldEdge's proven
/// `{identity, kind, label}` pattern exactly.
library;

import 'software_identity.dart';
import 'software_types.dart';

class SoftwareNode {
  final SoftwareIdentity identity;
  final SoftwareNodeKind kind;
  final String label;

  const SoftwareNode({
    required this.identity,
    required this.kind,
    required this.label,
  });

  String get id => identity.value;
}

class SoftwareEdge {
  final SoftwareIdentity fromId;
  final SoftwareIdentity toId;
  final SoftwareRelationshipKind kind;
  final SoftwareEvidence evidence;

  const SoftwareEdge({
    required this.fromId,
    required this.toId,
    required this.kind,
    required this.evidence,
  });
}
