/// Regression tests for IS-P25: generic requirement preservation +
/// requirement satisfaction (supersedes the P23/P24 Wikipedia-blacklist
/// approach, which was removed by design).
///
/// What must stay true:
/// - The Experience's semantic subject (topic) and freshness need survive
///   from creation into every runtime acquisition query.
/// - Evidence is judged against the requirement (terms + recency), never
///   against a source-name blacklist. A Wikipedia URL with genuinely
///   current, topical content is acceptable; an encyclopedia article loses
///   to a current source on scoring, not on its domain name.
/// - freshness == 'current' re-acquires on every refresh; the TTL-less
///   cache is only an explicit offline fallback, labeled as cached.
/// - imageUrl and source attribution flow to the shell's state.
library;

import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/network_reference_interface_factory.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/knowledge/knowledge_acquisition_engine.dart';
import 'package:anything/knowledge/knowledge_bundle.dart';
import 'package:anything/knowledge/search_provider.dart';
import 'package:anything/knowledge/webweavex_adapter.dart';
import 'package:anything/runtime/behavior_interpreter.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/runtime/service_resolver.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake search provider: fixed URL list, records queries, can be told to
/// fail to simulate offline.
class _FakeSearch implements SearchProvider {
  final List<String> urls;
  final List<String> queries = [];
  bool failNext = false;

  _FakeSearch(this.urls);

  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    if (failNext) throw Exception('offline');
    queries.add(query);
    return [for (final u in urls) SearchResult(url: u)];
  }
}

/// Page fetcher returning canned HTML per URL — exercises the REAL
/// WebWeaveX extraction/normalization path without network.
WebWeaveXAdapter _adapterFor(Map<String, String> pages) {
  return WebWeaveXAdapter(
    fetchPage: (url) async => {
      'url': url,
      'status': 200,
      'html': pages[url] ?? '',
      'available': pages.containsKey(url),
    },
  );
}

String _page({required String title, required String body, String? ogImage}) {
  final meta = ogImage == null
      ? ''
      : '<meta property="og:image" content="$ogImage">';
  return '<html><head><title>$title</title>$meta</head>'
      '<body><p>$body</p></body></html>';
}

ExperiencePackage _shellPackage({String topic = '', String freshness = ''}) {
  return const NetworkReferenceInterfaceFactory().applyToPackage(
    ExperiencePackage(
      packageVersion: 1,
      manifest: ExperienceManifest(
        experienceId: 'test-p24',
        name: 'Test',
        description: 'test',
        version: '1.0.0',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        networkMode: NetworkMode.required,
        storageMode: StorageMode.localKey,
        requiredCapabilities: const [],
      ),
      interface: const InterfaceDefinition(screens: []),
      behavior: const BehaviorGraph(nodes: [], edges: []),
      state: const StateSchema(variables: []),
      services: const [],
      networkDeclarations: const [],
      capabilityDeclarations: const [],
      permissionDeclarations: const [],
      provenance: const PackageProvenance(
        creationEngineVersion: '1.0.0',
        specVersion: 1,
        planVersion: 1,
      ),
      integrity: PackageIntegrity(
        contentHash: '',
        computedAt: DateTime.utc(2026, 1, 1),
      ),
    ),
    name: 'Test',
    topic: topic,
    freshness: freshness,
  );
}

class _FakeCapability extends PlatformCapability {
  final Map<String, dynamic> Function(Map<String, dynamic> params) handler;
  Map<String, dynamic>? lastParams;

  _FakeCapability(this.handler)
    : super(
        id: 'knowledge',
        name: 'Knowledge',
        description: 'Test',
        supportedOperations: const ['retrieve'],
      );

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    lastParams = params;
    return CapabilityInvocationResult.success(data: handler(params));
  }
}

BehaviorExecutionContext _ctx({
  required ExperiencePackage package,
  required ExperienceStateEngine state,
  required ExperienceServiceResolver resolver,
}) {
  final dataRuntime = ExperienceDataRuntime();
  final session = ExperienceSession(
    id: 's1',
    experienceId: package.manifest.experienceId,
    package: package,
    status: SessionStatus.running,
    startedAt: DateTime.now(),
    lastActiveAt: DateTime.now(),
  );
  return BehaviorExecutionContext(
    session: session,
    stateEngine: state,
    dataRuntime: dataRuntime,
    serviceResolver: resolver,
  );
}

ExperienceServiceResolver _resolverFor(
  ExperiencePackage package,
  PlatformCapability cap,
) {
  final platform = CapabilityPlatform()..register(cap);
  return ExperienceServiceResolver(capabilityPlatform: platform)..resolve(
    package.services,
    experienceId: package.manifest.experienceId,
    declaredCapabilities: package.capabilityDeclarations
        .map((c) => c.capabilityId)
        .toList(),
  );
}

void main() {
  group('IS-P25 requirement preservation — shell config', () {
    test('behavior graph carries topic and freshness, no blacklist key', () {
      final bg = const NetworkReferenceInterfaceFactory().buildBehavior(
        topic: 'weather',
        freshness: 'current',
      );
      final node = bg.nodes.firstWhere((n) => n.id == 'refreshData_invoke');
      expect(node.config['topic'], 'weather');
      expect(node.config['freshness'], 'current');
      expect(node.config.containsKey('expectedSourceType'), isFalse);
      expect(node.config['imageStateId'], 'resultImage');
      expect(node.config['provenanceStateId'], 'sourceLabel');
    });

    test('deriveTopicTerms keeps the subject, drops construction words', () {
      expect(
        deriveTopicTerms(
          'Build me a professional weather dashboard that lets me search '
          'locations and refresh current weather.',
        ),
        contains('weather'),
      );
      expect(
        deriveTopicTerms('Build me a professional current news application.'),
        contains('news'),
      );
      final fermentation = deriveTopicTerms(
        'Build a professional home fermentation batch tracker.',
      );
      expect(fermentation, contains('fermentation'));
      for (final banned in ['build', 'professional', 'dashboard', 'app']) {
        expect(
          deriveTopicTerms('build professional dashboard app'),
          isNot(contains(banned)),
        );
      }
    });

    test('topic and freshness params reach the capability', () async {
      final package = _shellPackage(topic: 'weather', freshness: 'current');
      final state = ExperienceStateEngine()..initialize(package.state);
      final cap = _FakeCapability(
        (params) => {
          'results': [
            {
              'title': 'Lucknow weather now',
              'content': '32°C, clear skies, updated today',
              'sourceUri': 'https://example.com/wx',
            },
          ],
        },
      );
      final resolver = _resolverFor(package, cap);

      await BehaviorInterpreter().execute(
        package.behavior,
        'refreshData',
        context: _ctx(package: package, state: state, resolver: resolver),
        data: {'query': 'Lucknow'},
      );

      expect(cap.lastParams, isNotNull);
      expect(cap.lastParams!['query'], 'Lucknow');
      expect(cap.lastParams!['topic'], 'weather');
      expect(cap.lastParams!['freshness'], 'current');
    });
  });

  group('IS-P25 query composition + satisfaction — engine', () {
    KnowledgeRequirement req({
      String objective = 'Lucknow',
      String freshness = 'current',
      List<String> topic = const ['weather'],
    }) {
      return KnowledgeRequirement(
        objective: objective,
        resourceType: 'webDocument',
        freshness: freshness,
        topicTerms: topic,
      );
    }

    test('runtime query composes objective + topic + freshness cue', () async {
      final search = _FakeSearch(const ['https://a.example/wx']);
      final engine = KnowledgeAcquisitionEngine(
        searchProvider: search,
        webweavexAdapter: _adapterFor({
          'https://a.example/wx': _page(
            title: 'Lucknow weather',
            body: 'Lucknow weather now: 32 degrees, updated today.',
          ),
        }),
      );
      await engine.acquire(requirements: [req()], queryHints: const []);
      expect(search.queries.single, 'Lucknow weather current');
    });

    test(
      'current-data requirement: current topical page outranks encyclopedia '
      'article; off-topic page is dropped — no URL blacklist involved',
      () async {
        const wiki = 'https://en.wikipedia.org/wiki/Lucknow';
        const live = 'https://weather.example/lucknow';
        const junk = 'https://unrelated.example/page';
        final engine = KnowledgeAcquisitionEngine(
          searchProvider: _FakeSearch(const [wiki, live, junk]),
          webweavexAdapter: _adapterFor({
            wiki: _page(
              title: 'Lucknow - Wikipedia',
              body:
                  'Lucknow is the capital of the Indian state of Uttar '
                  'Pradesh. It was founded centuries ago and has a humid '
                  'subtropical climate.',
            ),
            live: _page(
              title: 'Lucknow weather now',
              body:
                  'Lucknow current weather, updated today: 32 degrees, '
                  'clear skies, live observations as of this morning, '
                  '${DateTime.now().year}.',
            ),
            junk: _page(
              title: 'Cookie recipes',
              body: 'How to bake cookies with butter and sugar.',
            ),
          }),
        );

        final bundle = await engine.acquire(
          requirements: [req()],
          queryHints: const [],
        );

        expect(bundle.resources, isNotEmpty);
        // The current, topical page wins on scoring.
        expect(bundle.resources.first.sourceUri, live);
        // The encyclopedia page is NOT rejected by name — it is present,
        // just ranked below the genuinely current source.
        expect(bundle.resources.map((r) => r.sourceUri), contains(wiki));
        // Evidence matching neither objective nor topic does not satisfy
        // the requirement at all.
        expect(bundle.resources.map((r) => r.sourceUri), isNot(contains(junk)));
      },
    );

    test(
      'freshness=current re-acquires on every call (Refresh works)',
      () async {
        final search = _FakeSearch(const ['https://a.example/wx']);
        final engine = KnowledgeAcquisitionEngine(
          searchProvider: search,
          webweavexAdapter: _adapterFor({
            'https://a.example/wx': _page(
              title: 'Lucknow weather',
              body: 'Lucknow weather updated today.',
            ),
          }),
        );
        await engine.acquire(requirements: [req()], queryHints: const []);
        await engine.acquire(requirements: [req()], queryHints: const []);
        expect(
          search.queries.length,
          2,
          reason: 'current data must re-acquire',
        );
      },
    );

    test(
      'reference requirement is served from cache on the second call',
      () async {
        final search = _FakeSearch(const ['https://a.example/ref']);
        final engine = KnowledgeAcquisitionEngine(
          searchProvider: search,
          webweavexAdapter: _adapterFor({
            'https://a.example/ref': _page(
              title: 'Lucknow history',
              body: 'Lucknow history reference article.',
            ),
          }),
        );
        final r = req(freshness: '', topic: const ['history']);
        await engine.acquire(requirements: [r], queryHints: const []);
        await engine.acquire(requirements: [r], queryHints: const []);
        expect(search.queries.length, 1, reason: 'reference data may cache');
      },
    );

    test(
      'offline: current requirement falls back to cache, labeled cached',
      () async {
        final search = _FakeSearch(const ['https://a.example/wx']);
        final engine = KnowledgeAcquisitionEngine(
          searchProvider: search,
          webweavexAdapter: _adapterFor({
            'https://a.example/wx': _page(
              title: 'Lucknow weather',
              body: 'Lucknow weather updated today.',
            ),
          }),
        );
        final first = await engine.acquire(
          requirements: [req()],
          queryHints: const [],
        );
        expect(first.resources, isNotEmpty);

        search.failNext = true;
        final offline = await engine.acquire(
          requirements: [req()],
          queryHints: const [],
        );
        expect(offline.resources, isNotEmpty, reason: 'cached fallback');
        expect(offline.status, BundleStatus.offlineCached);
        expect(offline.cacheStatus, 'offline_cached');
      },
    );

    test('og:image is extracted into the resource', () async {
      const url = 'https://news.example/story';
      final engine = KnowledgeAcquisitionEngine(
        searchProvider: _FakeSearch(const [url]),
        webweavexAdapter: _adapterFor({
          url: _page(
            title: 'Lucknow news today',
            body: 'Lucknow news headline updated today.',
            ogImage: 'https://cdn.example.com/story.jpg',
          ),
        }),
      );
      final bundle = await engine.acquire(
        requirements: [
          req(topic: const ['news']),
        ],
        queryHints: const [],
      );
      expect(
        bundle.resources.first.imageUrl,
        'https://cdn.example.com/story.jpg',
      );
    });
  });

  group('IS-P25 runtime outcome — interpreter', () {
    test(
      'unsatisfied requirement produces an honest, actionable message',
      () async {
        final package = _shellPackage(topic: 'weather', freshness: 'current');
        final state = ExperienceStateEngine()..initialize(package.state);
        final cap = _FakeCapability((params) => {'results': const []});
        final resolver = _resolverFor(package, cap);

        await BehaviorInterpreter().execute(
          package.behavior,
          'refreshData',
          context: _ctx(package: package, state: state, resolver: resolver),
          data: {'query': 'Lucknow'},
        );

        final text = state.read('resultText')?.toString() ?? '';
        expect(text, contains('No current results'));
        expect(text, contains('Lucknow'));
      },
    );

    test(
      'cached results are labeled as cached in the source attribution',
      () async {
        final package = _shellPackage(topic: 'weather', freshness: 'current');
        final state = ExperienceStateEngine()..initialize(package.state);
        final cap = _FakeCapability(
          (params) => {
            'results': [
              {
                'title': 'Lucknow weather',
                'content': 'Cached observation',
                'sourceUri': 'https://weather.example/lucknow',
                'sourceDomain': 'weather.example',
                'retrievedAt': '2026-08-10T09:00:00.000',
                'cacheStatus': 'offline_cached',
              },
            ],
          },
        );
        final resolver = _resolverFor(package, cap);

        await BehaviorInterpreter().execute(
          package.behavior,
          'refreshData',
          context: _ctx(package: package, state: state, resolver: resolver),
          data: {'query': 'Lucknow'},
        );

        final label = state.read('sourceLabel')?.toString() ?? '';
        expect(label, contains('Cached copy'));
        expect(label, contains('weather.example'));
        expect(label, contains('2026-08-10'));
      },
    );
  });
}
