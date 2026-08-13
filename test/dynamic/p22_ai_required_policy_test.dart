/// IS-P22 — application generation REQUIRES an AI provider.
///
/// The owner's rule: with no provider configured, asking Anything to CREATE an
/// application must return "connect an AI provider", NOT a deterministic
/// records/CRUD app masquerading as a generated one. Only trivial LOCAL tools
/// (calculator, timer) may be built without a provider.
library;

import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/composite_reasoner.dart';
import 'package:flutter_test/flutter_test.dart';

IntentUnderstanding _u(String objective) => IntentUnderstanding(
      intentId: 'p22',
      objective: objective,
      category: IntentCategory.create,
      existingExperience: ExistingExperienceResolution.notChecked(),
      desiredOutcome: objective,
      confidence: 0.9,
      networkNeed: NetworkNeed.none,
      creationNeed: CreationNeed.likelyNeeded,
      modificationNeed: ModificationNeed.notNeeded,
    );

Future<AppReasoningResult> _reason(String objective) =>
    CompositeApplicationReasoner(requireProviderForGeneration: true)
        .reason(ApplicationReasoningContext(understanding: _u(objective)));

void main() {
  group('IS-P22 production policy: app generation requires AI', () {
    test('records app without a provider -> ProviderRequired (connect AI)', () async {
      expect(
        await _reason('Create a restaurant reservation application'),
        isA<ReasoningProviderRequired>(),
      );
    });

    test('novel domain without a provider -> ProviderRequired', () async {
      expect(
        await _reason(
            'Create a marine equipment rental management application'),
        isA<ReasoningProviderRequired>(),
      );
    });

    test('train booking without a provider -> ProviderRequired', () async {
      expect(
        await _reason('Create a professional train ticket booking app'),
        isA<ReasoningProviderRequired>(),
      );
    });

    test('a trivial LOCAL tool (calculator) still builds without a provider',
        () async {
      // Calculators/timers are local capability shells, not app generation.
      expect(await _reason('Create a calculator'), isA<ReasoningReady>());
    });

    test('lenient mode (tests) still builds a records app without a provider',
        () async {
      final result = await CompositeApplicationReasoner(
        requireProviderForGeneration: false,
      ).reason(ApplicationReasoningContext(
          understanding: _u('Create a restaurant reservation application')));
      expect(result, isA<ReasoningReady>());
    });
  });
}
