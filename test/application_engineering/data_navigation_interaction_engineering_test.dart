/// Vision V3 AEE — DataEngineering, NavigationEngineering, and
/// InteractionEngineering: index/aggregation/migration decisions, modal/
/// deep-link/history/recovery decisions, and the honest interaction-pattern
/// catalog (never fabricating an unimplemented pattern as real).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/data_engineering.dart';
import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/interaction_engineering.dart';
import 'package:anything/application_engineering/navigation_engineering.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

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
          SemanticField(id: 'notes', name: 'Notes', type: BlueprintFieldType.text, required: true),
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
          SemanticField(id: 'label', name: 'Label', type: BlueprintFieldType.text, required: true),
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
    actions: [
      const SemanticAction(id: 'add_inspection', name: 'Add Inspection', targetEntityId: 'inspection'),
    ],
    derivedValues: [
      const SemanticDerivedValue(
        id: 'inspection_count',
        name: 'Total Inspections',
        sourceEntityId: 'inspection',
        operation: DerivedOperation.count,
      ),
    ],
  );
}

void main() {
  const architecturePlanner = ArchitecturePlanner();
  final app = _hiveApp();
  final candidate = architecturePlanner.plan(app);
  final context = EngineeringContext(architecture: candidate, app: app);

  group('DataEngineering', () {
    const dataEngineering = DataEngineering();

    test('recommends an index on display field and reference fields', () {
      final result = dataEngineering.plan(context);
      final indexed = result.indexes.map((i) => '${i.entityId}.${i.fieldId}').toSet();
      expect(indexed, contains('inspection.notes'));
      expect(indexed, contains('inspection.hiveId'));
    });

    test('one aggregation decision per derived value', () {
      final result = dataEngineering.plan(context);
      expect(result.aggregations, hasLength(1));
      expect(result.aggregations.single.derivedValueId, 'inspection_count');
    });

    test('migration decision honestly states no SQL migration is needed', () {
      final result = dataEngineering.plan(context);
      expect(result.migrationDecision.decision, contains('No SQL migration'));
    });
  });

  group('NavigationEngineering', () {
    const navigationEngineering = NavigationEngineering();

    test('every screen is deep-linkable and history/recovery decisions are real', () {
      final result = navigationEngineering.plan(context);
      expect(result.deepLinkableScreenIds, unorderedEquals(candidate.navigation.screenIds));
      expect(result.historyDecision.decision, contains('history'));
      expect(result.recoveryDecision.rationale, contains('ExperienceRouter'));
    });
  });

  group('InteractionEngineering', () {
    const interactionEngineering = InteractionEngineering();

    test('only real, tested patterns are reported implemented', () {
      final result = interactionEngineering.plan(context);
      bool implementedOf(InteractionPattern p) =>
          result.patterns.firstWhere((d) => d.pattern == p).implemented;

      expect(implementedOf(InteractionPattern.singleSelection), isTrue);
      expect(implementedOf(InteractionPattern.confirmation), isTrue);
      expect(implementedOf(InteractionPattern.batchSelection), isFalse);
      expect(implementedOf(InteractionPattern.undo), isFalse);
      expect(implementedOf(InteractionPattern.redo), isFalse);
      expect(implementedOf(InteractionPattern.contextMenu), isFalse);
      expect(implementedOf(InteractionPattern.grouping), isFalse);
    });

    test('unimplemented patterns carry zero confidence, never fabricated', () {
      final result = interactionEngineering.plan(context);
      final undo = result.patterns.firstWhere((d) => d.pattern == InteractionPattern.undo);
      expect(undo.decision.confidence.score, 0.0);
    });
  });
}
