/// P20 — full-stack unknown domains + structural filter/sort UI emission.
///
/// No domain factories. Same creation coordinator path for every prompt.
library;

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/kernel/anything_kernel.dart';
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

Future<CreationCreated> _create(String prompt) async {
  SharedPreferences.setMockInitialValues({});
  final result = await ExperienceCreationCoordinator(
    kernel: AnythingKernel(
      providerRegistry: _NoAi(),
      capabilityRegistry: _reg(),
    ),
    repository: SqliteExperienceRepository(
      dbName: 'p20_${DateTime.now().microsecondsSinceEpoch}.db',
    ),
  ).createFromIntent(Intent.create(expression: prompt));
  expect(
    result,
    isA<CreationCreated>(),
    reason: result is CreationFailed
        ? '${result.message} / ${result.error}'
        : result.message,
  );
  return result as CreationCreated;
}

Set<String> _entityIds(CreationCreated c) =>
    c.package.data!.entities.map((e) => e.id).toSet();

List<Map<String, dynamic>> _nodesOfType(CreationCreated c, String type) {
  final out = <Map<String, dynamic>>[];
  void walk(InterfaceNode node) {
    if (node.type == type) {
      out.add({'id': node.id, ...node.properties});
    }
    for (final child in node.children) {
      walk(child);
    }
  }

  for (final screen in c.package.interface.screens) {
    for (final child in screen.children) {
      walk(child);
    }
  }
  return out;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test(
    'bicycle repair workshop: entities + CRUD + search/filter/sort UI',
    () async {
      final created = await _create('''
Create a bicycle repair workshop application.
Manage:
- customers
- bicycles
- repairs
- parts
- appointments
- payments
Let me search, filter, and sort repair status, parts used, and outstanding payments.
''');
      final ids = _entityIds(created);
      for (final frag in [
        'customer',
        'bicycle',
        'repair',
        'part',
        'appointment',
        'payment',
      ]) {
        expect(
          ids.any((id) => id.contains(frag)),
          isTrue,
          reason: 'missing ~$frag in $ids',
        );
      }
      expect(
        created.package.behavior.nodes.any((n) => n.type == 'dataMutation'),
        isTrue,
      );
      expect(_nodesOfType(created, 'searchField'), isNotEmpty);
      final filters = _nodesOfType(created, 'filterField');
      expect(filters, isNotEmpty, reason: 'filter capability must emit UI');
      final filterFieldId = filters.first['fieldId'] as String?;
      expect(filterFieldId, isNotNull);
      expect(filterFieldId, isNotEmpty);
      final lists = _nodesOfType(created, 'entityList');
      expect(
        lists.any((n) => n['filterFieldId'] == filterFieldId),
        isTrue,
        reason: 'entityList filterFieldId must match filterField',
      );
      expect(_nodesOfType(created, 'sortField'), isNotEmpty);
      expect(
        created.package.services.any(
          (s) => s.type == 'newsData' || s.type == 'weatherData',
        ),
        isFalse,
      );
    },
  );

  test('community orchestra: independent domain on same engine', () async {
    final created = await _create('''
Create a community orchestra application.
Manage:
- musicians
- instruments
- rehearsals
- concerts
- attendance
- repertoire
Include search, filter, and sort.
''');
    final ids = _entityIds(created);
    for (final frag in ['musician', 'instrument', 'rehearsal', 'concert']) {
      expect(
        ids.any((id) => id.contains(frag)),
        isTrue,
        reason: 'missing ~$frag in $ids',
      );
    }
    expect(
      created.package.behavior.nodes.any((n) => n.type == 'dataMutation'),
      isTrue,
    );
    expect(_nodesOfType(created, 'searchField'), isNotEmpty);
    expect(_nodesOfType(created, 'filterField'), isNotEmpty);
    expect(_nodesOfType(created, 'sortField'), isNotEmpty);
  });

  test('random third domain: ceramic studio (no vocabulary patch)', () async {
    final created = await _create('''
Create a community ceramic studio application.
Manage:
- members
- kilns
- glaze recipes
- firings
- shelf assignments
- fees
Let me search, filter by firing status, and sort by scheduled date.
''');
    final ids = _entityIds(created);
    expect(ids.length, greaterThanOrEqualTo(4));
    expect(
      ids.any((id) => id.contains('kiln') || id.contains('firing')),
      isTrue,
      reason: ids.toString(),
    );
    expect(
      created.package.behavior.nodes.any((n) => n.type == 'dataMutation'),
      isTrue,
    );
    final filters = _nodesOfType(created, 'filterField');
    expect(filters, isNotEmpty);
    expect(filters.first['fieldId'], isNot(equals('')));
  });

  test('heuristic modify intent does not crash on CreationNeed cast', () async {
    // Regression for model_understanding_service heuristic cast bug.
    SharedPreferences.setMockInitialValues({});
    final result =
        await ExperienceCreationCoordinator(
          kernel: AnythingKernel(
            providerRegistry: _NoAi(),
            capabilityRegistry: _reg(),
          ),
          repository: SqliteExperienceRepository(
            dbName: 'p20_mod_${DateTime.now().microsecondsSinceEpoch}.db',
          ),
        ).createFromIntent(
          Intent.create(
            expression:
                'Create a task tracker. Manage:\n- tasks\n- projects\n'
                'Let me update task status and search.',
          ),
        );
    // Must not fail with CreationNeed/ModificationNeed cast.
    if (result is CreationFailed) {
      expect(
        result.error.contains('ModificationNeed'),
        isFalse,
        reason: result.error,
      );
      expect(result.error.contains('type cast'), isFalse, reason: result.error);
    }
  });
}
