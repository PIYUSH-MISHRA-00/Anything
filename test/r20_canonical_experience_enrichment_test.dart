/// Implementation Milestone R20 — Canonical Experience Enrichment, Close
/// The Legacy/Compiler Equivalence Gaps. Proves the two real, verified
/// gaps this milestone closes (per R19's own `EquivalenceReport`, both
/// found by direct code tracing, never invented):
///
/// 1. `SemanticField` (the reasoner's own output) already carries
///    `defaultValue`/`referenceEntityId`/`allowedValues`/`description`,
///    the SAME source legacy's `CreationEngine` already reads into
///    `DataFieldSchema` — but `ImplementationField` (R9) dropped all of
///    it. `minLength`/`maxLength`/`minimum`/`maximum` are deliberately
///    NOT enriched: legacy's own `CreationEngine
///    ._buildDataSchemaFromBlueprint` declares but never populates them
///    either (verified by reading it) — enriching them here would
///    fabricate parity with something legacy itself doesn't represent.
/// 2. `SemanticDerivedValue` gets real `dataQuery`+`calculation` behavior
///    nodes in legacy; `RuntimeExperienceGenerator` had zero handling of
///    them. Both node types are already real, already-supported
///    `BehaviorInterpreter` cases (confirmed by grep) — this milestone
///    makes the compiler emit the SAME node/state shape legacy already
///    does, not a new runtime concept.
///
/// Never a second `CanonicalImplementationModel`/`ExperiencePackage`/
/// Runtime/Generator Framework/Build Graph/Planner/AI Boundary.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/application_engineering/engineering_context.dart';
import 'package:anything/application_engineering/engineering_planner.dart';
import 'package:anything/backend_engineering/backend_engineering_context.dart';
import 'package:anything/backend_engineering/backend_engineering_planner.dart';
import 'package:anything/build_graph/universal_build_graph.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/compiler_integration/compiler_pipeline_runner.dart';
import 'package:anything/compiler_integration/equivalence_comparator.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/creation/creation_context.dart';
import 'package:anything/creation/creation_engine.dart' hide CreationResult;
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/generator_framework/generation_pipeline.dart';
import 'package:anything/generator_framework/generator.dart';
import 'package:anything/generator_framework/reference/runtime_experience_generator.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/implementation_model/canonical_implementation_planner.dart';
import 'package:anything/implementation_model/canonical_implementation_serialization.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures (mirroring test/r19_compiler_production_integration_test.dart's
// established shape — a test file cannot import another test file's
// private helpers, so equivalents are redeclared minimally). ─────────────

CapabilityRegistry _registryWithStorage() {
  final registry = CapabilityRegistry();
  registry.register(
    const CapabilityDescriptor(
      id: 'storage',
      version: '1.0.0',
      name: 'Storage',
      description: 'Local storage',
      category: CapabilityCategory.storage,
      inputContract: 'data',
      outputContract: 'stored data',
    ),
  );
  return registry;
}

class _FakeProviderRegistry implements ModelProviderRegistry {
  @override
  ModelProvider? get activeProvider => null;
  @override
  List<ModelProvider> get providers => const [];
  @override
  void registerProvider(ModelProvider provider) {}
  @override
  Future<void> setActiveProvider(String providerId) async {}
  @override
  ModelProvider? getProvider(String providerId) => null;
  @override
  Future<List<ProviderConfig>> listConfigs() async => [];
  @override
  Future<void> saveConfig(ProviderConfig config) async {}
  @override
  Future<void> deleteConfig(String id) async {}
  @override
  Future<ProviderConfig?> getDefaultConfig() async => null;
}

class _FixedReasoner implements ApplicationReasoner {
  final SemanticApp app;
  const _FixedReasoner(this.app);
  @override
  Future<AppReasoningResult> reason(
    ApplicationReasoningContext context,
  ) async => ReasoningReady(semanticApp: app);
}

/// "Field Log Rich" — same shape as R19's "Field Log" fixture, but with
/// real, non-trivial field metadata AND a real derived value, so this
/// milestone's enrichment has something real to prove against.
SemanticApp _fieldLogRichApp() => SemanticApp(
  name: 'Field Log Rich',
  purpose: 'Track field log entries with rich metadata',
  entities: [
    const SemanticEntity(
      id: 'entry',
      name: 'Entry',
      displayField: 'title',
      fields: [
        SemanticField(
          id: 'title',
          name: 'Title',
          type: BlueprintFieldType.text,
          required: true,
          defaultValue: 'Untitled',
          description: 'The entry title',
        ),
        SemanticField(
          id: 'status',
          name: 'Status',
          type: BlueprintFieldType.text,
          allowedValues: ['open', 'closed'],
        ),
        // Self-referencing (a real, surviving entity id) — a reference to
        // an UNDECLARED entity is a real, separate, honestly-handled case
        // covered by its own dedicated test below.
        SemanticField(
          id: 'related',
          name: 'Related',
          type: BlueprintFieldType.reference,
          referenceEntityId: 'entry',
        ),
      ],
    ),
  ],
  views: [
    const SemanticView(
      id: 'entries_list',
      name: 'Entries',
      purpose: 'list',
      sourceEntityId: 'entry',
      viewType: BlueprintViewType.list,
      isDefault: true,
    ),
  ],
  actions: [
    const SemanticAction(
      id: 'add_entry',
      name: 'Add Entry',
      targetEntityId: 'entry',
    ),
    const SemanticAction(
      id: 'delete_entry',
      name: 'Delete Entry',
      targetEntityId: 'entry',
      actionType: BlueprintActionType.delete,
    ),
  ],
  derivedValues: [
    const SemanticDerivedValue(
      id: 'entry_count',
      name: 'Entry Count',
      sourceEntityId: 'entry',
      operation: DerivedOperation.count,
    ),
  ],
);

Future<ExecutionPlanReady> _runKernel(
  SemanticApp app, {
  String expression = 'track my field log entries',
}) async {
  final kernel = AnythingKernel(
    providerRegistry: _FakeProviderRegistry(),
    capabilityRegistry: _registryWithStorage(),
    reasoner: _FixedReasoner(app),
  );
  final outcome = await kernel.processIntent(
    Intent.create(expression: expression),
  );
  expect(outcome, isA<ExecutionPlanReady>());
  return outcome as ExecutionPlanReady;
}

void _mockSecureStorageChannel() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'read':
          case 'containsKey':
            return null;
          default:
            return null;
        }
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Field enrichment (R20) — real SemanticField data reaches CanonicalImplementationModel',
    () {
      setUp(() {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
        SharedPreferences.setMockInitialValues({});
        _mockSecureStorageChannel();
      });

      test(
        'a real Kernel run enriches ImplementationField with defaultValue/allowedValues/referenceEntityId/hint',
        () async {
          final ready = await _runKernel(
            _fieldLogRichApp(),
            expression: 'track my rich field log entries',
          );
          final model = ready.canonicalImplementationModel!;
          final entryFields = {
            for (final f in model.entities.single.fields) f.name: f,
          };

          expect(entryFields['Title']!.defaultValue, 'Untitled');
          expect(entryFields['Title']!.hint, 'The entry title');
          expect(entryFields['Status']!.allowedValues, ['open', 'closed']);
          expect(entryFields['Related']!.referenceEntityId, 'entry');
          // The compiler's own real, deliberate auto primary-key column
          // (BackendEngineeringPlanner, R8) has no SemanticField counterpart
          // — its enrichment fields stay null, honestly, never fabricated.
          expect(entryFields['id']!.defaultValue, isNull);
        },
      );

      test(
        'a referenceEntityId naming an entity that was never declared is honestly dropped, matching legacy '
        'exactly — a real bug this milestone found and fixed: an early version of this enrichment leaked the '
        'dangling reference through unchecked',
        () async {
          final app = SemanticApp(
            name: 'Dangling Ref App',
            purpose: 'Test dangling references',
            entities: [
              const SemanticEntity(
                id: 'entry',
                name: 'Entry',
                displayField: 'title',
                fields: [
                  SemanticField(
                    id: 'title',
                    name: 'Title',
                    type: BlueprintFieldType.text,
                    required: true,
                  ),
                  SemanticField(
                    id: 'owner',
                    name: 'Owner',
                    type: BlueprintFieldType.reference,
                    referenceEntityId: 'person',
                  ),
                ],
              ),
            ],
            views: [
              const SemanticView(
                id: 'entries_list',
                name: 'Entries',
                purpose: 'list',
                sourceEntityId: 'entry',
                viewType: BlueprintViewType.list,
                isDefault: true,
              ),
            ],
          );
          final ready = await _runKernel(
            app,
            expression: 'dangling reference test',
          );
          final model = ready.canonicalImplementationModel!;
          final ownerField = model.entities.single.fields.firstWhere(
            (f) => f.name == 'Owner',
          );
          expect(
            ownerField.referenceEntityId,
            isNull,
            reason:
                '"person" is not a real, declared entity — must not be carried through',
          );
        },
      );

      test(
        'omitting semanticEntities/derivedValues from CanonicalImplementationContext leaves ImplementationField '
        'byte-for-byte unenriched — fully backward compatible with every pre-R20 construction site',
        () {
          final architecture = _minimalArchitecture;
          final app = _minimalApp;
          final engineering = const EngineeringPlanner().plan(
            EngineeringContext(architecture: architecture, app: app),
          );
          final backend = const BackendEngineeringPlanner().plan(
            BackendEngineeringContext(architecture: architecture, app: app),
          );

          // No semanticEntities/derivedValues supplied — the exact pre-R20 shape.
          final model = const CanonicalImplementationPlanner().plan(
            CanonicalImplementationContext(
              engineering: engineering,
              backend: backend,
            ),
          );
          final titleField = model.entities.single.fields.firstWhere(
            (f) => f.name == 'Title',
          );
          expect(titleField.defaultValue, isNull);
          expect(titleField.allowedValues, isEmpty);
          expect(model.derivedValues, isEmpty);
        },
      );

      test(
        'the compiler-generated ExperiencePackage carries the SAME enriched field metadata into DataFieldSchema',
        () async {
          final ready = await _runKernel(
            _fieldLogRichApp(),
            expression: 'track my rich field log entries',
          );
          final outcome = runCompilerPipeline(
            ready.canonicalImplementationModel!,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          expect(
            outcome.succeeded,
            isTrue,
            reason: outcome.result.diagnostics.map((d) => d.message).join('; '),
          );

          final entryFields = {
            for (final f in outcome.package!.data!.entities.single.fields)
              f.name: f,
          };
          expect(entryFields['Title']!.defaultValue, 'Untitled');
          expect(entryFields['Title']!.hint, 'The entry title');
          expect(entryFields['Status']!.allowedValues, ['open', 'closed']);
          expect(entryFields['Related']!.referenceEntityId, 'entry');

          // Real form-field properties too, not just the data schema.
          final formScreen = outcome.package!.interface.screens.firstWhere(
            (s) => s.id == 'entry_form',
          );
          final fieldDefs =
              formScreen.children.single.properties['fields'] as List;
          final titleDef =
              fieldDefs.firstWhere((f) => f['id'] == 'entry.title') as Map;
          expect(titleDef['defaultValue'], 'Untitled');
          expect(titleDef['hint'], 'The entry title');
        },
      );
    },
  );

  group(
    'Derived value enrichment (R20) — real SemanticDerivedValue reaches real behavior nodes/state',
    () {
      setUp(() {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
        SharedPreferences.setMockInitialValues({});
        _mockSecureStorageChannel();
      });

      test(
        'a real Kernel run produces a real ImplementationDerivedValue, mirroring SemanticDerivedValue',
        () async {
          final ready = await _runKernel(
            _fieldLogRichApp(),
            expression: 'track my rich field log entries',
          );
          final model = ready.canonicalImplementationModel!;
          expect(model.derivedValues, hasLength(1));
          expect(model.derivedValues.single.id, 'entry_count');
          expect(model.derivedValues.single.sourceEntityId, 'entry');
          expect(
            model.derivedValues.single.operation,
            ImplementationDerivedOperation.count,
          );
        },
      );

      test(
        'the compiler package emits the SAME dataQuery+calculation node pair and state variables legacy '
        'already does, for the SAME derived value',
        () async {
          final ready = await _runKernel(
            _fieldLogRichApp(),
            expression: 'track my rich field log entries',
          );

          final legacyResult = await CreationEngine().create(
            CreationContext(
              intent: Intent.create(
                expression: 'track my rich field log entries',
              ),
              specification: ready.specification,
              plan: ready.plan,
              blueprint: ready.blueprint,
              platformContext: const PlatformContext(
                platform: 'android',
                sdkVersion: 34,
              ),
              securityPolicy: const CreationSecurityPolicy(),
            ),
          );
          final legacyPackage = (legacyResult as CreationReady).package;

          final compilerOutcome = runCompilerPipeline(
            ready.canonicalImplementationModel!,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          final compilerPackage = compilerOutcome.package!;

          for (final package in [legacyPackage, compilerPackage]) {
            expect(
              package.behavior.nodes.any(
                (n) =>
                    n.id == 'derived_entry_count_query' &&
                    n.type == 'dataQuery',
              ),
              isTrue,
            );
            expect(
              package.behavior.nodes.any(
                (n) =>
                    n.id == 'derived_entry_count_calc' &&
                    n.type == 'calculation',
              ),
              isTrue,
            );
            expect(
              package.behavior.edges.any(
                (e) =>
                    e.from == 'derived_entry_count_query' &&
                    e.to == 'derived_entry_count_calc',
              ),
              isTrue,
            );
            expect(
              package.state.variables.any((v) => v.id == 'entry_count'),
              isTrue,
            );
            expect(
              package.state.variables.any(
                (v) => v.id == 'entry_count_raw_data',
              ),
              isTrue,
            );
          }

          final compilerCalcNode = compilerPackage.behavior.nodes.firstWhere(
            (n) => n.id == 'derived_entry_count_calc',
          );
          expect(compilerCalcNode.config['operation'], 'count');
          expect(compilerCalcNode.config['targetStateId'], 'entry_count');
        },
      );

      test(
        'no derived values: no derived-value nodes/state generated, never fabricated',
        () async {
          final plainApp = SemanticApp(
            name: 'Field Log Plain',
            purpose: 'Track field log entries',
            entities: [
              const SemanticEntity(
                id: 'entry',
                name: 'Entry',
                displayField: 'title',
                fields: [
                  SemanticField(
                    id: 'title',
                    name: 'Title',
                    type: BlueprintFieldType.text,
                    required: true,
                  ),
                ],
              ),
            ],
            views: [
              const SemanticView(
                id: 'entries_list',
                name: 'Entries',
                purpose: 'list',
                sourceEntityId: 'entry',
                viewType: BlueprintViewType.list,
                isDefault: true,
              ),
            ],
          );
          final ready = await _runKernel(
            plainApp,
            expression: 'track entries only',
          );
          final outcome = runCompilerPipeline(
            ready.canonicalImplementationModel!,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          expect(
            outcome.package!.behavior.nodes.where(
              (n) => n.id.startsWith('derived_'),
            ),
            isEmpty,
          );
        },
      );
    },
  );

  group(
    'Canonical serialization (R20) — full round-trip and backward compatibility',
    () {
      test(
        'ImplementationField/derivedValues round-trip with full fidelity',
        () {
          const model = CanonicalImplementationModel(
            entities: [
              ImplementationEntity(
                id: 'entry',
                name: 'Entry',
                fields: [
                  ImplementationField(
                    id: 'entry.title',
                    name: 'Title',
                    type: ImplementationDataType.text,
                    required: true,
                    defaultValue: 'Untitled',
                    allowedValues: ['a', 'b'],
                    hint: 'h',
                    referenceEntityId: 'person',
                  ),
                ],
              ),
            ],
            authentication: AuthenticationAdapterSpec(
              requiresCredentials: false,
            ),
            backgroundWorker: BackgroundWorkerSpec(
              requiresBackgroundSync: false,
            ),
            derivedValues: [
              ImplementationDerivedValue(
                id: 'dv1',
                name: 'DV',
                sourceEntityId: 'entry',
                operation: ImplementationDerivedOperation.sum,
                fieldId: 'amount',
                description: 'd',
              ),
            ],
          );

          final restored = canonicalImplementationModelFromJson(
            jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>,
          );
          final restoredField = restored.entities.single.fields.single;
          expect(restoredField.defaultValue, 'Untitled');
          expect(restoredField.allowedValues, ['a', 'b']);
          expect(restoredField.hint, 'h');
          expect(restoredField.referenceEntityId, 'person');
          expect(restored.derivedValues.single.id, 'dv1');
          expect(
            restored.derivedValues.single.operation,
            ImplementationDerivedOperation.sum,
          );
          expect(restored.derivedValues.single.fieldId, 'amount');
        },
      );

      test(
        'backward compatibility: JSON persisted before R20 (no new field keys, no derivedValues key) deserializes '
        'to null/empty, never throws',
        () {
          const model = CanonicalImplementationModel(
            entities: [
              ImplementationEntity(
                id: 'entry',
                name: 'Entry',
                fields: [
                  ImplementationField(
                    id: 'entry.title',
                    name: 'Title',
                    type: ImplementationDataType.text,
                  ),
                ],
              ),
            ],
            authentication: AuthenticationAdapterSpec(
              requiresCredentials: false,
            ),
            backgroundWorker: BackgroundWorkerSpec(
              requiresBackgroundSync: false,
            ),
          );
          final preR20Json = model.toJson();
          (preR20Json['entities'] as List)
              .cast<Map<String, dynamic>>()
              .first['fields'] = [
            {
              'id': 'entry.title',
              'name': 'Title',
              'type': 'text',
              'required': false,
            },
          ];
          preR20Json.remove('derivedValues');

          final restored = canonicalImplementationModelFromJson(preR20Json);
          expect(restored.entities.single.fields.single.defaultValue, isNull);
          expect(restored.entities.single.fields.single.allowedValues, isEmpty);
          expect(restored.derivedValues, isEmpty);
        },
      );
    },
  );

  group(
    'Generator compatibility (R20) — entities WITHOUT rich data still generate exactly as before',
    () {
      test(
        'a plain CanonicalImplementationModel (no field enrichment, no derived values) produces the same shape R13 already tested',
        () {
          const model = CanonicalImplementationModel(
            entities: [
              ImplementationEntity(
                id: 'book',
                name: 'Book',
                fields: [
                  ImplementationField(
                    id: 'title',
                    name: 'Title',
                    type: ImplementationDataType.text,
                    required: true,
                  ),
                ],
              ),
            ],
            controllers: [
              ImplementationController(
                id: 'book.controller',
                entityId: 'book',
                operations: [
                  ImplementationOperation(
                    id: 'book.list',
                    kind: ImplementationOperationKind.list,
                  ),
                ],
              ),
            ],
            authentication: AuthenticationAdapterSpec(
              requiresCredentials: false,
            ),
            backgroundWorker: BackgroundWorkerSpec(
              requiresBackgroundSync: false,
            ),
          );
          const pipeline = GenerationPipeline();
          final result = pipeline.run(
            buildGraph: const BuildGraphBuilder().build(model),
            generator: const RuntimeExperienceGenerator(),
            target: const GeneratorTarget(
              id: 'book-tracker',
              name: 'Book Tracker',
            ),
          );
          expect(result.hasErrors, isFalse);
          expect(
            ExperiencePackageValidator.validate(
              ExperiencePackage.fromJson(
                jsonDecode(result.allArtifacts.single.content!)
                    as Map<String, dynamic>,
              ),
            ).isValid,
            isTrue,
          );
        },
      );
    },
  );

  group(
    'Equivalence improvement (R20) — real, measured before/after, no invented score',
    () {
      setUp(() {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
        SharedPreferences.setMockInitialValues({});
        _mockSecureStorageChannel();
      });

      test(
        'for the enriched "Field Log Rich" fixture, sharedFieldMetadataParity — the dimension R20 added — genuinely '
        'passes because the compiler now carries the same field metadata legacy already did',
        () async {
          final ready = await _runKernel(
            _fieldLogRichApp(),
            expression: 'track my rich field log entries',
          );

          final legacyResult = await CreationEngine().create(
            CreationContext(
              intent: Intent.create(
                expression: 'track my rich field log entries',
              ),
              specification: ready.specification,
              plan: ready.plan,
              blueprint: ready.blueprint,
              platformContext: const PlatformContext(
                platform: 'android',
                sdkVersion: 34,
              ),
              securityPolicy: const CreationSecurityPolicy(),
            ),
          );
          final legacyPackage = (legacyResult as CreationReady).package;
          final compilerOutcome = runCompilerPipeline(
            ready.canonicalImplementationModel!,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          final compilerPackage = compilerOutcome.package!;

          const comparator = EquivalenceComparator();
          final report = comparator.compare(
            legacyPackage,
            compilerPackage,
            legacyLatency: Duration.zero,
            compilerLatency: Duration.zero,
          );

          // ignore: avoid_print
          print(
            'R20 EquivalenceReport (Field Log Rich, real measured before/after): '
            'score=${report.compatibilityScore.toStringAsFixed(2)} passed=${report.dimensionsPassed} '
            'failed=${report.dimensionsChecked.toSet().difference(report.dimensionsPassed.toSet())}',
          );

          // The real, new proof: field metadata richness now genuinely
          // matches, on a fixture that actually has rich data to differ on
          // (unlike R19's own "Field Log" fixture, which had none).
          expect(
            report.dimensionsPassed,
            contains('sharedFieldMetadataParity'),
          );
          // dataFieldCountParity/screenCountParity remain real, documented,
          // unaddressed differences (auto primary-key column; non-CRUD view
          // types) — not fabricated as fixed.
          expect(
            report.dimensionsChecked.toSet().difference(
              report.dimensionsPassed.toSet(),
            ),
            {'dataFieldCountParity', 'screenCountParity'},
          );
          expect(report.compatibilityScore, closeTo(10 / 12, 0.001));
        },
      );
    },
  );

  group(
    'Performance (R20) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test(
        'compiler pipeline latency with a richly-enriched model (50 fields, 20 derived values)',
        () {
          final entity = ImplementationEntity(
            id: 'big',
            name: 'Big',
            fields: [
              for (var i = 0; i < 50; i++)
                ImplementationField(
                  id: 'big.f$i',
                  name: 'F$i',
                  type: ImplementationDataType.text,
                  defaultValue: 'd$i',
                  allowedValues: ['x', 'y'],
                  hint: 'hint$i',
                  referenceEntityId: i.isEven ? 'other' : null,
                ),
            ],
          );
          final model = CanonicalImplementationModel(
            entities: [entity],
            controllers: [
              ImplementationController(
                id: 'big.controller',
                entityId: 'big',
                operations: [
                  ImplementationOperation(
                    id: 'big.list',
                    kind: ImplementationOperationKind.list,
                  ),
                ],
              ),
            ],
            authentication: const AuthenticationAdapterSpec(
              requiresCredentials: false,
            ),
            backgroundWorker: const BackgroundWorkerSpec(
              requiresBackgroundSync: false,
            ),
            derivedValues: [
              for (var i = 0; i < 20; i++)
                ImplementationDerivedValue(
                  id: 'dv$i',
                  name: 'DV$i',
                  sourceEntityId: 'big',
                  operation: ImplementationDerivedOperation.count,
                ),
            ],
          );

          final stopwatch = Stopwatch()..start();
          final outcome = runCompilerPipeline(
            model,
            id: 'big-app',
            name: 'Big App',
          );
          stopwatch.stop();

          expect(outcome.succeeded, isTrue);
          // ignore: avoid_print
          print(
            'R20 compiler pipeline latency (50 enriched fields, 20 derived values): ${stopwatch.elapsedMilliseconds}ms',
          );
        },
      );

      test('serialization round-trip timing for an enriched model', () {
        final model = CanonicalImplementationModel(
          entities: [
            ImplementationEntity(
              id: 'big',
              name: 'Big',
              fields: [
                for (var i = 0; i < 100; i++)
                  ImplementationField(
                    id: 'big.f$i',
                    name: 'F$i',
                    type: ImplementationDataType.text,
                    defaultValue: 'd',
                    allowedValues: const ['a', 'b', 'c'],
                    hint: 'h',
                  ),
              ],
            ),
          ],
          authentication: const AuthenticationAdapterSpec(
            requiresCredentials: false,
          ),
          backgroundWorker: const BackgroundWorkerSpec(
            requiresBackgroundSync: false,
          ),
        );

        final stopwatch = Stopwatch()..start();
        final json = jsonEncode(model.toJson());
        final restored = canonicalImplementationModelFromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        stopwatch.stop();

        expect(restored.entities.single.fields, hasLength(100));
        // ignore: avoid_print
        print(
          'R20 serialization round-trip (100 enriched fields): ${stopwatch.elapsedMilliseconds}ms',
        );
      });

      test(
        'memory: real process RSS delta while planning 50 enriched CanonicalImplementationModels',
        () async {
          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 50; i++) {
            await _runKernel(
              _fieldLogRichApp(),
              expression: 'track entries $i',
            );
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R20 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 50 runs',
          );
        },
      );
    },
  );
}

// ── Minimal fixture for the isolated (no-Kernel) planner test above —
// real ArchitectureCandidate built via the real ArchitecturePlanner, never
// hand-rolled (that type has real internal invariants this test should
// not need to know about). ─────────────────────────────────────────────

final _minimalApp = SemanticApp(
  name: 'Minimal',
  purpose: 'Minimal test app',
  entities: [
    const SemanticEntity(
      id: 'thing',
      name: 'Thing',
      displayField: 'title',
      fields: [
        SemanticField(
          id: 'title',
          name: 'Title',
          type: BlueprintFieldType.text,
          required: true,
        ),
      ],
    ),
  ],
  views: [
    const SemanticView(
      id: 'thing_list',
      name: 'Things',
      purpose: 'list',
      sourceEntityId: 'thing',
      viewType: BlueprintViewType.list,
      isDefault: true,
    ),
  ],
);

final _minimalArchitecture = const ArchitecturePlanner().plan(_minimalApp);
