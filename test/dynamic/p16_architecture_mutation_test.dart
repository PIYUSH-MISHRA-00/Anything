/// P16 — architectural mutation certification.
///
/// Detects domain-application factory routing that would break open-world
/// generation. Also asserts capability shells stay capability-scoped.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final libRoot = Directory('lib');

  test('no production Garden/Bakery/Photo/Finance application factories', () {
    final offenders = <String>[];
    for (final file in libRoot.listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      final rel = file.path.replaceAll('\\', '/');
      for (final pattern in const [
        'class GardenFactory',
        'class BakeryFactory',
        'class PhotographyFactory',
        'class FinanceFactory',
        'class CommunityGarden',
        'class BakeryOps',
        'buildGardenApp(',
        'buildBakeryApp(',
        "if domain == 'community_garden'",
        'if (domain == "bakery_ops")',
        "contains('community garden')",
        "contains('bakery operations')",
      ]) {
        if (text.contains(pattern)) {
          offenders.add('$rel :: $pattern');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('InterfaceFactory count stays capability-scoped (≤5)', () {
    final factories = <String>[];
    for (final file in libRoot.listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final name = file.uri.pathSegments.last;
      if (name.endsWith('_interface_factory.dart')) {
        factories.add(name);
      }
    }
      factories.sort();
    // Allowed capability shells only — not product domains.
    expect(
      factories,
      unorderedEquals(const [
        'calculation_interface_factory.dart',
        'network_reference_interface_factory.dart',
        'timing_interface_factory.dart',
      ]),
    );
  });

  test('CreationEngine does not route on product domain string equals', () {
    final engine = File('lib/creation/creation_engine.dart').readAsStringSync();
    expect(engine.contains("domain == 'news'"), isFalse);
    expect(engine.contains('buildNewsApp'), isFalse);
    expect(engine.contains('buildWeatherApp'), isFalse);
    expect(engine.contains('GardenFactory'), isFalse);
    // Capability IDs are allowed; product factories are not.
    expect(engine.contains('AppCapabilityIds.newsData'), isTrue);
    expect(engine.contains('AppCapabilityIds.weatherData'), isTrue);
  });
}
