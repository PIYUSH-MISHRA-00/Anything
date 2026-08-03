/// SoftwareCognitionCoordinator — the application-facing entry point,
/// mirroring EvolutionCoordinator (V7) / RuntimeIntelligenceCoordinator
/// (V8) / WorldModelCoordinator (V9-V10)'s established role: owns the
/// SoftwareCognitionEngine, bridges its output into the World Graph, and
/// converts an acquired understanding into a real KnowledgeResource so it
/// can flow into `ModelApplicationReasoner`'s prompt through the exact
/// same already-safe, already-tested delimited/sanitized/size-bounded
/// "acquired knowledge" pathway every other web resource already uses
/// (see `lib/synthesis/model_reasoner.dart`) — never a second,
/// parallel prompt-injection surface, and never raw source code, only the
/// distilled RepositorySummary/description text.
///
/// This coordinator is deliberately NOT wired automatically into
/// `AnythingKernel.processIntent` — acquiring and understanding existing
/// software is an explicit, optional step a caller (the composition root,
/// exactly like SearchProvider/WebWeaveXAdapter wiring in
/// `lib/features/home/home_screen.dart`) opts into, not an implicit part
/// of every generation. This mirrors the documented, honest scope
/// boundary already established for `precheckModification()` before V10
/// wired it in, and for `ObservationEngine`'s runtime attachment.
library;

import '../evolution/evolution_context.dart';
import '../evolution/evolution_opportunity.dart';
import '../evolution/evolution_types.dart';
import '../knowledge/knowledge_resource.dart';
import '../world_model/world_model_coordinator.dart';
import 'package_model.dart';
import 'repository_model.dart';
import 'software_cognition_engine.dart';
import 'software_reasoner.dart';

class SoftwareCognitionCoordinator {
  final SoftwareCognitionEngine _engine;
  final SoftwareReasoner _reasoner;

  SoftwareCognitionCoordinator({SoftwareCognitionEngine? engine, SoftwareReasoner reasoner = const SoftwareReasoner()})
    : _engine = engine ?? SoftwareCognitionEngine(),
      _reasoner = reasoner;

  SoftwareCognitionEngine get engine => _engine;

  /// The shared reasoner (Implementation Milestone R15) — exposed the
  /// same way [engine] already is, so a caller acquiring multiple
  /// sources (e.g. `ExperienceCreationCoordinator`) can reuse the EXACT
  /// same `SoftwareReasoner` instance/config `suggestEvolutionOpportunities`
  /// already uses, never a second reasoner.
  SoftwareReasoner get reasoner => _reasoner;

  /// Converts a sound (no critical review issues, transformative digest)
  /// repository understanding into a real KnowledgeResource suitable for
  /// inclusion in a KnowledgeBundle — returns null rather than a
  /// fabricated resource when the understanding did not pass review or
  /// the copyright boundary.
  KnowledgeResource? toKnowledgeResource(RepositoryCognitionResult result) {
    if (!result.isSound) return null;
    final model = result.model;
    final content = model.summary.toDigestText();
    final hash = KnowledgeResource.computeHash(content);
    final uri = Uri.tryParse(model.metadata.provenance.sourceUrl);

    return KnowledgeResource(
      id: 'software-cognition-${DateTime.now().microsecondsSinceEpoch}',
      type: KnowledgeResourceType.repositoryMetadata,
      title: model.metadata.name,
      sourceUri: model.metadata.provenance.sourceUrl,
      sourceDomain: uri?.host ?? 'unknown',
      retrievedAt: model.metadata.provenance.retrievedAt,
      content: content,
      contentHash: hash,
      provenance: ResourceProvenance(
        sourceUrl: model.metadata.provenance.sourceUrl,
        sourceDomain: uri?.host ?? 'unknown',
        retrievedAt: model.metadata.provenance.retrievedAt,
        provider: model.metadata.provenance.provider,
        contentHash: hash,
      ),
      license: model.metadata.provenance.license,
      trust: const TrustMetadata(
        level: TrustLevel.unknown,
        reason: 'Software Cognition understanding, distilled via WebWeaveX; not independently verified.',
        confidence: 0.5,
      ),
      freshness: FreshnessMetadata(lastModified: model.metadata.provenance.retrievedAt),
      ranking: const RankingMetadata(relevanceScore: 0.5, authorityScore: 0.5, freshnessScore: 0.5),
    );
  }

  KnowledgeResource? packageToKnowledgeResource(PackageCognitionResult result) {
    if (!result.isSound) return null;
    final model = result.model;
    final content = 'Package: ${model.metadata.name}\n'
        'Description: ${model.metadata.description}\n'
        'Capabilities: ${model.capabilities.map((c) => c.name).join(', ')}';
    final hash = KnowledgeResource.computeHash(content);
    final uri = Uri.tryParse(model.metadata.provenance.sourceUrl);

    return KnowledgeResource(
      id: 'software-cognition-${DateTime.now().microsecondsSinceEpoch}',
      type: KnowledgeResourceType.packageInformation,
      title: model.metadata.name,
      sourceUri: model.metadata.provenance.sourceUrl,
      sourceDomain: uri?.host ?? 'unknown',
      retrievedAt: model.metadata.provenance.retrievedAt,
      content: content,
      contentHash: hash,
      provenance: ResourceProvenance(
        sourceUrl: model.metadata.provenance.sourceUrl,
        sourceDomain: uri?.host ?? 'unknown',
        retrievedAt: model.metadata.provenance.retrievedAt,
        provider: model.metadata.provenance.provider,
        contentHash: hash,
      ),
      license: model.metadata.provenance.license,
      trust: const TrustMetadata(
        level: TrustLevel.unknown,
        reason: 'Software Cognition understanding, distilled via WebWeaveX; not independently verified.',
        confidence: 0.5,
      ),
      freshness: FreshnessMetadata(lastModified: model.metadata.provenance.retrievedAt),
      ranking: const RankingMetadata(relevanceScore: 0.5, authorityScore: 0.5, freshnessScore: 0.5),
    );
  }

  /// Bridges an acquired repository's understanding into the real World
  /// Graph — the "Software becomes World Graph nodes" requirement.
  void syncToWorldModel(WorldModelCoordinator worldModel, RepositoryModel model) {
    worldModel.ingestSoftwareGraph(model.graph.graph);
  }

  void syncPackageToWorldModel(WorldModelCoordinator worldModel, PackageModel model) {
    worldModel.ingestSoftwareGraph(model.graph.graph);
  }

  /// Available, real, evidence-backed evolution signal: a capability
  /// repeated across multiple acquired repositories that the current
  /// design's context doesn't already declare becomes a real
  /// EvolutionOpportunity in the existing `missingCapability` category —
  /// reusing Evolution's own typed vocabulary rather than inventing a
  /// parallel one. Deliberately additive: a caller merges this list with
  /// `EvolutionObserver.observe()`'s own output; it does not modify
  /// EvolutionObserver or EvolutionContext.
  List<EvolutionOpportunity> suggestEvolutionOpportunities(List<RepositoryModel> acquired, EvolutionContext context) {
    final declaredCapabilities = context.blueprint.requiredCapabilities.toSet();
    final recommendations = _reasoner.reasonAboutRepositories(acquired).where((r) => r.accepted);

    final opportunities = <EvolutionOpportunity>[];
    for (final recommendation in recommendations) {
      final framework = recommendation.tracedTo.isNotEmpty ? recommendation.tracedTo.first.sourceArtifact : '';
      if (framework.isEmpty || declaredCapabilities.contains(framework)) continue;
      opportunities.add(
        EvolutionOpportunity(
          id: 'software-cognition-$framework',
          category: EvolutionOpportunityCategory.missingCapability,
          description: recommendation.description,
          reason: EvolutionReason(
            summary: recommendation.description,
            evidence: EvolutionEvidence(affectedGraph: 'SoftwareCognition', affectedNodeId: framework),
            confidence: recommendation.confidence,
          ),
        ),
      );
    }
    return opportunities;
  }
}
