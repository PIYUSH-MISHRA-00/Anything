/// Live probe: news query results must change with the query.
import 'package:anything/domain_services/news_data_service.dart';

Future<void> main() async {
  final news = NewsDataService();
  final queries = ['Lucknow', 'Delhi', 'AI'];
  final titlesByQuery = <String, Set<String>>{};

  for (final q in queries) {
    final articles = await news.searchArticles(q);
    print('--- $q (${articles.length}) ---');
    for (final a in articles.take(3)) {
      print('${a.title} | ${a.source}');
      final block = a.toResultMap()['content'] as String;
      if (block.contains('https://') || block.contains('http://')) {
        throw StateError('Display content must not include raw URLs for $q');
      }
      if ((a.url ?? '').contains('wikipedia.org')) {
        throw StateError('News must not be Wikipedia');
      }
    }
    titlesByQuery[q] = articles.map((a) => a.title).toSet();
  }

  final lucknow = titlesByQuery['Lucknow']!;
  final delhi = titlesByQuery['Delhi']!;
  final ai = titlesByQuery['AI']!;
  if (lucknow.isNotEmpty && delhi.isNotEmpty && lucknow.intersection(delhi).length == lucknow.length) {
    throw StateError('Lucknow and Delhi returned identical title sets');
  }
  if (ai.isNotEmpty &&
      lucknow.isNotEmpty &&
      ai.intersection(lucknow).length == ai.length) {
    throw StateError('AI and Lucknow returned identical title sets');
  }
  print('OK — query-sensitive results');
}
