/// Vision V10 RC — Accessibility Audit follow-up: ExperienceRenderer's
/// Switch and Icon nodes now carry real Flutter Semantics. Confirmed by
/// repository audit that these two node types previously had zero
/// screen-reader-facing label (a bare Switch announces only "on"/"off",
/// a bare Icon announces nothing) — proven fixed here with real widget
/// semantics assertions, not just "it renders."
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/creation/experience_package.dart';
import 'package:anything/runtime/experience_renderer.dart';
import 'package:anything/runtime/state_engine.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ExperienceRenderer renderer;
  late ExperienceStateEngine stateEngine;

  setUp(() {
    renderer = ExperienceRenderer();
    stateEngine = ExperienceStateEngine();
  });

  Widget wrap(Widget Function(BuildContext ctx) builder) => MaterialApp(home: Builder(builder: builder));

  testWidgets('a labeled Switch node exposes a real Semantics label a screen reader can announce', (tester) async {
    final handle = tester.ensureSemantics();
    stateEngine.initialize(const StateSchema(variables: [StateVariable(id: 'darkMode', type: 'boolean', defaultValue: false, persistence: 'session')]));

    final interface = InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'screen_1',
          title: 'Settings',
          children: [
            InterfaceNode(id: 'sw1', type: 'switch', properties: const {'label': 'Dark Mode'}, stateBinding: 'darkMode'),
          ],
        ),
      ],
    );

    await tester.pumpWidget(wrap((ctx) => renderer.render(ctx, interface, stateEngine)));

    final semantics = tester.getSemantics(find.byType(Switch));
    expect(semantics.label, 'Dark Mode');
    handle.dispose();
  });

  testWidgets('an unlabeled Switch node still renders correctly (backward compatible, no regression)', (tester) async {
    stateEngine.initialize(const StateSchema(variables: [StateVariable(id: 'x', type: 'boolean', defaultValue: false, persistence: 'session')]));

    final interface = InterfaceDefinition(
      screens: [
        InterfaceScreen(id: 'screen_1', title: 'Test', children: [InterfaceNode(id: 'sw1', type: 'switch', properties: const {}, stateBinding: 'x')]),
      ],
    );

    await tester.pumpWidget(wrap((ctx) => renderer.render(ctx, interface, stateEngine)));
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('an icon node exposes its icon name as a real semantic label', (tester) async {
    final handle = tester.ensureSemantics();
    final interface = InterfaceDefinition(
      screens: [
        InterfaceScreen(id: 'screen_1', title: 'Test', children: [InterfaceNode(id: 'ic1', type: 'icon', properties: const {'icon': 'star'})]),
      ],
    );

    await tester.pumpWidget(wrap((ctx) => renderer.render(ctx, interface, stateEngine)));

    final semantics = tester.getSemantics(find.byType(Icon));
    expect(semantics.label, 'star');
    handle.dispose();
  });
}
