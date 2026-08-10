/// P21 — DataProviderRegistry selects by capability, not vendor name.
library;

import 'package:anything/knowledge/data_provider_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('injectable provider wins; unregister fails over', () async {
    final registry = DataProviderRegistry();
    var primaryCalls = 0;
    var fallbackCalls = 0;

    registry.register(
      DataProviderDescriptor(
        providerId: 'primary-test',
        requirementTypes: const {'atmospheric_conditions'},
        reliability: 90,
        cost: 10,
        acquire: (req, params) async {
          primaryCalls++;
          return {'temperature_c': 21.0, 'provider': 'primary-test'};
        },
      ),
    );
    registry.register(
      DataProviderDescriptor(
        providerId: 'fallback-test',
        requirementTypes: const {'atmospheric_conditions'},
        reliability: 40,
        cost: 20,
        acquire: (req, params) async {
          fallbackCalls++;
          return {'temperature_c': 19.0, 'provider': 'fallback-test'};
        },
      ),
    );

    const req = DataRequirement(
      domainConcept: 'atmospheric_conditions',
      fields: ['temperature_c'],
    );
    final ranked = registry.resolve(req);
    expect(ranked.first.providerId, 'primary-test');

    final first = await registry.acquire(req, {});
    expect(first.ok, isTrue);
    expect(first.providerId, 'primary-test');
    expect(first.data!['provider'], 'primary-test');
    expect(primaryCalls, 1);

    registry.unregister('primary-test');
    final second = await registry.acquire(req, {});
    expect(second.ok, isTrue);
    expect(second.providerId, 'fallback-test');
    expect(fallbackCalls, 1);
  });

  test('no provider → truthful failure (not Wikipedia)', () async {
    final registry = DataProviderRegistry();
    const req = DataRequirement(domainConcept: 'atmospheric_conditions');
    final result = await registry.acquire(req, {});
    expect(result.ok, isFalse);
    expect(result.error, contains('PROVIDER_UNAVAILABLE'));
    expect(result.error!.toLowerCase(), isNot(contains('wikipedia')));
  });
}
