/// P18 — stronger unknown-domain battery (no domain factories / no AI).
///
/// Domains deliberately outside the P16/P17 set. Assertions check identity,
/// not mere entity counts.
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
      dbName: 'p18_${DateTime.now().microsecondsSinceEpoch}.db',
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

Set<String> _ids(CreationCreated c) =>
    c.package.data!.entities.map((e) => e.id).toSet();

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('ten unseen domains: identity + no news/weather hijack', () async {
    final cases = <({String key, String prompt, List<String> expectIds})>[
      (
        key: 'music',
        prompt: '''
Create a music rehearsal studio application.
Manage:
- rooms
- bands
- rehearsal sessions
- equipment
- bookings
- invoices
''',
        expectIds: const [
          'room',
          'band',
          'session',
          'equipment',
          'booking',
          'invoice',
        ],
      ),
      (
        key: 'grooming',
        prompt: '''
Create a pet grooming business application.
Manage:
- pets
- owners
- grooming appointments
- services
- groomers
- payments
''',
        expectIds: const [
          'pet',
          'owner',
          'appointment',
          'service',
          'groomer',
          'payment',
        ],
      ),
      (
        key: 'clinic',
        prompt: '''
Create a small clinic appointment manager.
Manage:
- patients
- clinicians
- appointments
- rooms
- prescriptions
- invoices
''',
        expectIds: const [
          'patient',
          'clinician',
          'appointment',
          'room',
          'prescription',
          'invoice',
        ],
      ),
      (
        key: 'sports',
        prompt: '''
Create a community sports league application.
Manage:
- teams
- players
- matches
- venues
- standings
- referees
''',
        expectIds: const [
          'team',
          'player',
          'match',
          'venue',
          'standing',
          'referee',
        ],
      ),
      (
        key: 'rental',
        prompt: '''
Create a car rental business application.
Manage:
- vehicles
- customers
- rentals
- insurance
- maintenance jobs
- invoices
''',
        expectIds: const [
          'vehicle',
          'customer',
          'rental',
          'insurance',
          'maintenance',
          'invoice',
        ],
      ),
      (
        key: 'library',
        prompt: '''
Create a home library application.
Manage:
- books
- authors
- shelves
- loans
- reading lists
- notes
''',
        expectIds: const ['book', 'author', 'shelve', 'loan', 'list', 'note'],
      ),
      (
        key: 'freelance',
        prompt: '''
Create a freelance project manager.
Manage:
- clients
- projects
- tasks
- time entries
- invoices
- expenses
''',
        expectIds: const [
          'client',
          'project',
          'task',
          'time',
          'invoice',
          'expense',
        ],
      ),
      (
        key: 'farm',
        prompt: '''
Create a farm equipment maintenance application.
Manage:
- machines
- maintenance jobs
- parts
- technicians
- schedules
- costs
''',
        expectIds: const [
          'machine',
          'job',
          'part',
          'technician',
          'schedule',
          'cost',
        ],
      ),
      (
        key: 'venue',
        prompt: '''
Create an event venue management application.
Manage:
- venues
- rooms
- bookings
- clients
- event packages
- invoices
- staff
- availability
''',
        expectIds: const [
          'venue',
          'room',
          'booking',
          'client',
          'package',
          'invoice',
          'staff',
        ],
      ),
      (
        key: 'lab',
        prompt: '''
Create a research lab sample tracker.
Manage:
- samples
- experiments
- researchers
- storage locations
- protocols
- results
''',
        expectIds: const [
          'sample',
          'experiment',
          'researcher',
          'storage',
          'protocol',
          'result',
        ],
      ),
    ];

    final allIds = <String, Set<String>>{};
    for (final c in cases) {
      final created = await _create(c.prompt);
      final ids = _ids(created);
      allIds[c.key] = ids;
      for (final frag in c.expectIds.take(3)) {
        expect(
          ids.any((id) => id.contains(frag)),
          isTrue,
          reason: '${c.key} missing ~$frag in $ids',
        );
      }
      expect(
        created.package.services.any(
          (s) => s.type == 'newsData' || s.type == 'weatherData',
        ),
        isFalse,
        reason: '${c.key} must not be news/weather',
      );
      expect(
        created.package.behavior.nodes.any((n) => n.type == 'dataMutation'),
        isTrue,
      );
    }

    // Material independence across partially distant domains.
    expect(
      allIds['grooming']!.intersection(allIds['lab']!).length,
      lessThan(allIds['grooming']!.length),
    );
    expect(allIds['music']!.any((e) => e.contains('sample')), isFalse);
    expect(allIds['lab']!.any((e) => e.contains('groomer')), isFalse);
  });

  test('semantic contrast: pet grooming vs pet adoption', () async {
    final grooming = await _create('''
Create a pet grooming business application.
Manage:
- pets
- owners
- grooming appointments
- services
- groomers
- payments
''');
    final adoption = await _create('''
Create a pet adoption organization application.
Manage:
- pets
- owners
- applications
- foster homes
- adoptions
- volunteers
''');
    final g = _ids(grooming);
    final a = _ids(adoption);
    expect(g.any((e) => e.contains('appointment') || e.contains('groomer')), isTrue);
    expect(a.any((e) => e.contains('adoption') || e.contains('foster')), isTrue);
    expect(g.any((e) => e.contains('foster')), isFalse);
    expect(a.any((e) => e.contains('groomer')), isFalse);
    expect(g.intersection(a), isNot(g));
  });

  test('anti-cheat venue + grooming sequential same binary path', () async {
    final venue = await _create('''
Create an event venue management application.
Manage:
- venues
- rooms
- bookings
- clients
- event packages
- invoices
- staff
- availability
''');
    final grooming = await _create('''
Create a pet grooming business application.
Manage:
- pets
- owners
- grooming appointments
- services
- groomers
- payments
''');
    final v = _ids(venue);
    final g = _ids(grooming);
    expect(v.any((e) => e.contains('venue') || e.contains('booking')), isTrue);
    expect(g.any((e) => e.contains('pet') || e.contains('groom')), isTrue);
    expect(v.intersection(g).length, lessThan(v.length));
  });
}
