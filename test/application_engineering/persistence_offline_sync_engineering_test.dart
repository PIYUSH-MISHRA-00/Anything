/// Vision V3 AEE — PersistenceEngineering, OfflineEngineering, and
/// SynchronizationEngineering. Synchronization must remain strictly
/// architecture-only: a typed strategy record, never a network client.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/engineering_types.dart';
import 'package:anything/application_engineering/persistence_offline_sync_engineering.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

SemanticApp _appWithCapabilities(List<String> capabilities) {
  return SemanticApp(
    name: 'Hive Inspection Log',
    purpose: 'Track beehive inspections',
    entities: [
      const SemanticEntity(
        id: 'inspection',
        name: 'Inspection',
        fields: [
          SemanticField(id: 'notes', name: 'Notes', type: BlueprintFieldType.text, required: true),
        ],
      ),
    ],
    requiredCapabilities: capabilities,
  );
}

void main() {
  const architecturePlanner = ArchitecturePlanner();
  const persistenceEngineering = PersistenceEngineering();
  const offlineEngineering = OfflineEngineering();
  const synchronizationEngineering = SynchronizationEngineering();

  test('PersistenceEngineering wraps V2\'s real per-entity storage decision', () {
    final candidate = architecturePlanner.plan(_appWithCapabilities(const []));
    final migration = const EngineeringDecision(
      id: 'migration:policy',
      category: EngineeringDecisionCategory.migration,
      subjectId: 'schema',
      decision: 'No SQL migration required',
      rationale: 'test',
      confidence: Confidence.full,
    );
    final result = persistenceEngineering.plan(candidate, migration);
    expect(result.entityStorageDecisions, hasLength(1));
    expect(result.entityStorageDecisions.single.decision, contains('sqlite'));
    expect(result.migrationDecision, migration);
  });

  test('OfflineEngineering: no network capability -> offlineFirst, conflict=none', () {
    final candidate = architecturePlanner.plan(_appWithCapabilities(const []));
    final result = offlineEngineering.plan(candidate);
    expect(result.strategy, OfflineStrategy.offlineFirst);
    expect(result.conflictStrategy, ConflictStrategy.none);
  });

  test('OfflineEngineering: http capability -> cacheFirst', () {
    final candidate = architecturePlanner.plan(_appWithCapabilities(const ['http']));
    final result = offlineEngineering.plan(candidate);
    expect(result.strategy, OfflineStrategy.cacheFirst);
    // No sync target exists yet -> conflict resolution stays honestly "none".
    expect(result.conflictStrategy, ConflictStrategy.none);
  });

  test('SynchronizationEngineering is explicitly architecture-only', () {
    final candidate = architecturePlanner.plan(_appWithCapabilities(const ['http']));
    final result = synchronizationEngineering.plan(candidate);
    expect(result.strategy, candidate.synchronization.strategy);
    expect(result.decision.decision, contains('architecture-only'));
    expect(result.decision.rationale, contains('no server component'));
  });
}
