/// IS-P11 — canonical Experience identity + library revision sync.
library;

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/experience_commit.dart';
import 'package:anything/app/experience_provenance.dart';
import 'package:anything/creation/calculation_interface_factory.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/network_reference_interface_factory.dart';
import 'package:anything/design_system/experience_icon.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('Home and My Apps resolve the same ExperienceIcon identity', () {
    final a = experienceVisualIdentity(
      experienceId: 'exp-calc',
      name: 'Calculator',
      category: 'utility',
    );
    final b = experienceVisualIdentity(
      experienceId: 'exp-calc',
      name: 'Calculator',
      category: 'utility',
    );
    expect(a.icon, b.icon);
    expect(a.paletteIndex, b.paletteIndex);
    expect(a.icon, Icons.calculate_outlined);

    final weather = experienceVisualIdentity(
      experienceId: 'exp-w',
      name: 'Personalized Weather Display',
      category: 'reference',
    );
    expect(weather.icon, Icons.wb_cloudy_outlined);
  });

  test('delete via commit bumps revision and removes from repository', () async {
    SharedPreferences.setMockInitialValues({});
    AppComposition.resetForTesting();
    final composition = AppComposition.freshForTesting();
    final before = composition.experienceLibraryRevision.value;
    final now = DateTime.now();
    final id = 'exp-del-${now.microsecondsSinceEpoch}';

    final package = ExperiencePackage(
      manifest: ExperienceManifest(
        experienceId: id,
        name: 'Temp Calc',
        description: 'd',
        createdAt: now,
        updatedAt: now,
      ),
      interface: const InterfaceDefinition(
        screens: [
          InterfaceScreen(
            id: 'main',
            title: 'Main',
            children: [
              InterfaceNode(
                type: 'text',
                id: 't',
                properties: {'content': 'hi'},
              ),
            ],
          ),
        ],
      ),
      behavior: const BehaviorGraph(nodes: [], edges: []),
      state: const StateSchema(variables: []),
      provenance: const PackageProvenance(
        creationEngineVersion: '1.0.0',
        specVersion: 1,
        planVersion: 1,
      ),
      integrity: PackageIntegrity(contentHash: 'h-$id', computedAt: now),
    );
    final metadata = ExperienceMetadataRecord(
      id: id,
      name: 'Temp Calc',
      description: 'd',
      category: 'utility',
      createdAt: now,
      updatedAt: now,
      provenance: ExperienceProvenance.createdLocally(
        at: now,
        fingerprint: ExperienceFingerprint('h-$id'),
      ),
    );

    final commit = await composition.experienceCommit.commit(
      experienceId: id,
      origin: CommitOrigin.creation,
      package: package,
      metadata: metadata,
    );
    expect(commit.succeeded, isTrue);
    expect(composition.experienceLibraryRevision.value, greaterThan(before));
    expect(
      (await composition.experienceRepository.listAll()).any((e) => e.id == id),
      isTrue,
    );

    final afterCreate = composition.experienceLibraryRevision.value;
    final removed = await composition.experienceCommit.remove(id);
    expect(removed.succeeded, isTrue);
    expect(
      composition.experienceLibraryRevision.value,
      greaterThan(afterCreate),
    );
    expect(
      (await composition.experienceRepository.listAll()).any((e) => e.id == id),
      isFalse,
    );
    expect(await composition.experienceRepository.getMetadata(id), isNull);
  });

  test('network shell exposes Search CTA bound to refreshData', () {
    final iface = const NetworkReferenceInterfaceFactory().buildInterface(
      title: 'Weather Dashboard',
      purpose: 'conditions',
    );
    final walk = <InterfaceNode>[];
    void collect(List<InterfaceNode> list) {
      for (final n in list) {
        walk.add(n);
        collect(n.children);
      }
    }

    collect(iface.screens.first.children);
    expect(
      walk.any(
        (n) =>
            n.id == 'search_button' &&
            n.actionBinding?.actionId == 'refreshData',
      ),
      isTrue,
    );
    expect(
      walk.any(
        (n) =>
            n.stateBinding == 'query' &&
            (n.properties['hint']?.toString().toLowerCase().contains(
                  'search',
                ) ??
                false),
      ),
      isTrue,
    );
  });

  test('calculation factory emits calculationPad for responsive layout', () {
    final now = DateTime.now();
    var package = ExperiencePackage(
      manifest: ExperienceManifest(
        experienceId: 'c',
        name: 'Calculator',
        description: 'math',
        createdAt: now,
        updatedAt: now,
      ),
      interface: const InterfaceDefinition(screens: []),
      behavior: const BehaviorGraph(nodes: [], edges: []),
      state: const StateSchema(variables: []),
      provenance: const PackageProvenance(
        creationEngineVersion: '1.0.0',
        specVersion: 1,
        planVersion: 1,
      ),
      integrity: PackageIntegrity(contentHash: 'x', computedAt: now),
    );
    package = const CalculationInterfaceFactory().applyToPackage(
      package,
      name: 'Calculator',
    );
    expect(
      package.interface.screens.first.children.any(
        (n) => n.type == 'calculationPad',
      ),
      isTrue,
    );
  });
}
