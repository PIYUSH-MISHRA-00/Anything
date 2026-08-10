/// Tests for design system components.
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anything/design_system/components/components.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('AnythingButton', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(AnythingButton(label: 'Test', onPressed: () {})),
      );
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestWidget(
          AnythingButton(label: 'Test', onPressed: () => tapped = true),
        ),
      );
      await tester.tap(find.text('Test'));
      expect(tapped, isTrue);
    });

    testWidgets('shows icon when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AnythingButton(label: 'Test', onPressed: () {}, icon: Icons.add),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(AnythingButton(label: 'Test', onPressed: null)),
      );
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AnythingChip', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(buildTestWidget(AnythingChip(label: 'Tag')));
      expect(find.text('Tag'), findsOneWidget);
    });

    testWidgets('shows icon when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(AnythingChip(label: 'Tag', icon: Icons.star)),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  group('AnythingEmptyState', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AnythingEmptyState(
            icon: Icons.inbox,
            title: 'Empty',
            message: 'Nothing here',
          ),
        ),
      );
      expect(find.text('Empty'), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('renders action button when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AnythingEmptyState(
            icon: Icons.inbox,
            title: 'Empty',
            message: 'Nothing here',
            actionLabel: 'Create',
            onAction: () {},
          ),
        ),
      );
      expect(find.text('Create'), findsOneWidget);
    });
  });

  group('AnythingListTile', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(AnythingListTile(title: 'Setting')),
      );
      expect(find.text('Setting'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AnythingListTile(title: 'Setting', subtitle: 'Description'),
        ),
      );
      expect(find.text('Description'), findsOneWidget);
    });
  });

  group('AnythingSectionHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(AnythingSectionHeader(title: 'Section')),
      );
      expect(find.text('SECTION'), findsOneWidget);
    });

    testWidgets('renders action when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AnythingSectionHeader(
            title: 'Section',
            actionText: 'See all',
            onAction: () {},
          ),
        ),
      );
      expect(find.text('See all'), findsOneWidget);
    });
  });
}
