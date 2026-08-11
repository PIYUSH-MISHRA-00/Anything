/// Live probe: weather and news queries via WebWeaveX.
library;

import 'dart:io';

import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/ai/ai_provider.dart';

Future<void> main() async {
  final engine = KnowledgeAcquisitionEngine(
    adapter: WebWeaveXAdapter(),
    aiProvider: AiProviderResolver.current,
  );

  // Weather probe
  final weatherResult = await engine.acquire(
    semanticRequirement: 'current weather conditions in Lucknow',
    domainHint: 'weather',
  );
  stdout.writeln('--- WEATHER ---');
  for (final item in weatherResult.data.take(1)) {
    stdout.writeln('${item.title}: ${item.summary}');
    if (item.summary.toLowerCase().contains('wikipedia')) {
      throw StateError('Weather must not contain Wikipedia');
    }
  }

  // News probe
  final newsResult = await engine.acquire(
    semanticRequirement: 'latest news about Lucknow',
    domainHint: 'news',
  );
  stdout.writeln('--- NEWS (${newsResult.data.length}) ---');
  for (final item in newsResult.data.take(3)) {
    stdout.writeln('${item.title} | ${item.source}');
    if (item.title.toLowerCase().contains('wikipedia') ||
        item.url.contains('wikipedia.org')) {
      throw StateError('News must not be Wikipedia');
    }
  }
  stdout.writeln('OK');
}
