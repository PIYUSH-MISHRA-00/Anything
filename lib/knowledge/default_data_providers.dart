/// Default data-provider adapters registered by composition — not Kernel rules.
library;

import '../domain_services/news_data_service.dart';
import '../domain_services/weather_data_service.dart';
import 'data_provider_registry.dart';

/// Semantic concepts used by DataRequirement (provider-agnostic).
abstract final class DataConcepts {
  static const atmosphericConditions = 'atmospheric_conditions';
  static const newsArticles = 'news_articles';
}

/// Builds a registry with built-in adapters. Tests may register fakes on a
/// fresh [DataProviderRegistry] without touching Kernel/renderer.
DataProviderRegistry buildDefaultDataProviderRegistry({
  WeatherDataService? weatherService,
  NewsDataService? newsService,
}) {
  final registry = DataProviderRegistry();
  final weather = weatherService ?? WeatherDataService();
  final news = newsService ?? NewsDataService();

  registry.register(
    DataProviderDescriptor(
      providerId: 'open-meteo',
      requirementTypes: {DataConcepts.atmosphericConditions},
      supportedFields: const [
        'temperature',
        'humidity',
        'wind',
        'condition',
        'feelsLike',
      ],
      freshness: 'current',
      reliability: 80,
      cost: 10,
      acquire: (req, params) async {
        final location =
            (params['location'] ?? params['query'] ?? req.entity)?.toString() ??
            '';
        if (location.trim().isEmpty) {
          throw ArgumentError('Location required');
        }
        final obs = await weather.getCurrentWeather(location.trim());
        return {
          'results': [obs.toResultMap()],
          'provenance': {
            'sourceType': 'structuredWeather',
            'provider': obs.provider,
            'retrievedAt': obs.retrievedAt.toIso8601String(),
          },
        };
      },
    ),
  );

  registry.register(
    DataProviderDescriptor(
      providerId: 'google-news-rss',
      requirementTypes: {DataConcepts.newsArticles},
      supportedFields: const [
        'title',
        'source',
        'summary',
        'url',
        'imageUrl',
        'publishedAt',
      ],
      freshness: 'current',
      reliability: 70,
      cost: 10,
      acquire: (req, params) async {
        final query =
            (params['query'] ?? params['location'] ?? req.entity)?.toString() ??
            '';
        if (query.trim().isEmpty) {
          throw ArgumentError('Query required');
        }
        final articles = await news.searchArticles(query.trim());
        return {
          'results': articles.map((a) => a.toResultMap()).toList(),
          'provenance': {
            'sourceType': 'structuredNews',
            'provider': 'google-news-rss',
            'retrievedAt': DateTime.now().toUtc().toIso8601String(),
          },
        };
      },
    ),
  );

  return registry;
}
