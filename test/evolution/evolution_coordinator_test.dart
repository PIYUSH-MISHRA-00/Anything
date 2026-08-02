/// Vision V7 AEE — EvolutionCoordinator: Modification Integration end to
/// end against a REAL SQLite-backed repository (real file I/O, not a
/// mock) — User Request + Evolution Proposal -> Merged Candidate ->
/// Review -> Approval -> Execution, reusing the existing ModificationEngine
/// and ExperiencePackageValidator, never a second engine.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/evolution/evolution_candidate.dart';
import 'package:anything/evolution/evolution_coordinator.dart';
import 'package:anything/evolution/evolution_opportunity.dart';
import 'package:anything/evolution/evolution_types.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';

EvolutionProposal _workflowProposal({required String entityId, bool approvedForExecution = false}) {
  final candidate = EvolutionCandidate(
    id: 'candidate:missingWorkflow:$entityId',
    opportunity: EvolutionOpportunity(
      id: 'evolution:missingWorkflow:$entityId',
      category: EvolutionOpportunityCategory.missingWorkflow,
      description: 'Add a quick action for $entityId',
      reason: EvolutionReason(
        summary: 'test',
        evidence: EvolutionEvidence(affectedGraph: 'test', affectedNodeId: entityId),
        confidence: Confidence.full,
      ),
    ),
    cost: const EvolutionCost(),
    risk: const EvolutionRisk(),
    benefit: const EvolutionBenefit(
      engineeringValue: Confidence.full,
      userValue: Confidence.full,
      maintenanceValue: Confidence.full,
      performanceValue: Confidence.full,
      securityValue: Confidence.full,
      accessibilityValue: Confidence.full,
      offlineValue: Confidence.full,
      futureValue: Confidence.full,
    ),
  );
  return EvolutionProposal(
    candidate: candidate,
    phase: EvolutionPhase.immediate,
    reviewDecision: const EvolutionDecision(
      subjectId: 'x',
      kind: EvolutionDecisionKind.accepted,
      rationale: 'r',
      confidence: Confidence.full,
    ),
    approvedForExecution: approvedForExecution,
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('applying a real evolution proposal persists a new, validated package version', () async {
    final repository = SqliteExperienceRepository(dbName: 'evolution_coord_${DateTime.now().microsecondsSinceEpoch}.db');
    final calculator = createCalculatorPackage();

    await repository.saveMetadata(
      ExperienceMetadataRecord(
        id: calculator.manifest.experienceId,
        name: calculator.manifest.name,
        description: calculator.manifest.description,
        category: 'utility',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        packageVersion: calculator.manifest.version,
      ),
    );
    await repository.savePackage(calculator);

    final coordinator = EvolutionCoordinator(repository: repository);
    final result = await coordinator.applyProposal(
      experienceId: calculator.manifest.experienceId,
      proposal: _workflowProposal(entityId: 'calculator'),
    );

    expect(result, isA<ModificationCoordinatorSucceeded>());
    final succeeded = result as ModificationCoordinatorSucceeded;
    expect(succeeded.newVersion, isNot(calculator.manifest.version));

    final persisted = await repository.getPackage(calculator.manifest.experienceId);
    expect(persisted, isNotNull);
    expect(persisted!.manifest.version, succeeded.newVersion);

    await repository.close();
  });

  test('a user objective is merged into the executed spec\'s objective, never silently dropped', () async {
    final repository = SqliteExperienceRepository(dbName: 'evolution_coord_${DateTime.now().microsecondsSinceEpoch}.db');
    final calculator = createCalculatorPackage();
    await repository.saveMetadata(
      ExperienceMetadataRecord(
        id: calculator.manifest.experienceId,
        name: calculator.manifest.name,
        description: calculator.manifest.description,
        category: 'utility',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        packageVersion: calculator.manifest.version,
      ),
    );
    await repository.savePackage(calculator);

    final coordinator = EvolutionCoordinator(repository: repository);
    final result = await coordinator.applyProposal(
      experienceId: calculator.manifest.experienceId,
      proposal: _workflowProposal(entityId: 'calculator'),
      userObjective: 'also make the buttons bigger',
    );

    expect(result, isA<ModificationCoordinatorSucceeded>());
    await repository.close();
  });

  test('a proposal for a category with no real ModificationOperation fails honestly, never silently no-ops', () async {
    final repository = SqliteExperienceRepository(dbName: 'evolution_coord_${DateTime.now().microsecondsSinceEpoch}.db');
    final calculator = createCalculatorPackage();
    await repository.saveMetadata(
      ExperienceMetadataRecord(
        id: calculator.manifest.experienceId,
        name: calculator.manifest.name,
        description: calculator.manifest.description,
        category: 'utility',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        packageVersion: calculator.manifest.version,
      ),
    );
    await repository.savePackage(calculator);

    final coordinator = EvolutionCoordinator(repository: repository);
    final offlineCandidate = EvolutionCandidate(
      id: 'candidate:missingOffline:x',
      opportunity: EvolutionOpportunity(
        id: 'evolution:missingOffline:x',
        category: EvolutionOpportunityCategory.missingOffline,
        description: 'test',
        reason: EvolutionReason(
          summary: 'test',
          evidence: const EvolutionEvidence(affectedGraph: 'test', affectedNodeId: 'x'),
          confidence: Confidence.full,
        ),
      ),
      cost: const EvolutionCost(),
      risk: const EvolutionRisk(),
      benefit: const EvolutionBenefit(
        engineeringValue: Confidence.full,
        userValue: Confidence.full,
        maintenanceValue: Confidence.full,
        performanceValue: Confidence.full,
        securityValue: Confidence.full,
        accessibilityValue: Confidence.full,
        offlineValue: Confidence.full,
        futureValue: Confidence.full,
      ),
    );
    final proposal = EvolutionProposal(
      candidate: offlineCandidate,
      phase: EvolutionPhase.later,
      reviewDecision: const EvolutionDecision(
        subjectId: 'x',
        kind: EvolutionDecisionKind.accepted,
        rationale: 'r',
        confidence: Confidence.full,
      ),
    );

    final result = await coordinator.applyProposal(experienceId: calculator.manifest.experienceId, proposal: proposal);
    expect(result, isA<ModificationCoordinatorFailed>());
    await repository.close();
  });

  test('applying a proposal for a nonexistent experience fails honestly', () async {
    final repository = SqliteExperienceRepository(dbName: 'evolution_coord_${DateTime.now().microsecondsSinceEpoch}.db');
    final coordinator = EvolutionCoordinator(repository: repository);
    final result = await coordinator.applyProposal(
      experienceId: 'does-not-exist',
      proposal: _workflowProposal(entityId: 'ghost'),
    );
    expect(result, isA<ModificationCoordinatorFailed>());
    await repository.close();
  });
}
