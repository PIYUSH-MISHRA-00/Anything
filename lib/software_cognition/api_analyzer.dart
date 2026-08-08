/// SchemaAnalyzer / APIAnalyzer — understands the API surface of acquired
/// software.
///
/// `fromRepositoryModel` derives endpoint hints from decorator names
/// WebWeaveX's own repository IR already extracted
/// (`RepositoryModel.decorators`, sourced from `compileRepository`'s
/// `symbols.decorators`) — it interprets WebWeaveX's own output, it does
/// not re-parse source.
///
/// `fromOpenApiSpec` is a small, real, deterministic OpenAPI
/// paths/methods extractor. WebWeaveX has an equivalent internal engine
/// (`core.repository.api_surface_reasoning_engine.reason_api_surface`,
/// ported as the private `reasonApiSurface` in
/// `package:webweavex/src/semantic_ir/repository_engines.dart`), but it
/// is not part of WebWeaveX's public export surface (`compileRepository`
/// does not accept an OpenAPI spec parameter publicly) — this fills that
/// specific, documented gap rather than duplicating a reachable API.
library;

import 'dart:convert';

import 'api_model.dart';
import 'semantic_software_graph.dart';
import 'software_identity.dart';
import 'software_node.dart';
import 'software_types.dart';

const Set<String> _httpVerbs = {'get', 'post', 'put', 'delete', 'patch'};

class SchemaAnalyzer {
  const SchemaAnalyzer();

  SchemaGraph fromOpenApiSpec(Map<String, dynamic> spec) {
    final components = spec['components'];
    final schemas = components is Map ? components['schemas'] : null;
    final nodes = <SoftwareNode>[];
    if (schemas is Map) {
      for (final name in schemas.keys) {
        nodes.add(
          SoftwareNode(
            identity: SoftwareIdentity.stable(
              SoftwareNodeKind.schema,
              name.toString(),
            ),
            kind: SoftwareNodeKind.schema,
            label: name.toString(),
          ),
        );
      }
    }
    return SchemaGraph(SemanticSoftwareGraph(nodes: nodes));
  }
}

class APIAnalyzer {
  final SchemaAnalyzer _schemaAnalyzer;

  const APIAnalyzer({SchemaAnalyzer schemaAnalyzer = const SchemaAnalyzer()})
    : _schemaAnalyzer = schemaAnalyzer;

  /// Real endpoints derived from an OpenAPI spec's `paths` object —
  /// `{path: {method: {...}}}` — every entry becomes one endpoint node,
  /// labeled "METHOD /path".
  APIGraph fromOpenApiJson(String openApiJson) {
    Map<String, dynamic> spec = <String, dynamic>{};
    try {
      final decoded = jsonDecode(openApiJson);
      if (decoded is Map) spec = Map<String, dynamic>.from(decoded);
    } on FormatException {
      // spec stays empty — malformed input never crashes the analyzer.
    }
    return _fromSpec(spec);
  }

  APIGraph fromOpenApiSpec(Map<String, dynamic> spec) => _fromSpec(spec);

  APIGraph _fromSpec(Map<String, dynamic> spec) {
    final paths = spec['paths'];
    final nodes = <SoftwareNode>[];
    if (paths is Map) {
      for (final pathEntry in paths.entries) {
        final methods = pathEntry.value;
        if (methods is! Map) continue;
        for (final method in methods.keys) {
          final label = '${method.toString().toUpperCase()} ${pathEntry.key}';
          nodes.add(
            SoftwareNode(
              identity: SoftwareIdentity.stable(
                SoftwareNodeKind.endpoint,
                label,
              ),
              kind: SoftwareNodeKind.endpoint,
              label: label,
            ),
          );
        }
      }
    }
    return APIGraph(
      endpoints: EndpointGraph(SemanticSoftwareGraph(nodes: nodes)),
      schemas: _schemaAnalyzer.fromOpenApiSpec(spec),
    );
  }

  /// Endpoint hints derived purely from decorator names WebWeaveX's own
  /// symbol extraction already computed — a real but bounded signal
  /// (a decorator literally named `get`/`post`/etc), never a claim of
  /// full route-table accuracy.
  APIGraph fromDecorators(List<String> decorators) {
    final nodes = decorators
        .where((d) => _httpVerbs.contains(d.toLowerCase()))
        .map(
          (d) => SoftwareNode(
            identity: SoftwareIdentity.stable(SoftwareNodeKind.endpoint, d),
            kind: SoftwareNodeKind.endpoint,
            label: d,
          ),
        )
        .toList();
    return APIGraph(
      endpoints: EndpointGraph(SemanticSoftwareGraph(nodes: nodes)),
      schemas: const SchemaGraph(SemanticSoftwareGraph()),
    );
  }
}
