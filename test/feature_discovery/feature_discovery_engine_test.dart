/// Vision V4 FDI — FeatureDiscoveryEngine: structural discovery from
/// RequirementGraph + SemanticApp, and the full plan() orchestration
/// (discover -> classify -> link -> priority/complexity -> confidence).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/feature_discovery/feature_types.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

const _requirementExtractor = RequirementExtractor();
const _engine = FeatureDiscoveryEngine();

IntentUnderstanding _understanding() {
  return IntentUnderstanding(
    intentId: 'test-${DateTime.now().microsecondsSinceEpoch}',
    objective: 'test',
    category: IntentCategory.create,
    existingExperience: const ExistingExperienceResolution(
      status: ExistingExperienceStatus.notChecked,
    ),
    desiredOutcome: '',
    confidence: 0.9,
    networkNeed: NetworkNeed.none,
    creationNeed: CreationNeed.definitelyNeeded,
    modificationNeed: ModificationNeed.notNeeded,
  );
}

/// "Beekeeping Hive Inspection Log" — zero footprint anywhere in lib/.
SemanticApp _hiveApp() {
  return SemanticApp(
    name: 'Hive Inspection Log',
    purpose: 'Track beehive inspections',
    entities: [
      const SemanticEntity(
        id: 'inspection',
        name: 'Inspection',
        displayField: 'notes',
        fields: [
          SemanticField(
            id: 'notes',
            name: 'Notes',
            type: BlueprintFieldType.text,
            required: true,
          ),
          SemanticField(
            id: 'hiveId',
            name: 'Hive',
            type: BlueprintFieldType.reference,
            referenceEntityId: 'hive',
            required: false,
          ),
        ],
      ),
      const SemanticEntity(
        id: 'hive',
        name: 'Hive',
        fields: [
          SemanticField(
            id: 'label',
            name: 'Label',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: [
      const SemanticView(
        id: 'inspections_list',
        name: 'Inspections',
        purpose: 'list',
        sourceEntityId: 'inspection',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      const SemanticView(
        id: 'inspections_form',
        name: 'Add Inspection',
        purpose: 'form',
        sourceEntityId: 'inspection',
        viewType: BlueprintViewType.form,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_inspection',
        name: 'Add Inspection',
        targetEntityId: 'inspection',
      ),
    ],
    derivedValues: const [
      SemanticDerivedValue(
        id: 'inspection_count',
        name: 'Total Inspections',
        sourceEntityId: 'inspection',
        operation: DerivedOperation.count,
      ),
    ],
    requiredCapabilities: const ['clock'],
  );
}

FeatureDiscoveryContext _contextFor(SemanticApp app) {
  final requirements = _requirementExtractor.extract(
    app: app,
    understanding: _understanding(),
  );
  return FeatureDiscoveryContext(app: app, requirements: requirements);
}

void main() {
  group('discover() — structural rules', () {
    test('one data + one persistence feature per entity', () {
      final candidates = _engine.discover(_contextFor(_hiveApp()));
      expect(
        candidates.where((c) => c.category == FeatureCategory.data),
        hasLength(2),
      );
      expect(
        candidates.where((c) => c.category == FeatureCategory.persistence),
        hasLength(2),
      );
    });

    test('one relational feature per reference field', () {
      final candidates = _engine.discover(_contextFor(_hiveApp()));
      expect(
        candidates.where((c) => c.category == FeatureCategory.relational),
        hasLength(1),
      );
    });

    test('search + index features for list views only', () {
      final candidates = _engine.discover(_contextFor(_hiveApp()));
      expect(
        candidates.where((c) => c.category == FeatureCategory.search),
        hasLength(1),
      );
      expect(
        candidates.where((c) => c.category == FeatureCategory.indexing),
        hasLength(1),
      );
    });

    test('one capability feature per required capability', () {
      final candidates = _engine.discover(_contextFor(_hiveApp()));
      final clock = candidates.where(
        (c) => c.category == FeatureCategory.capability,
      );
      expect(clock, hasLength(1));
      expect(clock.single.id, 'feature:capability:clock');
    });

    test(
      'navigation, validation, state features are aggregate and present',
      () {
        final candidates = _engine.discover(_contextFor(_hiveApp()));
        expect(candidates.any((c) => c.id == 'feature:navigation'), isTrue);
        expect(candidates.any((c) => c.id == 'feature:validation'), isTrue);
        expect(candidates.any((c) => c.id == 'feature:state'), isTrue);
      },
    );

    test('one reporting feature per derived value', () {
      final candidates = _engine.discover(_contextFor(_hiveApp()));
      expect(
        candidates.where((c) => c.category == FeatureCategory.reporting),
        hasLength(1),
      );
    });

    test('offline strategy and data protection are always discovered', () {
      final candidates = _engine.discover(_contextFor(_hiveApp()));
      expect(candidates.any((c) => c.id == 'feature:offline'), isTrue);
      expect(
        candidates.any((c) => c.id == 'feature:security:protection'),
        isTrue,
      );
    });

    test('no validation feature when no field has any bound', () {
      final app = SemanticApp(
        name: 'Sparse',
        purpose: 'p',
        entities: [
          const SemanticEntity(
            id: 'e',
            name: 'E',
            fields: [
              SemanticField(id: 'f', name: 'F', type: BlueprintFieldType.text),
            ],
          ),
        ],
      );
      final candidates = _engine.discover(_contextFor(app));
      expect(candidates.any((c) => c.id == 'feature:validation'), isFalse);
    });
  });

  group('plan() — full orchestration', () {
    test('produces a FeatureGraph with real feature-to-feature edges', () {
      final graph = _engine.plan(_contextFor(_hiveApp()));
      expect(graph.nodes, isNotEmpty);

      final searchNode = graph.nodesOfCategory(FeatureCategory.search).single;
      final indexEdge = graph.edgesFrom(searchNode.id).single;
      expect(indexEdge.kind, FeatureRelationKind.requires);
      final indexNode = graph.nodeById(indexEdge.toFeatureId)!;
      expect(indexNode.category, FeatureCategory.indexing);

      final persistenceEdge = graph.edgesFrom(indexNode.id).single;
      expect(persistenceEdge.kind, FeatureRelationKind.requires);
      expect(
        graph.nodeById(persistenceEdge.toFeatureId)!.category,
        FeatureCategory.persistence,
      );
    });

    test(
      'overall confidence is a real computed mean, not a fixed constant',
      () {
        final richGraph = _engine.plan(_contextFor(_hiveApp()));
        final sparseApp = SemanticApp(
          name: 'Sparse',
          purpose: 'p',
          entities: [const SemanticEntity(id: 'e', name: 'E')],
        );
        final sparseGraph = _engine.plan(_contextFor(sparseApp));

        expect(
          richGraph.overallConfidence.score,
          isNot(sparseGraph.overallConfidence.score),
        );
        expect(richGraph.overallConfidence.score, greaterThan(0));
        expect(richGraph.overallConfidence.score, lessThanOrEqualTo(1));
      },
    );
  });

  group(
    'never inspects entity/field names — identical shape, different names',
    () {
      test(
        'two structurally-identical, differently-named apps produce identically-shaped graphs',
        () {
          final appA = _hiveApp();
          final appB = SemanticApp(
            name: 'Xyzzy Plugh Tracker',
            purpose: 'zzz',
            entities: [
              const SemanticEntity(
                id: 'qqq',
                name: 'Qqq',
                displayField: 'zzz',
                fields: [
                  SemanticField(
                    id: 'zzz',
                    name: 'Zzz',
                    type: BlueprintFieldType.text,
                    required: true,
                  ),
                  SemanticField(
                    id: 'www',
                    name: 'Www',
                    type: BlueprintFieldType.reference,
                    referenceEntityId: 'rrr',
                  ),
                ],
              ),
              const SemanticEntity(
                id: 'rrr',
                name: 'Rrr',
                fields: [
                  SemanticField(
                    id: 'lbl',
                    name: 'Lbl',
                    type: BlueprintFieldType.text,
                    required: true,
                  ),
                ],
              ),
            ],
            views: const [
              SemanticView(
                id: 'qqq_list',
                name: 'Qqqs',
                purpose: 'list',
                sourceEntityId: 'qqq',
                viewType: BlueprintViewType.list,
                isDefault: true,
              ),
            ],
            actions: const [
              SemanticAction(
                id: 'add_qqq',
                name: 'Add Qqq',
                targetEntityId: 'qqq',
              ),
            ],
            derivedValues: const [
              SemanticDerivedValue(
                id: 'qqq_count',
                name: 'Total Qqq',
                sourceEntityId: 'qqq',
                operation: DerivedOperation.count,
              ),
            ],
            requiredCapabilities: const ['clock'],
          );

          final graphA = _engine.plan(_contextFor(appA));
          final graphB = _engine.plan(_contextFor(appB));

          final categoriesA = graphA.nodes.map((n) => n.category).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          final categoriesB = graphB.nodes.map((n) => n.category).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          // appA has one extra entity's persistence/data feature pair (hive) vs
          // appB's rrr — same count, same shape either way.
          expect(categoriesA.length, categoriesB.length);
          expect(categoriesA, categoriesB);
        },
      );
    },
  );
}
