/// Shared test scaffolding for Vision V7 (Autonomous Evolution Engine)
/// tests. Deliberately extends V6's `review_test_support.dart` rather
/// than rebuilding the same pipeline a second time — per this milestone's
/// own "avoid parallel implementations, prefer extension" directive.
/// Not a test file itself.
library;

import 'package:anything/design_review/design_review_engine.dart';
import 'package:anything/evolution/evolution_context.dart';
import 'package:anything/evolution/evolution_policy.dart';
import 'package:anything/synthesis/application_reasoner.dart' show SemanticApp;

import '../design_review/review_test_support.dart';

export '../design_review/review_test_support.dart';

/// Runs the full real V2-V6 pipeline (via `buildReviewContext`) plus a
/// real Design Review pass, then wraps the result into an EvolutionContext
/// — never a hand-rolled fake context.
EvolutionContext buildEvolutionContext(SemanticApp app, {EvolutionStrategy strategy = EvolutionStrategy.balanced}) {
  final reviewContext = buildReviewContext(app);
  final reviewOutcome = const DesignReviewEngine().review(reviewContext);
  return EvolutionContext(
    reviewContext: reviewOutcome.session.result.finalContext,
    reviewSession: reviewOutcome.session,
    strategy: strategy,
  );
}
