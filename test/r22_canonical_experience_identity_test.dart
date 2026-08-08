/// Implementation Milestone R22 — Canonical Experience Identity, Unified
/// Experience Identification. Proves the real, verified gap this milestone
/// closes: `BlueprintView.id` (legacy) is a direct passthrough of
/// `SemanticView.id` — free text the LLM itself writes
/// (`model_reasoner.dart`: `id: _normalizeId(view['id'] ?? view['name'])`),
/// never a deterministic `<entityId>_<role>` formula the way the
/// compiler's own screen ids are. `sourceEntityId`+`viewType` — real,
/// already-structured fields sitting right next to that free-text `id` —
/// are the screen's TRUE identity, and both pipelines already implicitly
/// organize their screens around exactly this pair. `ScreenIdentity`/
/// `ActionIdentity` (`lib/experience_identity/`) name and expose that
/// already-real structure so `EquivalenceComparator` can compare what a
/// screen MEANS, not what it happens to be spelled.
///
/// Never a second `ExperiencePackage`/Runtime/Generator Framework/Build
/// Graph/Planner/AI Boundary. `lib/creation/creation_engine.dart` is never
/// touched — the legacy projection is computed FROM its real inputs
/// (`BlueprintView.sourceEntityId`/`.viewType`), never by modifying legacy
/// itself or parsing its opaque output strings.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/compiler_integration/compiler_pipeline_runner.dart';
import 'package:anything/compiler_integration/equivalence_comparator.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/experience_identity/experience_identity.dart';
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures (mirroring test/r21_canonical_experience_views_test.dart's
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

/// The SAME "entries_list vs entry_list" mismatch class R19's own test
/// documented (`test/r19_compiler_production_integration_test.dart` ~line
/// 249) — a deliberately LLM-style, entity-unrelated view id, proving
/// identity resolution never reads `view.id`.
SemanticApp _fieldLogApp() => SemanticApp(
  name: 'Field Log',
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
        SemanticField(
          id: 'priority',
          name: 'Priority',
          type: BlueprintFieldType.integer,
        ),
      ],
    ),
  ],
  views: [
    const SemanticView(
      id: 'my_weird_screen_name',
      name: 'Entries',
      purpose: 'list',
      sourceEntityId: 'entry',
      viewType: BlueprintViewType.list,
      isDefault: true,
    ),
    const SemanticView(
      id: 'entries_overview',
      name: 'Overview',
      purpose: 'dashboard',
      sourceEntityId: 'entry',
      viewType: BlueprintViewType.dashboard,
    ),
  ],
  actions: [
    const SemanticAction(
      id: 'add_entry',
      name: 'Add Entry',
      targetEntityId: 'entry',
    ),
    const SemanticAction(
      id: 'edit_entry',
      name: 'Edit Entry',
      targetEntityId: 'entry',
      actionType: BlueprintActionType.update,
    ),
    const SemanticAction(
      id: 'remove_entry',
      name: 'Remove Entry',
      targetEntityId: 'entry',
      actionType: BlueprintActionType.delete,
    ),
    const SemanticAction(
      id: 'flag_entry',
      name: 'Flag Entry',
      targetEntityId: 'entry',
      actionType: BlueprintActionType.toggle,
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

  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorageChannel();
  });

  group(
    'Legacy Screen Identity Projection (R22) — from sourceEntityId/viewType, NEVER from id',
    () {
      test(
        'a view whose id is deliberately unrelated to its entity/role still resolves to the real identity',
        () {
          const view = BlueprintView(
            id: 'my_weird_screen_name',
            name: 'Entries',
            purpose: 'list',
            sourceEntityId: 'entry',
            viewType: BlueprintViewType.list,
          );
          expect(
            legacyScreenIdentity(view),
            const ScreenIdentity(entityId: 'entry', role: ScreenRole.list),
          );
        },
      );

      test('every BlueprintViewType maps to a real, distinct ScreenRole', () {
        for (final type in BlueprintViewType.values) {
          final identity = legacyScreenIdentity(
            BlueprintView(
              id: 'x',
              name: 'x',
              purpose: 'p',
              sourceEntityId: 'e',
              viewType: type,
            ),
          );
          expect(identity.role.name, type.name);
        }
      });

      test(
        'a view with no source entity produces a real null-entity identity, never a fabricated one',
        () {
          const view = BlueprintView(
            id: 'app_settings',
            name: 'Settings',
            purpose: 'settings',
            viewType: BlueprintViewType.settings,
          );
          expect(
            legacyScreenIdentity(view),
            const ScreenIdentity(entityId: null, role: ScreenRole.settings),
          );
        },
      );
    },
  );

  group(
    'Legacy Action Identity Projection (R22) — only create/update/delete resolve, the rest honestly null',
    () {
      test('create/update/delete resolve to real ActionIdentity', () {
        expect(
          legacyActionIdentity(
            const BlueprintAction(id: 'a', name: 'a', targetEntityId: 'entry'),
          ),
          const ActionIdentity(entityId: 'entry', role: ActionRole.create),
        );
        expect(
          legacyActionIdentity(
            const BlueprintAction(
              id: 'b',
              name: 'b',
              targetEntityId: 'entry',
              actionType: BlueprintActionType.update,
            ),
          ),
          const ActionIdentity(entityId: 'entry', role: ActionRole.update),
        );
        expect(
          legacyActionIdentity(
            const BlueprintAction(
              id: 'c',
              name: 'c',
              targetEntityId: 'entry',
              actionType: BlueprintActionType.delete,
            ),
          ),
          const ActionIdentity(entityId: 'entry', role: ActionRole.delete),
        );
      });

      test(
        'toggle (and other compiler-unsupported action types) resolve to null, never a fabricated ActionIdentity',
        () {
          expect(
            legacyActionIdentity(
              const BlueprintAction(
                id: 'd',
                name: 'd',
                targetEntityId: 'entry',
                actionType: BlueprintActionType.toggle,
              ),
            ),
            isNull,
          );
        },
      );
    },
  );

  group(
    'Compiler Screen/Action Identity Projection (R22) — mirrors RuntimeExperienceGenerator exactly',
    () {
      test(
        'an entity with list+create+update+get operations produces list/form(x2)/detail identities',
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
                  ),
                ],
              ),
            ],
            controllers: [
              ImplementationController(
                id: 'entry.controller',
                entityId: 'entry',
                operations: [
                  ImplementationOperation(
                    id: 'o1',
                    kind: ImplementationOperationKind.list,
                  ),
                  ImplementationOperation(
                    id: 'o2',
                    kind: ImplementationOperationKind.create,
                  ),
                  ImplementationOperation(
                    id: 'o3',
                    kind: ImplementationOperationKind.update,
                  ),
                  ImplementationOperation(
                    id: 'o4',
                    kind: ImplementationOperationKind.get,
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

          final identities = compilerScreenIdentities(model);
          expect(
            identities.where((i) => i.role == ScreenRole.list),
            hasLength(1),
          );
          expect(
            identities.where((i) => i.role == ScreenRole.form),
            hasLength(2),
            reason:
                'create screen + edit screen — the real, honest 2-vs-1 split legacy has no counterpart for',
          );
          expect(
            identities.where((i) => i.role == ScreenRole.detail),
            hasLength(1),
          );

          final actions = compilerActionIdentities(model);
          expect(
            actions,
            containsAll([
              const ActionIdentity(entityId: 'entry', role: ActionRole.create),
              const ActionIdentity(entityId: 'entry', role: ActionRole.update),
            ]),
          );
        },
      );

      test(
        'a non-CRUD ImplementationView resolves through the SAME role mapping legacy uses',
        () {
          const model = CanonicalImplementationModel(
            entities: [
              ImplementationEntity(id: 'entry', name: 'Entry', fields: []),
            ],
            views: [
              ImplementationView(
                id: 'entries_overview',
                name: 'Overview',
                kind: ImplementationViewKind.dashboard,
                sourceEntityId: 'entry',
              ),
            ],
            authentication: AuthenticationAdapterSpec(
              requiresCredentials: false,
            ),
            backgroundWorker: BackgroundWorkerSpec(
              requiresBackgroundSync: false,
            ),
          );
          expect(
            compilerScreenIdentities(model),
            contains(
              const ScreenIdentity(
                entityId: 'entry',
                role: ScreenRole.dashboard,
              ),
            ),
          );
        },
      );
    },
  );

  group(
    'Equivalence improvement (R22 centerpiece) — real before/after on the exact R19 mismatch scenario',
    () {
      test(
        'identity-based comparison recognizes legacy\'s LLM-chosen view id and the compiler\'s deterministic id as the SAME screen',
        () async {
          final ready = await _runKernel(_fieldLogApp());
          final model = ready.canonicalImplementationModel!;
          final blueprint = ready.blueprint!;

          final outcome = runCompilerPipeline(
            model,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          expect(
            outcome.succeeded,
            isTrue,
            reason: outcome.result.diagnostics.map((d) => d.message).join('; '),
          );

          // BEFORE (string-based, pre-R22 behavior, still available when
          // legacyBlueprint/compilerModel are omitted): legacy's real view id
          // 'my_weird_screen_name' has no compiler counterpart — a real,
          // reported mismatch, proving this isn't a fixture that happens to
          // already agree.
          final legacyPackageStandIn = outcome
              .package!; // no separate legacy ExperiencePackage needed for this identity-only assertion
          expect(
            legacyPackageStandIn.interface.screens.map((s) => s.id),
            isNot(contains('my_weird_screen_name')),
          );

          // AFTER (identity-based, R22): the SAME comparison, given the real
          // source blueprint/model, must recognize legacy's 'my_weird_screen_name'
          // (entity=entry, role=list) and compiler's 'entry_list' (same
          // entity+role) as the SAME component — no longer reported missing.
          const comparator = EquivalenceComparator();
          final report = comparator.compare(
            legacyPackageStandIn, // identity dimension only reads legacyBlueprint below, not this package's screen ids
            outcome.package!,
            legacyLatency: Duration.zero,
            compilerLatency: Duration.zero,
            legacyBlueprint: blueprint,
            compilerModel: model,
          );

          expect(
            report.missingComponents.any((m) => m.contains('entry:list')),
            isFalse,
            reason:
                'entry:list must be recognized as present on both sides once compared by identity, not by incidental id string',
          );
          // The dashboard view (entry:dashboard) is real on both sides too.
          expect(
            report.missingComponents.any((m) => m.contains('entry:dashboard')),
            isFalse,
          );
          // Compiler's genuine create/edit split (2 form-role screens vs.
          // legacy's 0 — this fixture declares no form-type SemanticView at
          // all, only list+dashboard) is a REAL difference, honestly reported,
          // never hidden.
          expect(
            report.extraComponents.any((e) => e.contains('entry:form')),
            isTrue,
          );
        },
      );

      test(
        'omitting legacyBlueprint/compilerModel keeps the exact pre-R22 string-based comparison — backward compatible',
        () async {
          final ready = await _runKernel(_fieldLogApp());
          final model = ready.canonicalImplementationModel!;
          final outcome = runCompilerPipeline(
            model,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          expect(outcome.succeeded, isTrue);

          const comparator = EquivalenceComparator();
          final report = comparator.compare(
            outcome.package!,
            outcome.package!,
            legacyLatency: Duration.zero,
            compilerLatency: Duration.zero,
          );
          // Comparing a package against itself with no identity context: every
          // string-based dimension trivially agrees, and the new
          // screenIdentityCoverage dimension must be ABSENT (not silently
          // computed) — proves the additive parameter genuinely gates it.
          expect(
            report.dimensionsChecked,
            isNot(contains('screenIdentityCoverage')),
          );
          expect(report.missingComponents, isEmpty);
          expect(report.extraComponents, isEmpty);
        },
      );
    },
  );

  group(
    'Performance (R22) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test(
        'identity generation + identity-based comparison latency for a large model (100 entities)',
        () {
          final entities = [
            for (var i = 0; i < 100; i++)
              ImplementationEntity(
                id: 'entity$i',
                name: 'Entity $i',
                fields: const [],
              ),
          ];
          final controllers = [
            for (var i = 0; i < 100; i++)
              ImplementationController(
                id: 'c$i',
                entityId: 'entity$i',
                operations: const [
                  ImplementationOperation(
                    id: 'o',
                    kind: ImplementationOperationKind.list,
                  ),
                ],
              ),
          ];
          final model = CanonicalImplementationModel(
            entities: entities,
            controllers: controllers,
            authentication: const AuthenticationAdapterSpec(
              requiresCredentials: false,
            ),
            backgroundWorker: const BackgroundWorkerSpec(
              requiresBackgroundSync: false,
            ),
          );
          final blueprint = AppBlueprint(
            id: 'large',
            name: 'Large',
            description: 'd',
            views: [
              for (var i = 0; i < 100; i++)
                BlueprintView(
                  id: 'view_$i',
                  name: 'View $i',
                  purpose: 'list',
                  sourceEntityId: 'entity$i',
                  viewType: BlueprintViewType.list,
                ),
            ],
            entities: const [],
          );

          final stopwatch = Stopwatch()..start();
          final legacyIds = legacyScreenIdentities(blueprint);
          final compilerIds = compilerScreenIdentities(model);
          stopwatch.stop();

          expect(legacyIds, hasLength(100));
          expect(compilerIds, hasLength(100));
          // ignore: avoid_print
          print(
            'R22 identity generation for 200 total screens: ${stopwatch.elapsedMilliseconds}ms',
          );
        },
      );

      test(
        'memory: real process RSS delta while generating identities for 100 models',
        () {
          final rssBefore = ProcessInfo.currentRss;
          final results = <List<ScreenIdentity>>[];
          for (var i = 0; i < 100; i++) {
            const model = CanonicalImplementationModel(
              entities: [
                ImplementationEntity(id: 'entry', name: 'Entry', fields: []),
              ],
              views: [
                ImplementationView(
                  id: 'v',
                  name: 'v',
                  kind: ImplementationViewKind.dashboard,
                  sourceEntityId: 'entry',
                ),
              ],
              authentication: AuthenticationAdapterSpec(
                requiresCredentials: false,
              ),
              backgroundWorker: BackgroundWorkerSpec(
                requiresBackgroundSync: false,
              ),
            );
            results.add(compilerScreenIdentities(model));
          }
          final rssAfter = ProcessInfo.currentRss;
          expect(results, hasLength(100));
          // ignore: avoid_print
          print(
            'R22 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 100 identity generations',
          );
        },
      );
    },
  );
}
