/// P17 — semantic plan beats lexical hijacks for capabilities.
library;

import 'package:anything/core/contracts/intent.dart';
import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/creation/intent_preservation.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/composite_reasoner.dart';
import 'package:anything/synthesis/deterministic_reasoner.dart';
import 'package:anything/synthesis/synthesis_planner.dart';
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
  test('management app is not hijacked by news/weather lexical cues', () async {
    const prompt = '''
Create a bakery operations application with article notes and temperature logs.
Manage:
- recipes
- ingredients
- inventory
''';
    final ready = await const DeterministicReasoner().reason(
      ApplicationReasoningContext(understanding: _u(prompt)),
    );
    final app = (ready as ReasoningReady).semanticApp;
    final bp = SynthesisPlanner(
      const DeterministicReasoner(),
    ).convertToBlueprint(app);
    final caps = AppCapabilityInferrer().infer(
      blueprint: bp,
      intent: Intent.create(expression: prompt),
    );
    expect(
      caps.contains(AppCapabilityIds.collection) ||
          caps.contains(AppCapabilityIds.crud),
      isTrue,
    );
    expect(caps.contains(AppCapabilityIds.newsData), isFalse);
    expect(caps.contains(AppCapabilityIds.weatherData), isFalse);
  });

  test('weather prompt purpose is weather, not calculation', () {
    final purpose = const IntentPreservationValidator().purposeFromPrompt(
      'Create a weather dashboard. Show temperature. Also mention add and multiply casually.',
    );
    expect(purpose, IntentPurpose.weather);
    expect(purpose, isNot(IntentPurpose.calculation));
  });

  test('stopwatch intent is not classified as calculator', () {
    final stop = const IntentPreservationValidator().purposeFromPrompt(
      'Create a stopwatch.',
    );
    final calc = const IntentPreservationValidator().purposeFromPrompt(
      'Create a calculator.',
    );
    expect(stop, IntentPurpose.timing);
    expect(calc, IntentPurpose.calculation);
    expect(stop, isNot(calc));
  });

  // Regression: a booking/management intent that mentions "search" must NOT be
  // pushed to the network-reference (location "search + refresh") shell. A
  // booking app has a search STEP; it is not a search app. Guards the device
  // failure "train ticket booking app" -> generic City-or-location shell.
  test('booking intent with "search" stays a records app, not a net shell', () async {
    const prompt = 'Create a train ticket booking app to search and book tickets.';

    // Fix B basis: the user's words classify this as a durable collection.
    final purpose =
        const IntentPreservationValidator().purposeFromPrompt(prompt);
    expect(purpose, IntentPurpose.collection);

    // Fix A: bare "search" must not infer external-data capabilities.
    // No provider (Groq unavailable) → composite best-effort records path,
    // exactly as on device.
    final ready = await CompositeApplicationReasoner().reason(
      ApplicationReasoningContext(understanding: _u(prompt)),
    );
    final app = (ready as ReasoningReady).semanticApp;
    final bp = SynthesisPlanner(
      const DeterministicReasoner(),
    ).convertToBlueprint(app);
    final caps = AppCapabilityInferrer().infer(
      blueprint: bp,
      intent: Intent.create(expression: prompt),
    );
    expect(caps.contains(AppCapabilityIds.networkData), isFalse,
        reason: '"search" is a list operator, not a network signal');
    expect(
      caps.contains(AppCapabilityIds.collection) ||
          caps.contains(AppCapabilityIds.crud),
      isTrue,
      reason: 'booking is a records app',
    );
  });
}
