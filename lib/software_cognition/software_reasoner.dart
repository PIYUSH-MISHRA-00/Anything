/// SoftwareReasoner — the multi-source reasoning pass: acquire multiple
/// repositories, compare them, extract the ideas repeated across
/// candidates (the best-supported, never a single source's
/// implementation), reject weakly-supported or isolated ones, and
/// produce named, evidence-backed recommendations. Never copies, never
/// clones, never emits source code — every SoftwareRecommendation names
/// a pattern/capability/framework choice, not an implementation.
library;

import 'package_model.dart';
import 'repository_model.dart';
import 'software_pattern.dart';
import 'software_similarity.dart';
import 'software_types.dart' show SoftwareConfidence, SoftwareEvidence;

/// A single, evidence-backed suggestion the reasoner produced —
/// `accepted` reflects whether the supporting evidence cleared the
/// acceptance threshold, never a hidden default.
class SoftwareRecommendation {
  final String description;
  final List<SoftwareEvidence> tracedTo;
  final SoftwareConfidence confidence;
  final bool accepted;

  const SoftwareRecommendation({
    required this.description,
    required this.tracedTo,
    required this.confidence,
    required this.accepted,
  });
}

/// Real, deterministic aggregate over one `reasonAboutRepositories`/
/// `reasonAboutPackages` call (Implementation Milestone R15's "Consensus
/// Metadata") — every field is a plain count already implied by the
/// `List<SoftwareRecommendation>` the reasoner returned, never a new
/// inference. `conflicting` is this reasoner's own honest
/// operationalization of "Conflicts": a claim only one source made that
/// no other acquired source corroborated (`accepted == false`) — NOT a
/// detector for two sources actively contradicting each other, since
/// that would require a concern taxonomy (e.g. "these two frameworks are
/// alternative choices for state management") this reasoner has no real
/// signal for. Documented here rather than fabricated.
class CorroborationSummary {
  final int sourceCount;
  final int recommendationsConsidered;
  final int corroborated;
  final int conflicting;

  const CorroborationSummary({
    required this.sourceCount,
    required this.recommendationsConsidered,
    required this.corroborated,
    required this.conflicting,
  });

  factory CorroborationSummary.of(List<SoftwareRecommendation> recommendations, {required int sourceCount}) =>
      CorroborationSummary(
        sourceCount: sourceCount,
        recommendationsConsidered: recommendations.length,
        corroborated: recommendations.where((r) => r.accepted).length,
        conflicting: recommendations.where((r) => !r.accepted).length,
      );
}

class SoftwareReasoner {
  final SoftwareSimilarity _similarity;

  /// A recommendation is only accepted when at least this many acquired
  /// candidates independently support it — the concrete, documented
  /// "never copy a single source" gate.
  final int minSupportingCandidates;

  const SoftwareReasoner({SoftwareSimilarity similarity = const SoftwareSimilarity(), this.minSupportingCandidates = 2})
    : _similarity = similarity;

  /// Compares N acquired repositories and extracts frameworks/patterns
  /// that repeat across candidates as accepted recommendations; anything
  /// seen in only one candidate is reported but rejected — never
  /// silently dropped, so a caller can see what was considered.
  List<SoftwareRecommendation> reasonAboutRepositories(List<RepositoryModel> candidates) {
    if (candidates.isEmpty) return const [];
    final frameworkSupport = <String, List<RepositoryModel>>{};
    for (final candidate in candidates) {
      for (final framework in candidate.frameworks) {
        frameworkSupport.putIfAbsent(framework, () => []).add(candidate);
      }
    }

    final recommendations = <SoftwareRecommendation>[];
    final frameworkNames = frameworkSupport.keys.toList()..sort();
    for (final framework in frameworkNames) {
      final supporters = frameworkSupport[framework]!;
      final accepted = supporters.length >= minSupportingCandidates;
      recommendations.add(
        SoftwareRecommendation(
          description: 'Consider the "$framework" approach — observed in ${supporters.length} of ${candidates.length} acquired repositories.',
          tracedTo: supporters
              .map((s) => SoftwareEvidence(sourceUrl: s.metadata.provenance.sourceUrl, sourceArtifact: framework))
              .toList(),
          confidence: SoftwareConfidence(
            score: supporters.length / candidates.length,
            reason: accepted ? 'repeated across ${supporters.length} independent sources' : 'seen in only ${supporters.length} source(s)',
          ),
          accepted: accepted,
        ),
      );
    }
    return recommendations;
  }

  /// Same repeated-across-candidates gate, for package capabilities.
  List<SoftwareRecommendation> reasonAboutPackages(List<PackageModel> candidates) {
    if (candidates.isEmpty) return const [];
    final capabilitySupport = <String, List<PackageModel>>{};
    for (final candidate in candidates) {
      for (final capability in candidate.capabilities) {
        capabilitySupport.putIfAbsent(capability.name, () => []).add(candidate);
      }
    }

    final recommendations = <SoftwareRecommendation>[];
    final capabilityNames = capabilitySupport.keys.toList()..sort();
    for (final capability in capabilityNames) {
      final supporters = capabilitySupport[capability]!;
      final accepted = supporters.length >= minSupportingCandidates;
      recommendations.add(
        SoftwareRecommendation(
          description: 'Consider the "$capability" capability — observed in ${supporters.length} of ${candidates.length} acquired packages.',
          tracedTo: supporters
              .map((s) => SoftwareEvidence(sourceUrl: s.metadata.provenance.sourceUrl, sourceArtifact: capability))
              .toList(),
          confidence: SoftwareConfidence(
            score: supporters.length / candidates.length,
            reason: accepted ? 'repeated across ${supporters.length} independent sources' : 'seen in only ${supporters.length} source(s)',
          ),
          accepted: accepted,
        ),
      );
    }
    return recommendations;
  }

  /// Detects a SoftwarePattern for every accepted recommendation — the
  /// typed, graph-facing form of the same "repeated across candidates"
  /// evidence.
  SoftwarePatternGraph detectPatterns(List<RepositoryModel> candidates) {
    final accepted = reasonAboutRepositories(candidates).where((r) => r.accepted);
    return SoftwarePatternGraph(
      patterns: accepted
          .map(
            (r) => SoftwarePattern(
              name: r.description.split('"')[1],
              description: r.description,
              supportingEvidence: r.tracedTo,
              confidence: r.confidence,
            ),
          )
          .toList(),
    );
  }

  /// Pairwise similarity across every candidate pair — exposes the
  /// underlying SoftwareSimilarity engine's real, deterministic scores
  /// rather than duplicating comparison logic.
  Map<String, double> pairwiseSimilarity(List<RepositoryModel> candidates) {
    final result = <String, double>{};
    for (var i = 0; i < candidates.length; i++) {
      for (var j = i + 1; j < candidates.length; j++) {
        final key = '${candidates[i].metadata.name}~${candidates[j].metadata.name}';
        result[key] = _similarity.repositorySimilarity(candidates[i], candidates[j]);
      }
    }
    return result;
  }
}
