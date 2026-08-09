/// P17 — relationship inference via reference fields (no domain factories).
library;

import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/deterministic_reasoner.dart';
import 'package:flutter_test/flutter_test.dart';

IntentUnderstanding _u(String objective) => IntentUnderstanding(
  intentId: 'p17',
  objective: objective,
  category: IntentCategory.create,
  existingExperience: ExistingExperienceResolution.notChecked(),
  desiredOutcome: objective,
  confidence: 0.9,
  networkNeed: NetworkNeed.none,
  creationNeed: CreationNeed.likelyNeeded,
  modificationNeed: ModificationNeed.notNeeded,
);

void main() {
  test('dependent entities reference anchor peers', () async {
    final result = await const DeterministicReasoner().reason(
      ApplicationReasoningContext(
        understanding: _u('''
Create a bakery operations application.
Manage:
- recipes
- ingredients
- production batches
- customer orders
'''),
      ),
    );
    final app = (result as ReasoningReady).semanticApp;
    final batch = app.entities.firstWhere((e) => e.id.contains('batch'));
    final refs = batch.fields
        .where((f) => f.type == BlueprintFieldType.reference)
        .toList();
    expect(refs, isNotEmpty);
    final targets = refs.map((f) => f.referenceEntityId).toSet();
    expect(
      targets.any(
        (t) => t != null && (t.contains('recipe') || t.contains('ingredient')),
      ),
      isTrue,
      reason: 'batch should reference recipe/ingredient, got $targets',
    );

    final order = app.entities.firstWhere((e) => e.id.contains('order'));
    expect(
      order.fields.any((f) => f.type == BlueprintFieldType.reference),
      isTrue,
    );
  });

  test('garden planting schedule references plot/plant anchors', () async {
    final result = await const DeterministicReasoner().reason(
      ApplicationReasoningContext(
        understanding: _u('''
Create a community garden management application.
Manage:
- garden plots
- plants
- planting schedules
'''),
      ),
    );
    final app = (result as ReasoningReady).semanticApp;
    final planting = app.entities.firstWhere((e) => e.id.contains('planting'));
    final refIds = planting.fields
        .where((f) => f.type == BlueprintFieldType.reference)
        .map((f) => f.referenceEntityId)
        .whereType<String>()
        .toSet();
    expect(refIds, isNotEmpty);
    expect(
      refIds.any((id) => id.contains('plot') || id.contains('plant')),
      isTrue,
      reason: '$refIds',
    );
  });
}
