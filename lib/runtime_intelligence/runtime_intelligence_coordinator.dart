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

  RuntimeIntelligenceCoordinator({
    ObservationMemory? observationMemory,
    LearningMemory? learningMemory,
    AutomationMemory? automationMemory,
    AutomationHistory? automationHistory,
    RuntimeIntelligenceEngine engine = const RuntimeIntelligenceEngine(),
    AutomationExecutor executor = const AutomationExecutor(),
  }) : observationMemory = observationMemory ?? ObservationMemory(),
       learningMemory = learningMemory ?? LearningMemory(),
       automationMemory = automationMemory ?? AutomationMemory(),
       automationHistory = automationHistory ?? AutomationHistory(),
       _engine = engine,
       _executor = executor;

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
}
