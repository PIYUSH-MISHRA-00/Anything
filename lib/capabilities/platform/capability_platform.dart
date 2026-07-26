/// Capability Platform — manages and executes trusted capabilities.
library;

import 'dart:async';

/// Status of a capability invocation.
enum CapabilityResultStatus {
  success,
  unavailable,
  permissionDenied,
  unsupported,
  cancelled,
  invalidArguments,
  policyDenied,
  timeout,
  failed,
}

/// Result of a capability invocation.
class CapabilityInvocationResult {
  final CapabilityResultStatus status;
  final Map<String, dynamic> data;
  final String? error;
  const CapabilityInvocationResult({
    required this.status,
    this.data = const {},
    this.error,
  });
  factory CapabilityInvocationResult.success({
    Map<String, dynamic> data = const {},
  }) => CapabilityInvocationResult(
    status: CapabilityResultStatus.success,
    data: data,
  );
  factory CapabilityInvocationResult.failure(String error) =>
      CapabilityInvocationResult(
        status: CapabilityResultStatus.failed,
        error: error,
      );
}

/// A registered capability in the platform.
abstract class PlatformCapability {
  final String id;
  final String name;
  final String description;
  final List<String> supportedOperations;
  const PlatformCapability({
    required this.id,
    required this.name,
    required this.description,
    required this.supportedOperations,
  });
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  );
}

/// The Capability Platform.
class CapabilityPlatform {
  final Map<String, PlatformCapability> _capabilities = {};
  final Map<String, Map<String, int>> _sessionCounts =
      {}; // sessionId -> capId -> count
  static const int _maxInvocationsPerCapability = 100;

  void register(PlatformCapability capability) {
    _capabilities[capability.id] = capability;
  }

  bool isRegistered(String capabilityId) =>
      _capabilities.containsKey(capabilityId);

  PlatformCapability? getCapability(String capabilityId) =>
      _capabilities[capabilityId];

  /// Invoke a capability operation with session-scoped budget.
  Future<CapabilityInvocationResult> invoke(
    String capabilityId,
    String operation,
    Map<String, dynamic> params, {
    List<String>? declaredCapabilities,
    String? sessionId,
  }) async {
    if (declaredCapabilities != null &&
        !declaredCapabilities.contains(capabilityId)) {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Capability not declared: $capabilityId',
      );
    }
    final cap = _capabilities[capabilityId];
    if (cap == null) {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.unsupported,
        error: 'Unknown capability: $capabilityId',
      );
    }

    // Session-scoped budget check
    final sid = sessionId ?? 'default';
    _sessionCounts.putIfAbsent(sid, () => {});
    final count = _sessionCounts[sid]![capabilityId] ?? 0;
    if (count >= _maxInvocationsPerCapability) {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.policyDenied,
        error: 'Invocation limit exceeded',
      );
    }
    if (!cap.supportedOperations.contains(operation)) {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.unsupported,
        error: 'Unsupported operation: $operation',
      );
    }
    try {
      _sessionCounts[sid]![capabilityId] = count + 1;
      return await cap.execute(operation, params);
    } catch (e) {
      return CapabilityInvocationResult.failure(e.toString());
    }
  }

  /// Reset counts for a specific session.
  void resetSession(String sessionId) => _sessionCounts.remove(sessionId);

  /// Reset all counts.
  void resetCounts() => _sessionCounts.clear();
  List<PlatformCapability> get all => _capabilities.values.toList();
}
