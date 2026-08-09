/// IS-P12 — intent preservation + timing capability regression tests.
library;

import 'package:anything/core/contracts/intent.dart';
import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/creation/calculation_interface_factory.dart';
import 'package:anything/creation/creation_request.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/intent_preservation.dart';
import 'package:anything/creation/timing_interface_factory.dart';
import 'package:anything/runtime/timing_session.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/synthesis/app_archetype.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IS-P12 utility must not imply calculation', () {
    test('utility archetype alone does not add calculation', () {
      final bp = AppBlueprint(
        id: 'bp1',
        name: 'Tool',
        description: 'a local tool',
        archetypes: const [AppArchetype.utility],
        entities: const [],
        actions: const [],
        views: const [],
        requiredCapabilities: const [],
      );
      final caps = const AppCapabilityInferrer().infer(blueprint: bp);
      expect(caps.contains(AppCapabilityIds.calculation), isFalse);
    });

    test('stopwatch prompt infers timers not calculation', () {
      final bp = AppBlueprint(
        id: 'bp2',
        name: 'Stopwatch',
        description: 'measure elapsed time',
        archetypes: const [AppArchetype.utility],
        entities: const [],
        actions: const [],
        views: const [],
        requiredCapabilities: const [],
      );
      final intent = Intent.create(expression: 'stopwatch');
      final caps = const AppCapabilityInferrer().infer(
        blueprint: bp,
        intent: intent,
      );
      expect(caps.contains(AppCapabilityIds.timers), isTrue);
      expect(caps.contains(AppCapabilityIds.calculation), isFalse);
    });

    test('calculator prompt still infers calculation', () {
      final bp = AppBlueprint(
        id: 'bp3',
        name: 'Calc',
        description: 'arithmetic',
        archetypes: const [AppArchetype.utility],
        entities: const [],
        actions: const [],
        views: const [],
        requiredCapabilities: const [],
      );
      final intent = Intent.create(expression: 'calculator');
      final caps = const AppCapabilityInferrer().infer(
        blueprint: bp,
        intent: intent,
      );
      expect(caps.contains(AppCapabilityIds.calculation), isTrue);
      expect(caps.contains(AppCapabilityIds.timers), isFalse);
    });
  });

  group('IS-P12 semantic mismatch', () {
    ExperiencePackage bare(String name) {
      final now = DateTime.now();
      return ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: 'x',
          name: name,
          description: name,
          createdAt: now,
          updatedAt: now,
        ),
        interface: const InterfaceDefinition(),
        behavior: const BehaviorGraph(),
        state: const StateSchema(),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(contentHash: '', computedAt: now),
      );
    }

    test('stopwatch vs calculator package is incompatible', () {
      final calc = const CalculationInterfaceFactory().applyToPackage(
        bare('Calculator'),
        name: 'Calculator',
      );
      final result = const IntentPreservationValidator().validate(
        rawPrompt: 'stopwatch',
        package: calc,
      );
      expect(result.isCompatible, isFalse);
      expect(result.requested, IntentPurpose.timing);
      expect(result.generated, IntentPurpose.calculation);
    });

    test('stopwatch vs timing package is compatible', () {
      final timing = const TimingInterfaceFactory().applyToPackage(
        bare('Stopwatch'),
        name: 'Stopwatch',
      );
      final result = const IntentPreservationValidator().validate(
        rawPrompt: 'a stopwatch',
        package: timing,
      );
      expect(result.isCompatible, isTrue);
      expect(PackageCapabilityProbe(timing).hasTimingControls, isTrue);
      expect(PackageCapabilityProbe(timing).hasCalculationPad, isFalse);
    });
  });

  group('IS-P12 timing session', () {
    test('start pause resume reset lap use wall clock', () async {
      final state = ExperienceStateEngine();
      state.initialize(const TimingInterfaceFactory().buildState());

      TimingSession.apply(state, eventId: TimingSession.start);
      expect(state.read('running'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      TimingSession.apply(state, eventId: TimingSession.tick);
      final runningDisplay = state.read('display') as String;
      expect(runningDisplay, isNot('00:00.00'));

      TimingSession.apply(state, eventId: TimingSession.pause);
      expect(state.read('running'), isFalse);
      final paused = state.read('display');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      TimingSession.apply(state, eventId: TimingSession.tick);
      expect(state.read('display'), paused);

      TimingSession.apply(state, eventId: TimingSession.resume);
      expect(state.read('running'), isTrue);

      TimingSession.apply(state, eventId: TimingSession.lap);
      final laps = state.read('lapsText') as String;
      expect(laps, contains('Lap'));

      TimingSession.apply(state, eventId: TimingSession.reset);
      expect(state.read('display'), '00:00.00');
      expect(state.read('running'), isFalse);
    });
  });

  group('IS-P12 creation request snapshot', () {
    test('normalizes and freezes prompt', () {
      final req = CreationRequest.capture(rawPrompt: '  stopwatch  \n');
      expect(req.normalizedPrompt, 'stopwatch');
      expect(req.requestId, isNotEmpty);
      expect(req.rawPrompt, '  stopwatch  \n');
    });
  });

  group('IS-P12 novel prompt purposes', () {
    const validator = IntentPreservationValidator();

    final cases = <String, IntentPurpose>{
      'a countdown timer': IntentPurpose.timing,
      'a habit tracker': IntentPurpose.collection,
      'a recipe manager': IntentPurpose.collection,
      'a personal CRM': IntentPurpose.collection,
      'a library manager': IntentPurpose.collection,
      'an inventory tracker': IntentPurpose.collection,
      'a workout tracker': IntentPurpose.collection,
      'a project planner': IntentPurpose.collection,
      'a journal': IntentPurpose.collection,
      'a flashcard app': IntentPurpose.collection,
      'a bill splitter': IntentPurpose.calculation,
      'a booking manager': IntentPurpose.collection,
      'a classroom attendance app': IntentPurpose.collection,
      'calculator': IntentPurpose.calculation,
      'weather dashboard': IntentPurpose.weather,
    };

    for (final entry in cases.entries) {
      test('prompt "${entry.key}" → ${entry.value.name}', () {
        expect(validator.purposeFromPrompt(entry.key), entry.value);
      });
    }
  });
}
