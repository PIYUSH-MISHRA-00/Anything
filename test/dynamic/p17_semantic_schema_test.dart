/// P17 — semantic schemas differ by domain (typed fields, not generic shell).
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

Future<SemanticApp> _reason(String prompt) async {
  final result = await const DeterministicReasoner().reason(
    ApplicationReasoningContext(understanding: _u(prompt)),
  );
  expect(result, isA<ReasoningReady>());
  return (result as ReasoningReady).semanticApp;
}

SemanticEntity _require(SemanticApp app, String idFragment) {
  final match = app.entities.where(
    (e) =>
        e.id.contains(idFragment) || e.name.toLowerCase().contains(idFragment),
  );
  expect(
    match,
    isNotEmpty,
    reason: 'missing entity ~$idFragment in ${app.entities.map((e) => e.id)}',
  );
  return match.first;
}

void main() {
  test(
    'inventory with explicit cues gets typed quantity/threshold fields',
    () async {
      final app = await _reason('''
Create an inventory tracker.
Manage:
- inventory with quantity, reorder threshold and supplier
- suppliers
''');
      final inv = _require(app, 'inventory');
      final q = inv.fields.where((f) => f.id == 'quantity');
      expect(q, isNotEmpty);
      expect(q.first.type, BlueprintFieldType.integer);
      final thr = inv.fields.where((f) => f.id.contains('reorder'));
      expect(thr, isNotEmpty);
      expect(thr.first.type, BlueprintFieldType.integer);
    },
  );

  test(
    'bakery vs garden schemas differ in entity ids and field types',
    () async {
      final bakery = await _reason('''
Create a bakery operations application.
Manage:
- recipes
- ingredients
- inventory
- production batches
- suppliers
- customer orders
- costs
''');
      final garden = await _reason('''
Create a community garden management application.
Manage:
- garden plots
- members
- plants
- planting schedules
- watering schedules
- harvest records
- photos
- reminders
''');

      final bIds = bakery.entities.map((e) => e.id).toSet();
      final gIds = garden.entities.map((e) => e.id).toSet();
      expect(
        bIds.contains('recipes') || bIds.any((id) => id.contains('recipe')),
        isTrue,
      );
      expect(gIds.any((id) => id.contains('plot')), isTrue);
      expect(bIds.intersection(gIds).length, lessThan(bIds.length));
      expect(gIds.any((id) => id.contains('recipe')), isFalse);
      expect(bIds.any((id) => id.contains('garden')), isFalse);

      final costs = _require(bakery, 'cost');
      expect(
        costs.fields.any((f) => f.type == BlueprintFieldType.decimal),
        isTrue,
      );
      final batches = _require(bakery, 'batch');
      expect(
        batches.fields.any((f) => f.type == BlueprintFieldType.reference),
        isTrue,
      );
      final schedules = _require(garden, 'schedule');
      expect(
        schedules.fields.any((f) => f.type == BlueprintFieldType.dateTime),
        isTrue,
      );
      final photos = _require(garden, 'photo');
      expect(
        photos.fields.any(
          (f) => f.id == 'media_uri' || f.type == BlueprintFieldType.url,
        ),
        isTrue,
      );
    },
  );
}
