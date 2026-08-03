/// AutonomousKnowledgeAcquisitionPlanner — Implementation Milestone R16.
///
/// REALITY this milestone builds on: `SemanticApp.knowledgeNeeds`
/// (`lib/synthesis/application_reasoner.dart`) is a real field the SINGLE
/// existing reasoning call (`ApplicationReasoner.reason`, via
/// `model_reasoner.dart`'s `knowledgeNeeds` JSON key) already populates on
/// its final, successful result — not just the intermediate
/// `ReasoningKnowledgeRequired` knowledge-loop path. Confirmed by
/// repository-wide grep that nothing downstream ever read this field
/// before this milestone: a real, orphaned signal, the same shape as V11's
/// `SoftwareCognitionCoordinator` before R14 wired it in.
///
/// This planner is a DETERMINISTIC, zero-new-LLM-call transformation of
/// that already-reasoned signal into a ranked acquisition plan — it never
/// invents a knowledge need the reasoner did not already name, and it
/// never re-reasons. This is what "planner reasoning happens inside the
/// existing reasoning boundary; everything afterwards remains
/// deterministic" means in practice: the judgment already happened, inside
/// the one AI call; this planner only structures its already-real output.
library;

import '../synthesis/application_reasoner.dart' show SemanticApp;

/// What kind of source a [KnowledgeTarget] names. Only [repository]/
/// [package] are actionable by this milestone's acquisition step —
/// Software Cognition's `RepositoryAnalyzer` understands repositories
/// specifically, not arbitrary API docs/reference pages (that is
/// Pipeline A's job, `KnowledgeAcquisitionEngine`, already autonomous
/// since before this milestone). [documentation]/[api]/[general] targets
/// are still planned and ranked for visibility, honestly left unactioned.
enum KnowledgeSourceCategory { repository, package, documentation, api, general }

/// Real, deterministic, non-exhaustive mapping from the reasoner's own
/// freeform `resourceType` string to a source category this planner can
/// act on — same documented "known hints" convention as
/// `_authDependencyHints` (`architecture_analyzer.dart`, R14). Confirmed
/// by reading `model_reasoner.dart`'s `_systemPrompt`/`_jsonSchema` that
/// the live prompt never actually teaches the model these category names
/// today, so in practice most `resourceType` values default to
/// `'domainKnowledge'` — this mapping is honest about existing today for
/// the (currently rare, but real and unmodified) case the model does emit
/// one of these values, never a claim that classification is reliable.
const Map<String, KnowledgeSourceCategory> _resourceTypeCategories = {
  'repository': KnowledgeSourceCategory.repository,
  'repositorymetadata': KnowledgeSourceCategory.repository,
  'package': KnowledgeSourceCategory.package,
  'packageinformation': KnowledgeSourceCategory.package,
  'externalapi': KnowledgeSourceCategory.api,
  'protocol': KnowledgeSourceCategory.api,
  'integrationdocumentation': KnowledgeSourceCategory.documentation,
  'technicalreference': KnowledgeSourceCategory.documentation,
};

KnowledgeSourceCategory _categorize(String resourceType) =>
    _resourceTypeCategories[resourceType.toLowerCase()] ?? KnowledgeSourceCategory.general;

/// One planned knowledge-acquisition target — a real, structured
/// restatement of one `SynthesisKnowledgeRequirement` the reasoner already
/// emitted. Every field is derived from a real, already-present source
/// field; nothing here is fabricated.
class KnowledgeTarget {
  /// The reasoner's own requirement id.
  final String id;

  /// The reasoner's own query text — used verbatim as the search query.
  final String query;

  final KnowledgeSourceCategory sourceCategory;

  /// Mirrors `SynthesisKnowledgeRequirement.required` — whether the
  /// reasoner flagged this as needed to proceed at all, vs. merely useful.
  final bool evidenceRequirement;

  /// Reflects only how firmly the reasoner flagged this need (required
  /// vs. optional) — never a claim about acquisition success, which is
  /// unknown until a real search/understanding attempt is made.
  final double confidence;

  /// 0 = required (acquired first), 1 = optional.
  final int priority;

  /// This target's position in `SemanticApp.knowledgeNeeds` as the
  /// reasoner originally listed it (before priority sorting) — the real,
  /// traceable "the reasoner asked for this Nth" fact `targets`' final
  /// list order (after priority sort) represents actual acquisition
  /// order; this field preserves provenance of the original position.
  final int acquisitionOrder;

  /// Always `'search+understand'` today: `SearchProvider.search` then
  /// `SoftwareCognitionEngine.understandRepositoryFromUrl` — the only
  /// strategy this milestone implements. A real, named field rather than
  /// a hardcoded assumption, so a future milestone can add a second
  /// strategy without changing this type's shape.
  final String acquisitionStrategy;

  /// The reasoner's own stated purpose for this requirement.
  final String expectedContribution;

  const KnowledgeTarget({
    required this.id,
    required this.query,
    required this.sourceCategory,
    required this.evidenceRequirement,
    required this.confidence,
    required this.priority,
    required this.acquisitionOrder,
    required this.acquisitionStrategy,
    required this.expectedContribution,
  });

  bool get isActionable =>
      sourceCategory == KnowledgeSourceCategory.repository || sourceCategory == KnowledgeSourceCategory.package;
}

/// Real output type: targets in final acquisition order (required first,
/// then as originally listed).
class AutonomousKnowledgeAcquisitionPlan {
  final List<KnowledgeTarget> targets;

  const AutonomousKnowledgeAcquisitionPlan({this.targets = const []});

  List<KnowledgeTarget> get actionableTargets => targets.where((t) => t.isActionable).toList();
}

class AutonomousKnowledgeAcquisitionPlanner {
  const AutonomousKnowledgeAcquisitionPlanner();

  AutonomousKnowledgeAcquisitionPlan plan(SemanticApp app) {
    final needs = app.knowledgeNeeds;
    if (needs.isEmpty) return const AutonomousKnowledgeAcquisitionPlan();

    final targets = <KnowledgeTarget>[];
    for (var i = 0; i < needs.length; i++) {
      final need = needs[i];
      if (need.query.trim().isEmpty) continue;
      targets.add(
        KnowledgeTarget(
          id: need.id,
          query: need.query,
          sourceCategory: _categorize(need.resourceType),
          evidenceRequirement: need.required,
          confidence: need.required ? 0.8 : 0.4,
          priority: need.required ? 0 : 1,
          acquisitionOrder: i,
          acquisitionStrategy: 'search+understand',
          expectedContribution: need.purpose,
        ),
      );
    }
    // Stable sort: required targets first, optional after — original
    // reasoning order preserved within each group.
    targets.sort((a, b) => a.priority.compareTo(b.priority));
    return AutonomousKnowledgeAcquisitionPlan(targets: targets);
  }
}
