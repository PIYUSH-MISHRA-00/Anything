/// Knowledge Provider boundary for Anything v2.
///
/// This defines the contract through which Anything accesses
/// external knowledge, including the future WebWeaveX system.
///
/// WebWeaveX will eventually become an adapter behind this contract.
/// UI widgets must NEVER import WebWeaveX directly.
library;

import 'dart:async';

/// A piece of retrieved knowledge.
class KnowledgeResult {
  /// The source of this knowledge (URL, document, etc.).
  final String source;

  /// A summary of the knowledge.
  final String summary;

  /// The full content, if available.
  final String? content;

  /// Relevance score (0.0 to 1.0).
  final double relevance;

  /// Metadata about this result.
  final Map<String, dynamic> metadata;

  const KnowledgeResult({
    required this.source,
    required this.summary,
    this.content,
    this.relevance = 0.0,
    this.metadata = const {},
  });
}

/// Configuration for a knowledge retrieval request.
class KnowledgeRequest {
  /// The query or topic to search for.
  final String query;

  /// Maximum number of results to return.
  final int maxResults;

  /// Filter by knowledge type (e.g., "documentation", "code", "api").
  final String? typeFilter;

  /// Additional context for the search.
  final Map<String, dynamic> context;

  const KnowledgeRequest({
    required this.query,
    this.maxResults = 10,
    this.typeFilter,
    this.context = const {},
  });
}

/// Abstract interface for knowledge providers.
///
/// WebWeaveX will implement this contract. The Kernel and
/// Runtime interact with knowledge through this boundary.
abstract class KnowledgeProvider {
  /// Provider identifier.
  String get providerId;

  /// Whether this provider is currently available.
  bool get isAvailable;

  /// Retrieve knowledge matching the given request.
  Future<List<KnowledgeResult>> retrieve(KnowledgeRequest request);

  /// Stream knowledge results as they arrive.
  Stream<KnowledgeResult> retrieveStream(KnowledgeRequest request);

  /// Check if a specific piece of knowledge is available.
  Future<bool> isSourceAvailable(String source);
}
