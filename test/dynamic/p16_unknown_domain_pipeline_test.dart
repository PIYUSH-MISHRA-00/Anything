/// P16 — unknown-domain apps via the REAL production pipeline.
///
/// Path exercised:
/// Intent → Kernel → Composite/DeterministicReasoner → Blueprint →
/// CreationEngine → ExperiencePackage → SQLite CRUD
///
/// No IntentSpec toy builder. No garden/bakery factories in lib/.
library;

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/kernel/anything_kernel.dart';
import 'package:anything/runtime/behavior_interpreter.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/runtime/service_resolver.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/services/provider_registry.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CapabilityRegistry _platformRegistry() {
  final registry = CapabilityRegistry();
  for (final d in const [
    CapabilityDescriptor(
      id: 'storage',
      version: '1.0.0',
      name: 'Storage',
      description: 'Durable local storage',
      category: CapabilityCategory.storage,
      inputContract: 'state values',
      outputContract: 'persisted state',
    ),
    CapabilityDescriptor(
      id: 'clock',
      version: '1.0.0',
      name: 'Clock',
      description: 'Trusted time',
      category: CapabilityCategory.computation,
      inputContract: 'none',
      outputContract: 'timestamp',
    ),
    CapabilityDescriptor(
      id: 'http',
      version: '1.0.0',
      name: 'HTTP',
      description: 'HTTPS',
      category: CapabilityCategory.integration,
      inputContract: 'request',
      outputContract: 'response',
      requiredPermissions: ['internet'],
      networkRequired: true,
    ),
    CapabilityDescriptor(
      id: 'knowledge',
      version: '1.0.0',
      name: 'Knowledge',
      description: 'Reference lookups',
      category: CapabilityCategory.knowledge,
      inputContract: 'query',
      outputContract: 'resources',
      networkRequired: true,
    ),
    CapabilityDescriptor(
      id: 'files',
      version: '1.0.0',
      name: 'Files',
      description: 'Files',
      category: CapabilityCategory.data,
      inputContract: 'file reference',
      outputContract: 'file contents',
      requiredPermissions: ['storage'],
    ),
  ]) {
    registry.register(d);
  }
  return registry;
}

class _NoAiProviders implements ModelProviderRegistry {
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

ExperienceCreationCoordinator _coordinator(String dbName) {
  return ExperienceCreationCoordinator(
    kernel: AnythingKernel(
      providerRegistry: _NoAiProviders(),
      capabilityRegistry: _platformRegistry(),
      // Default CompositeApplicationReasoner → DeterministicReasoner.
    ),
    repository: SqliteExperienceRepository(dbName: dbName),
  );
}

Future<CreationCreated> _create(String prompt) async {
  SharedPreferences.setMockInitialValues({});
  final dbName = 'p16_${DateTime.now().microsecondsSinceEpoch}.db';
  final result = await _coordinator(dbName).createFromIntent(
    Intent.create(expression: prompt),
  );
  expect(
    result,
    isA<CreationCreated>(),
    reason: result is CreationFailed
        ? '${result.message} / ${result.error}'
        : result.message,
  );
  return result as CreationCreated;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  const gardenPrompt = '''
Create a complete community garden management application.
It must manage:
- garden plots
- members
- plants
- planting schedules
- watering schedules
- harvest records
- photos
- reminders
''';

  const bakeryPrompt = '''
Create a bakery operations application.
It must manage:
- recipes
- ingredients
- inventory
- production batches
- suppliers
- customer orders
- production status
- costs
''';

  const photoPrompt = '''
Create a photography club application.
Manage:
- members
- photo submissions
- categories
- voting
- exhibitions
- judging
- results
''';

  test('garden + bakery + photo: real pipeline, different schemas, no AI', () async {
    final garden = await _create(gardenPrompt);
    final bakery = await _create(bakeryPrompt);
    final photo = await _create(photoPrompt);

    final gIds = garden.package.data!.entities.map((e) => e.id).toSet();
    final bIds = bakery.package.data!.entities.map((e) => e.id).toSet();
    final pIds = photo.package.data!.entities.map((e) => e.id).toSet();

    expect(gIds.length, greaterThanOrEqualTo(3));
    expect(bIds.length, greaterThanOrEqualTo(3));
    expect(pIds.length, greaterThanOrEqualTo(3));
    expect(gIds.intersection(bIds), isNot(gIds));
    expect(bIds.intersection(pIds), isNot(bIds));

    // Same generator surface: entityList/entityForm + dataMutation — not shells.
    expect(
      garden.package.interface.screens
          .expand((s) => s.children)
          .any((n) => n.type == 'entityList' || n.type == 'list'),
      isTrue,
    );
    expect(
      garden.package.behavior.nodes.any((n) => n.type == 'dataMutation'),
      isTrue,
    );
    expect(
      bakery.package.services.any((s) => s.type == 'newsData'),
      isFalse,
    );
    expect(
      photo.package.services.any((s) => s.type == 'weatherData'),
      isFalse,
    );
  });

  test('garden CRUD + persist via real BehaviorInterpreter + SQLite', () async {
    final created = await _create(gardenPrompt);
    final package = created.package;
    final entityId = package.data!.entities.first.id;

    final experienceId = '${package.manifest.experienceId}_runtime';
    final dataRuntime = ExperienceDataRuntime();
    dataRuntime.initialize(package.data!, experienceId: experienceId);

    final state = ExperienceStateEngine()..initialize(package.state);
    final session = ExperienceSession(
      id: 'p16-session',
      experienceId: package.manifest.experienceId,
      package: package,
      status: SessionStatus.running,
      startedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
    final ctx = BehaviorExecutionContext(
      session: session,
      stateEngine: state,
      dataRuntime: dataRuntime,
      serviceResolver: ExperienceServiceResolver(),
    );

    final createAction = package.behavior.nodes
        .where(
          (n) =>
              n.type == 'event' &&
              (n.id.contains('create') || n.id.contains('add')),
        )
        .map((n) => n.id)
        .first;

    await BehaviorInterpreter().execute(
      package.behavior,
      createAction,
      context: ctx,
      data: {
        'entityId': entityId,
        'values': {
          'name': 'Plot A',
          'details': 'Sunny corner',
          'status': 'active',
        },
      },
    );

    final rows = await dataRuntime.query(entityId);
    expect(rows, isNotEmpty);
    expect(
      rows.any((r) => (r['name'] ?? '').toString().contains('Plot A')),
      isTrue,
    );

    await dataRuntime.dispose();

    // Restart simulation: new runtime, same experience DB id.
    final restarted = ExperienceDataRuntime();
    restarted.initialize(package.data!, experienceId: experienceId);
    final again = await restarted.query(entityId);
    expect(
      again.any((r) => (r['name'] ?? '').toString().contains('Plot A')),
      isTrue,
    );
    await restarted.dispose();
  });
}
