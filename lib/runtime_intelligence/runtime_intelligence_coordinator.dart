/// RuntimeIntelligenceCoordinator — the application-facing entry point,
/// mirroring EvolutionCoordinator (V7) / ExperienceModificationCoordinator
/// (M2)'s role exactly. Owns the memories that persist across the
/// lifetime of the running app (not the Kernel — Observation is
/// inherently post-Runtime, and Runtime execution happens outside
/// AnythingKernel.processIntent's synchronous flow, confirmed unchanged
/// since V7's own audit finding), attaches ObservationEngine to real
/// runtime sessions, and runs RuntimeIntelligenceEngine on demand.
library;

import '../capabilities/registry/capability_registry.dart';
import '../creation/experience_package.dart';
import '../evolution/evolution_roadmap.dart';
import '../runtime/experience_router.dart';
import '../runtime/query_controller.dart';
import '../storage/sqlite_experience_repository.dart';
import '../storage/world_model_repository.dart';
import '../world_model/world_model_coordinator.dart';
import 'automation_executor.dart';
import 'automation_history.dart';
import 'automation_memory.dart';
import 'collaboration_graph.dart';
import 'experience_relationship_graph.dart';
import 'learning_memory.dart';
import 'observation_context.dart';
import 'observation_engine.dart';
import 'observation_memory.dart';
import 'runtime_intelligence_engine.dart';
import 'runtime_intelligence_result.dart';
import 'session_context.dart';
import 'workspace_context.dart';

class RuntimeIntelligenceCoordinator {
  final ObservationMemory observationMemory;
  final LearningMemory learningMemory;
  final AutomationMemory automationMemory;
  final AutomationHistory automationHistory;
  final RuntimeIntelligenceEngine _engine;
  final AutomationExecutor _executor;

  /// Optional real, SQLite-backed persistence (Vision Milestone V10),
  /// resolving V9's own documented "not yet persisted across process
  /// restarts" limitation for Observation/Learning/Automation history.
  /// Deliberately a separate, explicit `persist()` call rather than
  /// making every existing method asynchronous — preserving full
  /// backward compatibility with every synchronous call site V8/V9
  /// already established and tested.
  final WorldModelRepository? _persistence;

  RuntimeIntelligenceCoordinator({
    ObservationMemory? observationMemory,
    LearningMemory? learningMemory,
    AutomationMemory? automationMemory,
    AutomationHistory? automationHistory,
    RuntimeIntelligenceEngine engine = const RuntimeIntelligenceEngine(),
    AutomationExecutor executor = const AutomationExecutor(),
    WorldModelRepository? persistence,
  }) : observationMemory = observationMemory ?? ObservationMemory(),
       learningMemory = learningMemory ?? LearningMemory(),
       automationMemory = automationMemory ?? AutomationMemory(),
       automationHistory = automationHistory ?? AutomationHistory(),
       _engine = engine,
       _executor = executor,
       _persistence = persistence;

  /// Starts observing a real runtime session — attaches to whichever of
  /// the router/query controllers/state engine the caller passes;
  /// nothing is required, everything optional, since not every screen
  /// has all three.
  ObservationEngine attachSession({
    required String sessionId,
    String? experienceId,
    ExperienceRouter? router,
    List<ExperienceQueryController> queryControllers = const [],
  }) {
    final observationEngine = ObservationEngine(
      memory: observationMemory,
      context: ObservationContext(sessionId: sessionId, experienceId: experienceId, startedAt: DateTime.now()),
    );
    if (router != null) observationEngine.observeRouter(router);
    for (final controller in queryControllers) {
      observationEngine.observeQuery(controller);
    }
    return observationEngine;
  }

  /// Runs the full Learn -> Recommend -> Review -> Predict -> Plan pass
  /// over everything observed so far, validates every resulting
  /// AutomationPlan against the real CapabilityRegistry, and records the
  /// outcome into AutomationHistory/AutomationMemory.
  RuntimeIntelligenceResult runIntelligence({
    required CapabilityRegistry capabilityRegistry,
    EvolutionRoadmap? evolutionRoadmap,
    int minOccurrences = 2,
  }) {
    final result = _engine.run(observationMemory, learningMemory, evolutionRoadmap: evolutionRoadmap, minOccurrences: minOccurrences);

    final version = automationHistory.recordCount + 1;
    for (final plan in result.automationPlans) {
      final report = _executor.validate(plan, capabilityRegistry);
      final record = AutomationRecord(plan: plan, report: report, plannedAt: DateTime.now(), version: version);
      automationHistory.record(record);
      automationMemory.record(record);
    }

    return result;
  }

  /// Experience Runtime -> Observation -> Learning -> World Graph ->
  /// Recommendations -> Automation, as ONE call (Vision Milestone V10) —
  /// runs the full RuntimeIntelligenceEngine pass and immediately syncs
  /// its real UsageGraph and learned patterns into the given
  /// WorldModelCoordinator, instead of a caller having to manually
  /// sequence `runIntelligence()` -> `ingestUsage()` -> `ingestLearning()`
  /// in the right order itself. Attaching ObservationEngine to a live
  /// runtime session remains a separate, explicit `attachSession()` call
  /// (see that method's own docs for why — avoiding an invasive change
  /// to ExperienceHostScreen, unchanged since V8).
  RuntimeIntelligenceResult runAndSyncToWorldModel(
    WorldModelCoordinator worldModel, {
    required CapabilityRegistry capabilityRegistry,
    EvolutionRoadmap? evolutionRoadmap,
    int minOccurrences = 2,
  }) {
    final result = runIntelligence(capabilityRegistry: capabilityRegistry, evolutionRoadmap: evolutionRoadmap, minOccurrences: minOccurrences);
    worldModel.ingestUsage(result.usageGraph);
    worldModel.ingestLearning(result.learned);
    return result;
  }

  WorkspaceContext workspaceContext() {
    final experienceIds = observationMemory.records.map((r) => r.experienceId).whereType<String>().toSet().toList();
    return WorkspaceContext(experienceIds: experienceIds, totalSessions: experienceIds.length);
  }

  /// Builds a structural fingerprint for one Experience from its already-
  /// persisted metadata/package — capability ids and entity field TYPE
  /// names only, never field values or record data.
  ExperienceFingerprint fingerprintOf(ExperienceMetadataRecord metadata, ExperiencePackage package) {
    return ExperienceFingerprint(
      experienceId: metadata.id,
      name: metadata.name,
      capabilityIds: package.capabilityDeclarations.map((c) => c.capabilityId).toList(),
      entityFieldTypeNames: (package.data?.entities ?? const [])
          .expand((entity) => entity.fields)
          .map((field) => field.type)
          .toSet()
          .toList(),
    );
  }

  /// Reads every persisted Experience's package to build a real,
  /// inference-only ExperienceRelationshipGraph. Read-only — never
  /// mutates any Experience.
  Future<ExperienceRelationshipGraph> buildRelationshipGraph(SqliteExperienceRepository repository) async {
    final allMetadata = await repository.listAll();
    final fingerprints = <ExperienceFingerprint>[];
    for (final metadata in allMetadata) {
      final package = await repository.getPackage(metadata.id);
      if (package == null) continue;
      fingerprints.add(fingerprintOf(metadata, package));
    }
    return ExperienceRelationshipGraph.infer(fingerprints);
  }

  Future<CollaborationGraph> buildCollaborationGraph(SqliteExperienceRepository repository) async {
    final relationshipGraph = await buildRelationshipGraph(repository);
    return CollaborationGraph.fromRelationshipGraph(relationshipGraph);
  }

  SessionContext session(String sessionId, {String? experienceId}) =>
      SessionContext(sessionId: sessionId, experienceId: experienceId, startedAt: DateTime.now());

  /// Persists every observation captured so far, plus a real, honest
  /// SUMMARY of learned patterns and planned automations (never a
  /// fabricated full reconstruction of their nested evidence/step data —
  /// see WorldModelRepository's own documentation of this tradeoff). A
  /// no-op when no WorldModelRepository was configured.
  Future<void> persist() async {
    final persistence = _persistence;
    if (persistence == null) return;

    await persistence.recordObservations(observationMemory.records);

    for (final record in learningMemory.records) {
      await persistence.recordLearningSummary(
        PersistedLearningSummary(
          id: record.id,
          patternId: record.pattern.id,
          patternKind: record.pattern.kind,
          description: record.pattern.description,
          confidenceScore: record.pattern.confidence.score,
          confidenceReason: record.pattern.confidence.reason,
          learnedAt: record.learnedAt,
          version: record.version,
        ),
      );
    }

    for (final record in automationHistory.records) {
      await persistence.recordAutomationSummary(
        PersistedAutomationSummary(
          planId: record.plan.id,
          description: record.plan.description,
          allEligible: record.report.allEligible,
          plannedAt: record.plannedAt,
          version: record.version,
        ),
      );
    }
  }

  /// Rehydrates full-fidelity ObservationRecords from persistence into
  /// `observationMemory`. Learning/Automation history is intentionally
  /// NOT auto-rehydrated into `learningMemory`/`automationHistory` — only
  /// a summary was ever persisted for those (see `persist()`), and
  /// fabricating a full `LearningRecord`/`AutomationRecord` with an empty
  /// evidence/step list would misrepresent what was actually observed.
  /// Callers wanting the persisted summaries directly should query
  /// WorldModelRepository's own `loadLearningSummaries()`/
  /// `loadAutomationSummaries()`.
  Future<void> restoreObservations() async {
    final persistence = _persistence;
    if (persistence == null) return;
    for (final record in await persistence.loadObservations()) {
      observationMemory.record(record);
    }
  }
}
