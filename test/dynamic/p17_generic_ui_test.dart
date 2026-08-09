/// P17 — generic UI derives from semantic field types.
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('entityForm field types follow semantic schema', () async {
    SharedPreferences.setMockInitialValues({});
    final coord = ExperienceCreationCoordinator(
      kernel: AnythingKernel(
        providerRegistry: _NoAi(),
        capabilityRegistry: _reg(),
      ),
      repository: SqliteExperienceRepository(
        dbName: 'p17_ui_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    final result = await coord.createFromIntent(
      Intent.create(
        expression: '''
Create a bakery operations application.
Manage:
- recipes
- inventory
- production batches
- costs
''',
      ),
    );
    expect(result, isA<CreationCreated>());
    final pkg = (result as CreationCreated).package;
    final forms = pkg.interface.screens
        .expand((s) => s.children)
        .where((n) => n.type == 'entityForm');
    expect(forms, isNotEmpty);

    final allFields = <Map<String, dynamic>>[];
    for (final form in forms) {
      final fields = form.properties['fields'];
      if (fields is List) {
        for (final f in fields) {
          if (f is Map<String, dynamic>) allFields.add(f);
        }
      }
    }
    final types = allFields.map((f) => f['type']?.toString()).toSet();
    expect(types.contains('text') || types.contains('string'), isTrue);
    expect(
      types.any((t) => t == 'integer' || t == 'number' || t == 'decimal'),
      isTrue,
      reason: 'expected numeric field type in $types',
    );
    expect(
      pkg.interface.screens
          .expand((s) => s.children)
          .any((n) => n.type == 'entityList' || n.type == 'list'),
      isTrue,
    );
    expect(
      pkg.interface.screens
          .expand((s) => s.children)
          .any((n) => n.type == 'searchField'),
      isTrue,
    );
  });
}
