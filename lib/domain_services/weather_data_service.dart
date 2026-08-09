/// Structured weather data — Open-Meteo (no API key).
///
/// Distinct from WebWeaveX/generic knowledge. Returns observations, never
/// Wikipedia extracts.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of a structured weather lookup.
class WeatherObservation {
  final String location;
  final double? latitude;
  final double? longitude;
  final double? temperatureC;
  final double? feelsLikeC;
  final int? humidityPercent;
  final double? windKmh;
  final String condition;
  final DateTime retrievedAt;
  final String provider;

  const WeatherObservation({
    required this.location,
    required this.condition,
    required this.retrievedAt,
    this.latitude,
    this.longitude,
    this.temperatureC,
    this.feelsLikeC,
    this.humidityPercent,
    this.windKmh,
    this.provider = 'open-meteo',
  });

  String get displayBlock {
    final buf = StringBuffer()
      ..writeln(location)
      ..writeln(condition);
    if (temperatureC != null) {
      buf.writeln('Temperature: ${temperatureC!.toStringAsFixed(1)}°C');
    }
    if (feelsLikeC != null) {
      buf.writeln('Feels like: ${feelsLikeC!.toStringAsFixed(1)}°C');
    }
    if (humidityPercent != null) {
      buf.writeln('Humidity: $humidityPercent%');
    }
    if (windKmh != null) {
      buf.writeln('Wind: ${windKmh!.toStringAsFixed(1)} km/h');
    }
    buf.writeln('Updated: ${retrievedAt.toLocal().toIso8601String()}');
    buf.writeln('Source: $provider (structured weather)');
    return buf.toString().trim();
  }

  Map<String, dynamic> toResultMap() => {
    'title': location,
    'content': displayBlock,
    'sourceType': 'structuredWeather',
    'provider': provider,
    'sourceUri': 'https://open-meteo.com/',
    'temperatureC': temperatureC,
    'feelsLikeC': feelsLikeC,
    'humidityPercent': humidityPercent,
    'windKmh': windKmh,
    'condition': condition,
    'retrievedAt': retrievedAt.toIso8601String(),
  };
}

/// Fetches real weather via Open-Meteo geocoding + forecast APIs.
class WeatherDataService {
  WeatherDataService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _geoHost = 'geocoding-api.open-meteo.com';
  static const _wxHost = 'api.open-meteo.com';

  Future<WeatherObservation> getCurrentWeather(String location) async {
    final query = location.trim();
    if (query.isEmpty) {
      throw ArgumentError('Location is required');
    }

    final geoUri = Uri.https(_geoHost, '/v1/search', {
      'name': query,
      'count': '1',
      'language': 'en',
      'format': 'json',
    });
    final geoRes = await _client.get(geoUri).timeout(const Duration(seconds: 20));
    if (geoRes.statusCode != 200) {
      throw StateError('Could not resolve location (HTTP ${geoRes.statusCode})');
    }
    final geoJson = jsonDecode(geoRes.body) as Map<String, dynamic>;
    final results = geoJson['results'] as List? ?? const [];
    if (results.isEmpty) {
      throw StateError('Unknown location: $query');
    }
    final place = results.first as Map<String, dynamic>;
    final lat = (place['latitude'] as num).toDouble();
    final lon = (place['longitude'] as num).toDouble();
    final name = [
      place['name'],
      place['admin1'],
      place['country'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');

    final wxUri = Uri.https(_wxHost, '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,'
          'weather_code,wind_speed_10m',
      'wind_speed_unit': 'kmh',
      'timezone': 'auto',
    });
    final wxRes = await _client.get(wxUri).timeout(const Duration(seconds: 20));
    if (wxRes.statusCode != 200) {
      throw StateError('Weather provider failed (HTTP ${wxRes.statusCode})');
    }
    final wxJson = jsonDecode(wxRes.body) as Map<String, dynamic>;
    final current = wxJson['current'] as Map<String, dynamic>? ?? const {};
    final code = (current['weather_code'] as num?)?.toInt();

    return WeatherObservation(
      location: name.isEmpty ? query : name,
      latitude: lat,
      longitude: lon,
      temperatureC: (current['temperature_2m'] as num?)?.toDouble(),
      feelsLikeC: (current['apparent_temperature'] as num?)?.toDouble(),
      humidityPercent: (current['relative_humidity_2m'] as num?)?.toInt(),
      windKmh: (current['wind_speed_10m'] as num?)?.toDouble(),
      condition: _conditionLabel(code),
      retrievedAt: DateTime.now().toUtc(),
    );
  }

  static String _conditionLabel(int? code) {
    if (code == null) return 'Unknown conditions';
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly cloudy';
    if (code <= 48) return 'Fog';
    if (code <= 57) return 'Drizzle';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    if (code <= 82) return 'Rain showers';
    if (code <= 86) return 'Snow showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Weather code $code';
  }
}
