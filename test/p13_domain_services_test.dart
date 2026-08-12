/// IS-P13 — capability inference, semantic preservation + stopwatch controls.
///
/// Domain services (WeatherDataService, NewsDataService) have been removed.
/// All external data acquisition now flows through WebWeaveX via the ONE
/// generic knowledge capability (KnowledgeAcquisitionEngine), with topic +
/// freshness semantics carried in the requirement (IS-P25).
library;

import 'package:anything/core/contracts/intent.dart';
import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/creation/intent_preservation.dart';
import 'package:anything/creation/network_reference_interface_factory.dart';
import 'package:anything/creation/timing_interface_factory.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/runtime/timing_session.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/synthesis/app_archetype.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  group('IS-P13 capability inference', () {
    test('weather prompt → weatherData not network knowledge', () {
      final bp = AppBlueprint(
        id: 'bp',
        name: 'Wx',
        description: 'live conditions',
        archetypes: const [AppArchetype.reference],
      );
      final caps = const AppCapabilityInferrer().infer(
        blueprint: bp,
        intent: Intent.create(expression: 'weather dashboard'),
      );
      expect(caps.contains(AppCapabilityIds.weatherData), isTrue);
      expect(caps.contains(AppCapabilityIds.networkData), isFalse);
      expect(caps.contains(AppCapabilityIds.webKnowledge), isFalse);
    });

    test('news prompt → newsData not Wikipedia knowledge', () {
      final bp = AppBlueprint(
        id: 'bp',
        name: 'News',
        description: 'headlines',
        archetypes: const [AppArchetype.collection, AppArchetype.reference],
      );
      final caps = const AppCapabilityInferrer().infer(
        blueprint: bp,
        intent: Intent.create(expression: 'news app'),
      );
      expect(caps.contains(AppCapabilityIds.newsData), isTrue);
      expect(caps.contains(AppCapabilityIds.networkData), isFalse);
      expect(caps.contains(AppCapabilityIds.crud), isFalse);
      expect(caps.contains(AppCapabilityIds.form), isFalse);
    });
  });

  group('IS-P13 semantic preservation', () {
    test('weather vs knowledge package is incompatible', () {
      final knowledge = const NetworkReferenceInterfaceFactory().applyToPackage(
        bare('Lookup'),
        name: 'Lookup',
        purpose: 'lookup',
      );
      final result = const IntentPreservationValidator().validate(
        rawPrompt: 'weather dashboard',
        package: knowledge,
      );
      expect(result.isCompatible, isFalse);
      expect(result.requested, IntentPurpose.weather);
    });

    test('external data package is compatible', () {
      final net = const NetworkReferenceInterfaceFactory().applyToPackage(
        bare('External Data'),
        name: 'External Data',
        purpose: 'Fetch external data',
      );
      final result = const IntentPreservationValidator().validate(
        rawPrompt: 'dashboard for live data',
        package: net,
      );
      expect(result.isCompatible, isTrue);
      expect(PackageCapabilityProbe(net).hasKnowledgeService, isTrue);
      final input = net.interface.screens.first.children
          .expand((n) => [n, ...n.children])
          .firstWhere((n) => n.id == 'query_input');
      expect(input.properties['width'], 'expand');
    });

    test('news package is compatible', () {
      final net = const NetworkReferenceInterfaceFactory().applyToPackage(
        bare('News'),
        name: 'News',
        purpose: 'Fetch news articles',
      );
      final result = const IntentPreservationValidator().validate(
        rawPrompt: 'dashboard for live data',
        package: net,
      );
      expect(result.isCompatible, isTrue);
      expect(PackageCapabilityProbe(net).hasKnowledgeService, isTrue);
    });
  });

  group('IS-P13 stopwatch controls', () {
    test('timing package has start/pause/reset bindings and timingPad', () {
      final pkg = const TimingInterfaceFactory().applyToPackage(
        bare('Stopwatch'),
        name: 'Stopwatch',
      );
      expect(PackageCapabilityProbe(pkg).hasTimingControls, isTrue);
      expect(
        pkg.interface.screens.first.children.any((c) => c.type == 'timingPad'),
        isTrue,
      );
      final state = ExperienceStateEngine()..initialize(pkg.state);
      TimingSession.apply(state, eventId: TimingSession.start);
      expect(state.read('running'), isTrue);
    });
  });
}
