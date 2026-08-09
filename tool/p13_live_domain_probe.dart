import 'package:anything/domain_services/news_data_service.dart';
import 'package:anything/domain_services/weather_data_service.dart';

Future<void> main() async {
  final weather = WeatherDataService();
  final obs = await weather.getCurrentWeather('Lucknow');
  print('--- WEATHER ---');
  print(obs.displayBlock);
  if (obs.displayBlock.toLowerCase().contains('wikipedia')) {
    throw StateError('Weather must not contain Wikipedia');
  }

  final news = NewsDataService();
  final articles = await news.searchArticles('Lucknow');
  print('--- NEWS (${articles.length}) ---');
  for (final a in articles.take(3)) {
    print('${a.title} | ${a.source} | ${a.publishedAt}');
    if (a.title.toLowerCase().contains('wikipedia') ||
        (a.url ?? '').contains('wikipedia.org')) {
      throw StateError('News must not be Wikipedia');
    }
  }
  print('OK');
}
