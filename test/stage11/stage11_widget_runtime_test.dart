/// Stage 11 — Widget Runtime Tests
///
/// Tests ExperienceRenderer with ExperienceStateEngine via widget pumping.
/// Tests multi-screen creation, navigation, rendering, interaction, reactivity.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:anything/runtime/experience_renderer.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:anything/creation/experience_package.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // =========================================================================
  // ExperienceRenderer — Widget-level rendering
  // =========================================================================
  group('ExperienceRenderer', () {
    late ExperienceRenderer renderer;
    late ExperienceStateEngine stateEngine;

    setUp(() {
      renderer = ExperienceRenderer();
      stateEngine = ExperienceStateEngine();
    });

    Widget _wrap(Widget Function(BuildContext ctx) builder) {
      return MaterialApp(home: Builder(builder: builder));
    }

    InterfaceNode _node(
      String id,
      String type, {
      Map<String, dynamic>? properties,
      List<InterfaceNode>? children,
      String? stateBinding,
    }) {
      return InterfaceNode(
        id: id,
        type: type,
        properties: properties ?? {},
        children: children ?? [],
        stateBinding: stateBinding,
      );
    }

    InterfaceScreen _screen(String title, {List<InterfaceNode>? children}) {
      return InterfaceScreen(
        id: 'screen_1',
        title: title,
        children: children ?? [],
      );
    }

    testWidgets('Renders text node', (tester) async {
      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          _node('t1', 'text', properties: {'content': 'Hello World'}),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('Renders button with label', (tester) async {
      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          _node('b1', 'button', properties: {'label': 'Press Me'}),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Press Me'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Renders input with hint', (tester) async {
      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          _node('i1', 'input', properties: {'hint': 'Enter name'}),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Renders column with children', (tester) async {
      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          _node('col', 'column', children: [
            _node('t1', 'text', properties: {'content': 'Line 1'}),
            _node('t2', 'text', properties: {'content': 'Line 2'}),
            _node('t3', 'text', properties: {'content': 'Line 3'}),
          ]),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Line 1'), findsOneWidget);
      expect(find.text('Line 2'), findsOneWidget);
      expect(find.text('Line 3'), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('Renders card with children', (tester) async {
      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          _node('card', 'card', children: [
            _node('t1', 'text', properties: {'content': 'Card Title'}),
          ]),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Card Title'), findsOneWidget);
    });

    testWidgets('Renders divider and spacer', (tester) async {
      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          _node('d1', 'divider'),
          _node('s1', 'spacer'),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('Renders switch with state binding', (tester) async {
      stateEngine.initialize(const StateSchema(variables: [
        StateVariable(id: 'darkMode', type: 'boolean', defaultValue: false),
      ]));

      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          _node('sw1', 'switch', stateBinding: 'darkMode'),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('State binding reads initial value', (tester) async {
      stateEngine.initialize(const StateSchema(variables: [
        StateVariable(id: 'greeting', type: 'string', defaultValue: 'Hello'),
      ]));

      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          _node('t1', 'text', stateBinding: 'greeting'),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.byType(Text).first);
      expect(textWidget.data, 'Hello');
    });

    testWidgets('Renders unknown type safely', (tester) async {
      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          _node('u1', 'customWidget', properties: {'value': 'test'}),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unsupported: customWidget'), findsOneWidget);
    });

    testWidgets('Button tap fires onEvent', (tester) async {
      String? firedEvent;
      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          InterfaceNode(
            id: 'btn',
            type: 'button',
            properties: {'label': 'Submit'},
            actionBinding: const ActionBinding(actionId: 'submit_pressed'),
          ),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(
          ctx,
          interface,
          stateEngine,
          onEvent: (eventId, {data}) => firedEvent = eventId,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      expect(firedEvent, 'submit_pressed');
    });

    testWidgets('Renders app bar with screen title', (tester) async {
      final interface = InterfaceDefinition(screens: [
        _screen('My Experience', children: [
          _node('t1', 'text', properties: {'content': 'Content'}),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('My Experience'), findsOneWidget);
    });

    testWidgets('Empty screens shows placeholder', (tester) async {
      final interface = InterfaceDefinition(screens: []);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No screens defined'), findsOneWidget);
    });

    testWidgets('Row renders horizontally', (tester) async {
      final interface = InterfaceDefinition(screens: [
        _screen('Test', children: [
          _node('row', 'row', children: [
            _node('t1', 'text', properties: {'content': 'Left'}),
            _node('t2', 'text', properties: {'content': 'Right'}),
          ]),
        ]),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
      expect(find.byType(Row), findsWidgets);
    });
  });

  // =========================================================================
  // State Engine — Reactive updates
  // =========================================================================
  group('StateEngine reactivity', () {
    late ExperienceStateEngine stateEngine;

    setUp(() {
      stateEngine = ExperienceStateEngine();
    });

    test('Write triggers stream update', () async {
      stateEngine.initialize(const StateSchema(variables: [
        StateVariable(id: 'counter', type: 'integer'),
      ]));

      final values = <dynamic>[];
      stateEngine.watch('counter').listen(values.add);

      stateEngine.write('counter', 0);
      stateEngine.write('counter', 1);
      stateEngine.write('counter', 2);

      await Future.delayed(Duration.zero);

      expect(values, [0, 1, 2]);
    });

    test('Read returns current value', () {
      stateEngine.initialize(const StateSchema(variables: [
        StateVariable(id: 'key', type: 'string'),
      ]));
      stateEngine.write('key', 'value');
      expect(stateEngine.read('key'), 'value');
    });

    test('Read returns null for missing key', () {
      expect(stateEngine.read('missing'), isNull);
    });

    test('Initialize sets defaults', () {
      stateEngine.initialize(const StateSchema(variables: [
        StateVariable(id: 'x', type: 'integer', defaultValue: 42),
      ]));
      expect(stateEngine.read('x'), 42);
    });
  });

  // =========================================================================
  // Golden Path — Full Experience rendering
  // =========================================================================
  group('Golden Path — Experience rendering', () {
    late ExperienceRenderer renderer;
    late ExperienceStateEngine stateEngine;

    setUp(() {
      renderer = ExperienceRenderer();
      stateEngine = ExperienceStateEngine();
    });

    Widget _wrap(Widget Function(BuildContext ctx) builder) {
      return MaterialApp(home: Builder(builder: builder));
    }

    testWidgets('People Tracker: list screen renders', (tester) async {
      final interface = InterfaceDefinition(screens: [
        InterfaceScreen(
          id: 'list',
          title: 'People',
          children: [
            InterfaceNode(
              id: 'header',
              type: 'text',
              properties: {'content': 'People Tracker'},
            ),
            InterfaceNode(
              id: 'add_btn',
              type: 'button',
              properties: {'label': 'Add Person'},
            ),
            InterfaceNode(
              id: 'list_col',
              type: 'column',
              children: [
                InterfaceNode(
                  id: 'person_1',
                  type: 'card',
                  children: [
                    InterfaceNode(
                      id: 'name_1',
                      type: 'text',
                      properties: {'content': 'Alice'},
                    ),
                    InterfaceNode(
                      id: 'email_1',
                      type: 'text',
                      properties: {'content': 'alice@test.com'},
                    ),
                  ],
                ),
                InterfaceNode(
                  id: 'person_2',
                  type: 'card',
                  children: [
                    InterfaceNode(
                      id: 'name_2',
                      type: 'text',
                      properties: {'content': 'Bob'},
                    ),
                    InterfaceNode(
                      id: 'email_2',
                      type: 'text',
                      properties: {'content': 'bob@test.com'},
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('People Tracker'), findsOneWidget);
      expect(find.text('Add Person'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(2));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('People Tracker: form screen renders', (tester) async {
      final interface = InterfaceDefinition(screens: [
        InterfaceScreen(
          id: 'form',
          title: 'Add Person',
          children: [
            InterfaceNode(
              id: 'name_input',
              type: 'input',
              properties: {'hint': 'Name'},
            ),
            InterfaceNode(
              id: 'email_input',
              type: 'input',
              properties: {'hint': 'Email'},
            ),
            InterfaceNode(
              id: 'notes_input',
              type: 'input',
              properties: {'hint': 'Notes'},
            ),
            InterfaceNode(
              id: 'save_btn',
              type: 'button',
              properties: {'label': 'Save'},
            ),
            InterfaceNode(
              id: 'cancel_btn',
              type: 'button',
              properties: {'label': 'Cancel'},
            ),
          ],
        ),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Equipment Lending: dashboard renders', (tester) async {
      final interface = InterfaceDefinition(screens: [
        InterfaceScreen(
          id: 'dashboard',
          title: 'Equipment Lending',
          children: [
            InterfaceNode(
              id: 'stats_row',
              type: 'row',
              children: [
                InterfaceNode(
                  id: 'stat_total',
                  type: 'card',
                  children: [
                    InterfaceNode(
                      id: 'label_total',
                      type: 'text',
                      properties: {'content': 'Total Equipment'},
                    ),
                    InterfaceNode(
                      id: 'value_total',
                      type: 'text',
                      properties: {'content': '12'},
                    ),
                  ],
                ),
                InterfaceNode(
                  id: 'stat_active',
                  type: 'card',
                  children: [
                    InterfaceNode(
                      id: 'label_active',
                      type: 'text',
                      properties: {'content': 'Active Loans'},
                    ),
                    InterfaceNode(
                      id: 'value_active',
                      type: 'text',
                      properties: {'content': '5'},
                    ),
                  ],
                ),
                InterfaceNode(
                  id: 'stat_available',
                  type: 'card',
                  children: [
                    InterfaceNode(
                      id: 'label_available',
                      type: 'text',
                      properties: {'content': 'Available'},
                    ),
                    InterfaceNode(
                      id: 'value_available',
                      type: 'text',
                      properties: {'content': '7'},
                    ),
                  ],
                ),
              ],
            ),
            InterfaceNode(id: 'divider1', type: 'divider'),
            InterfaceNode(
              id: 'loans_header',
              type: 'text',
              properties: {'content': 'Recent Loans'},
            ),
          ],
        ),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(3));
      expect(find.text('Total Equipment'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Active Loans'), findsOneWidget);
      expect(find.text('Recent Loans'), findsOneWidget);
    });

    testWidgets('Novel Domain: reading collection renders', (tester) async {
      final interface = InterfaceDefinition(screens: [
        InterfaceScreen(
          id: 'tracker',
          title: 'Reading Collection',
          children: [
            InterfaceNode(
              id: 'search',
              type: 'input',
              properties: {'hint': 'Search books...'},
            ),
            InterfaceNode(
              id: 'filter_row',
              type: 'row',
              children: [
                InterfaceNode(
                  id: 'filter_btn',
                  type: 'button',
                  properties: {'label': 'Filter'},
                ),
                InterfaceNode(
                  id: 'sort_btn',
                  type: 'button',
                  properties: {'label': 'Sort'},
                ),
              ],
            ),
            InterfaceNode(
              id: 'books_list',
              type: 'column',
              children: [
                InterfaceNode(
                  id: 'book_1',
                  type: 'card',
                  children: [
                    InterfaceNode(
                      id: 'title_1',
                      type: 'text',
                      properties: {'content': 'The Great Gatsby'},
                    ),
                    InterfaceNode(
                      id: 'author_1',
                      type: 'text',
                      properties: {'content': 'F. Scott Fitzgerald'},
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Reading Collection'), findsOneWidget);
      expect(find.text('Search books...'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('The Great Gatsby'), findsOneWidget);
      expect(find.text('F. Scott Fitzgerald'), findsOneWidget);
    });

    testWidgets('Deeply nested layout renders', (tester) async {
      final interface = InterfaceDefinition(screens: [
        InterfaceScreen(
          id: 'nested',
          title: 'Nested',
          children: [
            InterfaceNode(
              id: 'outer_col',
              type: 'column',
              children: [
                InterfaceNode(
                  id: 'inner_row',
                  type: 'row',
                  children: [
                    InterfaceNode(
                      id: 'card1',
                      type: 'card',
                      children: [
                        InterfaceNode(
                          id: 'text1',
                          type: 'text',
                          properties: {'content': 'A'},
                        ),
                      ],
                    ),
                    InterfaceNode(
                      id: 'card2',
                      type: 'card',
                      children: [
                        InterfaceNode(
                          id: 'text2',
                          type: 'text',
                          properties: {'content': 'B'},
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ]);

      await tester.pumpWidget(_wrap(
        (ctx) => renderer.render(ctx, interface, stateEngine),
      ));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(2));
    });
  });
}
