import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/deterministic_reasoner.dart';
import 'package:anything/synthesis/structural_entity_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fermentation batch tracker does not produce Er from track⊂tracker',
    () async {
      const prompt =
          'a home fermentation batch tracker with jars starter notes and feed schedule';

      final extracted = StructuralEntityExtractor.extract(prompt);
      expect(
        extracted.map((e) => e.name),
        isNot(contains('Er')),
        reason: 'track must not match inside tracker',
      );

      final result = await const DeterministicReasoner().reason(
        ApplicationReasoningContext(
          understanding: IntentUnderstanding(
            intentId: 'rw-ferm-1',
            objective: prompt,
            category: IntentCategory.create,
            existingExperience: const ExistingExperienceResolution(
              status: ExistingExperienceStatus.notChecked,
            ),
            desiredOutcome: '',
            confidence: 0.9,
            networkNeed: NetworkNeed.none,
            creationNeed: CreationNeed.definitelyNeeded,
            modificationNeed: ModificationNeed.notNeeded,
          ),
        ),
      );
      expect(result, isA<ReasoningReady>());
      final app = (result as ReasoningReady).semanticApp;
      final names = app.entities.map((e) => e.name).toList();
      expect(names, isNot(contains('Er')));
      expect(
        names.any(
          (n) =>
              n.toLowerCase().contains('fermentation') ||
              n.toLowerCase().contains('batch'),
        ),
        isTrue,
        reason: 'manager head noun should be primary entity',
      );
    },
  );
}
