/// Implementation Specification IS-P03 Phase 5 — accessibility.
///
/// WHAT THE AUDITS FOUND, REPEATEDLY. Five `Semantics` widgets and four
/// `semanticLabel` usages across 71,983 lines of `lib/`. Every audit since the
/// Master Repository Audit has recorded accessibility as the worst-scoring
/// product dimension, and no milestone had touched it.
///
/// These tests assert the semantics tree a screen reader actually receives,
/// not the widget tree. They exist so the improvements cannot silently decay:
/// an unnamed control is invisible to a blind user and invisible to a code
/// review, and only a test of the semantics tree catches it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anything/design_system/components/anything_button.dart';
import 'package:anything/design_system/components/anything_empty_state.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('Buttons are named, and say when they are busy', () {
    testWidgets('a button exposes its label to a screen reader', (t) async {
      await t.pumpWidget(
        host(AnythingButton(label: 'Create app', onPressed: () {})),
      );

      // Assert the properties a screen reader uses, not an exact node shape:
      // Flutter merges our wrapper with ElevatedButton's own semantics, and
      // matchesSemantics against a merged node is brittle across versions.
      final node = t.getSemantics(find.byType(AnythingButton));
      expect(node.label, contains('Create app'));
      // `flagsCollection` is newer than the Flutter this project pins, so
      // `hasFlag` is the stable reader here. Scoped per line rather than
      // file-wide, so a future upgrade surfaces it again.
      // ignore: deprecated_member_use
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      // ignore: deprecated_member_use
      expect(node.hasFlag(SemanticsFlag.isEnabled), isTrue);
    });

    testWidgets('A LOADING BUTTON STILL HAS A NAME', (t) async {
      // The failure this prevents: while loading, the label is replaced by a
      // spinner. Without explicit semantics a screen reader announces
      // "button" with no name at all -- the user cannot tell what is loading,
      // or that anything is.
      await t.pumpWidget(
        host(
          AnythingButton(
            label: 'Create app',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      final node = t.getSemantics(find.byType(AnythingButton));
      expect(node.label, contains('Create app'));
      expect(
        node.label,
        contains('loading'),
        reason: 'a blind user must be told the button is busy',
      );
    });

    testWidgets('a disabled button reports that it is disabled', (t) async {
      await t.pumpWidget(host(const AnythingButton(label: 'Create app')));

      final node = t.getSemantics(find.byType(AnythingButton));
      expect(node.label, contains('Create app'));
      expect(
        // ignore: deprecated_member_use
        node.hasFlag(SemanticsFlag.isEnabled),
        isFalse,
        reason: 'greyed-out is a visual cue only; it must be announced too',
      );
    });
  });

  group('Decorative graphics do not shout', () {
    testWidgets('the empty-state icon is excluded from semantics', (t) async {
      // The icon repeats what the title already says. Announcing an unnamed
      // graphic before the text that matters is noise, and noise is what makes
      // screen-reader users abandon an app.
      await t.pumpWidget(
        host(
          const AnythingEmptyState(
            icon: Icons.auto_awesome,
            title: 'No apps yet',
            message: 'Ask Anything to build something.',
          ),
        ),
      );

      expect(find.bySemanticsLabel('No apps yet'), findsOneWidget);
      expect(find.text('Ask Anything to build something.'), findsOneWidget);

      // The Icon itself must contribute no semantics node.
      final iconSemantics = find.descendant(
        of: find.byType(ExcludeSemantics),
        matching: find.byType(Icon),
      );
      expect(
        iconSemantics,
        findsOneWidget,
        reason: 'the decorative icon must sit inside ExcludeSemantics',
      );
    });
  });

  group('The app survives large text', () {
    testWidgets('a button does not overflow at 2.0x text scale', (t) async {
      // Android allows font scaling well above 1.0. A fixed-height button with
      // scaled text is the classic overflow, and it makes the app unusable for
      // anyone who needs larger type.
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: host(
            SizedBox(
              width: 200,
              child: AnythingButton(label: 'Create app', onPressed: () {}),
            ),
          ),
        ),
      );

      expect(hasNoOverflow(t), isTrue);
    });

    testWidgets('an empty state does not overflow at 2.0x text scale', (
      t,
    ) async {
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: host(
            const SizedBox(
              width: 320,
              height: 600,
              child: AnythingEmptyState(
                icon: Icons.auto_awesome,
                title: 'No apps yet',
                message: 'Ask Anything to build something for you.',
              ),
            ),
          ),
        ),
      );

      expect(hasNoOverflow(t), isTrue);
    });
  });
}

/// Flutter reports an overflow through the error reporter rather than by
/// throwing, so a widget test passes happily while the UI is visibly broken.
/// This makes the check explicit.
bool hasNoOverflow(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception == null) return true;
  // Re-surface anything that is not an overflow; a real error must not be
  // swallowed by an accessibility test.
  if (exception is FlutterError &&
      exception.toString().contains('overflowed')) {
    return false;
  }
  throw exception;
}
