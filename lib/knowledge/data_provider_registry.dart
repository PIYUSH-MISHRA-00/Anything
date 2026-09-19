/// Capability-driven data provider selection — not domain→provider hardcoding.
///
/// Providers declare which semantic concepts they satisfy. The engine ranks
/// compatible providers and fails over. Registering a new provider does not
/// require Kernel or renderer changes.
library;

/// What is needed (not how to obtain it).
class DataRequirement {
  final String domainConcept;
  final List<String> fields;
  final String freshness;
  final String? entity;
  final Map<String, dynamic> constraints;

  const DataRequirement({
    required this.domainConcept,
    this.fields = const [],
    this.freshness = 'current',
    this.entity,
    this.constraints = const {},
  });
}

/// Machine-readable provider capability declaration.
class DataProviderDescriptor {
  final String providerId;
  final Set<String> requirementTypes;
  final List<String> supportedFields;
  final String freshness;
  final int reliability;
  final int cost;
  final Future<Map<String, dynamic>> Function(
    DataRequirement requirement,
    Map<String, dynamic> params,
  )
  acquire;

  const DataProviderDescriptor({
    required this.providerId,
    required this.requirementTypes,
    required this.acquire,
    this.supportedFields = const [],
    this.freshness = 'current',
    this.reliability = 50,
    this.cost = 50,
  });

  bool supports(DataRequirement requirement) {
    if (!requirementTypes.contains(requirement.domainConcept)) return false;
    if (requirement.freshness.isNotEmpty &&
        freshness != 'any' &&
        requirement.freshness != freshness &&
        !(requirement.freshness == 'current' && freshness == 'current')) {
      // Allow current↔current; reject live vs static mismatches later via fields.
    }
    if (requirement.fields.isEmpty) return true;
    if (supportedFields.isEmpty) return true;
    return requirement.fields.every(supportedFields.contains);
  }
}

/// Registry of data providers selectable by [DataRequirement].
class DataProviderRegistry {
  final List<DataProviderDescriptor> _providers = [];

  void register(DataProviderDescriptor provider) {
    _providers.removeWhere((p) => p.providerId == provider.providerId);
    _providers.add(provider);
  }

  void unregister(String providerId) {
    _providers.removeWhere((p) => p.providerId == providerId);
  }

  List<String> get providerIds =>
      _providers.map((p) => p.providerId).toList(growable: false);

  /// Compatible providers ranked by reliability (desc), then cost (asc).
  List<DataProviderDescriptor> resolve(DataRequirement requirement) {
    final matches = _providers.where((p) => p.supports(requirement)).toList();
    matches.sort((a, b) {
      final byRel = b.reliability.compareTo(a.reliability);
      if (byRel != 0) return byRel;
      return a.cost.compareTo(b.cost);
    });
    return matches;
  }

  /// Attempt providers in ranked order until one succeeds.
  Future<DataProviderAcquireResult> acquire(
    DataRequirement requirement,
    Map<String, dynamic> params,
  ) async {
    final candidates = resolve(requirement);
    if (candidates.isEmpty) {
      return DataProviderAcquireResult.failure(
        'PROVIDER_UNAVAILABLE: no provider for ${requirement.domainConcept}',
      );
    }
    final errors = <String>[];
    for (final provider in candidates) {
      try {
        final data = await provider.acquire(requirement, params);
        return DataProviderAcquireResult.success(
          data: data,
          providerId: provider.providerId,
          attempted: candidates.map((c) => c.providerId).toList(),
        );
      } catch (e) {
        errors.add('${provider.providerId}: $e');
      }
    }
    return DataProviderAcquireResult.failure(
      'PROVIDER_UNAVAILABLE: all candidates failed — ${errors.join('; ')}',
      attempted: candidates.map((c) => c.providerId).toList(),
    );
  }
}

class DataProviderAcquireResult {
  final bool ok;
  final Map<String, dynamic>? data;
  final String? providerId;
  final String? error;
  final List<String> attempted;

  const DataProviderAcquireResult._({
    required this.ok,
    this.data,
    this.providerId,
    this.error,
    this.attempted = const [],
  });

  factory DataProviderAcquireResult.success({
    required Map<String, dynamic> data,
    required String providerId,
    List<String> attempted = const [],
  }) => DataProviderAcquireResult._(
    ok: true,
    data: data,
    providerId: providerId,
    attempted: attempted,
  );

  factory DataProviderAcquireResult.failure(
    String error, {
    List<String> attempted = const [],
  }) => DataProviderAcquireResult._(
    ok: false,
    error: error,
    attempted: attempted,
  );
}
