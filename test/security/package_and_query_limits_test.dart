/// M2 — Package structural budgets and unbounded-fetch adversarial tests.
///
/// Covers gaps not exercised by stage11_security_certification_test.dart:
/// max screens/package, max behavior nodes/package, component property text
/// size, metadata field size, and the SQLite fetch-row ceiling that bounds
/// ExperienceDataRuntime.query() regardless of how many rows a malicious or
/// runaway Experience has written.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/security/runtime_security_limits.dart';

ExperiencePackage _packageWith({
  List<InterfaceScreen> screens = const [],
  List<BehaviorNode> behaviorNodes = const [],
  String name = 'Test',
  String description = 'Test',
}) {
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: 'pkg-limits-test',
      name: name,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    interface: InterfaceDefinition(screens: screens),
    behavior: BehaviorGraph(nodes: behaviorNodes),
    state: const StateSchema(),
    provenance: const PackageProvenance(
      creationEngineVersion: '1.0.0',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: '', computedAt: DateTime.now()),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Package structural budgets', () {
    test('screen count at the trusted maximum is accepted', () {
      final screens = List.generate(
        RuntimeSecurityLimits.maxScreensPerPackage,
        (i) => InterfaceScreen(id: 'screen_$i', title: 'Screen $i'),
      );
      final result = ExperiencePackageValidator.validate(
        _packageWith(screens: screens),
      );
      expect(
        result.errors.any((e) => e.contains('ui_screen_count_exceeded')),
        isFalse,
      );
    });

    test('screen count one over the trusted maximum is rejected', () {
      final screens = List.generate(
        RuntimeSecurityLimits.maxScreensPerPackage + 1,
        (i) => InterfaceScreen(id: 'screen_$i', title: 'Screen $i'),
      );
      final result = ExperiencePackageValidator.validate(
        _packageWith(screens: screens),
      );
      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('ui_screen_count_exceeded')),
        isTrue,
      );
    });

    test('behavior node count one over the trusted maximum is rejected', () {
      final nodes = List.generate(
        RuntimeSecurityLimits.maxBehaviorNodesPerPackage + 1,
        (i) => BehaviorNode(id: 'n_$i', type: 'stateWrite'),
      );
      final result = ExperiencePackageValidator.validate(
        _packageWith(
          screens: [const InterfaceScreen(id: 'home', title: 'Home')],
          behaviorNodes: nodes,
        ),
      );
      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('behavior_node_count_exceeded')),
        isTrue,
      );
    });

    test('oversized manifest name/description rejected', () {
      final result = ExperiencePackageValidator.validate(
        _packageWith(
          screens: [const InterfaceScreen(id: 'home', title: 'Home')],
          name: 'x' * (RuntimeSecurityLimits.maxMetadataFieldLength + 1),
          description: 'y' * (RuntimeSecurityLimits.maxMetadataFieldLength + 1),
        ),
      );
      expect(result.isValid, isFalse);
      expect(
        result.errors.where((e) => e.contains('metadata_field_too_long')),
        hasLength(2),
      );
    });

    test('oversized component property text rejected', () {
      final hugeText =
          'a' * (RuntimeSecurityLimits.maxComponentPropertyTextLength + 1);
      final screen = InterfaceScreen(
        id: 'home',
        title: 'Home',
        children: [
          InterfaceNode(
            id: 'label',
            type: 'text',
            properties: {'content': hugeText},
          ),
        ],
      );
      final result = ExperiencePackageValidator.validate(
        _packageWith(screens: [screen]),
      );
      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('ui_property_text_too_long')),
        isTrue,
      );
    });

    test('normal-sized package passes with no structural errors', () {
      final screen = InterfaceScreen(
        id: 'home',
        title: 'Home',
        children: [
          const InterfaceNode(
            id: 'label',
            type: 'text',
            properties: {'content': 'Hello world'},
          ),
        ],
      );
      final result = ExperiencePackageValidator.validate(
        _packageWith(
          screens: [screen],
          behaviorNodes: [const BehaviorNode(id: 'evt', type: 'event')],
        ),
      );
      expect(result.isValid, isTrue);
    });
  });

  group('Unbounded-fetch protection (real SQLite)', () {
    test('a table with more rows than the trusted fetch ceiling never returns '
        'more than the ceiling from a single query() call', () async {
      final dr = ExperienceDataRuntime();
      dr.initialize(
        const DataSchema(
          entities: [
            DataEntitySchema(
              id: 'spam',
              name: 'Spam',
              fields: [DataFieldSchema(id: 'n', name: 'N', type: 'text')],
            ),
          ],
        ),
        experienceId: 'fetch-ceiling-test',
      );

      final over = RuntimeSecurityLimits.maxFetchRowsPerQuery + 50;
      for (var i = 0; i < over; i++) {
        await dr.insert('spam', {'id': 'r$i', 'n': '$i'});
      }

      final results = await dr.query('spam');
      expect(results.length, RuntimeSecurityLimits.maxFetchRowsPerQuery);

      await dr.dispose();
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'a requested limit below the trusted ceiling is honored as-is',
      () async {
        final dr = ExperienceDataRuntime();
        dr.initialize(
          const DataSchema(
            entities: [
              DataEntitySchema(
                id: 'small',
                name: 'Small',
                fields: [DataFieldSchema(id: 'n', name: 'N', type: 'text')],
              ),
            ],
          ),
          experienceId: 'fetch-small-test',
        );
        for (var i = 0; i < 20; i++) {
          await dr.insert('small', {'id': 'r$i', 'n': '$i'});
        }

        final results = await dr.query('small', limit: 5);
        expect(results.length, 5);

        await dr.dispose();
      },
    );

    test('a requested limit above the trusted ceiling is clamped down to it, '
        'never raised', () async {
      final dr = ExperienceDataRuntime();
      dr.initialize(
        const DataSchema(
          entities: [
            DataEntitySchema(
              id: 'small2',
              name: 'Small2',
              fields: [DataFieldSchema(id: 'n', name: 'N', type: 'text')],
            ),
          ],
        ),
        experienceId: 'fetch-clamp-test',
      );
      for (var i = 0; i < 10; i++) {
        await dr.insert('small2', {'id': 'r$i', 'n': '$i'});
      }

      // Requesting far more than exists AND far more than the trusted
      // ceiling must still just return what exists (10), proving the
      // clamp doesn't error out — it silently narrows.
      final results = await dr.query(
        'small2',
        limit: RuntimeSecurityLimits.maxFetchRowsPerQuery * 10,
      );
      expect(results.length, 10);

      await dr.dispose();
    });
  });
}
