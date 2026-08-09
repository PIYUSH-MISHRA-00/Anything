/// P17 — CREATE / READ / UPDATE / DELETE + restart persistence.
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
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CapabilityRegistry _reg() {
  final r = CapabilityRegistry();
  for (final d in const [
    CapabilityDescriptor(
      id: 'storage',
      version: '1.0.0',
      name: 'Storage',
      description: 's',
      category: CapabilityCategory.storage,
      inputContract: 'v',
      outputContract: 'p',
    ),
    CapabilityDescriptor(
      id: 'clock',
      version: '1.0.0',
      name: 'Clock',
      description: 'c',
      category: CapabilityCategory.computation,
      inputContract: 'n',
      outputContract: 't',
    ),
    CapabilityDescriptor(
      id: 'http',
      version: '1.0.0',
      name: 'HTTP',
      description: 'h',
      category: CapabilityCategory.integration,
      inputContract: 'r',
      outputContract: 'r',
      requiredPermissions: ['internet'],
      networkRequired: true,
    ),
    CapabilityDescriptor(
      id: 'knowledge',
      version: '1.0.0',
      name: 'Knowledge',
      description: 'k',
      category: CapabilityCategory.knowledge,
      inputContract: 'q',
      outputContract: 'r',
      networkRequired: true,
    ),
    CapabilityDescriptor(
      id: 'files',
      version: '1.0.0',
      name: 'Files',
      description: 'f',
      category: CapabilityCategory.data,
      inputContract: 'f',
      outputContract: 'c',
      requiredPermissions: ['storage'],
    ),
  ]) {
    r.register(d);
  }
  return r;
}

class _NoAi implements ModelProviderRegistry {
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('full CRUD survives restart', () async {
    SharedPreferences.setMockInitialValues({});
    final dbName = 'p17_crud_${DateTime.now().microsecondsSinceEpoch}.db';
    final result =
        await ExperienceCreationCoordinator(
          kernel: AnythingKernel(
            providerRegistry: _NoAi(),
            capabilityRegistry: _reg(),
          ),
          repository: SqliteExperienceRepository(dbName: dbName),
        ).createFromIntent(
          Intent.create(
            expression: '''
Create a home maintenance application.
Manage:
- rooms
- maintenance jobs
- contractors
- costs
''',
          ),
        );
    expect(result, isA<CreationCreated>());
    final package = (result as CreationCreated).package;
    final entityId = package.data!.entities
        .firstWhere(
          (e) => e.id.contains('room'),
          orElse: () => package.data!.entities.first,
        )
        .id;

    final experienceId = '${package.manifest.experienceId}_crud';
    final dataRuntime = ExperienceDataRuntime()
      ..initialize(package.data!, experienceId: experienceId);
    final state = ExperienceStateEngine()..initialize(package.state);
    final session = ExperienceSession(
      id: 'p17-crud',
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
    final interp = BehaviorInterpreter();

    await interp.execute(
      package.behavior,
      'submitForm',
      context: ctx,
      data: {
        'entityId': entityId,
        'mode': 'create',
        'values': {'name': 'Plot A', 'details': 'north'},
      },
    );
    var rows = await dataRuntime.query(entityId);
    expect(rows.any((r) => r['name']?.toString() == 'Plot A'), isTrue);
    final id = rows
        .firstWhere((r) => r['name']?.toString() == 'Plot A')['id']
        .toString();

    await interp.execute(
      package.behavior,
      'submitForm',
      context: ctx,
      data: {
        'entityId': entityId,
        'mode': 'edit',
        'recordId': id,
        'values': {'name': 'Plot B', 'details': 'south'},
      },
    );
    rows = await dataRuntime.query(entityId);
    expect(rows.any((r) => r['name']?.toString() == 'Plot B'), isTrue);
    expect(rows.any((r) => r['name']?.toString() == 'Plot A'), isFalse);

    await dataRuntime.dispose();
    final restarted = ExperienceDataRuntime()
      ..initialize(package.data!, experienceId: experienceId);
    final again = await restarted.query(entityId);
    expect(again.any((r) => r['name']?.toString() == 'Plot B'), isTrue);

    final ctx2 = BehaviorExecutionContext(
      session: session,
      stateEngine: ExperienceStateEngine()..initialize(package.state),
      dataRuntime: restarted,
      serviceResolver: ExperienceServiceResolver(),
    );
    await BehaviorInterpreter().execute(
      package.behavior,
      'deleteRecord',
      context: ctx2,
      data: {'entityId': entityId, 'recordId': id},
    );
    expect(
      (await restarted.query(entityId)).any((r) => r['id']?.toString() == id),
      isFalse,
    );
    await restarted.dispose();

    final third = ExperienceDataRuntime()
      ..initialize(package.data!, experienceId: experienceId);
    expect(
      (await third.query(entityId)).any((r) => r['id']?.toString() == id),
      isFalse,
    );
    await third.dispose();
  });
}
