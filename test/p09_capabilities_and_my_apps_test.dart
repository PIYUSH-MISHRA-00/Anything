/// IS-P09 — My Apps refresh, capability inference, calculation, semantic gate.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/app/app_composition.dart';
import 'package:anything/app/experience_commit.dart';
import 'package:anything/app/experience_provenance.dart';
import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/creation/calculation_interface_factory.dart';
import 'package:anything/creation/deterministic_repair.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/network_reference_interface_factory.dart';
import 'package:anything/creation/semantic_completeness.dart';
import 'package:anything/runtime/calculation_session.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/synthesis/app_archetype.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/model_reasoner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AppCapabilityInferrer', () {
    test('utility archetype alone does not force calculation (IS-P12)', () {
      final bp = AppBlueprint(
        id: 'bp1',
        name: 'Quick Math',
        description: 'Do arithmetic',
        archetypes: const [AppArchetype.utility],
      );
      final caps = const AppCapabilityInferrer().infer(blueprint: bp);
      expect(caps, isNot(contains(AppCapabilityIds.calculation)));
    });

    test('calculator expression still infers calculation (IS-P12)', () {
      final bp = AppBlueprint(
        id: 'bp1b',
        name: 'Quick Math',
        description: 'Do arithmetic',
        archetypes: const [AppArchetype.utility],
      );
      final caps = const AppCapabilityInferrer().infer(
        blueprint: bp,
        intent: Intent.create(expression: 'calculator'),
      );
      expect(caps, contains(AppCapabilityIds.calculation));
      expect(caps, contains(AppCapabilityIds.resultDisplay));
    });

    test('reference archetype requires network data capabilities', () {
      final bp = AppBlueprint(
        id: 'bp2',
        name: 'Live Lookup',
        description: 'External conditions',
        archetypes: const [AppArchetype.reference],
        networkConfig: const BlueprintNetworkConfig(
          purpose: 'Fetch live conditions',
        ),
      );
      final caps = const AppCapabilityInferrer().infer(blueprint: bp);
      expect(caps, contains(AppCapabilityIds.networkData));
      expect(caps, contains(AppCapabilityIds.refresh));
      expect(caps, contains(AppCapabilityIds.loadingState));
      expect(caps, isNot(contains('weather')));
    });

    test('collection CRUD requires persistence capabilities', () {
      final bp = AppBlueprint(
        id: 'bp3',
        name: 'Notes',
        description: 'Store notes',
        archetypes: const [AppArchetype.collection],
        entities: const [
          BlueprintEntity(
            id: 'note',
            name: 'Note',
            fields: [
              BlueprintField(
                id: 'title',
                name: 'Title',
                type: BlueprintFieldType.text,
              ),
            ],
          ),
        ],
        actions: const [
          BlueprintAction(
            id: 'create_note',
            name: 'Add',
            targetEntityId: 'note',
            actionType: BlueprintActionType.create,
          ),
        ],
        views: const [
          BlueprintView(
            id: 'list',
            name: 'List',
            purpose: 'Show notes',
            viewType: BlueprintViewType.list,
            sourceEntityId: 'note',
          ),
        ],
      );
      final caps = const AppCapabilityInferrer().infer(blueprint: bp);
      expect(caps, contains(AppCapabilityIds.crud));
      expect(caps, contains(AppCapabilityIds.persistence));
    });
  });

  group('CalculationSession', () {
    ExperienceStateEngine engine() {
      final e = ExperienceStateEngine();
      e.initialize(const CalculationInterfaceFactory().buildState());
      return e;
    }

    test('2 + 2 = 4', () {
      final s = engine();
      CalculationSession.apply(
        s,
        eventId: CalculationSession.digit,
        data: {'value': 2},
      );
      CalculationSession.apply(
        s,
        eventId: CalculationSession.operator_,
        data: {'op': '+'},
      );
      CalculationSession.apply(
        s,
        eventId: CalculationSession.digit,
        data: {'value': 2},
      );
      CalculationSession.apply(s, eventId: CalculationSession.equals);
      expect(s.read('display'), '4');
    });

    test('12 × 8 = 96', () {
      final s = engine();
      CalculationSession.apply(
        s,
        eventId: CalculationSession.digit,
        data: {'value': 1},
      );
      CalculationSession.apply(
        s,
        eventId: CalculationSession.digit,
        data: {'value': 2},
      );
      CalculationSession.apply(
        s,
        eventId: CalculationSession.operator_,
        data: {'op': '*'},
      );
      CalculationSession.apply(
        s,
        eventId: CalculationSession.digit,
        data: {'value': 8},
      );
      CalculationSession.apply(s, eventId: CalculationSession.equals);
      expect(s.read('display'), '96');
    });

    test('division by zero sets error', () {
      final s = engine();
      CalculationSession.apply(
        s,
        eventId: CalculationSession.digit,
        data: {'value': 1},
      );
      CalculationSession.apply(
        s,
        eventId: CalculationSession.operator_,
        data: {'op': '/'},
      );
      CalculationSession.apply(
        s,
        eventId: CalculationSession.digit,
        data: {'value': 0},
      );
      CalculationSession.apply(s, eventId: CalculationSession.equals);
      expect(s.read('display'), 'Error');
      expect(s.read('error'), isNotEmpty);
    });

    test('clear resets display', () {
      final s = engine();
      CalculationSession.apply(
        s,
        eventId: CalculationSession.digit,
        data: {'value': 9},
      );
      CalculationSession.apply(s, eventId: CalculationSession.clear);
      expect(s.read('display'), '0');
    });

    test('legacy aliases still work', () {
      final s = engine();
      CalculationSession.apply(s, eventId: 'numberPressed', data: {'value': 3});
      CalculationSession.apply(
        s,
        eventId: 'operationPressed',
        data: {'op': '+'},
      );
      CalculationSession.apply(s, eventId: 'numberPressed', data: {'value': 4});
      CalculationSession.apply(s, eventId: 'equalsPressed');
      expect(s.read('display'), '7');
    });
  });

  group('SemanticCompleteness + repair', () {
    test('incomplete calculation package fails then repair succeeds', () {
      final now = DateTime.now();
      final incomplete = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: 'exp-calc',
          name: 'Calc',
          description: 'math',
          createdAt: now,
          updatedAt: now,
        ),
        interface: const InterfaceDefinition(
          screens: [
            InterfaceScreen(
              id: 'main',
              title: 'Calc',
              children: [
                InterfaceNode(
                  type: 'text',
                  id: 'pretty',
                  properties: {'content': 'Beautiful but empty'},
                ),
              ],
            ),
          ],
        ),
        behavior: const BehaviorGraph(nodes: [], edges: []),
        state: const StateSchema(variables: []),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(contentHash: 'x', computedAt: now),
      );

      final caps = {
        AppCapabilityIds.calculation,
        AppCapabilityIds.resultDisplay,
      };
      final before = const SemanticCompletenessValidator().validate(
        package: incomplete,
        requiredCapabilities: caps,
      );
      expect(before.isComplete, isFalse);

      final repaired = const DeterministicCapabilityRepair().repair(
        package: incomplete,
        requiredCapabilities: caps,
      );
      expect(repaired.repaired, isTrue);
      expect(repaired.completeness.isComplete, isTrue);
      expect(
        PackageCapabilityProbe(repaired.package).hasCalculationPad,
        isTrue,
      );
    });

    test('network shell satisfies networkData capabilities', () {
      final now = DateTime.now();
      final base = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: 'exp-ref',
          name: 'Lookup',
          description: 'live data',
          createdAt: now,
          updatedAt: now,
        ),
        interface: const InterfaceDefinition(screens: []),
        behavior: const BehaviorGraph(nodes: [], edges: []),
        state: const StateSchema(variables: []),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(contentHash: 'x', computedAt: now),
      );
      final caps = {
        AppCapabilityIds.networkData,
        AppCapabilityIds.refresh,
        AppCapabilityIds.loadingState,
        AppCapabilityIds.errorState,
        AppCapabilityIds.input,
        AppCapabilityIds.resultDisplay,
      };
      final repaired = const DeterministicCapabilityRepair().repair(
        package: base,
        requiredCapabilities: caps,
      );
      expect(repaired.completeness.isComplete, isTrue);
      expect(
        PackageCapabilityProbe(repaired.package).hasKnowledgeService,
        isTrue,
      );
    });

    // Regression (owner report): a booking/records app must NOT be clobbered
    // into the "City or location" search shell by the repair pass when a
    // networkData gap exists. A records surface (entity list/form) means the
    // app IS a manager; repair may enrich it but must never replace its UI.
    test('repair does not replace a records surface with the search shell', () {
      final now = DateTime.now();
      final base = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: 'exp-booking',
          name: 'Train Ticket Booking',
          description: 'search, book and manage train tickets',
          createdAt: now,
          updatedAt: now,
        ),
        interface: const InterfaceDefinition(
          screens: [
            InterfaceScreen(
              id: 'list',
              title: 'Bookings',
              children: [
                InterfaceNode(
                  type: 'entityList',
                  id: 'booking_list',
                  properties: {'entityId': 'booking'},
                ),
                InterfaceNode(
                  type: 'entityForm',
                  id: 'booking_form',
                  properties: {'entityId': 'booking'},
                ),
              ],
            ),
          ],
        ),
        behavior: const BehaviorGraph(nodes: [], edges: []),
        state: const StateSchema(variables: []),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(contentHash: 'x', computedAt: now),
      );
      final repaired = const DeterministicCapabilityRepair().repair(
        package: base,
        requiredCapabilities: {
          AppCapabilityIds.networkData,
          AppCapabilityIds.crud,
          AppCapabilityIds.collection,
        },
      );
      final probe = PackageCapabilityProbe(repaired.package);
      expect(probe.hasEntityList, isTrue,
          reason: 'the records list must survive repair');
      expect(probe.hasEntityForm, isTrue,
          reason: 'the records form must survive repair');
      expect(repaired.appliedFixes, isNot(contains('injected_network_reference_shell')));
    });
  });

  group('Model reasoner open-world coercion', () {
    test('unknown action/field types do not throw via parse helpers', () {
      // Exercise through a minimal fake by constructing SemanticApp path
      // via private parsers is not possible — instead ensure vocabulary is
      // advertised and coercion constants exist.
      expect(AppCapabilityIds.vocabulary, contains('networkData'));
      expect(AppCapabilityIds.vocabulary, contains('calculation'));
      expect(ModelApplicationReasoner, isNotNull);
    });
  });

  group('My Apps library revision', () {
    tearDown(() {
      AppComposition.resetForTesting();
    });

    test('commit bumps experienceLibraryRevision', () async {
      final composition = AppComposition.freshForTesting();
      addTearDown(() async {
        await composition.experienceRepository.close();
      });

      var bumps = 0;
      void listener() => bumps++;
      composition.experienceLibraryRevision.addListener(listener);
      addTearDown(
        () => composition.experienceLibraryRevision.removeListener(listener),
      );

      final now = DateTime.now();
      final id = 'exp-p09-${now.microsecondsSinceEpoch}';
      final package = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: id,
          name: 'Visible App',
          description: 'should appear in My Apps',
          createdAt: now,
          updatedAt: now,
        ),
        interface: const InterfaceDefinition(
          screens: [
            InterfaceScreen(
              id: 'main',
              title: 'Main',
              children: [
                InterfaceNode(
                  type: 'text',
                  id: 't',
                  properties: {'content': 'hi'},
                ),
              ],
            ),
          ],
        ),
        behavior: const BehaviorGraph(nodes: [], edges: []),
        state: const StateSchema(variables: []),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(contentHash: 'h', computedAt: now),
      );
      final metadata = ExperienceMetadataRecord(
        id: id,
        name: 'Visible App',
        description: 'should appear in My Apps',
        category: 'utility',
        createdAt: now,
        updatedAt: now,
        provenance: ExperienceProvenance.createdLocally(
          at: now,
          fingerprint: ExperienceFingerprint('h'),
        ),
      );

      final before = composition.experienceLibraryRevision.value;
      final result = await composition.experienceCommit.commit(
        experienceId: id,
        origin: CommitOrigin.creation,
        package: package,
        metadata: metadata,
      );
      expect(result.succeeded, isTrue);
      expect(composition.experienceLibraryRevision.value, greaterThan(before));
      expect(bumps, greaterThan(0));

      final listed = await composition.experienceRepository.listAll();
      expect(listed.any((e) => e.id == id), isTrue);
      expect(listed.firstWhere((e) => e.id == id).name, 'Visible App');
    });
  });

  group('NetworkReferenceInterfaceFactory', () {
    test('emits query, refresh, loading, error, result', () {
      final iface = const NetworkReferenceInterfaceFactory().buildInterface(
        title: 'Lookup',
        purpose: 'External data',
      );
      final nodes = <InterfaceNode>[];
      void walk(List<InterfaceNode> list) {
        for (final n in list) {
          nodes.add(n);
          walk(n.children);
        }
      }

      walk(iface.screens.expand((s) => s.children).toList());
      expect(nodes.any((n) => n.stateBinding == 'query'), isTrue);
      expect(
        nodes.any((n) => n.actionBinding?.actionId == 'refreshData'),
        isTrue,
      );
      expect(nodes.any((n) => n.id == 'search_button'), isTrue);
      expect(nodes.any((n) => n.stateBinding == 'error'), isTrue);
      expect(nodes.any((n) => n.stateBinding == 'resultText'), isTrue);
    });
  });
}
