/// Vision V4 FDI — FeatureClassifier: de-duplicates candidates sharing an
/// id, merging evidence rather than dropping it.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/feature_classifier.dart';
import 'package:anything/feature_discovery/feature_types.dart';

void main() {
  const classifier = FeatureClassifier();

  test('candidates with distinct ids all survive unchanged', () {
    final result = classifier.classify(const [
      FeatureCandidate(
        id: 'feature:a',
        name: 'A',
        category: FeatureCategory.data,
        rationale: 'r',
      ),
      FeatureCandidate(
        id: 'feature:b',
        name: 'B',
        category: FeatureCategory.data,
        rationale: 'r',
      ),
    ]);
    expect(result, hasLength(2));
  });

  test(
    'candidates sharing an id are merged into one, union of source nodes',
    () {
      final result = classifier.classify(const [
        FeatureCandidate(
          id: 'feature:a',
          name: 'A',
          category: FeatureCategory.data,
          sourceNodeIds: ['n1'],
          rationale: 'r',
        ),
        FeatureCandidate(
          id: 'feature:a',
          name: 'A',
          category: FeatureCategory.data,
          sourceNodeIds: ['n2'],
          rationale: 'r',
        ),
      ]);
      expect(result, hasLength(1));
      expect(result.single.sourceNodeIds, unorderedEquals(['n1', 'n2']));
    },
  );
}
