/// Shared vocabulary for the Software Cognition subsystem (Vision
/// Milestone V11) — mirrors the World Graph's proven
/// `{identity, kind, label}` node / typed-relationship-kind edge shape
/// (`lib/world_model/world_types.dart`) so a SemanticSoftwareGraph bridges
/// into the World Graph the same way every other graph already does.
library;

import '../software_architect/confidence.dart';

/// What kind of software artifact a SoftwareNode represents.
enum SoftwareNodeKind {
  repository,
  package,
  library,
  file,
  classType,
  function,
  widget,
  component,
  entity,
  capability,
  endpoint,
  schema,
  database,
  architectureLayer,
}

/// A typed relationship between two software artifacts — never a raw
/// string, never inferred from a keyword.
enum SoftwareRelationshipKind {
  contains,
  dependsOn,
  imports,
  calls,
  implements_,
  exposes,
  references,
  derivedFrom,
  similarTo,
}

/// SoftwareConfidence reuses the same typed confidence vocabulary already
/// proven across the Software Architect / Solution Reasoning / Evolution
/// engines (score + reason + risk + alternatives) — never a second,
/// parallel confidence type.
typedef SoftwareConfidence = Confidence;

/// Points to exactly what produced a software-cognition fact — which
/// acquisition, which source artifact — mirroring the "never a vague
/// claim" evidence pattern already used by GraphEvidence (World Model)
/// and EvolutionEvidence.
class SoftwareEvidence {
  final String sourceUrl;
  final String sourceArtifact;

  const SoftwareEvidence({required this.sourceUrl, required this.sourceArtifact});
}
