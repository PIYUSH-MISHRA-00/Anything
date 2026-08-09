/// Weather capability — structured observations (not WebWeaveX knowledge).
library;

import '../../domain_services/weather_data_service.dart';
import '../platform/capability_platform.dart';

/// Platform capability: `weather` / getCurrentWeather.
class WeatherCapability extends PlatformCapability {
  WeatherCapability({WeatherDataService? service})
    : _service = service ?? WeatherDataService(),
      super(
        id: 'weather',
        name: 'Weather',
        description: 'Structured weather observations and forecasts',
        supportedOperations: const ['getCurrentWeather', 'retrieve'],
      );

  final WeatherDataService _service;

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
    try {
      final obs = await _service.getCurrentWeather(location);
      return CapabilityInvocationResult.success(
        data: {
          'results': [obs.toResultMap()],
          'provenance': {
            'sourceType': 'structuredWeather',
            'provider': obs.provider,
            'retrievedAt': obs.retrievedAt.toIso8601String(),
          },
        },
      );
    } catch (e) {
      return CapabilityInvocationResult.failure(e.toString());
    }
  }
}
