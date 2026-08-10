/// IS-P13 — domain services vs generic knowledge + stopwatch controls.
library;

import 'package:anything/core/contracts/intent.dart';
import 'package:anything/creation/app_capabilities.dart';
import 'package:anything/creation/intent_preservation.dart';
import 'package:anything/creation/network_reference_interface_factory.dart';
import 'package:anything/creation/news_interface_factory.dart';
import 'package:anything/creation/timing_interface_factory.dart';
import 'package:anything/creation/weather_interface_factory.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/domain_services/news_data_service.dart';
import 'package:anything/domain_services/weather_data_service.dart';
import 'package:anything/runtime/timing_session.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/synthesis/app_archetype.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ExperiencePackage bare(String name) {
    final now = DateTime.now();
    return ExperiencePackage(
      manifest: ExperienceManifest(
        experienceId: 'x',
        name: name,
        description: name,
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
  }

  group('IS-P13 capability inference', () {
    test('weather prompt → weatherData not network knowledge', () {
      final bp = AppBlueprint(
        id: 'bp',
        name: 'Wx',
        description: 'live conditions',
        archetypes: const [AppArchetype.reference],
      );
      final caps = const AppCapabilityInferrer().infer(
        blueprint: bp,
        intent: Intent.create(expression: 'weather dashboard'),
      );
      expect(caps.contains(AppCapabilityIds.weatherData), isTrue);
      expect(caps.contains(AppCapabilityIds.networkData), isFalse);
      expect(caps.contains(AppCapabilityIds.webKnowledge), isFalse);
    });

    test('news prompt → newsData not Wikipedia knowledge', () {
      final bp = AppBlueprint(
        id: 'bp',
        name: 'News',
        description: 'headlines',
        archetypes: const [AppArchetype.collection, AppArchetype.reference],
      );
      final caps = const AppCapabilityInferrer().infer(
        blueprint: bp,
        intent: Intent.create(expression: 'news app'),
      );
      expect(caps.contains(AppCapabilityIds.newsData), isTrue);
      expect(caps.contains(AppCapabilityIds.networkData), isFalse);
      expect(caps.contains(AppCapabilityIds.crud), isFalse);
      expect(caps.contains(AppCapabilityIds.form), isFalse);
    });
  });

  group('IS-P13 semantic preservation', () {
    test('weather vs knowledge package is incompatible', () {
      final knowledge = const NetworkReferenceInterfaceFactory().applyToPackage(
        bare('Lookup'),
        name: 'Lookup',
        purpose: 'lookup',
      );
      final result = const IntentPreservationValidator().validate(
        rawPrompt: 'weather dashboard',
        package: knowledge,
      );
      expect(result.isCompatible, isFalse);
      expect(result.requested, IntentPurpose.weather);
    });

    test('weather package is compatible', () {
      final wx = const WeatherInterfaceFactory().applyToPackage(
        bare('Weather'),
        name: 'Weather',
      );
      final result = const IntentPreservationValidator().validate(
        rawPrompt: 'weather dashboard',
        package: wx,
      );
      expect(result.isCompatible, isTrue);
      expect(PackageCapabilityProbe(wx).hasWeatherService, isTrue);
      expect(PackageCapabilityProbe(wx).hasKnowledgeService, isFalse);
      final input = wx.interface.screens.first.children
          .expand((n) => [n, ...n.children])
          .firstWhere((n) => n.id == 'query_input');
      expect(input.properties['width'], 'expand');
    });

    test('news package is compatible', () {
      final news = const NewsInterfaceFactory().applyToPackage(
        bare('News'),
        name: 'News',
      );
      final result = const IntentPreservationValidator().validate(
        rawPrompt: 'news app',
        package: news,
      );
      expect(result.isCompatible, isTrue);
      expect(PackageCapabilityProbe(news).hasNewsService, isTrue);
    });
  });

  group('IS-P13 stopwatch controls', () {
    test('timing package has start/pause/reset bindings and timingPad', () {
      final pkg = const TimingInterfaceFactory().applyToPackage(
        bare('Stopwatch'),
        name: 'Stopwatch',
      );
      expect(PackageCapabilityProbe(pkg).hasTimingControls, isTrue);
      expect(
        pkg.interface.screens.first.children.any((c) => c.type == 'timingPad'),
        isTrue,
      );
      final state = ExperienceStateEngine()..initialize(pkg.state);
      TimingSession.apply(state, eventId: TimingSession.start);
      expect(state.read('running'), isTrue);
    });
  });

  group('IS-P13 weather service parsing', () {
    test('parses Open-Meteo style responses', () async {
      final client = MockClient((request) async {
        if (request.url.host.contains('geocoding')) {
          return http.Response(
            '{"results":[{"name":"Lucknow","latitude":26.85,'
            '"longitude":80.95,"country":"India","admin1":"UP"}]}',
            200,
          );
        }
        return http.Response(
          '{"current":{"temperature_2m":31.2,"apparent_temperature":33.0,'
          '"relative_humidity_2m":55,"weather_code":1,"wind_speed_10m":8.5}}',
          200,
        );
      });
      final obs = await WeatherDataService(
        client: client,
      ).getCurrentWeather('Lucknow');
      expect(obs.location, contains('Lucknow'));
      expect(obs.temperatureC, 31.2);
      expect(obs.toResultMap()['sourceType'], 'structuredWeather');
      expect(obs.displayBlock.toLowerCase(), isNot(contains('wikipedia')));
    });
  });

  group('IS-P13 news service parsing', () {
    test('parses RSS items', () async {
      final client = MockClient((request) async {
        return http.Response('''<?xml version="1.0"?>
<rss><channel>
<item>
<title><![CDATA[Lucknow news one]]></title>
<link>https://example.com/a</link>
<source>Example</source>
<pubDate>Sun, 09 Aug 2026 10:00:00 GMT</pubDate>
<description><![CDATA[Summary one]]></description>
</item>
<item>
<title>Second headline</title>
<link>https://example.com/b</link>
<source>Wire</source>
</item>
</channel></rss>''', 200);
      });
      final articles = await NewsDataService(
        client: client,
      ).searchArticles('Lucknow');
      expect(articles, isNotEmpty);
      expect(articles.first.title, contains('Lucknow'));
      expect(articles.first.toResultMap()['sourceType'], 'structuredNews');
    });
  });
}
