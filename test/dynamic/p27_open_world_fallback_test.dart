/// IS-P27 — open-world planning must not hard-fail record-shaped domains.
///
/// The owner reported "restaurant booking application" → "Could not plan this
/// app." Root cause: with no working AI provider, an unfamiliar record-shaped
/// request fell through every deterministic path to ReasoningProviderRequired,
/// which the coordinator surfaced as a hard failure.
///
/// Fix: CompositeApplicationReasoner falls back to an honest best-effort
/// single-entity records/reservation manager when the model path is
/// unavailable or fails — WITHOUT preempting a working provider, and WITHOUT a
/// domain-specific factory (the subject entity is derived structurally).
library;

import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/composite_reasoner.dart';
import 'package:anything/synthesis/deterministic_reasoner.dart';
import 'package:flutter_test/flutter_test.dart';

ApplicationReasoningContext _ctx(String objective) {
  return ApplicationReasoningContext(
    understanding: IntentUnderstanding(
      intentId: 'test-p27',
      objective: objective,
      category: IntentCategory.create,
      existingExperience: const ExistingExperienceResolution(
        status: ExistingExperienceStatus.notChecked,
      ),
      desiredOutcome: '',
      confidence: 0.8,
      networkNeed: NetworkNeed.none,
      creationNeed: CreationNeed.definitelyNeeded,
      modificationNeed: ModificationNeed.notNeeded,
    ),
  );
}

void main() {
  group('IS-P27 best-effort fallback (deterministic)', () {
    const reasoner = DeterministicReasoner();

    test(
      'restaurant booking → honest records app, no provider needed',
      () async {
        final app = reasoner.tryBestEffortPrimaryEntity(
          'Create a professional restaurant booking application',
        );
        expect(app, isNotNull);
        expect(app!.entities, isNotEmpty);
        expect(app.tags, contains('best-effort'));
        // Full-stack collection capabilities, not a bare shell.
        expect(app.requiredCapabilities, contains('crud'));
        expect(app.requiredCapabilities, contains('persistence'));
        expect(app.requiredCapabilities, contains('search'));
        // The subject is derived structurally (no restaurant factory).
        expect(
          app.entities.first.name.toLowerCase(),
          anyOf(contains('booking'), contains('restaurant')),
        );
      },
    );

    test('veterinary clinic → honest records app', () async {
      final app = reasoner.tryBestEffortPrimaryEntity(
        'Create a professional veterinary clinic management application',
      );
      expect(app, isNotNull);
      expect(app!.entities, isNotEmpty);
    });

    test('genuinely vague prompt still returns null (escalates)', () async {
      expect(reasoner.tryBestEffortPrimaryEntity('create an app'), isNull);
      expect(reasoner.tryBestEffortPrimaryEntity('make me something'), isNull);
    });

    test('non-records novel prompt is NOT force-fit into CRUD', () async {
      // A collaborative whiteboard genuinely needs the AI reasoner — the
      // fallback must decline so it escalates rather than becoming a bad
      // records app.
      expect(
        reasoner.tryBestEffortPrimaryEntity(
          'Build a real-time collaborative whiteboard',
        ),
        isNull,
      );
    });
  });

  group('IS-P27 composite: no hard-fail without a provider', () {
    test(
      'restaurant booking plans instead of ReasoningProviderRequired',
      () async {
        // No provider registry → the model path is unavailable.
        final composite = CompositeApplicationReasoner();
        final result = await composite.reason(
          _ctx('Create a professional restaurant booking application'),
        );
        expect(result, isA<ReasoningReady>());
        final ready = result as ReasoningReady;
        expect(ready.semanticApp.entities, isNotEmpty);
      },
    );

    test('non-records novel intent still escalates to provider', () async {
      final composite = CompositeApplicationReasoner();
      final result = await composite.reason(
        _ctx('Build a real-time collaborative whiteboard'),
      );
      expect(result, isA<ReasoningProviderRequired>());
    });
  });
}
