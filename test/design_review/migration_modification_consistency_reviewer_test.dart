/// Vision V6 SCARE — MigrationReviewer + ModificationReviewer,
/// ConsistencyReviewer. ConsistencyReviewer is the one check that spans
/// every earlier milestone at once (Feature Discovery through the final
/// blueprint).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/design_review/review_types.dart';
import 'package:anything/design_review/reviewers/consistency_reviewer.dart';
import 'package:anything/design_review/reviewers/migration_modification_reviewer.dart';

import 'review_test_support.dart';

void main() {
  final context = buildReviewContext(fieldSurveyApp());

  group('MigrationReviewer', () {
    const reviewer = MigrationReviewer();

    test(
      'a real migration decision (schemaless storage) produces no critical issues',
      () {
        final issues = reviewer.review(context);
        expect(
          issues.any((i) => i.severity == ReviewSeverity.critical),
          isFalse,
        );
        expect(context.engineering.data.migrationDecision.decision, isNotEmpty);
      },
    );
  });

  group('ModificationReviewer', () {
    const reviewer = ModificationReviewer();

    test(
      'RequirementExtractor always records the future-modification requirement',
      () {
        final issues = reviewer.review(context);
        expect(issues, isEmpty);
      },
    );
  });

  group('ConsistencyReviewer', () {
    const reviewer = ConsistencyReviewer();

    test(
      'a real design that actually built every mandatory discovered feature has no critical issues',
      () {
        final issues = reviewer.review(context);
        expect(
          issues.any((i) => i.severity == ReviewSeverity.critical),
          isFalse,
        );
      },
    );

    test(
      'a mandatory persistence feature missing its entity is flagged critical',
      () {
        final architecture = context.architecture;
        final withoutEntity = architecture.copyWith(
          entities: architecture.entities
              .where((e) => e.entityId != 'entry')
              .toList(),
        );
        final broken = withArchitecture(context, withoutEntity);
        final issues = reviewer.review(broken);
        expect(
          issues.any(
            (i) => i.id.startsWith(
              'consistency:missingMandatoryFeature:feature:persistence:entry',
            ),
          ),
          isTrue,
        );
      },
    );
  });
}
