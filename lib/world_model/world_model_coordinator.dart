/// WorldModelCoordinator — the application-facing entry point, mirroring
/// EvolutionCoordinator (V7) / RuntimeIntelligenceCoordinator (V8)'s
/// role: owns the persistent WorldModel/WorldHistory/WorldMemory, ingests
/// real data from every bridge, and exposes graph-aware pre-checks for
/// Modification.
///
/// "Modification Engine becomes graph-aware": ModificationEngine.modify()
/// itself exposes no pre-flight hook (confirmed by repository audit) and
/// is never modified here — `precheckModification()` is a real, tested,
/// separate call a caller makes BEFORE invoking the existing
/// ModificationEngine/ExperienceModificationCoordinator, exactly the same
/// "real capability, not yet auto-wired into that pipeline" pattern
/// already established for ReviewMemory (V6), EvolutionCoordinator's
/// package-observation gap (V7), and ObservationEngine's
/// ExperienceHostScreen non-wiring (V8).
library;

import '../creation/experience_package.dart';
import '../design_review/review_history.dart';
import '../evolution/evolution_roadmap.dart';
import '../runtime_intelligence/learning_record.dart';
import '../runtime_intelligence/usage_graph.dart';
import '../software_architect/knowledge_graph.dart';
import '../software_cognition/semantic_software_graph.dart';
import '../storage/sqlite_experience_repository.dart';
import '../storage/world_model_repository.dart';
import '../synthesis/app_blueprint.dart' show AppBlueprint;
import 'bridges/evolution_graph_bridge.dart';
import 'bridges/experience_graph_bridge.dart';
import 'bridges/knowledge_graph_bridge.dart';
import 'bridges/review_graph_bridge.dart';
import 'bridges/runtime_graph_bridge.dart';
import 'bridges/software_graph_bridge.dart';
import 'entity_identity.dart';
import 'entity_resolver.dart';
import 'graph_consistency.dart';
import 'impact_analyzer.dart';
import 'world_history.dart';
import 'world_memory.dart';
import 'world_model.dart';
import 'world_model_engine.dart';
import 'world_snapshot.dart';
import 'world_types.dart';

class ModificationImpactCheck {
  final ImpactReport impact;
  final GraphValidation currentGraphValidation;

  const ModificationImpactCheck({required this.impact, required this.currentGraphValidation});

  /// Approved only if the World Graph is currently structurally sound —
  /// the impact report itself is informational either way (an empty
  /// impact list is a valid, honest answer, not a failure).
  bool get approved => currentGraphValidation.isValid;
}

class WorldModelCoordinator {
  final EntityResolver _resolver;
  final KnowledgeGraphBridge _knowledgeBridge;
  final ExperienceGraphBridge _experienceBridge;
  final EvolutionGraphBridge _evolutionBridge;
  final RuntimeGraphBridge _runtimeBridge;
  final ReviewGraphBridge _reviewBridge;
  final SoftwareGraphBridge _softwareBridge;
  final WorldModelEngine _engine;
  final ImpactAnalyzer _impactAnalyzer;
  final GraphConsistency _consistency;

  final WorldHistory history;
  final WorldMemory memory;

  /// Optional real, SQLite-backed persistence (Vision Milestone V10),
  /// resolving V9's own documented limitation that WorldMemory/
  /// WorldHistory never survived a process restart. Deliberately
  /// separate, explicit `persist()`/`restore()` calls rather than making
  /// every `ingest*` method asynchronous — preserving full backward
  /// compatibility with every synchronous call site V9 already
  /// established and tested.
  final WorldModelRepository? _persistence;

  WorldModel _model;

  WorldModelCoordinator({
    EntityResolver resolver = const EntityResolver(),
    KnowledgeGraphBridge? knowledgeBridge,
    ExperienceGraphBridge? experienceBridge,
    EvolutionGraphBridge? evolutionBridge,
    RuntimeGraphBridge? runtimeBridge,
    ReviewGraphBridge? reviewBridge,
    SoftwareGraphBridge? softwareBridge,
    WorldModelEngine engine = const WorldModelEngine(),
    ImpactAnalyzer impactAnalyzer = const ImpactAnalyzer(),
    GraphConsistency consistency = const GraphConsistency(),
    WorldHistory? history,
    WorldMemory? memory,
    WorldModelRepository? persistence,
  }) : _resolver = resolver,
       _knowledgeBridge = knowledgeBridge ?? KnowledgeGraphBridge(resolver: resolver),
       _experienceBridge = experienceBridge ?? ExperienceGraphBridge(resolver: resolver),
       _evolutionBridge = evolutionBridge ?? EvolutionGraphBridge(resolver: resolver),
       _runtimeBridge = runtimeBridge ?? RuntimeGraphBridge(resolver: resolver),
       _reviewBridge = reviewBridge ?? ReviewGraphBridge(resolver: resolver),
       _softwareBridge = softwareBridge ?? SoftwareGraphBridge(resolver: resolver),
       _engine = engine,
       _impactAnalyzer = impactAnalyzer,
       _consistency = consistency,
       history = history ?? WorldHistory(),
       memory = memory ?? WorldMemory(),
       _persistence = persistence,
       _model = engine.empty();

  WorldModel get model => _model;

  void ingestKnowledge(KnowledgeGraph knowledgeGraph) {
    _model = _engine.apply(_model, _knowledgeBridge.bridge(knowledgeGraph), history: history, memory: memory);
  }

  void ingestExperience(ExperienceMetadataRecord metadata, ExperiencePackage package) {
    _model = _engine.apply(_model, _experienceBridge.bridge(metadata, package), history: history, memory: memory);
  }

  /// [blueprint] is optional but strongly recommended (Vision Milestone
  /// V10): when supplied, evolution-affected entities unify with
  /// ExperienceGraphBridge's identity for the same real entity instead
  /// of anchoring on a separate, un-unified node for the raw id.
  void ingestEvolutionRoadmap(EvolutionRoadmap roadmap, {AppBlueprint? blueprint}) {
    _model = _engine.apply(_model, _evolutionBridge.bridge(roadmap, blueprint: blueprint), history: history, memory: memory);
  }

  void ingestUsage(UsageGraph usageGraph) {
    _model = _engine.apply(_model, _runtimeBridge.bridgeUsage(usageGraph), history: history, memory: memory);
  }

  void ingestLearning(List<LearningRecord> learned) {
    _model = _engine.apply(_model, _runtimeBridge.bridgeLearning(learned), history: history, memory: memory);
  }

  void ingestReviewSession(ReviewSession session) {
    _model = _engine.apply(_model, _reviewBridge.bridge(session), history: history, memory: memory);
  }

  /// Ingests a real SemanticSoftwareGraph (Vision Milestone V11's
  /// Software Cognition subsystem) — acquired repositories/packages
  /// become real World Graph nodes, connected the same way every other
  /// graph already is.
  void ingestSoftwareGraph(SemanticSoftwareGraph softwareGraph) {
    _model = _engine.apply(_model, _softwareBridge.bridge(softwareGraph), history: history, memory: memory);
  }

  /// Ingests every real, already-persisted Experience via the existing,
  /// read-only SqliteExperienceRepository — never writes anything to it.
  /// Automatically persists the resulting World Graph afterward when
  /// this coordinator was configured with a WorldModelRepository.
  Future<void> ingestAllPersistedExperiences(SqliteExperienceRepository repository) async {
    for (final metadata in await repository.listAll()) {
      final package = await repository.getPackage(metadata.id);
      if (package == null) continue;
      ingestExperience(metadata, package);
    }
    await persist();
  }

  /// Persists the current World Graph (always the latest state — "no
  /// stale graph") and records a WorldSnapshotRecord audit-trail entry.
  /// A no-op when no WorldModelRepository was configured.
  Future<void> persist() async {
    final persistence = _persistence;
    if (persistence == null) return;
    await persistence.saveGraph(_model.graph);
    await persistence.recordSnapshot(
      WorldSnapshotRecord(
        version: _model.version.number,
        createdAt: _model.version.createdAt,
        nodeCount: _model.graph.nodes.length,
        edgeCount: _model.graph.edges.length,
      ),
    );
  }

  /// Rehydrates this coordinator's World Graph from persistence — the
  /// counterpart to `persist()`, resolving V9's "not yet persisted across
  /// process restarts" limitation. A no-op when no WorldModelRepository
  /// was configured, or when nothing has ever been persisted.
  Future<void> restore() async {
    final persistence = _persistence;
    if (persistence == null) return;
    final graph = await persistence.loadGraph();
    if (graph.nodes.isEmpty && graph.edges.isEmpty) return;
    final history = await persistence.loadSnapshotHistory();
    final latestVersion = history.isEmpty ? 0 : history.last.version;
    _model = WorldModel(graph: graph, context: _model.context, version: WorldVersion(number: latestVersion, createdAt: DateTime.now()));
  }

  ImpactReport impactOf(EntityIdentity identity) => _impactAnalyzer.analyze(_model.graph, identity);

  /// A real, tested pre-check a caller can run before invoking the
  /// EXISTING ModificationEngine — never a replacement for it.
  ModificationImpactCheck precheckModification(String experienceId) {
    final identity = _resolver.resolve(WorldNodeKind.experience, stableId: experienceId);
    return ModificationImpactCheck(impact: impactOf(identity), currentGraphValidation: _consistency.validate(_model.graph));
  }
}
