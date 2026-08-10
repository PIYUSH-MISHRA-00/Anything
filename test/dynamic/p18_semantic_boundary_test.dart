/// P18 — deterministic inference boundaries (no uncontrolled noun growth).
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
  intentId: 'p18',
  objective: objective,
  category: IntentCategory.create,
  existingExperience: ExistingExperienceResolution.notChecked(),
  desiredOutcome: objective,
  confidence: 0.9,
  networkNeed: NetworkNeed.none,
  creationNeed: CreationNeed.likelyNeeded,
  modificationNeed: ModificationNeed.notNeeded,
);

Future<AppReasoningResult> _reason(String prompt) =>
    const DeterministicReasoner().reason(
      ApplicationReasoningContext(understanding: _u(prompt)),
    );

void main() {
  test(
    'false positive: bare inventory does not invent reorder threshold',
    () async {
      final result = await _reason('Create an inventory.');
      // Too vague / single-entity → provider required, not hallucinated schema.
      expect(
        result is ReasoningProviderRequired || result is ReasoningReady,
        isTrue,
      );
      if (result is ReasoningReady) {
        final fields = result.semanticApp.entities
            .expand((e) => e.fields.map((f) => f.id))
            .toSet();
        expect(fields.contains('reorder_threshold'), isFalse);
      }
    },
  );

  test('false positive: manage photos alone does not invent voting', () async {
    final result = await _reason('''
Create a photo album.
Manage:
- photos
- albums
''');
    expect(result, isA<ReasoningReady>());
    final app = (result as ReasoningReady).semanticApp;
    final ids = app.entities.map((e) => e.id).toSet();
    expect(
      ids.any((id) => id.contains('vote') || id.contains('voting')),
      isFalse,
    );
    expect(
      ids.any((id) => id.contains('exhibition') || id.contains('judging')),
      isFalse,
    );
  });

  test('false negative: explicit with-clause fields appear', () async {
    final result = await _reason('''
Create an inventory tracker.
Manage:
- inventory with quantity, reorder threshold and supplier
- suppliers
''');
    final app = (result as ReasoningReady).semanticApp;
    final inv = app.entities.firstWhere((e) => e.id.contains('inventory'));
    expect(inv.fields.any((f) => f.id == 'quantity'), isTrue);
    expect(inv.fields.any((f) => f.id.contains('reorder')), isTrue);
    expect(inv.fields.any((f) => f.type == BlueprintFieldType.integer), isTrue);
  });

  test('explicit structure: task with deadline and completed flag', () async {
    final result = await _reason('''
Create a task list.
Manage:
- tasks with deadline and completed flag
- projects
''');
    final app = (result as ReasoningReady).semanticApp;
    final tasks = app.entities.firstWhere((e) => e.id.contains('task'));
    final ids = tasks.fields.map((f) => f.id).toSet();
    expect(
      ids.any((id) => id.contains('deadline') || id.contains('date')),
      isTrue,
    );
    expect(
      tasks.fields.any(
        (f) =>
            f.id.contains('completed') || f.type == BlueprintFieldType.boolean,
      ),
      isTrue,
    );
  });

  test('relationship: every repair job belongs to a customer', () async {
    final result = await _reason('''
Create a bicycle repair shop management application.
Manage:
- customers
- repair jobs
- parts
Every repair job belongs to a customer.
''');
    final app = (result as ReasoningReady).semanticApp;
    final job = app.entities.firstWhere((e) => e.id.contains('job'));
    final refs = job.fields.where(
      (f) => f.type == BlueprintFieldType.reference,
    );
    expect(refs, isNotEmpty);
    expect(
      refs.any((f) => (f.referenceEntityId ?? '').contains('customer')),
      isTrue,
      reason: '${refs.map((f) => f.referenceEntityId).toList()}',
    );
  });

  test(
    'ambiguous bank: river bank vs bank account are not identical apps',
    () async {
      final river = await _reason('''
Create a river bank monitoring application.
Manage:
- observation points
- water levels
- erosion reports
- photos
''');
      final finance = await _reason('''
Create a bank account management application.
Manage:
- accounts
- transactions
- categories
- budgets
''');
      expect(river, isA<ReasoningReady>());
      expect(finance, isA<ReasoningReady>());
      final rIds = (river as ReasoningReady).semanticApp.entities
          .map((e) => e.id)
          .toSet();
      final fIds = (finance as ReasoningReady).semanticApp.entities
          .map((e) => e.id)
          .toSet();
      expect(
        rIds.any((id) => id.contains('water') || id.contains('erosion')),
        isTrue,
      );
      expect(
        fIds.any((id) => id.contains('account') || id.contains('transaction')),
        isTrue,
      );
      expect(rIds.intersection(fIds).length, lessThan(rIds.length));
    },
  );
}
