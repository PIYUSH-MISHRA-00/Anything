/// P14 — provider independence + expression evaluator.
library;

import 'package:anything/capabilities/builtin/weather_capability.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/knowledge/data_provider_registry.dart';
import 'package:anything/knowledge/default_data_providers.dart';
import 'package:anything/runtime/expression_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataProviderRegistry', () {
    test(
      'fake provider satisfies atmospheric_conditions without Kernel',
      () async {
        final registry = DataProviderRegistry();
        registry.register(
          DataProviderDescriptor(
            providerId: 'fake-weather',
            requirementTypes: {DataConcepts.atmosphericConditions},
            supportedFields: const [
              'temperature',
              'humidity',
              'wind',
              'condition',
            ],
            reliability: 99,
            acquire: (req, params) async => {
              'results': [
                {
                  'title': params['location'],
                  'content': 'temp 21',
                  'sourceType': 'structuredWeather',
                  'provider': 'fake-weather',
                  'temperature': 21,
                },
              ],
              'provenance': {
                'sourceType': 'structuredWeather',
                'provider': 'fake-weather',
              },
            },
          ),
        );

        final weather = WeatherCapability(registry: registry);
        final result = await weather.execute('getCurrentWeather', {
          'location': 'Testville',
        });
        expect(result.status, CapabilityResultStatus.success);
        final data = result.data;
        expect(data['provenance']['selectedProvider'], 'fake-weather');
        expect((data['results'] as List).first['temperature'], 21);
      },
    );

    test('failover: preferred fails, second succeeds', () async {
      final registry = DataProviderRegistry();
      registry.register(
        DataProviderDescriptor(
          providerId: 'broken',
          requirementTypes: {DataConcepts.atmosphericConditions},
          reliability: 100,
          acquire: (req, params) async => throw StateError('down'),
        ),
      );
      registry.register(
        DataProviderDescriptor(
          providerId: 'backup',
          requirementTypes: {DataConcepts.atmosphericConditions},
          reliability: 50,
          acquire: (req, params) async => {
            'results': [
              {
                'title': 'ok',
                'content': 'ok',
                'sourceType': 'structuredWeather',
                'provider': 'backup',
              },
            ],
            'provenance': {
              'sourceType': 'structuredWeather',
              'provider': 'backup',
            },
          },
        ),
      );

      final acquired = await registry.acquire(
        const DataRequirement(
          domainConcept: DataConcepts.atmosphericConditions,
          freshness: 'current',
        ),
        {'location': 'X'},
      );
      expect(acquired.ok, isTrue);
      expect(acquired.providerId, 'backup');
      expect(acquired.attempted, containsAll(['broken', 'backup']));
    });

    test('registration order does not override reliability ranking', () async {
      final registry = DataProviderRegistry();
      registry.register(
        DataProviderDescriptor(
          providerId: 'low',
          requirementTypes: {DataConcepts.newsArticles},
          reliability: 10,
          acquire: (req, params) async => {
            'results': [],
            'provenance': {'provider': 'low'},
          },
        ),
      );
      registry.register(
        DataProviderDescriptor(
          providerId: 'high',
          requirementTypes: {DataConcepts.newsArticles},
          reliability: 90,
          acquire: (req, params) async => {
            'results': [
              {
                'title': 'H',
                'content': 'H',
                'sourceType': 'structuredNews',
                'provider': 'high',
              },
            ],
            'provenance': {'sourceType': 'structuredNews', 'provider': 'high'},
          },
        ),
      );
      final resolved = registry.resolve(
        const DataRequirement(domainConcept: DataConcepts.newsArticles),
      );
      expect(resolved.first.providerId, 'high');
    });
  });

  group('ExpressionEvaluator', () {
    test('parentheses and precedence', () {
      final r = ExpressionEvaluator.evaluate('2+(3*4)');
      expect(r.ok, isTrue);
      expect(r.value, 14);
      final r2 = ExpressionEvaluator.evaluate('(2+3)*4');
      expect(r2.value, 20);
    });

    test('scientific functions', () {
      expect(ExpressionEvaluator.evaluate('sqrt(16)').value, 4);
      expect(ExpressionEvaluator.evaluate('sin(0)').value, 0);
      expect(ExpressionEvaluator.evaluate('2^8').value, 256);
    });
  });
}
