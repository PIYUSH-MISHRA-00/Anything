/// SoftwarePattern / SoftwarePatternGraph — a structural regularity
/// observed across two or more acquired software understandings (e.g.
/// "these repositories share a dependency that implies an offline-first
/// architecture"). Every pattern traces to real, named evidence from the
/// candidates that produced it — never a template, never fabricated from
/// a single source.
library;

import 'software_types.dart' show SoftwareConfidence, SoftwareEvidence;

class SoftwarePattern {
  final String name;
  final String description;
  final List<SoftwareEvidence> supportingEvidence;
  final SoftwareConfidence confidence;

  const SoftwarePattern({
    required this.name,
    required this.description,
    required this.supportingEvidence,
    required this.confidence,
  });
}

class SoftwarePatternGraph {
  final List<SoftwarePattern> patterns;

  const SoftwarePatternGraph({this.patterns = const []});
}
