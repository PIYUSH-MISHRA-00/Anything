/// Architectural guard: production generation must not collapse distinct
/// calculation modes into one pad, and must register generic image nodes.
library;

import 'dart:io';

import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/creation/calculation_interface_factory.dart';
import 'package:anything/creation/calculation_spec.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/runtime/component_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('I-DYN anti-hardcode probes', () {
    test('basic calculator package ≠ scientific calculator package', () {
      final now = DateTime.now();
      ExperiencePackage bare() => ExperiencePackage(
            manifest: ExperienceManifest(
              experienceId: 'x',
              name: 'x',
              description: 'x',
              createdAt: now,
              updatedAt: now,
            ),
            interface: const InterfaceDefinition(),
            behavior: const BehaviorGraph(),
            state: const StateSchema(),
            provenance: const PackageProvenance(
              creationEngineVersion: '1.0.0',
              specVersion: 1,
              planVersion: 1,
            ),
            integrity: PackageIntegrity(contentHash: '', computedAt: now),
          );

      final basic = const CalculationInterfaceFactory().applyToPackage(
        bare(),
        name: 'Basic',
        spec: const CalculationSpec(
          mode: CalculationMode.basic,
          operations: CalculationSpec.basicOps,
        ),
      );
      final sci = const CalculationInterfaceFactory().applyToPackage(
        bare(),
        name: 'Scientific',
        spec: const CalculationSpec(
          mode: CalculationMode.scientific,
          operations: CalculationSpec.scientificOps,
        ),
      );

      expect(PackageCapabilityProbe(basic).hasScientificOps, isFalse);
      expect(PackageCapabilityProbe(sci).hasScientificOps, isTrue);
      expect(
        basic.manifest.requiredCapabilities.contains('scientificCalculation'),
        isFalse,
      );
      expect(
        sci.manifest.requiredCapabilities.contains('scientificCalculation'),
        isTrue,
      );
    });

    test('runtime registry implements remoteImage and image', () {
      final reg = RuntimeComponentRegistry.defaults();
      expect(reg.isRegistered('remoteImage'), isTrue);
      expect(reg.isRegistered('image'), isTrue);
    });

    test('production lib has no NewsHtmlParser / WeatherHtmlParser', () {
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue);
      final offenders = <String>[];
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        if (text.contains('class NewsHtmlParser') ||
            text.contains('class WeatherHtmlParser') ||
            text.contains('class AnythingWeatherParser')) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
