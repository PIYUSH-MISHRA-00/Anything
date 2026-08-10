/// P21 — production hardcoding probe (lib/ only).
///
/// Flags domain-name switches that select application implementations.
/// Capability shells and provider metadata are allowlisted.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _forbidden = <RegExp>[
  RegExp(r'''if\s*\([^)]*domain\s*==\s*['"]'''),
  RegExp(r'switch\s*\(\s*appName\s*\)'),
  RegExp(r'''contains\(\s*['"]Lucknow['"]\s*\)'''),
  RegExp(r'''if\s*\([^)]*appName\s*==\s*['"]'''),
  RegExp(r'VenueFactory|PetGroomingFactory|BakeryFactory|AstronomyFactory'),
];

/// Files allowed to mention product words (capability shells / providers).
const _allowPathFragments = <String>[
  'domain_services/weather_data_service.dart',
  'domain_services/news_data_service.dart',
  'knowledge/default_data_providers.dart',
  'creation/weather_interface_factory.dart',
  'creation/news_interface_factory.dart',
  'creation/timing_interface_factory.dart',
  'creation/calculation_interface_factory.dart',
  'creation/network_reference_interface_factory.dart',
  'capabilities/builtin/',
  'creation/intent_preservation.dart',
  'creation/intent_contract.dart',
  'creation/app_capabilities.dart',
  'creation/semantic_completeness.dart',
  'synthesis/model_reasoner.dart',
];

bool _allowed(String path) {
  final norm = path.replaceAll('\\', '/');
  return _allowPathFragments.any(norm.contains);
}

void main() {
  test('no domain-factory / city hardcoding in production lib/', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);
    final hits = <String>[];
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (_allowed(file.path)) continue;
      final text = file.readAsStringSync();
      for (final re in _forbidden) {
        if (re.hasMatch(text)) {
          hits.add('${file.path}: ${re.pattern}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('probe detects injected hardcoding (mutation)', () {
    const sample = 'if (domain == "weather") { return WeatherApp(); }';
    expect(_forbidden.first.hasMatch(sample), isTrue);
  });
}
