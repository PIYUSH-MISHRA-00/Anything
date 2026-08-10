/// Live probe: news query results must change with the query.
library;

import 'dart:io';

import 'package:anything/domain_services/news_data_service.dart';

Future<void> main() async {
  final news = NewsDataService();
  final queries = ['Lucknow', 'Delhi', 'AI'];
  final titlesByQuery = <String, Set<String>>{};

  for (final q in queries) {
    final articles = await news.searchArticles(q);
    stdout.writeln('--- $q (${articles.length}) ---');
    for (final a in articles.take(3)) {
      stdout.writeln('${a.title} | ${a.source}');
      final block = a.toResultMap()['content'] as String;
      if (block.contains('https://') || block.contains('http://')) {
        throw StateError('Display content must not include raw URLs for $q');
      }
      if ((a.url ?? '').contains('wikipedia.org')) {
        throw StateError('News must not use Wikipedia for $q');
      }
    }
    titlesByQuery[q] = articles.map((a) => a.title).toSet();
  }

  if (titlesByQuery['Lucknow']!.intersection(titlesByQuery['Delhi']!).length ==
      titlesByQuery['Lucknow']!.length) {
    throw StateError('Lucknow and Delhi results must differ');
  }
  stdout.writeln('OK: query results differ');
}
