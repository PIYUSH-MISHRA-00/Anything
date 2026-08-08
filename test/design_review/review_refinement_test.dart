/// Vision V6 SCARE — ReviewRefinement: review -> apply conservative
/// auto-fixes -> re-review, deterministic termination. Mirrors the
/// proven-terminating design already established by ASAE/AEE/FDI/MSRA.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/engineering_types.dart';
import 'package:anything/design_review/review_refinement.dart';
import 'package:anything/design_review/review_result.dart';

import 'review_test_support.dart';

void main() {
  final context = buildReviewContext(fieldSurveyApp());

  test('a real, approved design is approved with a single review pass', () {
    final result = const ReviewRefinement().refine(context);
    expect(result.outcome, ReviewOutcome.approved);
    expect(result.iterations, hasLength(1));
  });

  test('fixes a duplicated binding edge and reaches approved', () {
    final duplicatedEdges = [
      ...context.engineering.bindingGraph.edges,
      context.engineering.bindingGraph.edges.first,
    ];
    final broken = withEngineering(
      context,
      context.engineering.copyWith(
        bindingGraph: BindingGraph(edges: duplicatedEdges),
      ),
    );

    final result = const ReviewRefinement().refine(broken);

    expect(result.outcome, ReviewOutcome.approved);
    expect(
      result.finalContext.engineering.bindingGraph.edges.length,
      context.engineering.bindingGraph.edges.length,
    );
  });

  test(
    'every applied fix is logged in the iteration history — never silent',
    () {
      final duplicatedEdges = [
        ...context.engineering.bindingGraph.edges,
        context.engineering.bindingGraph.edges.first,
      ];
      final broken = withEngineering(
        context,
        context.engineering.copyWith(
          bindingGraph: BindingGraph(edges: duplicatedEdges),
        ),
      );

      final result = const ReviewRefinement().refine(broken);

      expect(
        result.iterations.first.issues.any(
          (i) => i.category.name == 'engineering' && i.autoFixable,
        ),
        isTrue,
      );
      expect(result.iterations.length, greaterThan(1));
    },
  );
}
