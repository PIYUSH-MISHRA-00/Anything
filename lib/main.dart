import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/splash_screen.dart';
import 'screens/app_shell.dart';

// Global Key for navigation to handle deep links
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.setAppGroupId('com.anything.widget');
  runApp(const ProviderScope(child: AnythingApp()));
}

class AnythingApp extends ConsumerStatefulWidget {
  const AnythingApp({super.key});

  @override
  ConsumerState<AnythingApp> createState() => _AnythingAppState();
}

class _AnythingAppState extends ConsumerState<AnythingApp> {
  @override
  void initState() {
    super.initState();
    HomeWidget.widgetClicked.listen((Uri? uri) => _loadFromWidget(uri));
  }
  
  void _loadFromWidget(Uri? uri) {
    if (uri != null && uri.scheme == 'anything' && uri.host == 'intent') {
       final query = uri.queryParameters['query'];
       if (query != null && query.isNotEmpty) {
         // Deep link routing into the AI workspace specifically to handle the intent query
         navigatorKey.currentState?.pushAndRemoveUntil(
           MaterialPageRoute(builder: (_) => const AppShell()),
           (route) => false,
         );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anything',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
