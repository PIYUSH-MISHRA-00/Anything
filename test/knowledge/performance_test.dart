/// V1 — Knowledge pipeline performance measurement.
///
/// Records real timings for retrieval (cache miss), cache hit, and the
/// synthesis/package-generation stages that consume a KnowledgeBundle.
/// Not a strict benchmark (network latency varies run to run) — no hard
/// thresholds are asserted, since a network-latency-based CI failure
/// would be flaky by nature. Timings are printed for
/// docs/progress/V2_KNOWLEDGE_PERFORMANCE.md to cite.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/synthesis/deterministic_reasoner.dart';
import 'package:anything/synthesis/application_reasoner.dart';
import 'package:anything/synthesis/synthesis_planner.dart';
import 'package:anything/synthesis/generic_package_builder.dart';
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/kernel/classification/intent_category.dart';

class _FixedUrlSearchProvider implements SearchProvider {
  final String url;
  const _FixedUrlSearchProvider(this.url);
  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    return [SearchResult(url: url)];
  }
}

Future<bool> _hasNetwork() async {
  try {
    final r = await http
        .get(Uri.parse('https://example.com/'))
        .timeout(const Duration(seconds: 8));
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() {
  test(
    'measured timings: cache-miss retrieval vs cache-hit vs synthesis',
    () async {
      if (!await _hasNetwork()) {
        markTestSkipped('No outbound network access in this environment.');
        return;
      }

      final engine = KnowledgeAcquisitionEngine(
        searchProvider: const _FixedUrlSearchProvider('https://example.com/'),
        webweavexAdapter: WebWeaveXAdapter(),
      );
      final requirements = [
        const KnowledgeRequirement(
          objective: 'example domain reference',
          resourceType: 'domainKnowledge',
        ),
      ];

      final missStart = DateTime.now();
      final missBundle = await engine.acquire(
        requirements: requirements,
        queryHints: const [],
      );
      final missElapsed = DateTime.now().difference(missStart);

      final hitStart = DateTime.now();
      final hitBundle = await engine.acquire(
        requirements: requirements,
        queryHints: const [],
      );
      final hitElapsed = DateTime.now().difference(hitStart);

      // Deterministic-reasoner + synthesis timing (no network involved).
      final synthesisStart = DateTime.now();
      final understanding = IntentUnderstanding(
        intentId: 'perf-${DateTime.now().microsecondsSinceEpoch}',
        objective: 'track my reading list',
        category: IntentCategory.create,
        existingExperience: const ExistingExperienceResolution(
          status: ExistingExperienceStatus.notChecked,
        ),
        desiredOutcome: '',
        confidence: 0.9,
        networkNeed: NetworkNeed.none,
        creationNeed: CreationNeed.definitelyNeeded,
        modificationNeed: ModificationNeed.notNeeded,
      );
      final reasoning = await const DeterministicReasoner().reason(
        ApplicationReasoningContext(understanding: understanding),
      );
      String synthesisOutcome = 'no-op';
      if (reasoning is ReasoningReady) {
        final blueprint = SynthesisPlanner(
          const DeterministicReasoner(),
        ).convertToBlueprint(reasoning.semanticApp);
        GenericPackageBuilder.build(blueprint);
        synthesisOutcome = 'built';
      }
      final synthesisElapsed = DateTime.now().difference(synthesisStart);

      // ignore: avoid_print
      print(
        'KNOWLEDGE PIPELINE PERFORMANCE '
        '(cache_miss_ms=${missElapsed.inMilliseconds}, '
        'cache_hit_ms=${hitElapsed.inMilliseconds}, '
        'synthesis_ms=${synthesisElapsed.inMilliseconds}, '
        'synthesis_outcome=$synthesisOutcome, '
        'miss_resources=${missBundle.resources.length}, '
        'hit_resources=${hitBundle.resources.length})',
      );

      // Sanity, not a performance assertion: cache hit must not be slower
      // than a fresh network fetch by an order of magnitude.
      expect(
        hitElapsed.inMilliseconds,
        lessThan(missElapsed.inMilliseconds + 50),
      );
    },
  );
}
