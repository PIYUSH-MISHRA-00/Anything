/// Live probe: news query results must change with the query.
/// Uses WebWeaveX via KnowledgeAcquisitionEngine.
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
  final queries = ['Lucknow', 'Delhi', 'AI'];
  final titlesByQuery = <String, Set<String>>{};

  for (final q in queries) {
    final result = await engine.acquire(
      semanticRequirement: 'news articles about $q',
      domainHint: 'news',
    );
    final titles = result.data.map((e) => e.title).toSet();
    stdout.writeln('--- $q (${titles.length}) ---');
    for (final item in result.data.take(3)) {
      stdout.writeln('${item.title} | ${item.source}');
    }
    titlesByQuery[q] = titles;
  }

  if (titlesByQuery['Lucknow']!.intersection(titlesByQuery['Delhi']!).length ==
      titlesByQuery['Lucknow']!.length) {
    throw StateError('Lucknow and Delhi results must differ');
  }
  stdout.writeln('OK: query results differ');
}
