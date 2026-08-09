/// P15 — SearchAction query propagation + image semantics (no URL-as-text).
library;

import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/news_interface_factory.dart';
import 'package:anything/domain_services/news_data_service.dart';
import 'package:anything/knowledge/data_provider_registry.dart';
import 'package:anything/knowledge/default_data_providers.dart';
import 'package:anything/runtime/behavior_interpreter.dart';
import 'package:anything/runtime/data_runtime.dart';
import 'package:anything/runtime/experience_session.dart';
import 'package:anything/runtime/remote_image.dart';
import 'package:anything/runtime/service_resolver.dart';
import 'package:anything/runtime/state_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingNewsCapability extends PlatformCapability {
  String? lastQuery;
  final Map<String, dynamic> Function(Map<String, dynamic> params) handler;

  _RecordingNewsCapability(this.handler)
      : super(
          id: 'news',
          name: 'News',
          description: 'Test news capability',
          supportedOperations: const ['searchArticles'],
        );

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    lastQuery = params['query']?.toString();
    return CapabilityInvocationResult.success(data: handler(params));
  }
}

ExperiencePackage _newsPackage() {
  final built = const NewsInterfaceFactory().applyToPackage(
    ExperiencePackage(
      packageVersion: 1,
      manifest: ExperienceManifest(
        experienceId: 'news-p15',
        name: 'News',
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
        contentHash: 'p15',
        computedAt: DateTime.utc(2026, 1, 1),
      ),
    ),
    name: 'News',
  );
  return built;
}

BehaviorExecutionContext _ctx({
  required ExperiencePackage package,
  required ExperienceStateEngine state,
  required ExperienceServiceResolver resolver,
}) {
  final dataRuntime = ExperienceDataRuntime();
  if (package.data != null) {
    dataRuntime.initialize(
      package.data!,
      experienceId: package.manifest.experienceId,
    );
  }
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

void main() {
  group('NewsArticle display semantics', () {
    test('article content never dumps raw http(s) URLs', () {
      final article = NewsArticle(
        title: 'Headline',
        source: 'Wire',
        retrievedAt: DateTime.utc(2026, 1, 1),
        summary: 'See https://example.com/story and more',
        url: 'https://example.com/story',
        imageUrl: 'https://cdn.example.com/pic.jpg',
      );
      final block = article.toResultMap()['content'] as String;
      expect(block, contains('Headline'));
      expect(block, isNot(contains('https://')));
      expect(article.toResultMap()['imageUrl'], 'https://cdn.example.com/pic.jpg');
      expect(article.toResultMap()['sourceUri'], 'https://example.com/story');
    });
  });

  group('RemoteImageUrl', () {
    test('sanitize accepts http(s) and rejects junk', () {
      expect(
        RemoteImageUrl.sanitize('https://cdn.example.com/a.png'),
        'https://cdn.example.com/a.png',
      );
      expect(RemoteImageUrl.sanitize('not a url'), isNull);
      expect(RemoteImageUrl.sanitize(''), isNull);
      expect(RemoteImageUrl.sanitize(null), isNull);
    });
  });

  group('SearchAction query propagation', () {
    test('event payload query reaches news provider params', () async {
      final package = _newsPackage();
      final state = ExperienceStateEngine()..initialize(package.state);
      state.write('query', 'stale');

      final newsCap = _RecordingNewsCapability((params) => {
            'results': [
              {
                'title': 'Lucknow today',
                'content': 'Lucknow today\nSource: Wire',
                'sourceType': 'structuredNews',
                'provider': 'fake',
                'imageUrl': 'https://cdn.example.com/news.jpg',
                'sourceUri': 'https://example.com/a',
              },
            ],
            'provenance': {
              'sourceType': 'structuredNews',
              'provider': 'fake',
            },
          });

      final platform = CapabilityPlatform()..register(newsCap);
      final resolver = ExperienceServiceResolver(capabilityPlatform: platform)
        ..resolve(
          package.services,
          experienceId: package.manifest.experienceId,
          declaredCapabilities:
              package.capabilityDeclarations.map((c) => c.capabilityId).toList(),
        );

      await BehaviorInterpreter().execute(
        package.behavior,
        'search',
        context: _ctx(package: package, state: state, resolver: resolver),
        data: {'query': 'Lucknow'},
      );

      expect(newsCap.lastQuery, 'Lucknow');
      expect(state.read('query'), 'Lucknow');
      expect(state.read('resultTitle'), 'Lucknow today');
      expect(state.read('heroImageUrl'), 'https://cdn.example.com/news.jpg');
      expect(state.read('articleUrl'), 'https://example.com/a');
      expect(
        state.read('resultText')?.toString() ?? '',
        isNot(contains('https://')),
      );
    });

    test('stale concurrent search does not overwrite newer result', () async {
      final package = _newsPackage();
      final state = ExperienceStateEngine()..initialize(package.state);

      var bDone = false;
      final newsCap = _RecordingNewsCapability((params) {
        final q = params['query']?.toString() ?? '';
        if (q == 'A') {
          return {
            'results': [
              {
                'title': 'Result A',
                'content': 'A',
                'sourceType': 'structuredNews',
                'provider': 'fake',
              },
            ],
            'provenance': {
              'sourceType': 'structuredNews',
              'provider': 'fake',
            },
          };
        }
        bDone = true;
        return {
          'results': [
            {
              'title': 'Result B',
              'content': 'B',
              'sourceType': 'structuredNews',
              'provider': 'fake',
            },
          ],
          'provenance': {
            'sourceType': 'structuredNews',
            'provider': 'fake',
          },
        };
      });

      // Slow-A / fast-B: override execute with delay for A.
      final delayed = _DelayedNewsCapability(newsCap);

      final platform = CapabilityPlatform()..register(delayed);
      final resolver = ExperienceServiceResolver(capabilityPlatform: platform)
        ..resolve(
          package.services,
          experienceId: package.manifest.experienceId,
          declaredCapabilities:
              package.capabilityDeclarations.map((c) => c.capabilityId).toList(),
        );

      final ctx = _ctx(package: package, state: state, resolver: resolver);
      final futureA = BehaviorInterpreter().execute(
        package.behavior,
        'search',
        context: ctx,
        data: {'query': 'A'},
      );
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await BehaviorInterpreter().execute(
        package.behavior,
        'search',
        context: ctx,
        data: {'query': 'B'},
      );
      await futureA;

      expect(bDone, isTrue);
      expect(state.read('resultTitle'), 'Result B');
      expect(state.read('query'), 'B');
    });
  });

  group('Provider independence — FakeArticleProvider', () {
    test('same articleSearch requirement satisfied by fake provider', () async {
      final registry = DataProviderRegistry();
      String? seenQuery;
      registry.register(
        DataProviderDescriptor(
          providerId: 'fake-articles',
          requirementTypes: {DataConcepts.newsArticles},
          supportedFields: const [
            'title',
            'source',
            'summary',
            'url',
            'image',
          ],
          reliability: 99,
          acquire: (req, params) async {
            seenQuery = params['query']?.toString();
            return {
              'results': [
                {
                  'title': 'About $seenQuery',
                  'content': 'About $seenQuery\nSource: Fake',
                  'sourceType': 'structuredNews',
                  'provider': 'fake-articles',
                  'imageUrl': '',
                },
              ],
              'provenance': {
                'sourceType': 'structuredNews',
                'provider': 'fake-articles',
              },
            };
          },
        ),
      );

      final acquired = await registry.acquire(
        const DataRequirement(
          domainConcept: DataConcepts.newsArticles,
          freshness: 'recent',
          fields: ['title', 'source', 'summary'],
        ),
        {'query': 'AI'},
      );
      expect(acquired.ok, isTrue);
      expect(seenQuery, 'AI');
      expect(acquired.providerId, 'fake-articles');
      final title = ((acquired.data!['results'] as List).first as Map)['title'];
      expect(title, 'About AI');
    });
  });

  group('News surface media nodes', () {
    test('factory exposes remoteImage bound to heroImageUrl', () {
      final ui = const NewsInterfaceFactory().buildInterface(title: 'News');
      final nodes = ui.screens.first.children;
      final image = nodes.where((n) => n.type == 'remoteImage').single;
      expect(image.stateBinding, 'heroImageUrl');
    });
  });
}

/// Wraps [_RecordingNewsCapability] and delays query A so B can finish first.
class _DelayedNewsCapability extends PlatformCapability {
  final _RecordingNewsCapability inner;

  _DelayedNewsCapability(this.inner)
      : super(
          id: 'news',
          name: 'News',
          description: 'Delayed news',
          supportedOperations: const ['searchArticles'],
        );

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    final q = params['query']?.toString() ?? '';
    if (q == 'A') {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return inner.execute(operation, params);
  }
}
