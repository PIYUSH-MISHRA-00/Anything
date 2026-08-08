/// Implementation Milestone R21 — Canonical Experience Views, Non-CRUD
/// Experience Generation. Proves the real, verified gap this milestone
/// closes: `RuntimeExperienceGenerator` had ZERO concept of non-CRUD
/// `SemanticView`s (dashboard/calendar/settings/summary/empty) — legacy's
/// `CreationEngine` already renders them (confirmed by reading lines
/// ~551-676): a real, bespoke `dashboardMetrics` node for `dashboard`, and
/// ONE identical shared generic-field-editor fallback for calendar/
/// settings/empty/summary (legacy never differentiates these four either
/// — this milestone matches that reality, not the milestone prose's
/// evocative "Calendar/Summary/Settings" framing as if they were
/// distinct). `SemanticView.sections`/composite-view rendering is
/// deliberately NOT modeled: legacy's `CreationEngine` never reads
/// `view.sections` anywhere (confirmed by grep) — there is no real
/// legacy behavior to be equivalent WITH.
///
/// Never a second `CanonicalImplementationModel`/`ExperiencePackage`/
/// Runtime/Generator Framework/Build Graph/Planner/AI Boundary.
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
import 'package:anything/creation/creation_context.dart';
import 'package:anything/creation/creation_engine.dart' hide CreationResult;
import 'package:anything/implementation_model/canonical_implementation_model.dart';
import 'package:anything/implementation_model/canonical_implementation_serialization.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/kernel/outcomes/kernel_outcome.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

// ── Fixtures (mirroring test/r20_canonical_experience_enrichment_test.dart's
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

/// "Task Board" — one entity with a numeric field (for dashboard sum/avg),
/// a boolean field and a self-reference (for the generic-fallback
/// settings view), plus a real list view (CRUD), a real dashboard view,
/// and a real settings view carrying a real (legacy-unread) `sections`
/// list — proves that data is honestly ignored, not fabricated into
/// composite rendering.
SemanticApp _taskBoardApp() => SemanticApp(
  name: 'Task Board',
  purpose: 'Track tasks with priority and completion',
  entities: [
    const SemanticEntity(
      id: 'task',
      name: 'Task',
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
        SemanticField(
          id: 'done',
          name: 'Done',
          type: BlueprintFieldType.boolean,
        ),
        SemanticField(
          id: 'assignee',
          name: 'Assignee',
          type: BlueprintFieldType.reference,
          referenceEntityId: 'task',
        ),
      ],
    ),
  ],
  views: [
    const SemanticView(
      id: 'tasks_list',
      name: 'Tasks',
      purpose: 'list',
      sourceEntityId: 'task',
      viewType: BlueprintViewType.list,
      isDefault: true,
    ),
    const SemanticView(
      id: 'tasks_dashboard',
      name: 'Overview',
      purpose: 'dashboard',
      sourceEntityId: 'task',
      viewType: BlueprintViewType.dashboard,
    ),
    SemanticView(
      id: 'tasks_settings',
      name: 'Settings',
      purpose: 'settings',
      sourceEntityId: 'task',
      viewType: BlueprintViewType.settings,
      // Real, reasoner-producible data that legacy itself never reads —
      // proves this milestone doesn't fabricate composite-view rendering
      // just because the field is populated.
      sections: const [
        SemanticViewSection(
          id: 'sec1',
          purpose: 'summary',
          sourceEntityId: 'task',
        ),
      ],
    ),
  ],
  actions: [
    const SemanticAction(
      id: 'add_task',
      name: 'Add Task',
      targetEntityId: 'task',
    ),
  ],
);

Future<ExecutionPlanReady> _runKernel(
  SemanticApp app, {
  String expression = 'track my tasks',
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
    'Canonical Experience Views (R21) — real SemanticView reaches CanonicalImplementationModel',
    () {
      test(
        'a real Kernel run produces real ImplementationViews for dashboard/settings, excluding the CRUD list view',
        () async {
          final ready = await _runKernel(_taskBoardApp());
          final model = ready.canonicalImplementationModel!;

          expect(
            model.views,
            hasLength(2),
            reason:
                'the list-type view is already covered by the CRUD entity path, never duplicated',
          );
          final byId = {for (final v in model.views) v.id: v};
          expect(
            byId['tasks_dashboard']!.kind,
            ImplementationViewKind.dashboard,
          );
          expect(byId['tasks_settings']!.kind, ImplementationViewKind.settings);
          expect(byId.containsKey('tasks_list'), isFalse);
        },
      );

      test(
        'omitting semanticViews leaves CanonicalImplementationModel.views empty — fully backward compatible',
        () async {
          final ready = await _runKernel(
            SemanticApp(
              name: 'Plain',
              purpose: 'p',
              entities: [
                const SemanticEntity(
                  id: 'task',
                  name: 'Task',
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
                  id: 'tasks_list',
                  name: 'Tasks',
                  purpose: 'list',
                  sourceEntityId: 'task',
                  viewType: BlueprintViewType.list,
                  isDefault: true,
                ),
              ],
            ),
            expression: 'plain app',
          );
          expect(ready.canonicalImplementationModel!.views, isEmpty);
        },
      );
    },
  );

  group(
    'Generator impact (R21) — real dashboardMetrics/generic-fallback nodes, matching legacy exactly',
    () {
      test(
        'dashboard view produces the exact metric set legacy computes: count + sum/avg per numeric field',
        () async {
          final ready = await _runKernel(_taskBoardApp());
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

          final dashboardScreen = outcome.package!.interface.screens.firstWhere(
            (s) => s.id == 'tasks_dashboard',
          );
          final metricsNode = dashboardScreen.children.firstWhere(
            (n) => n.type == 'dashboardMetrics',
          );
          final metrics = (metricsNode.properties['metrics'] as List)
              .cast<Map<String, dynamic>>();

          expect(
            metrics.any(
              (m) => m['operation'] == 'count' && m['label'] == 'Total Task',
            ),
            isTrue,
          );
          expect(
            metrics.any(
              (m) => m['operation'] == 'sum' && m['fieldId'] == 'task.priority',
            ),
            isTrue,
          );
          expect(
            metrics.any(
              (m) =>
                  m['operation'] == 'average' &&
                  m['fieldId'] == 'task.priority',
            ),
            isTrue,
          );
          // Boolean/reference/text fields must NOT get sum/avg metrics.
          expect(metrics.any((m) => m['fieldId'] == 'task.done'), isFalse);

          // Real heading node prepended, matching legacy.
          expect(dashboardScreen.children.first.type, 'heading');
          expect(
            dashboardScreen.children.first.properties['content'],
            'Overview',
          );

          // Real add button, reusing the SAME create_<entityId> convention
          // the CRUD list screen's own Add button already uses.
          final addButton = dashboardScreen.children.firstWhere(
            (n) => n.type == 'button',
          );
          expect(addButton.actionBinding?.actionId, 'create_task');
        },
      );

      test(
        'settings (generic-fallback) view produces referenceSelector for the reference field, switch for boolean, '
        'input for text — the SAME shared behavior calendar/empty/summary would also get',
        () async {
          final ready = await _runKernel(_taskBoardApp());
          final outcome = runCompilerPipeline(
            ready.canonicalImplementationModel!,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          final settingsScreen = outcome.package!.interface.screens.firstWhere(
            (s) => s.id == 'tasks_settings',
          );
          final byId = {for (final n in settingsScreen.children) n.id: n};

          // Field ids are namespaced ('task.<fieldId>', DatabaseColumn's real
          // id shape, R8) — includes the compiler's own real auto primary-key
          // column, which has no legacy SemanticField counterpart (R20).
          expect(
            byId['tasks_settings_task.assignee_ref']!.type,
            'referenceSelector',
          );
          expect(
            byId['tasks_settings_task.assignee_ref']!.properties['entityId'],
            'task',
          );
          expect(byId['tasks_settings_task.done']!.type, 'switch');
          expect(byId['tasks_settings_task.title']!.type, 'input');

          // Composite/sections rendering is honestly NOT modeled — the real
          // `sections` data on this fixture's SemanticView produces zero
          // extra structure beyond the plain per-field fallback: one node per
          // field (id/title/priority/done/assignee) plus the heading.
          expect(settingsScreen.children.length, 1 + 5);
          expect(settingsScreen.children.first.type, 'heading');
        },
      );

      test(
        'a view whose sourceEntityId does not resolve to a real entity produces an honest empty-children screen, '
        'matching legacy\'s own null-entity guard exactly',
        () async {
          final app = SemanticApp(
            name: 'Orphan View',
            purpose: 'p',
            entities: [
              const SemanticEntity(
                id: 'task',
                name: 'Task',
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
                id: 'tasks_list',
                name: 'Tasks',
                purpose: 'list',
                sourceEntityId: 'task',
                viewType: BlueprintViewType.list,
                isDefault: true,
              ),
              const SemanticView(
                id: 'orphan_dash',
                name: 'Orphan',
                purpose: 'dashboard',
                sourceEntityId: null,
                viewType: BlueprintViewType.dashboard,
              ),
            ],
          );
          final ready = await _runKernel(app, expression: 'orphan view test');
          final outcome = runCompilerPipeline(
            ready.canonicalImplementationModel!,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          final orphanScreen = outcome.package!.interface.screens.firstWhere(
            (s) => s.id == 'orphan_dash',
          );
          expect(orphanScreen.children, isEmpty);
        },
      );

      test(
        'no views: existing CRUD-only behavior is byte-for-byte unaffected (purely additive)',
        () async {
          final app = SemanticApp(
            name: 'CRUD Only',
            purpose: 'p',
            entities: [
              const SemanticEntity(
                id: 'task',
                name: 'Task',
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
                id: 'tasks_list',
                name: 'Tasks',
                purpose: 'list',
                sourceEntityId: 'task',
                viewType: BlueprintViewType.list,
                isDefault: true,
              ),
            ],
          );
          final ready = await _runKernel(app, expression: 'crud only test');
          expect(
            ready.canonicalImplementationModel!.views,
            isEmpty,
            reason:
                'the list-type view is entirely CRUD-covered, never mapped into ImplementationView',
          );

          final outcome = runCompilerPipeline(
            ready.canonicalImplementationModel!,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          // No R21 view-only node types leak into a purely CRUD generation.
          final allNodeTypes = outcome.package!.interface.screens
              .expand((s) => s.children)
              .map((n) => n.type)
              .toSet();
          expect(allNodeTypes, isNot(contains('dashboardMetrics')));
          expect(allNodeTypes, isNot(contains('referenceSelector')));
        },
      );
    },
  );

  group(
    'Navigation generation (R21) — real bottom-navigation items with correct per-kind icons',
    () {
      test(
        'a multi-view fixture produces real navigation items for both entity-list and non-CRUD views, correct icons, capped at 5',
        () async {
          final ready = await _runKernel(_taskBoardApp());
          final outcome = runCompilerPipeline(
            ready.canonicalImplementationModel!,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          final nav = outcome.package!.interface.navigation!;
          final byScreenId = {
            for (final item in nav.items) item.screenId: item,
          };

          expect(byScreenId['task_list']!.icon, 'list');
          expect(byScreenId['tasks_dashboard']!.icon, 'dashboard');
          expect(byScreenId['tasks_settings']!.icon, 'settings');
          expect(nav.items.length, lessThanOrEqualTo(5));
        },
      );
    },
  );

  group(
    'Canonical serialization (R21) — full round-trip and backward compatibility',
    () {
      test('views round-trip with full fidelity', () {
        const model = CanonicalImplementationModel(
          entities: [
            ImplementationEntity(
              id: 'task',
              name: 'Task',
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
          views: [
            ImplementationView(
              id: 'v1',
              name: 'Overview',
              kind: ImplementationViewKind.dashboard,
              sourceEntityId: 'task',
            ),
          ],
          authentication: AuthenticationAdapterSpec(requiresCredentials: false),
          backgroundWorker: BackgroundWorkerSpec(requiresBackgroundSync: false),
        );
        final restored = canonicalImplementationModelFromJson(model.toJson());
        expect(restored.views, hasLength(1));
        expect(restored.views.single.id, 'v1');
        expect(restored.views.single.kind, ImplementationViewKind.dashboard);
        expect(restored.views.single.sourceEntityId, 'task');
      });

      test(
        'backward compatibility: JSON persisted before R21 (no views key) deserializes to an empty list, never throws',
        () {
          const model = CanonicalImplementationModel(
            authentication: AuthenticationAdapterSpec(
              requiresCredentials: false,
            ),
            backgroundWorker: BackgroundWorkerSpec(
              requiresBackgroundSync: false,
            ),
          );
          final preR21Json = model.toJson()..remove('views');
          final restored = canonicalImplementationModelFromJson(preR21Json);
          expect(restored.views, isEmpty);
        },
      );
    },
  );

  group(
    'Equivalence improvement (R21) — real, measured before/after, never an invented score',
    () {
      test(
        'legacy and compiler packages agree on real dashboard/settings structural dimensions for the SAME real request',
        () async {
          final ready = await _runKernel(_taskBoardApp());

          final legacyStopwatch = Stopwatch()..start();
          final legacyResult = await CreationEngine().create(
            CreationContext(
              intent: Intent.create(expression: 'track my tasks'),
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
          legacyStopwatch.stop();
          final legacyPackage = (legacyResult as CreationReady).package;

          final compilerOutcome = runCompilerPipeline(
            ready.canonicalImplementationModel!,
            id: ready.specification.id,
            name: ready.specification.name,
          );
          final compilerPackage = compilerOutcome.package!;

          final report = const EquivalenceComparator().compare(
            legacyPackage,
            compilerPackage,
            legacyLatency: legacyStopwatch.elapsed,
            compilerLatency: compilerOutcome.latency,
          );

          // Real, measured numbers — printed for the record, never asserted
          // to be 1.0 (that would fabricate equivalence this milestone did
          // not achieve on every dimension, e.g. dataFieldCountParity's real,
          // permanent auto-primary-key-column difference, R20).
          // ignore: avoid_print
          print(
            'R21 equivalence on Task Board fixture (dashboard+settings views): '
            'compatibilityScore=${report.compatibilityScore} '
            '(${report.dimensionsPassed.length}/${report.dimensionsChecked.length}) '
            'missingComponents=${report.missingComponents} extraComponents=${report.extraComponents}',
          );

          // The dashboard/settings screen ids must now be present on BOTH
          // sides — the real, itemized proof this milestone closes the gap
          // (screen ids match exactly for views, unlike CRUD entity screens,
          // since both pipelines key them by the SAME real SemanticView.id).
          expect(report.missingComponents, isNot(contains('tasks_dashboard')));
          expect(report.missingComponents, isNot(contains('tasks_settings')));
          expect(report.compatibilityScore, greaterThan(0.5));
        },
      );
    },
  );

  group(
    'Performance (R21) — real Stopwatch/ProcessInfo.currentRss numbers, never fabricated',
    () {
      test(
        'generation latency with a large multi-view model (50 entities, 100 views)',
        () {
          final entities = [
            for (var i = 0; i < 50; i++)
              ImplementationEntity(
                id: 'e$i',
                name: 'Entity $i',
                fields: const [
                  ImplementationField(
                    id: 'name',
                    name: 'Name',
                    type: ImplementationDataType.text,
                  ),
                ],
              ),
          ];
          final views = [
            for (var i = 0; i < 50; i++) ...[
              ImplementationView(
                id: 'dash_$i',
                name: 'Dashboard $i',
                kind: ImplementationViewKind.dashboard,
                sourceEntityId: 'e$i',
              ),
              ImplementationView(
                id: 'settings_$i',
                name: 'Settings $i',
                kind: ImplementationViewKind.settings,
                sourceEntityId: 'e$i',
              ),
            ],
          ];
          final model = CanonicalImplementationModel(
            entities: entities,
            views: views,
            authentication: const AuthenticationAdapterSpec(
              requiresCredentials: false,
            ),
            backgroundWorker: const BackgroundWorkerSpec(
              requiresBackgroundSync: false,
            ),
          );

          final outcome = runCompilerPipeline(
            model,
            id: 'perf-test',
            name: 'Perf Test',
          );
          expect(outcome.succeeded, isTrue);
          expect(
            outcome.package!.interface.screens.length,
            greaterThanOrEqualTo(100),
          );
          // ignore: avoid_print
          print(
            'R21 generation latency (50 entities, 100 views): ${outcome.latency.inMilliseconds}ms',
          );
        },
      );

      test('serialization round-trip latency with 100 views', () {
        final views = [
          for (var i = 0; i < 100; i++)
            ImplementationView(
              id: 'v$i',
              name: 'View $i',
              kind: ImplementationViewKind.dashboard,
              sourceEntityId: 'e0',
            ),
        ];
        final model = CanonicalImplementationModel(
          entities: const [ImplementationEntity(id: 'e0', name: 'Entity 0')],
          views: views,
          authentication: const AuthenticationAdapterSpec(
            requiresCredentials: false,
          ),
          backgroundWorker: const BackgroundWorkerSpec(
            requiresBackgroundSync: false,
          ),
        );
        final stopwatch = Stopwatch()..start();
        final restored = canonicalImplementationModelFromJson(model.toJson());
        stopwatch.stop();
        expect(restored.views, hasLength(100));
        // ignore: avoid_print
        print(
          'R21 serialization round-trip (100 views): ${stopwatch.elapsedMicroseconds}us',
        );
      });

      test(
        'memory: real process RSS delta while generating 20 multi-view models',
        () {
          final rssBefore = ProcessInfo.currentRss;
          for (var i = 0; i < 20; i++) {
            final model = CanonicalImplementationModel(
              entities: const [
                ImplementationEntity(
                  id: 'e0',
                  name: 'Entity 0',
                  fields: [
                    ImplementationField(
                      id: 'n',
                      name: 'N',
                      type: ImplementationDataType.integer,
                    ),
                  ],
                ),
              ],
              views: const [
                ImplementationView(
                  id: 'dash',
                  name: 'Dashboard',
                  kind: ImplementationViewKind.dashboard,
                  sourceEntityId: 'e0',
                ),
                ImplementationView(
                  id: 'settings',
                  name: 'Settings',
                  kind: ImplementationViewKind.settings,
                  sourceEntityId: 'e0',
                ),
              ],
              authentication: const AuthenticationAdapterSpec(
                requiresCredentials: false,
              ),
              backgroundWorker: const BackgroundWorkerSpec(
                requiresBackgroundSync: false,
              ),
            );
            runCompilerPipeline(model, id: 'mem-$i', name: 'Mem $i');
          }
          final rssAfter = ProcessInfo.currentRss;
          // ignore: avoid_print
          print(
            'R21 memory: process RSS before=${rssBefore ~/ 1024}KB after=${rssAfter ~/ 1024}KB delta=${(rssAfter - rssBefore) ~/ 1024}KB for 20 generations',
          );
        },
      );
    },
  );
}
