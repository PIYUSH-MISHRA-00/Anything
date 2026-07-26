// Basic smoke test for AnythingApp.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/app/app.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('AnythingApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AnythingApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AnythingApp), findsOneWidget);
  });
}
