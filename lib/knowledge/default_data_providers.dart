/// Default data-provider adapters — WebWeaveX as the universal acquisition engine.
///
/// All external data acquisition flows through WebWeaveX. No domain-specific
/// APIs (Open-Meteo, Google News RSS, etc.) are hardcoded. The semantic
/// purpose determines the search query, not a domain switch.
library;

import 'data_provider_registry.dart';
import 'webweavex_data_provider.dart';
import 'knowledge_acquisition_engine.dart';
import 'search_provider.dart';
import 'webweavex_adapter.dart';

/// Semantic concepts used by DataRequirement (provider-agnostic).
///
/// These are PURPOSE labels, not domain switches. Any concept can be
/// acquired through WebWeaveX by constructing an appropriate query.
abstract final class DataConcepts {
  static const atmosphericConditions = 'atmospheric_conditions';
  static const newsArticles = 'news_articles';
  static const stockPrices = 'stock_prices';
  static const sportsScores = 'sports_scores';
  static const currencyRates = 'currency_rates';
  static const documentation = 'documentation';
  static const softwareReference = 'software_reference';
}

/// Builds a registry with WebWeaveX as the universal acquisition engine.
///
/// Tests may register fakes on a fresh [DataProviderRegistry] without
/// touching Kernel/renderer.
DataProviderRegistry buildDefaultDataProviderRegistry({
  KnowledgeAcquisitionEngine? knowledgeEngine,
  SearchProvider? searchProvider,
  WebWeaveXAdapter? webweavexAdapter,
}) {
  final registry = DataProviderRegistry();
  final wwxProvider = WebWeaveXDataProvider(
    engine: knowledgeEngine ?? KnowledgeAcquisitionEngine(
      searchProvider: searchProvider,
      webweavexAdapter: webweavexAdapter,
    ),
  );

  // Register WebWeaveX as the provider for ALL semantic concepts.
  // The same provider handles weather, news, stocks, sports, etc.
  // The search query is determined by the requirement, not a domain switch.
  registry.register(
    DataProviderDescriptor(
      providerId: 'webweavex',
      requirementTypes: {
        DataConcepts.atmosphericConditions,
        DataConcepts.newsArticles,
        DataConcepts.stockPrices,
        DataConcepts.sportsScores,
        DataConcepts.currencyRates,
        DataConcepts.documentation,
        DataConcepts.softwareReference,
      },
      supportedFields: const [
        'temperature',
        'humidity',
        'wind',
        'condition',
        'feelsLike',
        'title',
        'source',
        'summary',
        'url',
        'imageUrl',
        'publishedAt',
        'price',
        'change',
        'volume',
        'score',
        'homeTeam',
        'awayTeam',
        'rate',
        'from',
        'to',
      ],
      freshness: 'current',
      reliability: 70,
      cost: 10,
      acquire: wwxProvider.acquire,
    ),
  );

  return registry;
}
