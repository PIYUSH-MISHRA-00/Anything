/// Tests for ExperiencePackage and Creation Engine.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/creation_engine.dart';
import 'package:anything/creation/creation_context.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/kernel/planning/execution_plan.dart';
import 'package:anything/core/contracts/intent.dart';

void main() {
  group('ExperiencePackage', () {
    test('serialization round trip', () {
      final now = DateTime(2025, 1, 1);
      final pkg = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: 'exp-1',
          name: 'Calculator',
          description: 'A calculator',
          createdAt: now,
          updatedAt: now,
        ),
        interface: InterfaceDefinition(
          screens: [InterfaceScreen(id: 'main', title: 'Calculator')],
        ),
        behavior: BehaviorGraph(
          nodes: [
            BehaviorNode(
              id: 'n1',
              type: 'event',
              config: {'description': 'input'},
            ),
          ],
        ),
        state: StateSchema(
          variables: [StateVariable(id: 'result', type: 'decimal')],
        ),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(contentHash: 'abc123', computedAt: now),
      );

      final json = pkg.toJson();
      final restored = ExperiencePackage.fromJson(json);

      expect(restored.manifest.experienceId, equals('exp-1'));
      expect(restored.manifest.name, equals('Calculator'));
      expect(restored.interface.screens, hasLength(1));
      expect(restored.behavior.nodes, hasLength(1));
      expect(restored.state.variables, hasLength(1));
    });

    test('integrity hash is deterministic', () {
      final now = DateTime(2025, 1, 1);
      final pkg1 = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: 'exp-1',
          name: 'Test',
          description: 'Test',
          createdAt: now,
          updatedAt: now,
        ),
        interface: InterfaceDefinition(),
        behavior: BehaviorGraph(),
        state: StateSchema(),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(
          contentHash: '',
          computedAt: DateTime(2025, 1, 1),
        ),
      );

      final hash1 = ExperiencePackage.computeIntegrityHash(pkg1);
      final hash2 = ExperiencePackage.computeIntegrityHash(pkg1);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 hex
    });
  });

  group('ExperienceManifest', () {
    test('network mode serialization', () {
      final manifest = ExperienceManifest(
        experienceId: 'exp-1',
        name: 'Test',
        description: 'Test',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        networkMode: NetworkMode.required,
      );

      final json = manifest.toJson();
      final restored = ExperienceManifest.fromJson(json);

      expect(restored.networkMode, equals(NetworkMode.required));
    });
  });

  group('InterfaceDefinition', () {
    test('nested structure', () {
      final interface = InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Main',
            children: [
              InterfaceNode(
                type: 'text',
                id: 'title',
                properties: {'content': 'Hello'},
              ),
              InterfaceNode(
                type: 'column',
                id: 'body',
                children: [
                  InterfaceNode(type: 'text', id: 'item1'),
                  InterfaceNode(type: 'button', id: 'action1'),
                ],
              ),
            ],
          ),
        ],
      );

      final json = interface.toJson();
      final restored = InterfaceDefinition.fromJson(json);

      expect(restored.screens, hasLength(1));
      expect(restored.screens[0].children, hasLength(2));
      expect(restored.screens[0].children[1].children, hasLength(2));
    });
  });

  group('BehaviorGraph', () {
    test('edges connect nodes', () {
      final graph = BehaviorGraph(
        nodes: [
          BehaviorNode(id: 'n1', type: 'event'),
          BehaviorNode(id: 'n2', type: 'stateWrite'),
        ],
        edges: [BehaviorEdge(from: 'n1', to: 'n2')],
      );

      final json = graph.toJson();
      final restored = BehaviorGraph.fromJson(json);

      expect(restored.nodes, hasLength(2));
      expect(restored.edges, hasLength(1));
      expect(restored.edges[0].from, equals('n1'));
      expect(restored.edges[0].to, equals('n2'));
    });
  });

  group('DataSchema', () {
    test('entity with fields', () {
      final schema = DataSchema(
        entities: [
          DataEntitySchema(
            id: 'e_habit',
            name: 'habit',
            fields: [
              DataFieldSchema(
                id: 'f_test',
                name: 'id',
                type: 'integer',
                required: true,
              ),
              DataFieldSchema(
                id: 'f_test',
                name: 'name',
                type: 'string',
                required: true,
              ),
              DataFieldSchema(
                id: 'f_test3',
                name: 'completed',
                type: 'boolean',
                defaultValue: false,
              ),
            ],
          ),
        ],
      );

      final json = schema.toJson();
      final restored = DataSchema.fromJson(json);

      expect(restored.entities, hasLength(1));
      expect(restored.entities[0].fields, hasLength(3));
      expect(restored.entities[0].fields[2].defaultValue, equals(false));
    });
  });

  group('ExperiencePackageValidator', () {
    test('valid package passes', () {
      final pkg = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: 'exp-1',
          name: 'Test',
          description: 'Test',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
        interface: InterfaceDefinition(
          screens: [InterfaceScreen(id: 'main', title: 'Main')],
        ),
        behavior: BehaviorGraph(
          nodes: [BehaviorNode(id: 'n1', type: 'event')],
        ),
        state: StateSchema(),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(
          contentHash: 'abc',
          computedAt: DateTime(2025, 1, 1),
        ),
      );

      final result = ExperiencePackageValidator.validate(pkg);
      expect(result.isValid, isTrue);
    });

    test('missing experienceId fails', () {
      final pkg = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: '',
          name: 'Test',
          description: 'Test',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
        interface: InterfaceDefinition(),
        behavior: BehaviorGraph(),
        state: StateSchema(),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(
          contentHash: '',
          computedAt: DateTime(2025, 1, 1),
        ),
      );

      final result = ExperiencePackageValidator.validate(pkg);
      expect(result.isValid, isFalse);
      expect(result.errors, contains('Manifest missing experienceId'));
    });

    test('dangling state reference fails', () {
      final pkg = ExperiencePackage(
        manifest: ExperienceManifest(
          experienceId: 'exp-1',
          name: 'Test',
          description: 'Test',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
        interface: InterfaceDefinition(),
        behavior: BehaviorGraph(
          nodes: [
            BehaviorNode(
              id: 'n1',
              type: 'stateRead',
              config: {'stateRef': 'nonexistent'},
            ),
          ],
        ),
        state: StateSchema(
          variables: [StateVariable(id: 'existing', type: 'string')],
        ),
        provenance: const PackageProvenance(
          creationEngineVersion: '1.0.0',
          specVersion: 1,
          planVersion: 1,
        ),
        integrity: PackageIntegrity(
          contentHash: '',
          computedAt: DateTime(2025, 1, 1),
        ),
      );

      final result = ExperiencePackageValidator.validate(pkg);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('nonexistent')), isTrue);
    });
  });

  group('CreationEngine', () {
    test('Calculator golden path', () async {
      final spec = ExperienceSpec(
        id: 'spec-calc',
        name: 'Calculator',
        description: 'A calculator',
        category: ExperienceCategory.tool,
        interactionModel: InteractionModel.directManipulation,
        uiRequirements: const UIRequirements(
          description: 'Calculator interface',
          primaryViews: ['main'],
          inputElements: ['numeric keypad'],
          displayElements: ['result display'],
        ),
        stateRequirements: const StateRequirements(
          description: 'Ephemeral calculation state',
        ),
        storageRequirements: const StorageRequirements(
          description: 'No storage',
        ),
        networkRequirements: const NetworkRequirements(
          networkNeed: NetworkNeed.none,
        ),
        backendClassification: BackendClassification.none,
        protectionRequirements: const ProtectionRequirements(),
        runtimeRequirements: const RuntimeRequirements(),
        qualityRequirements: const QualityRequirements(),
        accessibilityRequirements: const AccessibilityRequirements(),
        offlineBehavior: const OfflineBehavior(
          offlineCapability: OfflineCapability.fullyOffline,
        ),
        createdAt: DateTime(2025, 1, 1),
      );

      final plan = ExecutionPlan(
        id: 'plan-1',
        specification: spec,
        steps: const [
          ExecutionStep(
            stepId: 's1',
            type: StepType.validateImplementation,
            description: 'Validate',
            expectedOutputType: 'result',
          ),
        ],
        createdAt: DateTime(2025, 1, 1),
      );

      final context = CreationContext(
        intent: Intent.create(expression: 'Calculator'),
        specification: spec,
        plan: plan,
        platformContext: const PlatformContext(
          platform: 'android',
          sdkVersion: 34,
        ),
        securityPolicy: const CreationSecurityPolicy(),
      );

      final engine = CreationEngine();
      final result = await engine.create(context);

      expect(result, isA<CreationReady>());
      if (result is CreationReady) {
        expect(result.package.manifest.name, equals('Calculator'));
        expect(result.package.manifest.networkMode, equals(NetworkMode.none));
        expect(result.package.manifest.storageMode, equals(StorageMode.none));
        expect(result.package.interface.screens, isNotEmpty);
        expect(result.package.integrity.contentHash, isNotEmpty);
      }
    });

    test('Habit Tracker has local data', () async {
      final spec = ExperienceSpec(
        id: 'spec-habit',
        name: 'Habit Tracker',
        description: 'Track habits',
        category: ExperienceCategory.productivity,
        interactionModel: InteractionModel.formBased,
        uiRequirements: const UIRequirements(description: 'Tracker'),
        stateRequirements: const StateRequirements(
          description: 'Persistent state',
          requiresPersistentState: true,
        ),
        storageRequirements: const StorageRequirements(
          description: 'Local database',
          storageType: StorageType.localDatabase,
          requiresDatabase: true,
        ),
        networkRequirements: const NetworkRequirements(
          networkNeed: NetworkNeed.none,
        ),
        backendClassification: BackendClassification.localDatabase,
        protectionRequirements: const ProtectionRequirements(),
        runtimeRequirements: const RuntimeRequirements(),
        qualityRequirements: const QualityRequirements(),
        accessibilityRequirements: const AccessibilityRequirements(),
        offlineBehavior: const OfflineBehavior(
          offlineCapability: OfflineCapability.fullyOffline,
        ),
        createdAt: DateTime(2025, 1, 1),
      );

      final plan = ExecutionPlan(
        id: 'plan-2',
        specification: spec,
        steps: const [
          ExecutionStep(
            stepId: 's1',
            type: StepType.prepareStorage,
            description: 'Prepare storage',
            expectedOutputType: 'schema',
          ),
        ],
        createdAt: DateTime(2025, 1, 1),
      );

      final context = CreationContext(
        intent: Intent.create(expression: 'Create a habit tracker'),
        specification: spec,
        plan: plan,
        platformContext: const PlatformContext(
          platform: 'android',
          sdkVersion: 34,
        ),
        securityPolicy: const CreationSecurityPolicy(),
      );

      final engine = CreationEngine();
      final result = await engine.create(context);

      expect(result, isA<CreationReady>());
      if (result is CreationReady) {
        expect(result.package.data, isNotNull);
        expect(
          result.package.manifest.storageMode,
          equals(StorageMode.localDatabase),
        );
      }
    });

    test('Weather Dashboard declares network', () async {
      final spec = ExperienceSpec(
        id: 'spec-weather',
        name: 'Weather Dashboard',
        description: 'Weather info',
        category: ExperienceCategory.utility,
        interactionModel: InteractionModel.dashboard,
        uiRequirements: const UIRequirements(description: 'Weather'),
        stateRequirements: const StateRequirements(description: 'State'),
        storageRequirements: const StorageRequirements(description: 'None'),
        networkRequirements: const NetworkRequirements(
          networkNeed: NetworkNeed.required,
          description: 'Weather API',
        ),
        backendClassification: BackendClassification.externalApi,
        protectionRequirements: const ProtectionRequirements(),
        runtimeRequirements: const RuntimeRequirements(),
        qualityRequirements: const QualityRequirements(),
        accessibilityRequirements: const AccessibilityRequirements(),
        offlineBehavior: const OfflineBehavior(
          offlineCapability: OfflineCapability.requiresNetwork,
        ),
        createdAt: DateTime(2025, 1, 1),
      );

      final plan = ExecutionPlan(
        id: 'plan-3',
        specification: spec,
        steps: const [
          ExecutionStep(
            stepId: 's1',
            type: StepType.obtainKnowledge,
            description: 'Get API docs',
            expectedOutputType: 'knowledge',
          ),
        ],
        createdAt: DateTime(2025, 1, 1),
      );

      final context = CreationContext(
        intent: Intent.create(expression: 'Make me a weather dashboard'),
        specification: spec,
        plan: plan,
        platformContext: const PlatformContext(
          platform: 'android',
          sdkVersion: 34,
        ),
        securityPolicy: const CreationSecurityPolicy(),
        isOffline: false,
      );

      final engine = CreationEngine();
      final result = await engine.create(context);

      expect(result, isA<CreationReady>());
      if (result is CreationReady) {
        expect(
          result.package.manifest.networkMode,
          equals(NetworkMode.required),
        );
        expect(result.package.networkDeclarations, isNotEmpty);
      }
    });

    test('Notes app has CRUD behavior', () async {
      final spec = ExperienceSpec(
        id: 'spec-notes',
        name: 'Notes',
        description: 'Note taking',
        category: ExperienceCategory.productivity,
        interactionModel: InteractionModel.formBased,
        uiRequirements: const UIRequirements(
          description: 'Notes',
          primaryViews: ['note list', 'note editor'],
        ),
        functionalRequirements: const [
          FunctionalRequirement(id: 'fr-1', description: 'Create note'),
          FunctionalRequirement(id: 'fr-2', description: 'Read note'),
          FunctionalRequirement(id: 'fr-3', description: 'Update note'),
          FunctionalRequirement(id: 'fr-4', description: 'Delete note'),
        ],
        stateRequirements: const StateRequirements(description: 'State'),
        storageRequirements: const StorageRequirements(
          description: 'Local database',
          storageType: StorageType.localDatabase,
          requiresDatabase: true,
        ),
        networkRequirements: const NetworkRequirements(
          networkNeed: NetworkNeed.none,
        ),
        backendClassification: BackendClassification.localDatabase,
        protectionRequirements: const ProtectionRequirements(),
        runtimeRequirements: const RuntimeRequirements(),
        qualityRequirements: const QualityRequirements(),
        accessibilityRequirements: const AccessibilityRequirements(),
        offlineBehavior: const OfflineBehavior(
          offlineCapability: OfflineCapability.fullyOffline,
        ),
        createdAt: DateTime(2025, 1, 1),
      );

      final plan = ExecutionPlan(
        id: 'plan-4',
        specification: spec,
        steps: const [
          ExecutionStep(
            stepId: 's1',
            type: StepType.prepareImplementation,
            description: 'Build',
            expectedOutputType: 'impl',
          ),
        ],
        createdAt: DateTime(2025, 1, 1),
      );

      final context = CreationContext(
        intent: Intent.create(expression: 'Create a notes app'),
        specification: spec,
        plan: plan,
        platformContext: const PlatformContext(
          platform: 'android',
          sdkVersion: 34,
        ),
        securityPolicy: const CreationSecurityPolicy(),
      );

      final engine = CreationEngine();
      final result = await engine.create(context);

      expect(result, isA<CreationReady>());
      if (result is CreationReady) {
        expect(result.package.behavior.nodes.length, greaterThanOrEqualTo(4));
        expect(result.package.data, isNotNull);
      }
    });
  });
}
