/// Vision V4 FDI — Engineering Integration: DataEngineering and
/// OfflineEngineering genuinely cross-reference a real FeatureGraph when
/// one is supplied, and are byte-for-byte unchanged when it isn't.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/data_engineering.dart';
import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/persistence_offline_sync_engineering.dart';
import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart' show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

const _architecturePlanner = ArchitecturePlanner();
const _requirementExtractor = RequirementExtractor();
const _featureEngine = FeatureDiscoveryEngine();
const _dataEngineering = DataEngineering();
const _offlineEngineering = OfflineEngineering();

IntentUnderstanding _understanding() {
  return IntentUnderstanding(
    intentId: 'test-${DateTime.now().microsecondsSinceEpoch}',
    objective: 'test',
    category: IntentCategory.create,
    existingExperience: const ExistingExperienceResolution(status: ExistingExperienceStatus.notChecked),
    desiredOutcome: '',
    confidence: 0.9,
    networkNeed: NetworkNeed.none,
    creationNeed: CreationNeed.definitelyNeeded,
    modificationNeed: ModificationNeed.notNeeded,
  );
}

SemanticApp _hiveApp() {
  return SemanticApp(
    name: 'Hive Inspection Log',
    purpose: 'Track beehive inspections',
    entities: [
      const SemanticEntity(
        id: 'inspection',
        name: 'Inspection',
        displayField: 'notes',
        fields: [SemanticField(id: 'notes', name: 'Notes', type: BlueprintFieldType.text, required: true)],
      ),
    ],
    views: const [
      SemanticView(
        id: 'inspections_list',
        name: 'Inspections',
        purpose: 'list',
        sourceEntityId: 'inspection',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [SemanticAction(id: 'add_inspection', name: 'Add Inspection', targetEntityId: 'inspection')],
  );
}

void main() {
  final app = _hiveApp();
  final candidate = _architecturePlanner.plan(app);
  final requirements = _requirementExtractor.extract(app: app, understanding: _understanding());
  final featureGraph = _featureEngine.plan(FeatureDiscoveryContext(app: app, requirements: requirements));

  test('DataEngineering corroborates its index recommendation when a matching Index feature exists', () {
    final withFeatures = _dataEngineering.plan(
      EngineeringContext(architecture: candidate, app: app, featureGraph: featureGraph),
    );
    final decision = withFeatures.indexes.firstWhere((i) => i.entityId == 'inspection').decision;
    expect(decision.confidence.score, 0.85);
    expect(decision.rationale, contains('Confirmed by Feature Discovery'));
  });

  test('DataEngineering is unchanged when no FeatureGraph is supplied', () {
    final withoutFeatures = _dataEngineering.plan(EngineeringContext(architecture: candidate, app: app));
    final decision = withoutFeatures.indexes.firstWhere((i) => i.entityId == 'inspection').decision;
    expect(decision.confidence.score, 0.7);
    expect(decision.rationale, isNot(contains('Confirmed by Feature Discovery')));
  });

  test('OfflineEngineering cites the discovered Offline Strategy feature priority when supplied', () {
    final withFeatures = _offlineEngineering.plan(candidate, featureGraph: featureGraph);
    expect(withFeatures.decision.rationale, contains("Feature Discovery's Offline Strategy feature"));
  });

  test('OfflineEngineering is unchanged when no FeatureGraph is supplied', () {
    final withoutFeatures = _offlineEngineering.plan(candidate);
    expect(withoutFeatures.decision.rationale, isNot(contains('Feature Discovery')));
  });
}
