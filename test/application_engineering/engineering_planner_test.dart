/// Vision V3 AEE — EngineeringPlanner: the top-level orchestrator that
/// assembles one EngineeringCandidate from every *Engineering module and
/// computes a real, non-fixed overall confidence.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/engineering_planner.dart';
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
          SemanticField(
            id: 'notes',
            name: 'Notes',
            type: BlueprintFieldType.text,
            required: true,
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
    ],
    actions: [
      const SemanticAction(
        id: 'add_inspection',
        name: 'Add Inspection',
        targetEntityId: 'inspection',
      ),
    ],
    requiredCapabilities: const ['clock'],
  );
}

void main() {
  const architecturePlanner = ArchitecturePlanner();
  const engineeringPlanner = EngineeringPlanner();

  test('assembles every engineering concern into one candidate', () {
    final app = _hiveApp();
    final candidate = architecturePlanner.plan(app);
    final result = engineeringPlanner.plan(
      EngineeringContext(architecture: candidate, app: app),
    );

    expect(result.behaviors, hasLength(2));
    expect(result.data.indexes, isNotEmpty);
    expect(result.navigation.deepLinkableScreenIds, isNotEmpty);
    expect(result.interaction.patterns, isNotEmpty);
    expect(result.bindingGraph.edges, isNotEmpty);
    expect(result.validations, isNotEmpty);
    expect(result.persistence.entityStorageDecisions, hasLength(2));
    expect(result.lifecycle.hooks, isNotEmpty);
    expect(result.performance.decisions, isNotEmpty);
    expect(result.accessibility.decisions, isNotEmpty);
    expect(result.security.decisions, isNotEmpty);
  });

  test('overall confidence is a real computed mean, not a fixed constant', () {
    final richApp = _hiveApp();
    final sparseApp = SemanticApp(
      name: 'Sparse',
      purpose: 'p',
      entities: [const SemanticEntity(id: 'e', name: 'E')],
    );

    final richCandidate = architecturePlanner.plan(richApp);
    final sparseCandidate = architecturePlanner.plan(sparseApp);

    final richResult = engineeringPlanner.plan(
      EngineeringContext(architecture: richCandidate, app: richApp),
    );
    final sparseResult = engineeringPlanner.plan(
      EngineeringContext(architecture: sparseCandidate, app: sparseApp),
    );

    expect(
      richResult.overallConfidence.score,
      isNot(sparseResult.overallConfidence.score),
    );
    expect(richResult.overallConfidence.score, greaterThan(0));
    expect(richResult.overallConfidence.score, lessThanOrEqualTo(1));
  });

  test('allDecisions flattens every sub-module\'s decisions', () {
    final app = _hiveApp();
    final candidate = architecturePlanner.plan(app);
    final result = engineeringPlanner.plan(
      EngineeringContext(architecture: candidate, app: app),
    );
    expect(result.allDecisions.length, greaterThan(10));
  });
}
