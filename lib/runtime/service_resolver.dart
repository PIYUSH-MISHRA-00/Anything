/// Experience Service Resolver — maps service definitions to trusted implementations.
library;

import '../capabilities/platform/capability_platform.dart';
import '../creation/experience_package.dart';

/// Maps a `ServiceDefinition.type` string to the matching
/// `CapabilityPlatform` capability id. `localDatabase` has no entry — no
/// registered Capability Platform capability answers it yet (REALITY,
/// Implementation Milestone R1: `ExperienceDataRuntime` already owns real
/// generic CRUD outside this resolver entirely; extending Capability
/// Platform with a new "database" capability would be inventing new
/// architecture, out of R1's "wire what exists" scope).
const Map<String, String> _serviceTypeToCapabilityId = {
  'httpClient': 'http',
  'notifications': 'notifications',
  'fileAccess': 'files',
  'knowledgeRetrieval': 'knowledge',
  // IS-P25: legacy semantic service types resolve to the ONE generic
  // knowledge capability. Weather/news are topics, not capabilities —
  // topic + freshness semantics travel in the service config instead.
  'weatherData': 'knowledge',
  'newsData': 'knowledge',
  'aiInference': 'ai',
};

/// Resolves service definitions to trusted Runtime services.
class ExperienceServiceResolver {
  final Map<String, _ServiceEntry> _services = {};

  /// Optional shared Capability Platform (Implementation Milestone R1).
  /// REALITY before R1: `localDatabase`/`httpClient` always returned
  /// `{'status': 'not_implemented'}` and `notifications`/`fileAccess`/
  /// `knowledgeRetrieval`/`aiInference` always fell through to "Unknown
  /// service type" — `CapabilityPlatform.register()`/`.invoke()` existed
  /// and were fully tested (M2) but had zero production callers (MIS-1
  /// Part 1/2's largest standing finding). Null by default — every
  /// existing test/call site that constructs `ExperienceServiceResolver()`
  /// without one keeps identical (stubbed) behavior; `clock` is untouched
  /// either way.
  final CapabilityPlatform? _capabilityPlatform;
  List<String>? _declaredCapabilities;
  String? _sessionId;

  ExperienceServiceResolver({CapabilityPlatform? capabilityPlatform})
    : _capabilityPlatform = capabilityPlatform;

  /// Resolve a list of service definitions. [experienceId] and
  /// [declaredCapabilities] (Implementation Milestone R1) scope the
  /// Capability Platform dispatch below to this Experience's own
  /// declarations and session budget — omitted, dispatch still works but
  /// without a declared-capability allow-list (matches the permissive
  /// default every pre-R1 caller already relied on for `clock`).
  void resolve(
    List<ServiceDefinition> definitions, {
    String? experienceId,
    List<String>? declaredCapabilities,
  }) {
    _sessionId = experienceId;
    _declaredCapabilities = declaredCapabilities;
    for (final def in definitions) {
      if (_isKnownService(def.type)) {
        _services[def.id] = _ServiceEntry(
          id: def.id,
          type: def.type,
          config: def.config,
          available: true,
        );
      } else {
        _services[def.id] = _ServiceEntry(
          id: def.id,
          type: def.type,
          config: def.config,
          available: false,
        );
      }
    }
  }

  /// Check if a service is available.
  bool isAvailable(String serviceId) {
    return _services[serviceId]?.available ?? false;
  }

  /// Execute a service operation.
  Future<Map<String, dynamic>> execute(
    String serviceId,
    String operation,
    Map<String, dynamic> params,
  ) async {
    final entry = _services[serviceId];
    if (entry == null || !entry.available) {
      return {'error': 'Service not available: $serviceId'};
    }

    // Execute through trusted implementation
    switch (entry.type) {
      case 'clock':
        return _executeClock(operation, params);
      case 'localDatabase':
        return _executeDatabase(operation, params);
      default:
        final capabilityId = _serviceTypeToCapabilityId[entry.type];
        if (capabilityId != null && _capabilityPlatform != null) {
          return _executeViaCapabilityPlatform(capabilityId, operation, params);
        }
        return entry.type == 'httpClient'
            ? _executeHttp(operation, params)
            : {'error': 'Unknown service type: ${entry.type}'};
    }
  }

  /// Dispatches through the shared Capability Platform (Implementation
  /// Milestone R1) — the real, budgeted, declaration-enforced invocation
  /// path `CapabilityPlatform.invoke()` already provides (M2-certified;
  /// unchanged here). Translates its typed `CapabilityInvocationResult`
  /// into this resolver's existing `Map<String, dynamic>` contract so
  /// every caller (`BehaviorInterpreter`) is unaffected by the change.
  Future<Map<String, dynamic>> _executeViaCapabilityPlatform(
    String capabilityId,
    String operation,
    Map<String, dynamic> params,
  ) async {
    final result = await _capabilityPlatform!.invoke(
      capabilityId,
      operation,
      params,
      declaredCapabilities: _declaredCapabilities,
      sessionId: _sessionId,
    );
    if (result.status == CapabilityResultStatus.success) {
      return result.data;
    }
    return {'error': result.error ?? result.status.name};
  }

  bool _isKnownService(String type) {
    const knownTypes = {
      'clock',
      'localDatabase',
      'httpClient',
      'notifications',
      'fileAccess',
      'knowledgeRetrieval',
      'weatherData',
      'newsData',
      'aiInference',
    };
    return knownTypes.contains(type);
  }

  Future<Map<String, dynamic>> _executeClock(
    String operation,
    Map<String, dynamic> params,
  ) async {
    switch (operation) {
      case 'now':
        return {'timestamp': DateTime.now().toIso8601String()};
      case 'date':
        final now = DateTime.now();
        return {'year': now.year, 'month': now.month, 'day': now.day};
      default:
        return {'error': 'Unknown clock operation: $operation'};
    }
  }

  Future<Map<String, dynamic>> _executeDatabase(
    String operation,
    Map<String, dynamic> params,
  ) async {
    // Stage 7: placeholder for database operations
    return {'status': 'not_implemented'};
  }

  Future<Map<String, dynamic>> _executeHttp(
    String operation,
    Map<String, dynamic> params,
  ) async {
    // Stage 7: placeholder for HTTP operations
    return {'status': 'not_implemented'};
  }
}

class _ServiceEntry {
  final String id;
  final String type;
  final Map<String, dynamic> config;
  final bool available;

  const _ServiceEntry({
    required this.id,
    required this.type,
    required this.config,
    required this.available,
  });
}
