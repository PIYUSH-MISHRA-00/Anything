/// Weather capability — structured observations via DataProviderRegistry.
library;

import '../../knowledge/data_provider_registry.dart';
import '../../knowledge/default_data_providers.dart';
import '../platform/capability_platform.dart';

/// Platform capability: `weather` / getCurrentWeather.
///
/// Selects a provider that satisfies `atmospheric_conditions`, not a
/// hardcoded "weather → Open-Meteo" Kernel rule.
class WeatherCapability extends PlatformCapability {
  WeatherCapability({DataProviderRegistry? registry})
    : _registry = registry ?? buildDefaultDataProviderRegistry(),
      super(
        id: 'weather',
        name: 'Weather',
        description: 'Structured weather observations and forecasts',
        supportedOperations: const ['getCurrentWeather', 'retrieve'],
      );

  final DataProviderRegistry _registry;

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    if (operation != 'getCurrentWeather' && operation != 'retrieve') {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.unsupported,
        error: 'Unknown weather operation: $operation',
      );
    }
    final location =
        (params['location'] ?? params['query'])?.toString().trim() ?? '';
    if (location.isEmpty) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.invalidArguments,
        error: 'Location required',
      );
    }
    final result = await _registry.acquire(
      const DataRequirement(
        domainConcept: DataConcepts.atmosphericConditions,
        fields: ['temperature', 'humidity', 'wind', 'condition'],
        freshness: 'current',
      ),
      {'location': location, 'query': location},
    );
    if (!result.ok) {
      return CapabilityInvocationResult.failure(
        result.error ?? 'Weather provider unavailable',
      );
    }
    final data = Map<String, dynamic>.from(result.data!);
    final prov = Map<String, dynamic>.from(
      (data['provenance'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    prov['selectedProvider'] = result.providerId;
    prov['attemptedProviders'] = result.attempted;
    data['provenance'] = prov;
    return CapabilityInvocationResult.success(data: data);
  }
}
