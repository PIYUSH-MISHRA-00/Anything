/// P17 — expanded unknown domains via real Kernel pipeline (no AI).
library;

import 'package:anything/app/creation_coordinator.dart';
import 'package:anything/capabilities/registry/capability_descriptor.dart';
import 'package:anything/capabilities/registry/capability_registry.dart';
import 'package:anything/core/contracts/intent.dart';
import 'package:anything/core/contracts/model_provider.dart';
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
      dbName: 'p17_exp_${DateTime.now().microsecondsSinceEpoch}.db',
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test(
    'six domains: material schema independence, same generic engine',
    () async {
      final garden = await _create('''
Create a community garden management application.
Manage:
- garden plots
- members
- plants
- planting schedules
- watering schedules
- harvest records
- photos
- reminders
''');
      final bakery = await _create('''
Create a bakery operations application.
Manage:
- recipes
- ingredients
- inventory
- production batches
- suppliers
- customer orders
- production status
- costs
''');
      final photo = await _create('''
Create a photography club application.
Manage:
- members
- photo submissions
- categories
- voting
- exhibitions
- judging
- results
''');
      final home = await _create('''
Create a home maintenance application.
Manage:
- rooms
- maintenance jobs
- contractors
- costs
- schedules
- photos
- warranties
''');
      final lang = await _create('''
Create a language-learning application.
Manage:
- vocabulary
- lessons
- practice sessions
- review schedules
- progress
- statistics
''');
      final bike = await _create('''
Create a bicycle repair shop management application.
Manage:
- customers
- bicycles
- repair jobs
- parts
- mechanics
- appointments
- invoices
''');

      Set<String> ids(CreationCreated c) =>
          c.package.data!.entities.map((e) => e.id).toSet();

      final g = ids(garden);
      final b = ids(bakery);
      final p = ids(photo);
      final h = ids(home);
      final l = ids(lang);
      final k = ids(bike);

      expect(g.any((e) => e.contains('plot')), isTrue);
      expect(g.any((e) => e.contains('recipe')), isFalse);
      expect(b.any((e) => e.contains('recipe')), isTrue);
      expect(b.any((e) => e.contains('garden')), isFalse);
      expect(
        p.any((e) => e.contains('submission') || e.contains('photo')),
        isTrue,
      );
      expect(p.any((e) => e.contains('ingredient')), isFalse);
      expect(h.any((e) => e.contains('room') || e.contains('job')), isTrue);
      expect(
        l.any((e) => e.contains('vocabulary') || e.contains('lesson')),
        isTrue,
      );
      expect(
        k.any((e) => e.contains('bicycle') || e.contains('repair')),
        isTrue,
      );
      expect(k.any((e) => e.contains('bakery')), isFalse);

      // Packages differ in UI tree + behavior, same mutation surface.
      for (final pkg in [
        garden.package,
        bakery.package,
        photo.package,
        home.package,
        lang.package,
        bike.package,
      ]) {
        expect(pkg.behavior.nodes.any((n) => n.type == 'dataMutation'), isTrue);
        expect(
          pkg.services.any(
            (s) => s.type == 'newsData' || s.type == 'weatherData',
          ),
          isFalse,
        );
        expect(
          pkg.interface.screens
              .expand((s) => s.children)
              .any((n) => n.type == 'entityList' || n.type == 'entityForm'),
          isTrue,
        );
      }

      expect(g.intersection(b).length, lessThan(g.length));
      expect(b.intersection(k).length, lessThan(b.length));
      expect(
        garden.package.interface.screens.length !=
                bike.package.interface.screens.length ||
            g.difference(k).isNotEmpty,
        isTrue,
      );
    },
  );
}
