/// IS-P25 live acquisition probe (host-side, evidence for certification).
///
/// Exercises the REAL production path — DuckDuckGoSearchProvider →
/// WebWeaveXAdapter → KnowledgeAcquisitionEngine judging — and prints
/// judged results (domain, title, scores, image presence). Never prints
/// page bodies or secrets.
///
/// Lives in tool/ (NOT test/) so it never runs in the normal suite; it
/// needs live network by design. Run explicitly with:
///
///   flutter test tool/p25_live_acquisition_probe.dart
///
/// Self-skips when offline, matching test/knowledge/*'s convention.
library;

import 'dart:io';

import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

Future<bool> _online() async {
  try {
    final result = await InternetAddress.lookup('duckduckgo.com');
    return result.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<void> _probe(String query, String topic, String freshness) async {
  final engine = KnowledgeAcquisitionEngine(
    searchProvider: DuckDuckGoSearchProvider(),
    webweavexAdapter: WebWeaveXAdapter(),
  );
  final started = DateTime.now();
  final bundle = await engine.acquire(
    requirements: [
      KnowledgeRequirement(
        objective: query,
        resourceType: 'webDocument',
        freshness: freshness,
        topicTerms: KnowledgeAcquisitionEngine.significantTerms(topic),
      ),
    ],
    queryHints: const [],
  );
  final elapsed = DateTime.now().difference(started);

  // ignore: avoid_print
  print('PROBE query="$query" topic="$topic" freshness="$freshness"');
  // ignore: avoid_print
  print(
    'PROBE status=${bundle.status.name} resources=${bundle.resources.length} '
    'elapsedMs=${elapsed.inMilliseconds} warnings=${bundle.warnings}',
  );
  var rank = 1;
  for (final r in bundle.resources) {
    // ignore: avoid_print
    print(
      'PROBE #$rank ${r.sourceDomain} | "${r.title}" | '
      'rel=${r.ranking.relevanceScore.toStringAsFixed(2)} '
      'fresh=${r.ranking.freshnessScore.toStringAsFixed(2)} '
      'overall=${r.ranking.overallScore.toStringAsFixed(2)} '
      'image=${r.imageUrl != null} '
      'contentChars=${r.content?.length ?? 0}',
    );
    rank++;
  }
}

void main() {
  test(
    'live probe: current-data acquisition for weather/news-class queries',
    () async {
      if (!await _online()) {
        markTestSkipped('No outbound network — live probe skipped.');
        return;
      }
      await _probe('Lucknow', 'weather', 'current');
      await _probe('Lucknow', 'news', 'current');
      await _probe('India', 'news', 'current');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
